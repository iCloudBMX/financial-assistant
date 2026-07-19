import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/ui/components/velora_money_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('autofocuses, formats UZS, and announces currency', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VeloraMoneyField(
            controller: controller,
            currency: CurrencyRegistry.uzs,
            label: 'Summa',
            autofocus: true,
          ),
        ),
      ),
    );

    expect(tester.testTextInput.hasAnyClients, isTrue);
    await tester.enterText(find.byType(TextField), '1250000');

    expect(controller.text, '1 250 000');
    expect(find.text("so'm"), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(VeloraMoneyField)).label,
      contains('Summa, UZS'),
    );
  });

  testWidgets('reports empty input as null and zero as money', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final changes = <Money?>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VeloraMoneyField(
            controller: controller,
            currency: CurrencyRegistry.uzs,
            label: 'Summa',
            onChanged: changes.add,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '0');
    await tester.enterText(find.byType(TextField), '');

    expect(changes, <Money?>[const Money(0, CurrencyRegistry.uzs), null]);
  });

  testWidgets('reflows at 200 percent text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController(text: '1 250 000');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: VeloraMoneyField(
            controller: controller,
            currency: CurrencyRegistry.uzs,
            label: 'Jami summa',
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(VeloraMoneyField)).width, 320);
  });

  testWidgets('disabled field cannot receive focus or edits', (tester) async {
    final controller = TextEditingController(text: '10 000');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VeloraMoneyField(
            controller: controller,
            currency: CurrencyRegistry.uzs,
            label: 'Summa',
            enabled: false,
          ),
        ),
      ),
    );

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.enabled, isFalse);

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(tester.testTextInput.hasAnyClients, isFalse);
    expect(controller.text, '10 000');
  });
}
