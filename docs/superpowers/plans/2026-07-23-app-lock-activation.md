# App Lock activation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the already-built PIN-first App Lock its two missing entry points (Settings toggle + onboarding step) plus brute-force backoff, so a user can actually set a PIN and turn the lock on.

**Architecture:** The lock engine (`AppLockController`), keypad lock screen (`AppLockGate`), and composition-root wiring (`app.dart`) already exist and are correct. This plan (1) extracts the private keypad into a shared widget, (2) adds a reusable PIN-setup modal used by both new entry points, (3) adds persisted backoff + `clearPin` to the controller, (4) makes the lock screen honor lockout, (5) replaces the two neutralized Settings placeholders with live switches, and (6) adds a skippable onboarding security step. No schema change — PIN + backoff state live in device secure storage.

**Tech Stack:** Flutter, Riverpod 3.3 (`flutter_riverpod` + `legacy.dart` for `StateNotifier`), `flutter_secure_storage`, `crypto` (SHA-256), `local_auth`. Tests: `flutter_test`, Drift `NativeDatabase.memory()`.

## Global Constraints

- All user-facing strings are Uzbek (Latin), matching existing screens.
- Run tests with `flutter test --concurrency=1` (default concurrency drops suites on the Windows dev box).
- No new dependency, no SQLite schema change. Secrets never touch SQLite.
- `AppLockController.verifyPin` keeps its `Future<bool>` signature (existing tests and `AppLockGate` depend on it).
- Keypad widget keys stay `app_lock_key_$d`, `app_lock_key_backspace`, `app_lock_biometric_retry` so existing `app_lock_gate_test.dart` passes unchanged.
- Design spec: `docs/superpowers/specs/2026-07-23-app-lock-activation-design.md`.

---

### Task 1: Controller — `clearPin` + persisted backoff

**Files:**
- Modify: `lib/features/security/app_lock_controller.dart`
- Test: `test/features/security/app_lock_controller_test.dart`

**Interfaces:**
- Consumes: existing `SecretStore`, `PinHasher`, `AppLockController(this.store, [LocalAuthentication? auth])`.
- Produces:
  - `AppLockController(SecretStore store, [LocalAuthentication? auth, DateTime Function()? clock])`
  - `Future<void> clearPin()`
  - `Future<Duration> lockoutRemaining()`
  - `static Duration lockoutFor(int failCount)`
  - `verifyPin(String)` unchanged signature, now backoff-aware.

- [ ] **Step 1: Write the failing tests**

Append to `test/features/security/app_lock_controller_test.dart` (the file already defines `FakeStore`):

```dart
  test('clearPin removes the stored PIN so verify fails afterward', () async {
    final c = AppLockController(FakeStore());
    await c.setPin('1234');
    expect(await c.verifyPin('1234'), isTrue);
    await c.clearPin();
    expect(await c.verifyPin('1234'), isFalse);
  });

  test('lockoutFor: no lockout below threshold, escalates, then caps at 15m',
      () {
    expect(AppLockController.lockoutFor(4), Duration.zero);
    expect(AppLockController.lockoutFor(5), const Duration(seconds: 30));
    expect(AppLockController.lockoutFor(6), const Duration(seconds: 60));
    expect(AppLockController.lockoutFor(7), const Duration(seconds: 120));
    expect(AppLockController.lockoutFor(50), const Duration(minutes: 15));
  });

  test('four wrong attempts do not lock out; a correct PIN still verifies',
      () async {
    final c = AppLockController(FakeStore());
    await c.setPin('1234');
    for (var i = 0; i < 4; i++) {
      expect(await c.verifyPin('0000'), isFalse);
    }
    expect(await c.lockoutRemaining(), Duration.zero);
    expect(await c.verifyPin('1234'), isTrue);
  });

  test('the fifth wrong attempt locks out and refuses even the correct PIN',
      () async {
    var now = DateTime(2026, 1, 1, 12);
    final c = AppLockController(FakeStore(), null, () => now);
    await c.setPin('1234');
    for (var i = 0; i < 5; i++) {
      expect(await c.verifyPin('0000'), isFalse);
    }
    expect(await c.lockoutRemaining(), greaterThan(Duration.zero));
    // Correct PIN is refused while the lockout is active.
    expect(await c.verifyPin('1234'), isFalse);
    // After the cooldown elapses, the correct PIN works again.
    now = now.add(const Duration(seconds: 31));
    expect(await c.verifyPin('1234'), isTrue);
  });

  test('a successful verify resets the fail counter', () async {
    final c = AppLockController(FakeStore());
    await c.setPin('1234');
    for (var i = 0; i < 4; i++) {
      await c.verifyPin('0000');
    }
    expect(await c.verifyPin('1234'), isTrue); // resets counter
    // One more wrong attempt must not immediately re-lock (counter reset to 0).
    expect(await c.verifyPin('0000'), isFalse);
    expect(await c.lockoutRemaining(), Duration.zero);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test --concurrency=1 test/features/security/app_lock_controller_test.dart`
