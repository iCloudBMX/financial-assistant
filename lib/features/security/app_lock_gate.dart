import 'package:flutter/material.dart';

import '../../core/theme/velora_tokens.dart';
import 'app_lock_controller.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.biometricEnabled) {
      // Exactly once per lock entry, and only after the first frame is up
      // (never from `build`) -- calling this from `build` would re-launch
      // the native prompt on every unrelated rebuild.
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
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
  }

  void _onDigit(int d) {
    if (_checking || _digits.length >= 4) return;
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      key: const Key('app_lock_keypad'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(VeloraSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: colorScheme.primary),
                const SizedBox(height: VeloraSpacing.lg),
                const Text('Ilova qulflangan'),
                const SizedBox(height: VeloraSpacing.xl),
                _PinDots(filled: _digits.length, error: _error != null),
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
                _Keypad(
                  enabled: !_checking,
                  onDigit: _onDigit,
                  onBackspace: _onBackspace,
                  showBiometric: widget.biometricEnabled,
                  onBiometricRetry: _tryBiometric,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.filled, required this.error});

  final int filled;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = error ? colorScheme.error : colorScheme.primary;
    return Semantics(
      label: '$filled / 4 raqam kiritildi',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: VeloraSpacing.sm,
                ),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < filled ? color : Colors.transparent,
                    border: Border.all(color: color, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
    required this.showBiometric,
    required this.onBiometricRetry,
  });

  final bool enabled;
  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;
  final bool showBiometric;
  final VoidCallback onBiometricRetry;

  @override
  Widget build(BuildContext context) {
    Widget digitButton(int d) => _KeypadButton(
          key: Key('app_lock_key_$d'),
          onPressed: enabled ? () => onDigit(d) : null,
          semanticLabel: '$d raqami',
          child: Text('$d'),
        );

    Widget row(List<Widget> children) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: children,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([digitButton(1), digitButton(2), digitButton(3)]),
        const SizedBox(height: VeloraSpacing.md),
        row([digitButton(4), digitButton(5), digitButton(6)]),
        const SizedBox(height: VeloraSpacing.md),
        row([digitButton(7), digitButton(8), digitButton(9)]),
        const SizedBox(height: VeloraSpacing.md),
        row([
          if (showBiometric)
            _KeypadButton(
              key: const Key('app_lock_biometric_retry'),
              onPressed: enabled ? onBiometricRetry : null,
              semanticLabel: "Biometrik orqali qayta urinish",
              child: const Icon(Icons.fingerprint),
            )
          else
            const SizedBox(width: 56, height: 56),
          digitButton(0),
          _KeypadButton(
            key: const Key('app_lock_key_backspace'),
            onPressed: enabled ? onBackspace : null,
            semanticLabel: "Bitta raqamni o'chirish",
            child: const Icon(Icons.backspace_outlined),
          ),
        ]),
      ],
    );
  }
}

/// A single keypad key. Digit glyphs opt out of system text scaling so the
/// 56x56 touch target (>= the 48x48 minimum) never overflows at 200% text
/// scale -- the key stays a fixed, thumb-reachable size regardless.
class _KeypadButton extends StatelessWidget {
  const _KeypadButton({
    super.key,
    required this.onPressed,
    required this.child,
    required this.semanticLabel,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      enabled: onPressed != null,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: ExcludeSemantics(
              child: Center(
                child: MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.noScaling),
                  child: DefaultTextStyle.merge(
                    style: Theme.of(context).textTheme.headlineSmall,
                    child: IconTheme.merge(
                      data: const IconThemeData(size: 24),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
