# App Lock activation — design

**Date:** 2026-07-23
**Status:** approved, ready for plan

## Problem

The app has a fully-built, PIN-first App Lock (controller, keypad lock screen,
gate, salted-SHA-256 hashing in secure storage, biometric-on-top, cold-start +
resume re-lock, all wired into `app.dart`). But **nothing ever calls
`AppLockController.setPin`**, so during the Velora review the two Settings
tiles ("Ilova qulfi", "Biometrik autentifikatsiya") were deliberately
neutralized to disabled "(keyingi bosqichda)" placeholders — flipping
`appLockEnabled=true` with no PIN stored would lock the user out permanently
(`verifyPin` always returns `false`).

This is a **reactivation**, not a build-from-scratch. It adds the two missing
entry points that let a user set a PIN, plus the brute-force backoff flagged as
required before real financial data ships (SP0 security note).

Primary language of all user-facing strings: Uzbek (Latin), matching the rest
of the app.

## Non-goals

- No schema change. PIN material and backoff state live in device secure
  storage (`FlutterSecureStorage`), never in SQLite.
- No dedicated "change PIN" screen — disable + re-enable already changes it.
- No KDF / constant-time compare in this pass (see Deferred).
- No biometric prompt inside onboarding — biometric is a Settings-only concern.

## Existing pieces reused unchanged

- `AppLockGate` / `_LockScreen` — cold-start lock, resume-after-timeout re-lock,
  auto-biometric-once-on-entry. Only extended for lockout (below).
- `AppLockController.setPin` / `verifyPin` / `authenticateBiometric`.
- `app.dart` composition-root wiring gated on `settings.appLockEnabled` /
  `biometricEnabled` (already correct — no change).
- `appLockControllerProvider` (device-backed `SecureSecretStore`).

## Components

### 1. Shared keypad — `lib/features/security/pin_keypad.dart` (new)

Lift the currently-private `_PinDots`, `_Keypad`, `_KeypadButton` out of
`app_lock_gate.dart` into a public module so both the lock screen and the new
setup flow render the identical keypad. No behavior change — pure extraction.
`app_lock_gate.dart` imports them back.

Public surface (approx):
- `PinDots({required int filled, required bool error, int length = 4})`
- `PinKeypad({required bool enabled, required ValueChanged<int> onDigit,
   required VoidCallback onBackspace, bool showBiometric = false,
   VoidCallback? onBiometricRetry})`

### 2. PIN setup flow — `lib/features/security/pin_setup_sheet.dart` (new)

A single reusable entry point used by **both** Settings and onboarding:

```
Future<bool> showPinSetup(BuildContext context, AppLockController controller)
```

Two-stage: enter 4 digits → confirm 4 digits. On mismatch, show an error, clear
both entries, restart at stage one. On match, call `controller.setPin(pin)` and
return `true`. Dismissing/cancelling returns `false` and stores nothing.
Renders via `PinDots` + `PinKeypad`. Auto-advances on the 4th digit (no submit
button), matching the lock screen.

### 3. Controller additions — `lib/features/security/app_lock_controller.dart`

- `Future<void> clearPin()` — deletes the PIN hash + salt + backoff keys.
- **Backoff**, persisted in secure storage so relaunching the app cannot reset
  it:
  - keys `app_lock_fail_count`, `app_lock_locked_until` (epoch millis).
  - `verifyPin` keeps its `Future<bool>` signature (existing tests unchanged):
    1. If currently locked out (`now < lockedUntil`), return `false` without
       hashing.
    2. Compute the hash. On match: reset fail count + clear lockedUntil, return
       `true`. On mismatch: increment fail count; if it reaches the threshold,
       set `lockedUntil = now + lockoutFor(failCount)`; return `false`.
  - `Future<Duration> lockoutRemaining()` — `max(0, lockedUntil - now)`.
  - `lockoutFor(int failCount)` — **pure** helper (own assert test): no lockout
    below `_lockThreshold` (5); at/above it, `30s * 2^(failCount - threshold)`
    capped at 15 min.
  - Inject an optional `DateTime Function() clock` (default `DateTime.now`) so
    backoff is deterministically unit-testable.

### 4. Lock screen honors lockout — `lib/features/security/app_lock_gate.dart`

`_LockScreenState`: on entry and after each failed submit, read
`lockoutRemaining()`. While `> 0`: disable the keypad, show a countdown message
("Qayta urinib ko'ring: MM:SS") driven by a `Timer.periodic(1s)`, re-enable when
it reaches zero. Cancel the timer in `dispose`.