Expected: FAIL — `clearPin`, `lockoutFor`, `lockoutRemaining` undefined; the 3-arg constructor doesn't exist.

- [ ] **Step 3: Implement the additions**

In `lib/features/security/app_lock_controller.dart`, add `import 'dart:async';` is not needed (Duration is core). Update the class:

```dart
class AppLockController {
  final SecretStore store;
  final LocalAuthentication _auth;
  final DateTime Function() _clock;

  AppLockController(this.store,
      [LocalAuthentication? auth, DateTime Function()? clock])
      : _auth = auth ?? LocalAuthentication(),
        _clock = clock ?? DateTime.now;

  static const _pinKey = 'app_lock_pin_hash';
  static const _saltKey = 'app_lock_salt';
  static const _failKey = 'app_lock_fail_count';
  static const _lockedUntilKey = 'app_lock_locked_until';

  /// Wrong attempts allowed before the first lockout arms.
  static const _lockThreshold = 5;

  Future<void> setPin(String pin) async {
    final rng = Random.secure();
    final salt =
        base64Url.encode(List<int>.generate(16, (_) => rng.nextInt(256)));
    await store.write(_saltKey, salt);
    await store.write(_pinKey, PinHasher.hash(pin, salt));
    await store.write(_failKey, '0');
    await store.write(_lockedUntilKey, '');
  }

  /// Removes the PIN, salt, and all backoff state. Used when the user turns
  /// App Lock off from Settings. `SecretStore` has no delete, so an empty
  /// string is the "unset" sentinel; `verifyPin` treats empty salt/hash as
  /// no-PIN.
  Future<void> clearPin() async {
    await store.write(_pinKey, '');
    await store.write(_saltKey, '');
    await store.write(_failKey, '');
    await store.write(_lockedUntilKey, '');
  }

  Future<bool> verifyPin(String pin) async {
    // Refuse without hashing while a lockout is active. This is the whole
    // point of the backoff -- a correct PIN must not unlock during cooldown.
    if (await lockoutRemaining() > Duration.zero) return false;

    final salt = await store.read(_saltKey);
    final stored = await store.read(_pinKey);
    if (salt == null || salt.isEmpty || stored == null || stored.isEmpty) {
      return false;
    }
    if (PinHasher.hash(pin, salt) == stored) {
      await store.write(_failKey, '0');
      await store.write(_lockedUntilKey, '');
      return true;
    }
    final fails = (int.tryParse(await store.read(_failKey) ?? '') ?? 0) + 1;
    await store.write(_failKey, '$fails');
    final cooldown = lockoutFor(fails);
    if (cooldown > Duration.zero) {
      final until = _clock().add(cooldown).millisecondsSinceEpoch;
      await store.write(_lockedUntilKey, '$until');
    }
    return false;
  }

  /// Time left on the current lockout, or [Duration.zero] if not locked.
  Future<Duration> lockoutRemaining() async {
    final until = int.tryParse(await store.read(_lockedUntilKey) ?? '');
    if (until == null) return Duration.zero;
    final ms = until - _clock().millisecondsSinceEpoch;
    return ms > 0 ? Duration(milliseconds: ms) : Duration.zero;
  }

  /// Escalating cooldown: nothing below the threshold, then 30s doubling per
  /// extra failure, capped at 15 minutes. Pure so it is unit-testable.
  static Duration lockoutFor(int failCount) {
    if (failCount < _lockThreshold) return Duration.zero;
    final steps = failCount - _lockThreshold;
    if (steps >= 5) return const Duration(minutes: 15);
    return Duration(seconds: 30 * (1 << steps));
  }

  Future<bool> authenticateBiometric() async {
    // ... unchanged ...
  }
}
```

Leave `authenticateBiometric` exactly as-is.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test --concurrency=1 test/features/security/app_lock_controller_test.dart`
Expected: PASS (all old + 5 new tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/security/app_lock_controller.dart test/features/security/app_lock_controller_test.dart
git commit -m "feat(security): add clearPin + persisted brute-force backoff to AppLockController"
```

---

### Task 2: Extract the shared keypad into `pin_keypad.dart`

Pure refactor: move the three private keypad widgets out of `app_lock_gate.dart` so the setup flow can reuse them. Existing gate tests are the regression guard — they must stay green with no edits.

**Files:**
- Create: `lib/features/security/pin_keypad.dart`
- Modify: `lib/features/security/app_lock_gate.dart`
- Test (regression, unchanged): `test/features/security/app_lock_gate_test.dart`

**Interfaces:**
- Produces (public, in `pin_keypad.dart`):
  - `PinDots({required int filled, required bool error, int length = 4})`
  - `PinKeypad({required bool enabled, required ValueChanged<int> onDigit, required VoidCallback onBackspace, bool showBiometric = false, VoidCallback? onBiometricRetry})`
  - `PinKeypadButton` (internal to the file; not exported for consumers).

