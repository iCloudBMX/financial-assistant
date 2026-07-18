import 'package:flutter/material.dart';

import 'app_lock_controller.dart';

/// Blocks [child] behind a PIN/biometric prompt until the user unlocks the
/// app. Requires unlock on cold start (when [enabled] is true) and again
/// whenever the app resumes after being paused longer than [lockTimeout]
/// (spec sec. 22.3 -- app-lock). [child] is only ever built after a
/// successful unlock, so no sensitive widget tree exists while locked.
///
/// This widget is self-contained: it does not read app settings or
/// construct its own [AppLockController]. The composition root (Task 15)
/// is responsible for wiring `settings.appLockEnabled` / `.biometricEnabled`
/// into [enabled] / [biometricEnabled] and supplying a real controller
/// backed by [SecureSecretStore].
class AppLockGate extends StatefulWidget {
  final Widget child;
  final AppLockController controller;
  final bool enabled;
  final bool biometricEnabled;
  final Duration lockTimeout;

  const AppLockGate({
    super.key,
    required this.child,
    required this.controller,
    this.enabled = false,
    this.biometricEnabled = false,
    this.lockTimeout = const Duration(seconds: 30),
  });

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  late bool _unlocked;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Cold start: locked whenever app-lock is enabled, otherwise there is
    // nothing to unlock.
    _unlocked = !widget.enabled;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enabled) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Only record the moment we first left the foreground; the platform
      // may report inactive then paused in the same backgrounding.
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt != null &&
          DateTime.now().difference(pausedAt) > widget.lockTimeout) {
        setState(() => _unlocked = false);
      }
    }
  }

  void _handleUnlocked() => setState(() => _unlocked = true);

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;
    return _LockScreen(
      controller: widget.controller,
      biometricEnabled: widget.biometricEnabled,
      onUnlocked: _handleUnlocked,
    );
  }
}

class _LockScreen extends StatefulWidget {
  final AppLockController controller;
  final bool biometricEnabled;
  final VoidCallback onUnlocked;

  const _LockScreen({
    required this.controller,
    required this.biometricEnabled,
    required this.onUnlocked,
  });

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  final _pinController = TextEditingController();
  String? _error;
  bool _checking = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submitPin() async {
    final pin = _pinController.text;
    if (pin.isEmpty) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    final ok = await widget.controller.verifyPin(pin);
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
      return;
    }
    setState(() {
      _checking = false;
      _error = "PIN kod noto'g'ri";
    });
  }

  Future<void> _tryBiometric() async {
    setState(() => _checking = true);
    final ok = await widget.controller.authenticateBiometric();
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
      return;
    }
    setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 16),
                const Text('Ilova qulflangan'),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('app_lock_pin_field'),
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  enabled: !_checking,
                  decoration: InputDecoration(
                    labelText: 'PIN kod',
                    errorText: _error,
                  ),
                  onSubmitted: (_) => _submitPin(),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  key: const Key('app_lock_unlock_button'),
                  onPressed: _checking ? null : _submitPin,
                  child: const Text('Ochish'),
                ),
                if (widget.biometricEnabled) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    key: const Key('app_lock_biometric_button'),
                    onPressed: _checking ? null : _tryBiometric,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Biometrik orqali ochish'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
