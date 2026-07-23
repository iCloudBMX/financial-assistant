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
