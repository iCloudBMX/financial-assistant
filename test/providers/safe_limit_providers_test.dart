import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/budget/category_budget_engine.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/settings/settings_repository.dart';
import 'package:financial_assistant/data/settings/settings_model.dart';
import 'package:financial_assistant/data/budget/budget_repository.dart';
import 'package:financial_assistant/data/categories/category_model.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  test('safeLimitProvider computes the daily figure from ledger + budget', () async {
    final db = AppDatabase(NativeDatabase.memory());
    // One cash account, opening 100,000,000; variable budget 1,400,000.
    final accId = await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(
            name: 'Naqd',
            type: 'cash',
            openingBalanceMinor: const Value(100000000),
          ),
        );
    final base = await DriftSettingsRepository(db).read();
    await DriftSettingsRepository(db).write(base.copyWith(
      variableBudget: const Money(1400000, CurrencyRegistry.uzs),
    ));
    // Spend 200,000 today in a variable category (category 1 is default/variable).
    await db.into(db.transactionsTable).insert(
          TransactionsTableCompanion.insert(
            accountId: accId,
            type: 'expense',
            amountMinor: -200000,
            currencyCode: 'UZS',
            categoryId: const Value(1),
            occurredAt: DateTime.now(),
            createdAt: DateTime.now(),
          ),
        );

    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    final limit = await container.read(safeLimitProvider.future);
    // numerator 1,400,000 - 200,000(spent variable) = 1,200,000; today spent 200,000.
    expect(limit.spendable.minorUnits, 1200000);
    expect(limit.todaySpent, const Money(200000, CurrencyRegistry.uzs));
    await db.close();
  });

  test('categoryBudgetsProvider reports over-limit status', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final accId = await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(name: 'Naqd', type: 'cash'),
        );
    // Give category 1 a small monthly limit and overspend it.
    await DriftBudgetRepository(db)
        .setCategoryLimits(1, monthlyLimitMinor: 100000);
    await db.into(db.transactionsTable).insert(
          TransactionsTableCompanion.insert(
            accountId: accId,
            type: 'expense',
            amountMinor: -150000,
            currencyCode: 'UZS',
            categoryId: const Value(1),
            occurredAt: DateTime.now(),
            createdAt: DateTime.now(),
          ),
        );
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    final views = await container.read(categoryBudgetsProvider.future);
    final cat1 = views.firstWhere((v) => v.category.id == 1);
    expect(cat1.monthStatus, CategoryLimitStatus.over);
    await db.close();
  });
}
