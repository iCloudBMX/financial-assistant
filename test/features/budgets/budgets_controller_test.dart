import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/budget/category_budget_engine.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/categories/category_model.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/budgets/budgets_controller.dart';
import 'package:financial_assistant/features/expense_entry/expense_entry_controller.dart';

void main() {
  test('setMonthlyLimit persists and bumps the revision', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    final before = container.read(ledgerRevisionProvider);
    await container
        .read(budgetsControllerProvider)
        .setMonthlyLimit(1, const Money(500000, CurrencyRegistry.uzs));

    expect(container.read(ledgerRevisionProvider), greaterThan(before));
    final views = await container.read(categoryBudgetsProvider.future);
    expect(views.firstWhere((v) => v.category.id == 1).category.monthlyLimitMinor,
        500000);
  });

  test('setVariableBudget updates settings', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    await container
        .read(budgetsControllerProvider)
        .setVariableBudget(const Money(1400000, CurrencyRegistry.uzs));
    final settings = await container.refresh(settingsProvider.future);
    expect(settings.variableBudget, const Money(1400000, CurrencyRegistry.uzs));
  });

  test('setKind toggles CategoryKind and categoryBudgetsProvider reflects it',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    final before = await container.read(categoryBudgetsProvider.future);
    // Default-seeded categories start out `variable` (PRD §10.1 defaults).
    expect(before.firstWhere((v) => v.category.id == 1).category.kind,
        CategoryKind.variable);

    await container
        .read(budgetsControllerProvider)
        .setKind(1, CategoryKind.mandatory);
    final after = await container.read(categoryBudgetsProvider.future);
    expect(after.firstWhere((v) => v.category.id == 1).category.kind,
        CategoryKind.mandatory);

    // toggling back
    await container
        .read(budgetsControllerProvider)
        .setKind(1, CategoryKind.variable);
    final after2 = await container.read(categoryBudgetsProvider.future);
    expect(after2.firstWhere((v) => v.category.id == 1).category.kind,
        CategoryKind.variable);
  });

  test(
      'a weekly limit makes weekStatus react to an expense recorded within '
      'the current week (previously-dead weekly path, exercised end to end)',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    await container.read(accountRepositoryProvider).create(
        name: 'Naqd',
        type: AccountType.cash,
        openingBalance: const Money(1000000, CurrencyRegistry.uzs),
        icon: 'w');
    await container.read(expenseEntryControllerProvider.future);

    final before = await container.read(categoryBudgetsProvider.future);
    expect(before.firstWhere((v) => v.category.id == 1).weekStatus,
        CategoryLimitStatus.noLimit,
        reason: 'no weekly limit set yet');

    // A small weekly limit on category 1 (Oziq-ovqat).
    await container
        .read(budgetsControllerProvider)
        .setWeeklyLimit(1, const Money(10000, CurrencyRegistry.uzs));

    // A variable expense this week that exceeds the weekly limit.
    await container.read(expenseEntryControllerProvider.notifier).save(
        amount: const Money(20000, CurrencyRegistry.uzs), categoryId: 1);

    final after = await container.read(categoryBudgetsProvider.future);
    expect(after.firstWhere((v) => v.category.id == 1).weekStatus,
        CategoryLimitStatus.over);
    // The monthly path must stay untouched — no monthly limit was set.
    expect(after.firstWhere((v) => v.category.id == 1).monthStatus,
        CategoryLimitStatus.noLimit);
  });
}
