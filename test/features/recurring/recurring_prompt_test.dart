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
import 'package:financial_assistant/features/recurring/recurring_prompt.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  test('confirm records income and clears the plan from due', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    final accId = await c.read(accountRepositoryProvider).create(
        name: 'Naqd', type: AccountType.cash, openingBalance: const Money(0, uzs), icon: 'w');
    await c.read(recurringIncomeRepositoryProvider).create(
        accountId: accId, amount: const Money(5000000, uzs), incomeType: IncomeType.salary,
        intervalKind: IntervalKind.monthly, anchorDay: 5, nextDueAt: DateTime(2026, 7, 5));

    final due = await c.read(recurringPromptControllerProvider.future);
    expect(due.length, 1);

    await c.read(recurringPromptControllerProvider.notifier).confirm(due.single);

    final data = await c.read(dashboardProvider.future);
    expect(data.monthIncome.minorUnits, greaterThan(0));
    final stillDue = await c.read(recurringIncomeRepositoryProvider).duePlans(DateTime(2026, 7, 6));
    expect(stillDue, isEmpty); // advanced past the current date
  });
}