- [ ] **Step 1: Confirm the regression baseline is green**

Run: `flutter test --concurrency=1 test/features/security/app_lock_gate_test.dart`
Expected: PASS (this is the baseline the refactor must preserve).

- [ ] **Step 2: Create `lib/features/security/pin_keypad.dart`**

Move `_PinDots`, `_Keypad`, `_KeypadButton` here verbatim, renamed to public `PinDots`, `PinKeypad`, `PinKeypadButton`. Add a `length` param to `PinDots` (default 4). Keep every widget key identical.

```dart
import 'package:flutter/material.dart';

import '../../core/theme/velora_tokens.dart';

/// Row of PIN entry dots, shared by the lock screen and the PIN-setup sheet.
class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.filled,
    required this.error,
    this.length = 4,
  });

  final int filled;
  final bool error;
  final int length;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = error ? colorScheme.error : colorScheme.primary;
    return Semantics(
      label: '$filled / $length raqam kiritildi',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < length; i++)
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

/// The 0-9 keypad with a backspace and an optional biometric-retry key.
/// Digit keys carry `Key('app_lock_key_$d')` so both the lock screen and
/// its existing widget tests keep working after the extraction.
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
    this.showBiometric = false,
    this.onBiometricRetry,
  });

  final bool enabled;
  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;
  final bool showBiometric;
  final VoidCallback? onBiometricRetry;

  @override
  Widget build(BuildContext context) {
    Widget digitButton(int d) => PinKeypadButton(
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
            PinKeypadButton(
              key: const Key('app_lock_biometric_retry'),
              onPressed: enabled ? onBiometricRetry : null,
              semanticLabel: 'Biometrik orqali qayta urinish',
              child: const Icon(Icons.fingerprint, color: VeloraColors.plum),
            )
          else
            const SizedBox(width: 56, height: 56),
          digitButton(0),
          PinKeypadButton(
            key: const Key('app_lock_key_backspace'),
            onPressed: enabled ? onBackspace : null,
            semanticLabel: "Bitta raqamni o'chirish",
            child:
                const Icon(Icons.backspace_outlined, color: VeloraColors.plum),
          ),
        ]),
      ],
    );
  }
}

/// A single 56x56 keypad key; digit glyphs opt out of system text scaling so
/// the fixed touch target never overflows at 200% scale.
class PinKeypadButton extends StatelessWidget {
  const PinKeypadButton({
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VeloraRadii.control),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(VeloraRadii.control),
            onTap: onPressed,
            child: ExcludeSemantics(
              child: Center(
                child: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.noScaling),
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
```

- [ ] **Step 3: Update `app_lock_gate.dart` to consume the shared keypad**

- Add `import 'pin_keypad.dart';` near the existing imports.
- Delete the private `_PinDots`, `_Keypad`, `_KeypadButton` class definitions (bottom of the file).
- In `_LockScreenState.build`, replace `_PinDots(filled: _digits.length, error: _error != null)` with `PinDots(filled: _digits.length, error: _error != null)`.
- Replace the `_Keypad(...)` usage with:

```dart
                PinKeypad(
                  enabled: !_checking,
                  onDigit: _onDigit,
                  onBackspace: _onBackspace,
                  showBiometric: widget.biometricEnabled,
                  onBiometricRetry: _tryBiometric,
                ),
```

- [ ] **Step 4: Run the regression tests + analyze**

Run: `flutter test --concurrency=1 test/features/security/app_lock_gate_test.dart`
Expected: PASS (unchanged behavior).
Run: `flutter analyze lib/features/security`
Expected: no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/security/pin_keypad.dart lib/features/security/app_lock_gate.dart
git commit -m "refactor(security): extract shared PinKeypad/PinDots from AppLockGate"
```

---

### Task 3: Reusable PIN-setup sheet

**Files:**
- Create: `lib/features/security/pin_setup_sheet.dart`
- Test: `test/features/security/pin_setup_sheet_test.dart`

**Interfaces:**
- Consumes: `AppLockController.setPin` (Task 1 baseline), `PinDots`, `PinKeypad` (Task 2).
- Produces: `Future<bool> showPinSetup(BuildContext context, AppLockController controller)` — resolves `true` after a confirmed PIN is stored, `false` if dismissed. Setup keypad keys are `pin_setup_key_$d`; sheet root key is `pin_setup_sheet`.

- [ ] **Step 1: Write the failing test**

Create `test/features/security/pin_setup_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/features/security/app_lock_controller.dart';
import 'package:financial_assistant/features/security/pin_setup_sheet.dart';

class FakeStore implements SecretStore {
  final _m = <String, String>{};
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String value) async => _m[key] = value;
}

