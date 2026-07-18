import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/recurring/recurring_model.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/income_entry/income_entry_controller.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  test('income is recorded undistributed and shows on the dashboard', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    final accId = await c.read(accountRepositoryProvider).create(
        name: 'Naqd', type: AccountType.cash, openingBalance: const Money(0, uzs), icon: 'w');

    await c.read(incomeEntryControllerProvider.notifier).save(
        accountId: accId, amount: const Money(5000000, uzs), incomeType: IncomeType.salary);

    final data = await c.read(dashboardProvider.future);
    expect(data.monthIncome, const Money(5000000, uzs));
    expect(data.undistributedFunds, const Money(5000000, uzs));
  });

  test('a recurring income also creates an active plan', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    final accId = await c.read(accountRepositoryProvider).create(
        name: 'Naqd', type: AccountType.cash, openingBalance: const Money(0, uzs), icon: 'w');

    await c.read(incomeEntryControllerProvider.notifier).save(
        accountId: accId, amount: const Money(5000000, uzs), incomeType: IncomeType.salary,
        occurredAt: DateTime(2026, 7, 5), recurring: true,
        intervalKind: IntervalKind.monthly, anchorDay: 5);

    final plans = await c.read(recurringIncomeRepositoryProvider).listActive();
    expect(plans.length, 1);
    expect(plans.single.anchorDay, 5);
    expect(plans.single.nextDueAt, DateTime(2026, 8, 5)); // next occurrence
  });
}
