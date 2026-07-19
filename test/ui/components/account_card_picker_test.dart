import 'dart:ui' show SemanticsAction, Tristate;

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
  const availableBalances = <int, Money>{
    1: Money(975000, CurrencyRegistry.uzs),
    2: Money(210000, CurrencyRegistry.uzs),
  };

  testWidgets('account cards show next-card peek and tap selection', (
    tester,
  ) async {
    final selected = <int>[];
    await tester.pumpWidget(
      _testApp(
        AccountCardPicker(
          accounts: accounts,
          availableBalances: availableBalances,
          selectedId: 1,
          onSelected: selected.add,
        ),
      ),
    );

    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.controller!.viewportFraction, 0.88);

    await tester.tap(find.text('Naqd'));
    await tester.pumpAndSettle();

    expect(selected, <int>[2]);
    expect(pageView.controller!.page, 1);
  });

  testWidgets('swiping to an account emits its id', (tester) async {
    final selected = <int>[];
    await tester.pumpWidget(
      _testApp(
        AccountCardPicker(
          accounts: accounts,
          availableBalances: availableBalances,
          selectedId: 1,
          onSelected: selected.add,
        ),
      ),
    );

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(selected, contains(2));
  });

  testWidgets('caller-selected id moves the page without callback feedback', (
    tester,
  ) async {
    var selectedId = 1;
    late StateSetter updateHost;
    final selected = <int>[];
    await tester.pumpWidget(
      _testApp(
        StatefulBuilder(
          builder: (context, setState) {
            updateHost = setState;
            return AccountCardPicker(
              accounts: accounts,
              availableBalances: availableBalances,
              selectedId: selectedId,
              onSelected: selected.add,
            );
          },
        ),
      ),
    );

    updateHost(() => selectedId = 2);
    await tester.pump();
    await tester.pumpAndSettle();

    final controller = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;
    expect(controller.page, 1);
    expect(selected, isEmpty);
  });

  testWidgets('active arrival reorder and removal keep controlled page valid', (
    tester,
  ) async {
    var activeAccounts = <Account>[];
    late StateSetter updateHost;
    final selected = <int>[];
    await tester.pumpWidget(
      _testApp(
        StatefulBuilder(
          builder: (context, setState) {
            updateHost = setState;
            return AccountCardPicker(
              accounts: activeAccounts,
              availableBalances: availableBalances,
              selectedId: 2,
              onSelected: selected.add,
            );
          },
        ),
      ),
    );
    expect(find.byType(PageView), findsNothing);

    updateHost(() => activeAccounts = accounts);
    await tester.pump();
    await tester.pumpAndSettle();
    var controller = tester.widget<PageView>(find.byType(PageView)).controller!;
    expect(controller.page, 1);
    expect(selected, isEmpty);

    updateHost(
      () => activeAccounts = <Account>[accounts[1], accounts[0], accounts[2]],
    );
    await tester.pump();
    await tester.pumpAndSettle();
    controller = tester.widget<PageView>(find.byType(PageView)).controller!;
    expect(controller.page, 0);
    expect(selected, isEmpty);

    updateHost(() => activeAccounts = <Account>[accounts[0], accounts[2]]);
    await tester.pump();
    await tester.pumpAndSettle();
    controller = tester.widget<PageView>(find.byType(PageView)).controller!;
    expect(controller.page, 0);
    expect(find.text('Asosiy karta'), findsOneWidget);
    expect(selected, isEmpty);
  });

  testWidgets('shows account details and excludes archived accounts', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        AccountCardPicker(
          accounts: accounts,
          availableBalances: availableBalances,
          selectedId: 1,
          onSelected: (_) {},
        ),
      ),
    );

    expect(find.text('Asosiy karta'), findsOneWidget);
    expect(find.text('Bank kartasi'), findsOneWidget);
    expect(find.text('UZS'), findsWidgets);
    expect(find.text('975 000 so‘m'), findsOneWidget);
    expect(find.text('1 250 000 so‘m'), findsNothing);
    expect(find.text('Eski hisob'), findsNothing);
  });

  testWidgets('announces selected account as a button', (tester) async {
    await tester.pumpWidget(
      _testApp(
        AccountCardPicker(
          accounts: accounts,
          availableBalances: availableBalances,
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
    expect(selected.label, contains('975 000 so‘m'));
    expect(selected.label, isNot(contains('1 250 000 so‘m')));
    expect(unselected.flagsCollection.isSelected, Tristate.isFalse);
  });

  testWidgets('screen-reader tap activates account selection', (tester) async {
    final selected = <int>[];
    await tester.pumpWidget(
      _testApp(
        AccountCardPicker(
          accounts: accounts,
          availableBalances: availableBalances,
          selectedId: 1,
          onSelected: selected.add,
        ),
      ),
    );

    final account = find.byKey(const Key('account-card-2'));
    final node = tester.getSemantics(account);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pump();

    expect(selected, <int>[2]);
  });

  testWidgets('disposing during a tap animation is race safe', (tester) async {
    await tester.pumpWidget(
      _testApp(
        AccountCardPicker(
          accounts: accounts,
          availableBalances: availableBalances,
          selectedId: 1,
          onSelected: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('Naqd'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('excludes an account with a missing available balance', (
    tester,
  ) async {
    final selected = <int>[];
    await tester.pumpWidget(
      _testApp(
        AccountCardPicker(
          accounts: accounts,
          availableBalances: const <int, Money>{
            1: Money(975000, CurrencyRegistry.uzs),
          },
          selectedId: 1,
          onSelected: selected.add,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Asosiy karta'), findsOneWidget);
    expect(find.text('Naqd'), findsNothing);
    expect(find.byKey(const Key('account-card-2')), findsNothing);

    await tester.tap(find.text('Asosiy karta'));
    expect(selected, <int>[1]);
  });

  testWidgets('excludes a currency-mismatched available balance', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        AccountCardPicker(
          accounts: accounts,
          availableBalances: const <int, Money>{
            1: Money(975000, CurrencyRegistry.uzs),
            2: Money(2100, CurrencyRegistry.usd),
          },
          selectedId: 1,
          onSelected: (_) {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Asosiy karta'), findsOneWidget);
    expect(find.text('Naqd'), findsNothing);
    expect(find.byKey(const Key('account-card-2')), findsNothing);
  });

  testWidgets('all-invalid balances render a stable empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        AccountCardPicker(
          accounts: accounts,
          availableBalances: const <int, Money>{},
          selectedId: 1,
          onSelected: (_) {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('account-picker-empty')), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
    expect(find.byKey(const Key('account-card-1')), findsNothing);
    expect(find.byKey(const Key('account-card-2')), findsNothing);
  });

  testWidgets('valid balance arrival resyncs without callback feedback', (
    tester,
  ) async {
    var balances = <int, Money>{};
    late StateSetter updateHost;
    final selected = <int>[];
    await tester.pumpWidget(
      _testApp(
        StatefulBuilder(
          builder: (context, setState) {
            updateHost = setState;
            return AccountCardPicker(
              accounts: accounts,
              availableBalances: balances,
              selectedId: 2,
              onSelected: selected.add,
            );
          },
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('account-picker-empty')), findsOneWidget);

    updateHost(() => balances = availableBalances);
    await tester.pump();
    await tester.pumpAndSettle();

    final controller = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;
    expect(tester.takeException(), isNull);
    expect(controller.page, 1);
    expect(
      tester
          .getSemantics(find.byKey(const Key('account-card-2')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(selected, isEmpty);
  });

  testWidgets('balance invalidation resyncs to a remaining valid account', (
    tester,
  ) async {
    var balances = availableBalances;
    late StateSetter updateHost;
    final selected = <int>[];
    await tester.pumpWidget(
      _testApp(
        StatefulBuilder(
          builder: (context, setState) {
            updateHost = setState;
            return AccountCardPicker(
              accounts: accounts,
              availableBalances: balances,
              selectedId: 2,
              onSelected: selected.add,
            );
          },
        ),
      ),
    );
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 1);

    updateHost(
      () =>
          balances = const <int, Money>{1: Money(975000, CurrencyRegistry.uzs)},
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Asosiy karta'), findsOneWidget);
    expect(find.text('Naqd'), findsNothing);
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 0);
    expect(selected, isEmpty);
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
          availableBalances: availableBalances,
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