Future<void> _tap(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.byKey(Key('pin_setup_key_$d')));
    await tester.pump();
  }
}

void main() {
  testWidgets('entering then confirming the same PIN stores it and returns true',
      (tester) async {
    final controller = AppLockController(FakeStore());
    bool? result;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showPinSetup(context, controller);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pin_setup_sheet')), findsOneWidget);

    await _tap(tester, '1234'); // enter
    await tester.pumpAndSettle();
    await _tap(tester, '1234'); // confirm
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(await controller.verifyPin('1234'), isTrue);
  });

  testWidgets('a mismatched confirmation shows an error and stores nothing',
      (tester) async {
    final controller = AppLockController(FakeStore());

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showPinSetup(context, controller),
            child: const Text('open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await _tap(tester, '1234'); // enter
    await tester.pumpAndSettle();
    await _tap(tester, '0000'); // wrong confirm
    await tester.pumpAndSettle();

    expect(find.text('PIN kod mos kelmadi'), findsOneWidget);
    expect(find.byKey(const Key('pin_setup_sheet')), findsOneWidget); // still open
    expect(await controller.verifyPin('1234'), isFalse);
    expect(await controller.verifyPin('0000'), isFalse);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test --concurrency=1 test/features/security/pin_setup_sheet_test.dart`
Expected: FAIL — `pin_setup_sheet.dart` / `showPinSetup` do not exist.

- [ ] **Step 3: Implement `lib/features/security/pin_setup_sheet.dart`**

```dart
import 'package:flutter/material.dart';

import '../../core/theme/velora_tokens.dart';
import 'app_lock_controller.dart';
import 'pin_keypad.dart';

/// Two-stage PIN setup (enter -> confirm) used by both the Settings App Lock
/// toggle and the onboarding security step. Resolves `true` once a confirmed
/// PIN has been written via [AppLockController.setPin], `false` if the user
/// dismisses the sheet. Nothing is stored unless the two entries match.
Future<bool> showPinSetup(
  BuildContext context,
  AppLockController controller,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PinSetupSheet(controller: controller),
  );
  return result ?? false;
}

class _PinSetupSheet extends StatefulWidget {
  const _PinSetupSheet({required this.controller});
  final AppLockController controller;

  @override
  State<_PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends State<_PinSetupSheet> {
  final List<int> _digits = [];
  String? _first; // null while in the "enter" stage
  String? _error;
  bool _busy = false;

  bool get _confirming => _first != null;

  void _onDigit(int d) {
    if (_busy || _digits.length >= 4) return;
    setState(() {
      _digits.add(d);
      _error = null;
    });
    if (_digits.length == 4) _advance();
  }

  void _onBackspace() {
    if (_busy || _digits.isEmpty) return;
    setState(() => _digits.removeLast());
  }

  Future<void> _advance() async {
    final entered = _digits.join();
    if (!_confirming) {
      // First stage done: remember it and ask for confirmation.
      setState(() {
        _first = entered;
        _digits.clear();
      });
      return;
    }
    if (entered != _first) {
      // Mismatch: restart from the enter stage.
      setState(() {
        _first = null;
        _digits.clear();
        _error = 'PIN kod mos kelmadi';
      });
      return;
    }
    setState(() => _busy = true);
    await widget.controller.setPin(entered);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      key: const Key('pin_setup_sheet'),
      child: Padding(
        padding: const EdgeInsets.all(VeloraSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _confirming ? 'PIN kodni tasdiqlang' : 'PIN kod o\'rnating',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: VeloraSpacing.xs),
            Text(
              _confirming
                  ? 'Xuddi shu 4 raqamni qayta kiriting'
                  : '4 raqamli PIN kod tanlang',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: VeloraColors.muted),
            ),
            const SizedBox(height: VeloraSpacing.xl),
            PinDots(filled: _digits.length, error: _error != null),
            const SizedBox(height: VeloraSpacing.md),
            SizedBox(
              height: 20,
              child: _error == null
                  ? null
                  : Text(_error!,
                      style: TextStyle(color: theme.colorScheme.error)),
            ),
            const SizedBox(height: VeloraSpacing.lg),
            // Setup keypad uses its own key namespace so tests can target it
            // independently of the lock screen's `app_lock_key_*`.
            _SetupKeypad(
              enabled: !_busy,
              onDigit: _onDigit,
              onBackspace: _onBackspace,
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin wrapper that renders [PinKeypad]'s layout but with `pin_setup_key_*`
/// keys. Reuses PinKeypadButton so styling stays identical to the lock screen.
class _SetupKeypad extends StatelessWidget {
  const _SetupKeypad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  final bool enabled;
  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    Widget digit(int d) => PinKeypadButton(
          key: Key('pin_setup_key_$d'),
          onPressed: enabled ? () => onDigit(d) : null,
          semanticLabel: '$d raqami',
          child: Text('$d'),
        );
    Widget row(List<Widget> c) =>
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: c);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([digit(1), digit(2), digit(3)]),
        const SizedBox(height: VeloraSpacing.md),
        row([digit(4), digit(5), digit(6)]),
        const SizedBox(height: VeloraSpacing.md),
        row([digit(7), digit(8), digit(9)]),
        const SizedBox(height: VeloraSpacing.md),
        row([
          const SizedBox(width: 56, height: 56),
          digit(0),
          PinKeypadButton(
            key: const Key('pin_setup_key_backspace'),
            onPressed: enabled ? onBackspace : null,
            semanticLabel: "Bitta raqamni o'chirish",
            child:
                const Icon(Icons.backspace_outlined, color: VeloraColors.plum),
          ),
        ]),
      ],
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test --concurrency=1 test/features/security/pin_setup_sheet_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/security/pin_setup_sheet.dart test/features/security/pin_setup_sheet_test.dart
git commit -m "feat(security): reusable PIN-setup sheet (enter + confirm)"
```

---

### Task 4: Lock screen honors lockout

**Files:**
- Modify: `lib/features/security/app_lock_gate.dart`
- Test: `test/features/security/app_lock_gate_test.dart`

**Interfaces:**
- Consumes: `AppLockController.lockoutRemaining` (Task 1).
- Produces: lock screen shows a countdown (widget key `app_lock_lockout`) and disables the keypad while locked out.

- [ ] **Step 1: Write the failing test**

Add to `test/features/security/app_lock_gate_test.dart`. First extend the existing `_FakeAppLockController` with an overridable lockout:

```dart
class _FakeAppLockController extends AppLockController {
  _FakeAppLockController() : super(_FakeStore());

  int biometricCalls = 0;
  bool biometricResult = false;
  Duration lockout = Duration.zero;

  @override
  Future<bool> authenticateBiometric() async {
    biometricCalls++;
    return biometricResult;
  }

  @override
  Future<Duration> lockoutRemaining() async => lockout;
}
```

Then add the test:

```dart
  testWidgets(
      'while locked out, the keypad is disabled, a countdown shows, and the '
      'correct PIN does not unlock', (tester) async {
    controller.lockout = const Duration(seconds: 45);
    await pumpGate(tester);
    await tester.pump();

    expect(find.byKey(const Key('app_lock_lockout')), findsOneWidget);

    // Digit keys are disabled (no unlock even with the correct PIN).
    await _tapDigits(tester, '1234');
    await tester.pumpAndSettle();
    expect(find.text('Unlocked home'), findsNothing);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test --concurrency=1 test/features/security/app_lock_gate_test.dart`
Expected: FAIL — no `app_lock_lockout` widget; keypad still enabled so the correct PIN unlocks.

- [ ] **Step 3: Implement lockout handling in `_LockScreenState`**

Add `import 'dart:async';` at the top of `app_lock_gate.dart`. In `_LockScreenState`:

```dart
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
```

Update `_submit` so a wrong PIN re-reads the lockout (a wrong attempt may have just armed one):

```dart
  Future<void> _submit() async {
    setState(() => _checking = true);
    final pin = _digits.join();
    final ok = await widget.controller.verifyPin(pin);
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
      return;
    }
    setState(() {
      _checking = false;
      _digits.clear();
      _error = "PIN kod noto'g'ri";
    });
    _refreshLockout();
  }
```

Guard digit entry while locked:

```dart
  void _onDigit(int d) {
    if (_checking || _lockout > Duration.zero || _digits.length >= 4) return;
    setState(() {
      _digits.add(d);
      _error = null;
    });
    if (_digits.length == 4) _submit();
  }
```

In `build`, disable the keypad and add the countdown message. Change the `PinKeypad` `enabled` and insert the lockout text below the error `SizedBox`:

```dart
                PinKeypad(
                  enabled: !_checking && _lockout == Duration.zero,
                  onDigit: _onDigit,
                  onBackspace: _onBackspace,
                  showBiometric: widget.biometricEnabled,
                  onBiometricRetry:
                      _lockout == Duration.zero ? _tryBiometric : () {},
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test --concurrency=1 test/features/security/app_lock_gate_test.dart`
Expected: PASS (all prior tests + the new lockout test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/security/app_lock_gate.dart test/features/security/app_lock_gate_test.dart
git commit -m "feat(security): lock screen honors backoff lockout with countdown"
```

---

### Task 5: Live Settings toggles (App Lock + Biometric)

**Files:**
- Modify: `lib/features/settings/settings_screen.dart:411-436` (the "Maxfiylik va xavfsizlik" group and its neutralization comment)
- Test: `test/features/settings/settings_screen_test.dart` (replace the stale "disabled placeholders" test)

**Interfaces:**
- Consumes: `showPinSetup` (Task 3), `AppLockController.clearPin` (Task 1), `appLockControllerProvider`, `settingsControllerProvider`.
- Produces: two `SwitchListTile`s; App Lock ON runs setup then persists `appLockEnabled: true`; OFF confirms, clears the PIN, persists `appLockEnabled: false, biometricEnabled: false`; Biometric switch is `onChanged: null` (disabled) while App Lock is off.

- [ ] **Step 1: Replace the stale settings test**

In `test/features/settings/settings_screen_test.dart`, **delete** the test titled `'App Lock and Biometric are disabled placeholders ...'` (lines ~119-169) and add the imports + tests below. Add near the top:

```dart
import 'package:financial_assistant/features/security/app_lock_controller.dart';
```

Add a fake store (top of `main`, or file scope):

```dart
class _FakeSecretStore implements SecretStore {
  final _m = <String, String>{};
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String value) async => _m[key] = value;
}
```

New tests:

```dart
  testWidgets(
      'enabling App Lock runs PIN setup and persists appLockEnabled=true',
      (tester) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final lock = AppLockController(_FakeSecretStore());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      appLockControllerProvider.overrideWithValue(lock),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Ilova qulfi'));
    await tester.tap(find.text('Ilova qulfi'));
    await tester.pumpAndSettle();

    // PIN setup sheet is open; enter + confirm.
    for (final d in '1234'.split('')) {
      await tester.tap(find.byKey(Key('pin_setup_key_$d')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    for (final d in '1234'.split('')) {
      await tester.tap(find.byKey(Key('pin_setup_key_$d')));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final settings = await container.read(settingsControllerProvider.future);
    expect(settings.appLockEnabled, isTrue);
    expect(await lock.verifyPin('1234'), isTrue);
  });

  testWidgets(
      'cancelling PIN setup leaves App Lock off and stores no PIN',
      (tester) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final lock = AppLockController(_FakeSecretStore());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      appLockControllerProvider.overrideWithValue(lock),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Ilova qulfi'));
    await tester.tap(find.text('Ilova qulfi'));
    await tester.pumpAndSettle();

    // Dismiss the sheet without entering a PIN (tap the barrier).
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();

    final settings = await container.read(settingsControllerProvider.future);
    expect(settings.appLockEnabled, isFalse);
    expect(await lock.verifyPin('1234'), isFalse);
  });

  testWidgets('Biometric switch is disabled while App Lock is off',
      (tester) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      appLockControllerProvider
          .overrideWithValue(AppLockController(_FakeSecretStore())),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    final biometric = tester.widget<SwitchListTile>(find.ancestor(
      of: find.text('Biometrik autentifikatsiya'),
      matching: find.byType(SwitchListTile),
    ));
    expect(biometric.onChanged, isNull); // disabled
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test --concurrency=1 test/features/settings/settings_screen_test.dart`
Expected: FAIL — the security rows are still disabled `ListTile`s, not `SwitchListTile`s.

- [ ] **Step 3: Wire the live toggles**

In `lib/features/settings/settings_screen.dart`:
- Add imports:
  ```dart
  import '../../providers/app_providers.dart';
  import '../security/pin_setup_sheet.dart';
  ```
  (`app_providers.dart` gives `appLockControllerProvider`; note `settingsControllerProvider` is already reachable via `settings_controller.dart`.)
- Replace the whole neutralized block (the comment + the `const _SettingsGroup` holding the two disabled `ListTile`s) with:

```dart
              const _SectionHeader('Maxfiylik va xavfsizlik'),
              _SettingsGroup(
                children: [
                  SwitchListTile(
                    secondary: const _RowIcon(Icons.lock_outline),
                    title: const Text('Ilova qulfi'),
                    subtitle: const Text('PIN kod bilan ilovani himoyalash'),
                    value: s.appLockEnabled,
                    onChanged: (want) async {
                      final lock = ref.read(appLockControllerProvider);
                      if (want) {
                        final ok = await showPinSetup(context, lock);
                        if (ok) save(s.copyWith(appLockEnabled: true));
                      } else {
                        final confirmed = await _confirmDisableLock(context);
                        if (confirmed) {
                          await lock.clearPin();
                          save(s.copyWith(
                            appLockEnabled: false,
                            biometricEnabled: false,
                          ));
                        }
                      }
                    },
                  ),
                  SwitchListTile(
                    secondary: const _RowIcon(Icons.fingerprint),
                    title: const Text('Biometrik autentifikatsiya'),
                    value: s.biometricEnabled,
                    onChanged: s.appLockEnabled
                        ? (want) => save(s.copyWith(biometricEnabled: want))
                        : null,
                  ),
                ],
              ),
```

- Add the confirm-dialog helper as a top-level function in the same file (near `_editName`):

```dart
Future<bool> _confirmDisableLock(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Ilova qulfini o\'chirasizmi?'),
      content: const Text(
          'PIN kod o\'chiriladi va ilova qulfsiz ochiladi.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Bekor qilish'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('O\'chirish'),
        ),
      ],
    ),
  );
  return result ?? false;
}
```

Note: `save`/`ref`/`context` are all in scope inside the `data: (s) {...}` builder (`build` receives `ref`; `save` is the local closure defined there).

- [ ] **Step 4: Run the tests + analyze**

Run: `flutter test --concurrency=1 test/features/settings/settings_screen_test.dart`
Expected: PASS.
Run: `flutter analyze lib/features/settings`
Expected: no issues (watch for `use_build_context_synchronously` — `showPinSetup`/`_confirmDisableLock` receive `context` before their `await`, and nothing uses `context` after the awaits, so it is clean).

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/settings_screen.dart test/features/settings/settings_screen_test.dart
git commit -m "feat(settings): live App Lock + Biometric toggles wired to PIN setup"
```

---

### Task 6: Onboarding security step

**Files:**
- Create: `lib/features/onboarding/steps/security_step.dart`
- Modify: `lib/features/onboarding/onboarding_screen.dart:23-30` (register the step) and its import block
- Test: `test/features/onboarding/security_step_test.dart`

**Interfaces:**
- Consumes: `showPinSetup` (Task 3), `appLockControllerProvider`, `OnboardingController.update`, `OnboardingStep`/`OnboardingStepScaffold`.
- Produces: `class SecurityStep extends OnboardingStep` with `id == 'security'`, registered before `ThemeStep`; a "PIN o'rnatish" button (key `onboarding_security_set_pin`) that on success flips `draft.settings.appLockEnabled` true and shows a "PIN o'rnatildi" badge.

- [ ] **Step 1: Write the failing tests**

Create `test/features/onboarding/security_step_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/meta/meta_repository.dart';
import 'package:financial_assistant/data/settings/settings_repository.dart';
import 'package:financial_assistant/features/onboarding/onboarding_controller.dart';
import 'package:financial_assistant/features/onboarding/onboarding_screen.dart';
import 'package:financial_assistant/features/onboarding/steps/security_step.dart';
import 'package:financial_assistant/features/security/app_lock_controller.dart';
import 'package:financial_assistant/providers/app_providers.dart';

class _FakeSecretStore implements SecretStore {
  final _m = <String, String>{};
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String value) async => _m[key] = value;
}

void main() {
  test('onboarding steps include the security step before the theme step', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ids = container
        .read(onboardingStepsProvider)
        .map((s) => s.id)
        .toList();
    expect(ids.contains('security'), isTrue);
    expect(ids.indexOf('security'), lessThan(ids.indexOf('theme')));
  });

  testWidgets(
      'setting a PIN in the step flips the draft appLockEnabled and shows a '
      'confirmed badge', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final controller = OnboardingController(
      settingsRepo: DriftSettingsRepository(db),
      metaRepo: DriftMetaRepository(db),
      stepCount: 7,
    );
    final lock = AppLockController(_FakeSecretStore());

    await tester.pumpWidget(ProviderScope(
      overrides: [appLockControllerProvider.overrideWithValue(lock)],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SecurityStep().build(tester.element(find.byType(Scaffold)),
                controller),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboarding_security_set_pin')));
    await tester.pumpAndSettle();
    for (final d in '1234'.split('')) {
      await tester.tap(find.byKey(Key('pin_setup_key_$d')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    for (final d in '1234'.split('')) {
      await tester.tap(find.byKey(Key('pin_setup_key_$d')));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(controller.state.settings.appLockEnabled, isTrue);
    expect(find.text('PIN o\'rnatildi'), findsOneWidget);
  });
}
```

Note: `ThemeStep.id == 'theme'` (confirmed in `lib/features/onboarding/steps/theme_step.dart`).

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test --concurrency=1 test/features/onboarding/security_step_test.dart`
Expected: FAIL — `security_step.dart` does not exist; provider has no `'security'` step.

- [ ] **Step 3: Implement `lib/features/onboarding/steps/security_step.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/velora_tokens.dart';
import '../../../providers/app_providers.dart';
import '../../../ui/components/velora_status.dart';
import '../../security/pin_setup_sheet.dart';
import '../onboarding_controller.dart';
import '../onboarding_step.dart';

/// Optional onboarding step: set a 4-digit PIN to lock the app. Skippable via
/// the shared "O'tkazib yuborish"/"Keyingi" controls -- skipping simply leaves
/// `appLockEnabled` at its default false. PIN-only; biometrics are offered in
/// Settings, not here.
///
/// "PIN already set this session" is read from the draft
/// (`settings.appLockEnabled`), not local state, so it survives the remount
/// that `OnboardingScreen` triggers when navigating back onto this step.
class SecurityStep extends OnboardingStep {
  @override
  String get id => 'security';
  @override
  String get title => 'Ilovangizni himoyalang';

  @override
  Widget build(BuildContext context, OnboardingController controller) =>
      _SecurityStepBody(controller: controller, title: title);
}

class _SecurityStepBody extends ConsumerWidget {
  const _SecurityStepBody({required this.controller, required this.title});

  final OnboardingController controller;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinSet = controller.state.settings.appLockEnabled;
    return OnboardingStepScaffold(
      title: title,
      lead: "4 raqamli PIN kod bilan ma'lumotlaringizni himoyalang. Buni "
          "keyinroq Sozlamalarda ham yoqishingiz mumkin.",
      children: [
        if (pinSet)
          const VeloraStatusBadge(
            key: Key('onboarding_security_pin_badge'),
            color: VeloraColors.success,
            icon: Icons.check_circle,
            label: "PIN o'rnatildi",
          )
        else
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              key: const Key('onboarding_security_set_pin'),
              style: FilledButton.styleFrom(
                backgroundColor: VeloraColors.plumTint,
                foregroundColor: VeloraColors.plum,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VeloraRadii.control),
                ),
              ),
              onPressed: () async {
                final ok = await showPinSetup(
                    context, ref.read(appLockControllerProvider));
                if (ok) {
                  controller.update((s) => s.copyWith(appLockEnabled: true));
                }
              },
              child: const Text("PIN o'rnatish"),
            ),
          ),
      ],
    );
  }
}
```

(`VeloraStatusBadge` takes `color`/`icon`/`label` — confirmed in `lib/ui/components/velora_status.dart`.)

- [ ] **Step 4: Register the step in `onboarding_screen.dart`**

Add the import with the other step imports:

```dart
import 'steps/security_step.dart';
```

Insert `SecurityStep()` before `ThemeStep()` in `onboardingStepsProvider`:

```dart
final onboardingStepsProvider = Provider<List<OnboardingStep>>((ref) => [
      WelcomeStep(),
      CurrencyStep(),
      PeriodStep(),
      AccountStep(),
      FinancialBaselineStep(),
      SecurityStep(),
      ThemeStep(),
    ]);
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test --concurrency=1 test/features/onboarding/security_step_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/onboarding/steps/security_step.dart lib/features/onboarding/onboarding_screen.dart test/features/onboarding/security_step_test.dart
git commit -m "feat(onboarding): optional PIN-setup security step"
```

---

### Task 7: Full-suite verification

**Files:** none (verification only).

- [ ] **Step 1: Run analyze**

Run: `flutter analyze`
Expected: no issues.

- [ ] **Step 2: Run the whole suite**

Run: `flutter test --concurrency=1`
Expected: PASS. Note: full-screen golden tests (onboarding/settings) may report mismatches on this Windows box — this is the known environmental issue recorded in memory (`toolchain-gotchas`), not a regression. Adding the security step and the live switches legitimately changes the onboarding and Settings goldens, so those goldens need CI re-baselining (`--update-goldens` on CI). Confirm all NON-golden tests pass; list any golden failures separately in the completion note.

- [ ] **Step 3: Commit any golden updates (only if runnable here)**

```bash
# Only if goldens can be regenerated in this environment:
flutter test --concurrency=1 --update-goldens
git add test/goldens
git commit -m "test(goldens): re-baseline onboarding + settings for App Lock activation"
```

---

## Self-Review

**Spec coverage:**
- Shared keypad extraction → Task 2. ✓
- Reusable `showPinSetup` → Task 3, consumed by Tasks 5 & 6. ✓
- `clearPin` + backoff (`failCount`/`lockedUntil` in secure storage, pure `lockoutFor`, injectable clock) → Task 1. ✓
- Lock screen honors lockout (disable + countdown) → Task 4. ✓
- Settings live toggles (enable→setup, disable→confirm+clear, biometric gated on app lock) → Task 5. ✓
- Onboarding skippable security step registered before ThemeStep → Task 6. ✓
- Testing section (controller/setup/gate/settings/onboarding) → Tasks 1–6; full suite → Task 7. ✓
- Deferred items (change-PIN, KDF/constant-time, biometric-in-onboarding) → intentionally not built; recorded in the spec. ✓
- No schema change → nothing in any task touches Drift tables/migrations. ✓

**Type consistency:** `verifyPin(String) -> Future<bool>`, `clearPin() -> Future<void>`, `lockoutRemaining() -> Future<Duration>`, `lockoutFor(int) -> Duration`, `showPinSetup(BuildContext, AppLockController) -> Future<bool>`, `PinDots({int filled, bool error, int length})`, `PinKeypad({bool enabled, ValueChanged<int> onDigit, VoidCallback onBackspace, bool showBiometric, VoidCallback? onBiometricRetry})` — used identically across Tasks 1–6. Constructor `AppLockController(store, [auth, clock])` matches every existing call site (single positional `store`).

**Placeholder scan:** no TBD/TODO/"handle edge cases"; every code step shows full code. Two verification caveats flagged (VeloraStatusBadge params and ThemeStep id) were verified against source and pinned to exact values.
