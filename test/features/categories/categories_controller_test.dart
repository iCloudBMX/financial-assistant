import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/categories/categories_controller.dart';

void main() {
  test('createCategory then it appears in categoriesProvider', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    final before = container.read(ledgerRevisionProvider);
    final id = await container
        .read(categoriesControllerProvider)
        .createCategory(name: 'Sport', icon: 'category');
    expect(container.read(ledgerRevisionProvider), greaterThan(before));

    final cats = await container.read(categoriesProvider.future);
    expect(cats.any((c) => c.id == id && c.name == 'Sport'), isTrue);
  });

  test('renameCategory and setCategoryIcon update the stored category',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    final controller = container.read(categoriesControllerProvider);
    await controller.renameCategory(1, 'Ovqatlanish');
    await controller.setCategoryIcon(1, 'fastfood');

    final cats = await container.read(categoriesProvider.future);
    final cat1 = cats.firstWhere((c) => c.id == 1);
    expect(cat1.name, 'Ovqatlanish');
    expect(cat1.icon, 'fastfood');
  });

  test('setCategoryArchived hides then restores a category', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    await container
        .read(categoriesControllerProvider)
        .setCategoryArchived(1, true);
    var cats = await container.read(categoriesProvider.future);
    expect(cats.firstWhere((c) => c.id == 1).archived, isTrue);

    await container
        .read(categoriesControllerProvider)
        .setCategoryArchived(1, false);
    cats = await container.read(categoriesProvider.future);
    expect(cats.firstWhere((c) => c.id == 1).archived, isFalse);
  });

  test('reorderCategories persists new order', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    final before = await container.read(categoriesProvider.future);
    final ids = before.map((c) => c.id).toList();
    final reversed = ids.reversed.toList();

    final rev = container.read(ledgerRevisionProvider);
    await container
        .read(categoriesControllerProvider)
        .reorderCategories(reversed);
    expect(container.read(ledgerRevisionProvider), greaterThan(rev));

    final after = await container.read(categoriesProvider.future);
    expect(after.map((c) => c.id).toList(), reversed);
  });

  test('saveCategory (new) creates and returns Ok(id)', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    final res = await container
        .read(categoriesControllerProvider)
        .saveCategory(name: 'Kitob', icon: 'category');
    expect(res.isOk, isTrue);
    final cats = await container.read(categoriesProvider.future);
    expect(cats.any((c) => c.name == 'Kitob'), isTrue);
  });

  test('saveCategory (existing id) renames and re-icons the category',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    final res = await container.read(categoriesControllerProvider).saveCategory(
          id: 1,
          name: 'Ovqatlanish',
          icon: 'fastfood',
        );
    expect(res.isOk, isTrue);
    final cats = await container.read(categoriesProvider.future);
    final cat1 = cats.firstWhere((c) => c.id == 1);
    expect(cat1.name, 'Ovqatlanish');
    expect(cat1.icon, 'fastfood');
  });
}
