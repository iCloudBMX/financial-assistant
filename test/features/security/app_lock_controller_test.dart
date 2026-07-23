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
}
