import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
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
}
