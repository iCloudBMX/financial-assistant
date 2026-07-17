import 'dart:convert';

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

  AppLockController(this.store, [LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  static const _pinKey = 'app_lock_pin_hash';
  static const _saltKey = 'app_lock_salt';

  Future<void> setPin(String pin) async {
    final salt = DateTime.now().microsecondsSinceEpoch.toString();
    await store.write(_saltKey, salt);
    await store.write(_pinKey, PinHasher.hash(pin, salt));
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await store.read(_saltKey);
    final stored = await store.read(_pinKey);
    if (salt == null || stored == null) return false;
    return PinHasher.hash(pin, salt) == stored;
  }

  /// Thin device-only adapter over `local_auth`. Not unit-tested: it talks
  /// to a platform plugin and is exercised via manual/integration testing.
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
