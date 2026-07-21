import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/categories/category_model.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/budgets/budgets_controller.dart';

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

  test('createCategory inserts a new category, bumps the revision, and is '
      'visible via categoryBudgetsProvider', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    final before = container.read(ledgerRevisionProvider);
    final id = await container
        .read(budgetsControllerProvider)
        .createCategory(name: 'Sport', icon: 'favorite');
    expect(container.read(ledgerRevisionProvider), greaterThan(before));

    final views = await container.read(categoryBudgetsProvider.future);
    final created = views.firstWhere((v) => v.category.id == id);
    expect(created.category.name, 'Sport');
    expect(created.category.icon, 'favorite');
    expect(created.category.kind, CategoryKind.variable,
        reason: 'new categories default to variable (§10.1)');
  });

  test('renameCategory and setCategoryIcon update the stored category',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    final controller = container.read(budgetsControllerProvider);
    await controller.renameCategory(1, 'Ovqatlanish');
    await controller.setCategoryIcon(1, 'fastfood');

    final views = await container.read(categoryBudgetsProvider.future);
    final cat1 = views.firstWhere((v) => v.category.id == 1).category;
    expect(cat1.name, 'Ovqatlanish');
    expect(cat1.icon, 'fastfood');
  });

  test('setCategoryArchived hides the category from the default budgets '
      'list (used categories can only be archived, never deleted)',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    await container.read(budgetsControllerProvider).setCategoryArchived(1, true);

    final views = await container.read(categoryBudgetsProvider.future);
    expect(views.any((v) => v.category.id == 1), isFalse);
  });

  test('reorderCategories persists the new sortOrder and bumps the revision',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    final before = await container.read(categoryBudgetsProvider.future);
    final ids = before.map((v) => v.category.id).toList();
    final reversed = ids.reversed.toList();

    final rev = container.read(ledgerRevisionProvider);
    await container.read(budgetsControllerProvider).reorderCategories(reversed);
    expect(container.read(ledgerRevisionProvider), greaterThan(rev));

    final after = await container.read(categoryBudgetsProvider.future);
    expect(after.map((v) => v.category.id).toList(), reversed);
  });
}