### 5. Settings tiles — `lib/features/settings/settings_screen.dart`

Replace the two disabled placeholder `ListTile`s (and drop the neutralization
comment) with live rows in the "Maxfiylik va xavfsizlik" group:

- **Ilova qulfi** (`SwitchListTile`, bound to `s.appLockEnabled`):
  - OFF → ON: `await showPinSetup(...)`; only if it returns `true`,
    `save(s.copyWith(appLockEnabled: true))`. If cancelled, the switch stays
    off (no PIN, no flag).
  - ON → OFF: confirm dialog; on confirm `controller.clearPin()` then
    `save(s.copyWith(appLockEnabled: false, biometricEnabled: false))`.
- **Biometrik autentifikatsiya** (`SwitchListTile`, bound to
  `s.biometricEnabled`): `enabled: s.appLockEnabled` (disabled/greyed while app
  lock is off). Toggling persists `biometricEnabled`.

Reads `appLockControllerProvider` via `ref`.

### 6. Onboarding step — `lib/features/onboarding/steps/security_step.dart` (new)

A skippable `OnboardingStep` registered in `onboardingStepsProvider` (inserted
before `ThemeStep`). One question ("Ilovangizni himoyalang"), a lead line, and:

- If no PIN set yet this session: a "PIN o'rnatish" button → `showPinSetup(...)`;
  on `true`, `controller.update((s) => s.copyWith(appLockEnabled: true))` and
  show a "PIN o'rnatildi" confirmed state.
- The standard onboarding "O'tkazib yuborish" / "Keyingi" handle skipping;
  skipping leaves `appLockEnabled` at its default `false`.

The step's widget is a `Consumer` (or `ConsumerWidget` body) so it can read
`appLockControllerProvider`. PIN-only — no biometric here.

Note: `showPinSetup` writes the PIN to secure storage immediately, while the
`appLockEnabled` flag is only persisted at `commit()`. If onboarding is
abandoned after setting a PIN, secure storage holds a PIN but settings default
`appLockEnabled=false`, so the gate never locks — no lockout risk.

## Data flow

```
Settings toggle ON ─► showPinSetup ─► controller.setPin ─► save(appLockEnabled=true)
                                                              │
cold start / resume timeout ─► AppLockGate reads settings ───┘
                              └─► _LockScreen ─► verifyPin ─┬─ ok ─► unlock
                                                            └─ locked ─► countdown, pad disabled
Settings toggle OFF ─► confirm ─► clearPin ─► save(appLockEnabled=false, biometricEnabled=false)
```

## Testing

- **Controller** (`test/features/security/app_lock_controller_test.dart`):
  `clearPin` removes stored PIN; backoff — below threshold wrong attempts do not
  lock; reaching threshold sets a lockout; a correct PIN is refused while locked
  out; `lockoutRemaining` shrinks with the injected clock; success resets the
  fail count. `lockoutFor` pure assert cases (below threshold = zero; escalation;
  cap).
- **Setup flow** (`test/features/security/pin_setup_sheet_test.dart`): mismatch
  re-prompts; matching pair calls `setPin`; cancel stores nothing.
- **Gate** (`test/features/security/app_lock_gate_test.dart`, extend): a fake
  controller reporting a lockout disables the keypad and shows the countdown.
- **Settings** (`test/features/settings/settings_screen_test.dart`, extend):
  enabling opens setup; cancelling leaves the switch off and `appLockEnabled`
  false; success persists `appLockEnabled=true`; disabling clears PIN and both
  flags; biometric row disabled while app lock off.
- **Onboarding** (`test/features/onboarding/...`): setting a PIN flips
  `draft.appLockEnabled` true; skipping leaves it false; step count / progress
  indicator updated.

Run with `flutter test --concurrency=1`.

## Deferred (with ceilings)

- **Dedicated change-PIN flow** — disable + re-enable covers it; add when asked.
- **KDF + constant-time compare** — SHA-256 + 16-byte random salt + hardware-
  backed secure storage + the new online backoff address the practical threats;
  the PIN hash is never compared against attacker-readable data. Remains the
  standing SP0 security note; revisit if PIN material ever leaves secure storage
  (e.g. an encrypted-backup export).
- **Biometric setup during onboarding** — offered in Settings instead, to keep
  the onboarding step to a single question.
