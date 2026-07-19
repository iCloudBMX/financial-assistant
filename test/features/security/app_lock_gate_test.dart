import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/features/security/app_lock_controller.dart';
import 'package:financial_assistant/features/security/app_lock_gate.dart';
import 'package:financial_assistant/features/security/background_shield.dart';

class _FakeStore implements SecretStore {
  final _m = <String, String>{};
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String value) async => _m[key] = value;
}

/// `AppLockController.authenticateBiometric` talks to a real platform
/// channel (`local_auth`), which isn't available in the widget-test
/// environment. Subclassing lets these tests assert call counts on the
/// exact production `verifyPin`/`setPin` (hash+salt) logic while faking out
/// only the platform-bound method -- never a custom biometric UI of our own.
class _FakeAppLockController extends AppLockController {
  _FakeAppLockController() : super(_FakeStore());

  int biometricCalls = 0;
  bool biometricResult = false;

  @override
  Future<bool> authenticateBiometric() async {
    biometricCalls++;
    return biometricResult;
  }
}

Future<void> _tapDigits(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.byKey(Key('app_lock_key_$d')));
    await tester.pump();
  }
}

void main() {
  late _FakeAppLockController controller;

  setUp(() async {
    controller = _FakeAppLockController();
    await controller.setPin('1234');
  });

  Future<void> pumpGate(
    WidgetTester tester, {
    bool biometricEnabled = false,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: AppLockGate(
        controller: controller,
        enabled: true,
        biometricEnabled: biometricEnabled,
        child: const Scaffold(body: Text('Unlocked home')),
      ),
    ));
  }

  testWidgets('renders a PIN keypad -- no text field and no submit button',
      (tester) async {
    await pumpGate(tester);
    await tester.pump();

    expect(find.byKey(const Key('app_lock_keypad')), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const Key('app_lock_pin_field')), findsNothing);
    expect(find.byKey(const Key('app_lock_unlock_button')), findsNothing);
    for (var d = 0; d <= 9; d++) {
      expect(find.byKey(Key('app_lock_key_$d')), findsOneWidget);
    }
  });

  testWidgets(
      'entering the correct four digits submits automatically (no submit '
      'button tap) and unlocks', (tester) async {
    await pumpGate(tester);
    await tester.pump();

    await _tapDigits(tester, '1234');
    await tester.pumpAndSettle();

    expect(find.text('Unlocked home'), findsOneWidget);
  });

  testWidgets(
      'a wrong PIN resets the entry (dots back to empty) and shows an '
      'error, without unlocking -- then the correct PIN still works',
      (tester) async {
    await pumpGate(tester);
    await tester.pump();

    await _tapDigits(tester, '0000');
    await tester.pumpAndSettle();

    expect(find.text('Unlocked home'), findsNothing);
    expect(find.text("PIN kod noto'g'ri"), findsOneWidget);

    // Entry was reset to empty -- re-entering the correct PIN from scratch
    // still unlocks (no leftover digits from the failed attempt).
    await _tapDigits(tester, '1234');
    await tester.pumpAndSettle();

    expect(find.text('Unlocked home'), findsOneWidget);
  });

  testWidgets(
      'authenticateBiometric is never called automatically when '
      'biometricEnabled is false', (tester) async {
    await pumpGate(tester);
    await tester.pump();
    await tester.pump();

    expect(controller.biometricCalls, 0);
  });

  testWidgets(
      'authenticateBiometric is called exactly once automatically on lock '
      'entry when biometricEnabled is true', (tester) async {
    await pumpGate(tester, biometricEnabled: true);
    await tester.pump();

    expect(controller.biometricCalls, 1);

    // Further, unrelated rebuilds must not re-trigger it.
    await tester.pump();
    await tester.pump();
    expect(controller.biometricCalls, 1);
  });

  testWidgets('the retry icon re-invokes authenticateBiometric',
      (tester) async {
    await pumpGate(tester, biometricEnabled: true);
    await tester.pump();
    expect(controller.biometricCalls, 1);

    await tester.tap(find.byKey(const Key('app_lock_biometric_retry')));
    await tester.pump();

    expect(controller.biometricCalls, 2);
  });

  testWidgets(
      'a successful biometric unlock shows the child, with no custom '
      'biometric dialog ever rendered', (tester) async {
    controller.biometricResult = true;
    await pumpGate(tester, biometricEnabled: true);
    await tester.pumpAndSettle();

    expect(find.text('Unlocked home'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets(
      'the background privacy shield hides content while the app is '
      'inactive/paused and un-hides it on resume', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: BackgroundShield(
        child: AppLockGate(
          controller: controller,
          enabled: false, // unlocked; the shield is independent of lock state
          child: const Scaffold(body: Text('Sensitive amount')),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Sensitive amount'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);

    final observer = tester.state<State<BackgroundShield>>(
      find.byType(BackgroundShield),
    ) as WidgetsBindingObserver;

    observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byType(BackdropFilter), findsOneWidget);

    observer.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();
    expect(find.byType(BackdropFilter), findsOneWidget);

    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
