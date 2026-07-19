import 'dart:ui' show Tristate;

import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/ui/components/account_card_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const accounts = <Account>[
    Account(
      id: 1,
      name: 'Asosiy karta',
      type: AccountType.bankCard,
      openingBalance: Money(1250000, CurrencyRegistry.uzs),
      icon: 'credit_card',
      archived: false,
    ),
    Account(
      id: 2,
      name: 'Naqd',
      type: AccountType.cash,
      openingBalance: Money(480000, CurrencyRegistry.uzs),
      icon: 'payments',
      archived: false,
    ),
    Account(
      id: 3,
      name: 'Eski hisob',
      type: AccountType.savings,
      openingBalance: Money(30000, CurrencyRegistry.uzs),
      icon: 'savings',
      archived: true,
    ),
  ];

  testWidgets('account cards show next-card peek and tap selection', (
    tester,
  ) async {
    final selected = <int>[];
    await tester.pumpWidget(
      _testApp(
        AccountCardPicker(
          accounts: accounts,
          selectedId: 1,
          onSelected: selected.add,
        ),
      ),
    );

    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.controller!.viewportFraction, 0.88);

    await tester.tap(find.text('Naqd'));
    expect(selected.last, 2);
  });

  testWidgets('swiping to an account emits its id', (tester) async {
    final selected = <int>[];
    await tester.pumpWidget(
      _testApp(
        AccountCardPicker(
          accounts: accounts,
          selectedId: 1,
          onSelected: selected.add,
        ),
      ),
    );

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(selected, contains(2));
  });

  testWidgets('shows account details and excludes archived accounts', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        AccountCardPicker(
          accounts: accounts,
          selectedId: 1,
          onSelected: (_) {},
        ),
      ),
    );

    expect(find.text('Asosiy karta'), findsOneWidget);
    expect(find.text('Bank kartasi'), findsOneWidget);
    expect(find.text('UZS'), findsWidgets);
    expect(find.text('1 250 000 so‘m'), findsOneWidget);
    expect(find.text('Eski hisob'), findsNothing);
  });

  testWidgets('announces selected account as a button', (tester) async {
    await tester.pumpWidget(
      _testApp(
        AccountCardPicker(
          accounts: accounts,
          selectedId: 1,
          onSelected: (_) {},
        ),
      ),
    );

    final selected = tester.getSemantics(
      find.byKey(const Key('account-card-1')),
    );
    final unselected = tester.getSemantics(
      find.byKey(const Key('account-card-2')),
    );
    expect(selected.flagsCollection.isSelected, Tristate.isTrue);
    expect(selected.flagsCollection.isButton, isTrue);
    expect(unselected.flagsCollection.isSelected, Tristate.isFalse);
  });

  testWidgets('reflows at 320px and 200 percent text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testApp(
        AccountCardPicker(
          accounts: accounts,
          selectedId: 1,
          onSelected: (_) {},
        ),
        textScale: 2,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('account-card-1'))).height,
      greaterThanOrEqualTo(48),
    );
  });
}

Widget _testApp(Widget child, {double textScale = 1}) => MaterialApp(
  builder: (context, appChild) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: appChild!,
  ),
  home: Scaffold(body: Center(child: child)),
);
