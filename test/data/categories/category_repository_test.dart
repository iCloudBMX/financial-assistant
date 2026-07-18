// test/data/categories/category_repository_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/categories/category_repository.dart';

void main() {
  late AppDatabase db;
  late CategoryRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftCategoryRepository(db);
  });
  tearDown(() => db.close());

  test('the 13 defaults are present and flagged isDefault', () async {
    final cats = await repo.list();
    expect(cats.length, 13);
    expect(cats.where((c) => c.isDefault).length, 13);
  });

  test('create, rename, and archive a custom category', () async {
    final id = await repo.create(name: 'Xayriya', icon: 'volunteer_activism');
    await repo.rename(id, 'Ehson');
    await repo.setArchived(id, true);
    final all = await repo.list(includeArchived: true);
    final mine = all.firstWhere((c) => c.id == id);
    expect(mine.name, 'Ehson');
    expect(mine.archived, isTrue);
    expect(mine.isDefault, isFalse);
    // archived categories are hidden from the default list (PRD §10.2)
    expect((await repo.list()).any((c) => c.id == id), isFalse);
  });
}
