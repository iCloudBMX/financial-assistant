import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/velora_tokens.dart';
import 'app_lock_controller.dart';
import 'pin_keypad.dart';

/// Blocks [child] behind a PIN/biometric prompt until the user unlocks the
/// app. Requires unlock on cold start (when [enabled] is true) and again
/// whenever the app resumes after being paused longer than [lockTimeout]
/// (spec sec. 22.3 -- app-lock). [child] is only ever built after a
/// successful unlock, so no sensitive widget tree exists while locked.
///
/// This widget is self-contained: it does not read app settings or
/// construct its own [AppLockController]. The composition root wires
/// `settings.appLockEnabled` / `.biometricEnabled` into [enabled] /
/// [biometricEnabled] and supplies a real controller backed by
/// [SecureSecretStore]. The background privacy shield (hiding content in
/// the OS app switcher) is a separate, independent concern implemented by
/// `BackgroundShield`, which the composition root wraps around this gate.
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
    // No `key` here: when `_unlocked` flips from true back to false the
    // widget at this tree position changes type (from `widget.child` to
    // `_LockScreen`), so Flutter always mounts a fresh `_LockScreenState`.
    // That is what makes the auto-biometric-on-entry contract ("exactly
    // once per lock entry") hold without any extra bookkeeping here.
    return _LockScreen(
      controller: widget.controller,
      biometricEnabled: widget.biometricEnabled,
      onUnlocked: _handleUnlocked,
    );
  }
}

/// PIN-first lock screen (design spec sec. 6.13): a four-digit numeric
/// keypad that submits automatically after the fourth digit -- there is no
/// submit button. When biometrics are enabled, the native OS prompt is
/// launched exactly once automatically on entry (from a post-frame
/// callback, never from `build`), and the fingerprint icon retries it. No
/// custom biometric dialog is ever rendered; `controller.authenticateBiometric`
/// is the only thing that talks to the platform prompt.
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
  final List<int> _digits = [];
  String? _error;
  bool _checking = false;
  Duration _lockout = Duration.zero;
  Timer? _lockTimer;

  @override
  void initState() {
    super.initState();
    _refreshLockout();
    if (widget.biometricEnabled) {
      // Exactly once per lock entry, and only after the first frame is up
      // (never from `build`) -- calling this from `build` would re-launch
      // the native prompt on every unrelated rebuild.
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshLockout() async {
    final remaining = await widget.controller.lockoutRemaining();
    if (!mounted) return;
    setState(() => _lockout = remaining);
    _lockTimer?.cancel();
    if (remaining > Duration.zero) {
      _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final next = _lockout - const Duration(seconds: 1);
        setState(() => _lockout = next > Duration.zero ? next : Duration.zero);
        if (_lockout == Duration.zero) _lockTimer?.cancel();
      });
    }
  }

  String _formatLockout(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _tryBiometric() async {
    if (!mounted || _checking) return;
    setState(() => _checking = true);
    final ok = await widget.controller.authenticateBiometric();
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
      return;
    }
    setState(() => _checking = false);
  }

  Future<void> _submit() async {
    setState(() => _checking = true);
    final pin = _digits.join();
    final ok = await widget.controller.verifyPin(pin);
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
      return;
    }
    // Wrong PIN: reset the entry back to empty rather than leaving the
    // wrong digits in place.
    setState(() {
      _checking = false;
      _digits.clear();
      _error = "PIN kod noto'g'ri";
    });
    _refreshLockout();
  }

  void _onDigit(int d) {
    if (_checking || _lockout > Duration.zero || _digits.length >= 4) return;
    setState(() {
      _digits.add(d);
      _error = null;
    });
    if (_digits.length == 4) _submit();
  }

  void _onBackspace() {
    if (_checking || _digits.isEmpty) return;
    setState(() => _digits.removeLast());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      key: const Key('app_lock_keypad'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(VeloraSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The Velora brand mark: a plum tile + wordmark, so the lock
                // screen reads as "Velora, locked" rather than a bare OS
                // prompt (design spec sec. 6.13).
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: VeloraColors.plum,
                        borderRadius:
                            BorderRadius.circular(VeloraRadii.control),
                      ),
                      child: const Text(
                        'V',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: VeloraSpacing.sm),
                    Text(
                      'Velora',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: VeloraSpacing.xl),
                Text(
                  'Ilova qulflangan',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: VeloraSpacing.xs),
                Text(
                  'PIN kodni kiriting',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: VeloraColors.muted,
                  ),
                ),
                const SizedBox(height: VeloraSpacing.xl),
                PinDots(filled: _digits.length, error: _error != null),
                const SizedBox(height: VeloraSpacing.md),
                SizedBox(
                  height: 20,
                  child: _error == null
                      ? null
                      : Text(
                          _error!,
                          style: TextStyle(color: colorScheme.error),
                        ),
                ),
                const SizedBox(height: VeloraSpacing.xl),
                PinKeypad(
                  enabled: !_checking && _lockout == Duration.zero,
                  onDigit: _onDigit,
                  onBackspace: _onBackspace,
                  showBiometric: widget.biometricEnabled,
                  biometricEnabled: !_checking,
                  onBiometricRetry: _tryBiometric,
                ),
                if (_lockout > Duration.zero) ...[
                  const SizedBox(height: VeloraSpacing.lg),
                  Text(
                    'Juda ko\'p urinish. Qayta urinib ko\'ring: '
                    '${_formatLockout(_lockout)}',
                    key: const Key('app_lock_lockout'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.error),
                  ),
                ],
                if (widget.biometricEnabled) ...[
                  const SizedBox(height: VeloraSpacing.lg),
                  Text(
                    'Biometrika qurilma orqali avtomatik ishlaydi',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: VeloraColors.muted,
                    ),
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

