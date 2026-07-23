import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class PinHasher {
  const PinHasher._();
  static String hash(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }
}

abstract class SecretStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
}

/// Device-backed [SecretStore] wrapping [FlutterSecureStorage]. Never store
/// the raw PIN here -- only the salt and the salted hash go through this
/// store, and nothing security-related is ever written to SQLite.
class SecureSecretStore implements SecretStore {
  final FlutterSecureStorage _storage;

  const SecureSecretStore([this._storage = const FlutterSecureStorage()]);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);
}

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
    final salt = base64Url.encode(List<int>.generate(16, (_) => rng.nextInt(256)));
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

  /// Thin device-only adapter over `local_auth`. Not unit-tested here: it
  /// talks to a platform plugin and is exercised via manual/integration
  /// testing. `AppLockGate`'s PIN-first lock screen calls this exactly once
  /// automatically on lock entry (from a post-frame callback, never from
  /// `build`) when biometrics are enabled, and again whenever the user taps
  /// the retry icon -- it never renders its own biometric UI, only the
  /// platform's native prompt via this method. Subclassable in tests (see
  /// `test/features/security/app_lock_gate_test.dart`) since it talks to a
  /// platform channel that isn't available in the widget-test environment.
  Future<bool> authenticateBiometric() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      return await _auth.authenticate(
        localizedReason: 'Ilovaga kirish uchun tasdiqlang',
        biometricOnly: true,
      );
    } on Exception {
      return false;
    }
  }
}
