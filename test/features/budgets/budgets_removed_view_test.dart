import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/budgets/budgets_controller.dart';

void main() {
  test('archivedCategoriesProvider lists only archived categories, and '
      'restoring returns the category to the active list', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    await container.read(budgetsControllerProvider).setCategoryArchived(1, true);
    final archived = await container.read(archivedCategoriesProvider.future);
    expect(archived.map((c) => c.id), contains(1));
    expect(archived.every((c) => c.archived), isTrue);

    await container.read(budgetsControllerProvider).setCategoryArchived(1, false);
    final active = await container.read(categoryBudgetsProvider.future);
    expect(active.any((v) => v.category.id == 1), isTrue);
  });
}
