import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/mortgage/mortgage_engine.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/goals/goal_model.dart';
import 'package:financial_assistant/data/mortgage/mortgage_model.dart';
import 'package:financial_assistant/features/home/home_screen.dart';
import 'package:financial_assistant/providers/app_providers.dart';

import '../support/golden_devices.dart';
import '../support/velora_test_app.dart';

Future<ProviderContainer> _seededContainer() async {
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
        openingBalance: const Money(12500000, CurrencyRegistry.uzs),
        icon: 'payments',
      );
  await container.read(ledgerRepositoryProvider).addIncome(
        accountId: accountId,
        amount: const Money(2000000, CurrencyRegistry.uzs),
        incomeType: IncomeType.salary,
        occurredAt: DateTime(2026, 7, 3),
      );
  await container.read(goalRepositoryProvider).create(GoalDraft(
        name: "Zaxira jamg'armasi",
        targetAmountMinor: 20000000,
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
        nextPaymentDate: DateTime(2026, 7, 25),
        paymentType: PaymentType.annuity,
      ));
  container.read(ledgerRevisionProvider.notifier).update((n) => n + 1);
  // Let every seeded FutureProvider resolve before the first pump so the
  // golden captures settled data, not a loading skeleton.
  await container.read(dashboardProvider.future);

  return container;
}

void main() {
  testWidgets('Home matches the approved hierarchy at 390px light',
      (tester) async {
    final container = await _seededContainer();

    await pumpVelora(
      tester,
      child: UncontrolledProviderScope(
        container: container,
        child: const HomeScreen(),
      ),
      size: phone390,
      brightness: Brightness.light,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('baselines/home-light-390.png'),
    );
  });

  testWidgets('Home reflows without overflow at 320px dark 200% text scale',
      (tester) async {
    final container = await _seededContainer();

    await pumpVelora(
      tester,
      child: UncontrolledProviderScope(
        container: container,
        child: const HomeScreen(),
      ),
      size: phone320,
      brightness: Brightness.dark,
      textScale: textScale200,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('baselines/home-dark-320-scale200.png'),
    );
  });
}
