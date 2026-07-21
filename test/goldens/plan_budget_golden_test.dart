import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/features/budgets/budgets_controller.dart';
import 'package:financial_assistant/features/budgets/budgets_screen.dart';
import 'package:financial_assistant/providers/app_providers.dart';

import '../support/golden_devices.dart';
import '../support/velora_test_app.dart';

/// Seeds the "Reja" plan/budget screen with a category in each §10.4 status
/// (safe / near / over), a weekly limit, and the standalone variable-budget
/// + safety-buffer settings, so the golden captures every status tone at
/// once (per the design spec's "safe/near/over must carry text + icon").
Future<ProviderContainer> _seededContainer() async {
  const uzs = CurrencyRegistry.uzs;
  final db = AppDatabase(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
  addTearDown(() {
    container.dispose();
    db.close();
  });

  final accountId = await container.read(accountRepositoryProvider).create(
        name: 'Naqd',
        type: AccountType.cash,
        openingBalance: const Money(50000000, uzs),
        icon: 'payments',
      );

  final budgets = container.read(budgetsControllerProvider);
  await budgets.setVariableBudget(const Money(3000000, uzs));
  // The budget page no longer has its own safety-buffer editor (Task 7
  // dropped `BudgetsController.setSafetyBuffer`), so seed the setting
  // directly through the repository instead of through the controller.
  final settingsRepo = container.read(settingsRepositoryProvider);
  await settingsRepo
      .write((await settingsRepo.read()).copyWith(
        safetyBuffer: const Money(500000, uzs),
      ));

  final ledger = container.read(ledgerRepositoryProvider);
  final now = DateTime.now();

  // Category 1 (Oziq-ovqat): safe — well under its monthly limit.
  await budgets.setMonthlyLimit(1, const Money(600000, uzs));
  await ledger.addExpense(
    accountId: accountId,
    amount: const Money(150000, uzs),
    categoryId: 1,
    occurredAt: now,
  );

  // Category 2 (Transport): near — at 90% of its monthly limit.
  await budgets.setMonthlyLimit(2, const Money(300000, uzs));
  await ledger.addExpense(
    accountId: accountId,
    amount: const Money(270000, uzs),
    categoryId: 2,
    occurredAt: now,
  );

  // Category 3 (Uy): over its monthly limit, with a weekly limit too.
  await budgets.setMonthlyLimit(3, const Money(200000, uzs));
  // The budget page no longer renders a weekly status line (Task 7 dropped
  // `BudgetsController.setWeeklyLimit`), so seed the weekly limit directly
  // through the repository instead of through the controller.
  await container.read(budgetRepositoryProvider).setCategoryLimits(
        3,
        weeklyLimitMinor: const Money(50000, uzs).minorUnits,
      );
  await ledger.addExpense(
    accountId: accountId,
    amount: const Money(250000, uzs),
    categoryId: 3,
    occurredAt: now,
  );

  container.read(ledgerRevisionProvider.notifier).update((n) => n + 1);
  await container.read(categoryBudgetsProvider.future);

  return container;
}

void main() {
  testWidgets('Reja/Budjet matches the approved status hierarchy at 390px '
      'light', (tester) async {
    final container = await _seededContainer();

    await pumpVelora(
      tester,
      child: UncontrolledProviderScope(
        container: container,
        child: const BudgetsScreen(),
      ),
      size: phone390,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(BudgetsScreen),
      matchesGoldenFile('baselines/plan-budget-light-390.png'),
    );
  });

  testWidgets(
      'Reja/Budjet reflows without overflow at 320px dark 200% text scale',
      (tester) async {
    final container = await _seededContainer();

    await pumpVelora(
      tester,
      child: UncontrolledProviderScope(
        container: container,
        child: const BudgetsScreen(),
      ),
      size: phone320,
      brightness: Brightness.dark,
      textScale: textScale200,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(BudgetsScreen),
      matchesGoldenFile('baselines/plan-budget-dark-320-scale200.png'),
    );
  });
}
