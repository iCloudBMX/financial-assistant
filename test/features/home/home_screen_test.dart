import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/core/mortgage/mortgage_engine.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/goals/goal_model.dart';
import 'package:financial_assistant/data/mortgage/mortgage_model.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/home/home_screen.dart';

void main() {
  testWidgets('shows the total balance card', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    await container.read(accountRepositoryProvider).create(
        name: 'Naqd', type: AccountType.cash,
        openingBalance: const Money(1000000, CurrencyRegistry.uzs), icon: 'w');

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Balans'), findsWidgets);
    expect(find.textContaining('1 000 000'), findsWidgets);
  });

  testWidgets(
      'renders the approved hierarchy: balance -> safe limit -> quick '
      'actions -> unallocated alert -> goal -> mortgage', (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container =
        ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    final accountId = await container.read(accountRepositoryProvider).create(
        name: 'Naqd', type: AccountType.cash,
        openingBalance: const Money(1000000, CurrencyRegistry.uzs), icon: 'w');
    // An unallocated income entry so the unallocated-income alert renders.
    await container.read(ledgerRepositoryProvider).addIncome(
          accountId: accountId,
          amount: const Money(500000, CurrencyRegistry.uzs),
          incomeType: IncomeType.salary,
          occurredAt: DateTime(2026, 7, 3),
        );
    await container.read(goalRepositoryProvider).create(GoalDraft(
          name: "Zaxira",
          targetAmountMinor: 10000000,
          startDate: DateTime(2026, 1, 1),
          priority: GoalPriority.high,
        ));
    await container.read(mortgageRepositoryProvider).create(MortgageDraft(
          name: 'Uy',
          initialLoanMinor: 120000000,
          openingPrincipalMinor: 100000000,
          annualRateBp: 1800,
          startDate: DateTime(2025, 1, 1),
          mandatoryPaymentMinor: 5000000,
          nextPaymentDate: DateTime(2026, 7, 10),
          paymentType: PaymentType.annuity,
        ));
    container.read(ledgerRevisionProvider.notifier).update((n) => n + 1);

    // Home is a ListView (for PageStorage scroll retention, see
    // routes_test.dart); the Sliver protocol only lays out what fits in the
    // viewport, so a tall physical size is needed to get every card's real
    // geometry for the getTopLeft comparisons below without scrolling.
    t.view.physicalSize = const Size(390, 2200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: HomeScreen()),
    ));
    await t.pumpAndSettle();

    double top(String key) => t.getTopLeft(find.byKey(Key(key))).dy;

    expect(find.byKey(const Key('balance-card')), findsOneWidget);
    expect(find.byKey(const Key('safe-limit-hero')), findsOneWidget);
    expect(find.byKey(const Key('quick-actions-row')), findsOneWidget);
    expect(find.byKey(const Key('unallocated-alert')), findsOneWidget);
    expect(find.byKey(const Key('goal-summary-card')), findsOneWidget);
    expect(find.byKey(const Key('mortgage-summary-card')), findsOneWidget);

    // Velora redesign order: the safe-to-spend hero leads as the dominant
    // decision card; the merged Balans card sits below quick actions and the
    // unallocated alert, above the goal and mortgage cards.
    expect(top('safe-limit-hero'), lessThan(top('quick-actions-row')));
    expect(top('quick-actions-row'), lessThan(top('unallocated-alert')));
    expect(top('unallocated-alert'), lessThan(top('balance-card')));
    expect(top('balance-card'), lessThan(top('goal-summary-card')));
    expect(top('goal-summary-card'), lessThan(top('mortgage-summary-card')));

    expect(find.textContaining('Erkin'), findsWidgets);
    expect(find.textContaining('Rezerv'), findsWidgets);
  });

  testWidgets('header icons pin flush to the right edge, level with the cards',
      (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container =
        ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    await container.read(accountRepositoryProvider).create(
        name: 'Naqd', type: AccountType.cash,
        openingBalance: const Money(1000000, CurrencyRegistry.uzs), icon: 'w');

    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: HomeScreen()),
    ));
    await t.pumpAndSettle();

    // The rightmost header icon (accounts) must reach the same right edge as
    // the balance card below it — not float ~60px inward.
    final cardRight = t.getBottomRight(find.byKey(const Key('balance-card'))).dx;
    final iconRight =
        t.getBottomRight(find.byKey(const Key('accounts-open'))).dx;
    expect(iconRight, moreOrLessEquals(cardRight, epsilon: 1.0));
  });

  testWidgets('privacy toggle hides and reveals the balance amount',
      (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container =
        ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    await container.read(accountRepositoryProvider).create(
        name: 'Naqd', type: AccountType.cash,
        openingBalance: const Money(1000000, CurrencyRegistry.uzs), icon: 'w');

    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: HomeScreen()),
    ));
    await t.pumpAndSettle();

    final amountFinder = find.byKey(const Key('balance-amount'));
    expect(
      t.widget<Text>(amountFinder).data,
      contains('1 000 000'),
    );

    await t.tap(find.byKey(const Key('balance-privacy-toggle')));
    await t.pumpAndSettle();

    final hiddenText = t.widget<Text>(amountFinder).data!;
    expect(hiddenText, isNot(contains('1 000 000')));
    expect(hiddenText, contains('•'));

    await t.tap(find.byKey(const Key('balance-privacy-toggle')));
    await t.pumpAndSettle();

    expect(t.widget<Text>(amountFinder).data, contains('1 000 000'));
  });
}
