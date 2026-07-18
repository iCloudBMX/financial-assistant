import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/features/security/app_lock_controller.dart';

class FakeStore implements SecretStore {
  final _m = <String, String>{};
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String value) async => _m[key] = value;
}

void main() {
  test('a set PIN verifies and a wrong PIN fails', () async {
    final c = AppLockController(FakeStore());
    await c.setPin('1234');
    expect(await c.verifyPin('1234'), isTrue);
    expect(await c.verifyPin('0000'), isFalse);
  });

  test('verify fails when no PIN is set', () async {
    expect(await AppLockController(FakeStore()).verifyPin('1234'), isFalse);
  });

  test('hash is salted: same pin, different salt, different hash', () {
    expect(PinHasher.hash('1234', 'a'), isNot(PinHasher.hash('1234', 'b')));
  });
}
