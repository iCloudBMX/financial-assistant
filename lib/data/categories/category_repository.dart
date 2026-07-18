import 'package:drift/drift.dart';
import '../db/app_database.dart';
import 'category_model.dart';

abstract class CategoryRepository {
  Future<int> create({required String name, required String icon});
  Future<void> rename(int id, String name);
  Future<void> setIcon(int id, String icon);
  Future<void> setArchived(int id, bool archived);
  Future<void> reorder(List<int> orderedIds);
  Future<List<Category>> list({bool includeArchived = false});
}

class DriftCategoryRepository implements CategoryRepository {
  final AppDatabase db;
  DriftCategoryRepository(this.db);

  Category _map(dynamic r) => Category(
        id: r.id as int,
        name: r.name as String,
        icon: r.icon as String,
        isDefault: r.isDefault as bool,
        archived: r.archived as bool,
      );

  @override
  Future<int> create({required String name, required String icon}) {
    return db.into(db.categoriesTable).insert(
          CategoriesTableCompanion.insert(name: name, icon: Value(icon)),
        );
  }

  @override
  Future<void> rename(int id, String name) async {
    await (db.update(db.categoriesTable)..where((t) => t.id.equals(id)))
        .write(CategoriesTableCompanion(name: Value(name)));
  }

  @override
  Future<void> setIcon(int id, String icon) async {
    await (db.update(db.categoriesTable)..where((t) => t.id.equals(id)))
        .write(CategoriesTableCompanion(icon: Value(icon)));
  }

  @override
  Future<void> setArchived(int id, bool archived) async {
    await (db.update(db.categoriesTable)..where((t) => t.id.equals(id)))
        .write(CategoriesTableCompanion(archived: Value(archived)));
  }

  @override
  Future<void> reorder(List<int> orderedIds) async {
    await db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (db.update(db.categoriesTable)
              ..where((t) => t.id.equals(orderedIds[i])))
            .write(CategoriesTableCompanion(sortOrder: Value(i)));
      }
    });
  }

  @override
  Future<List<Category>> list({bool includeArchived = false}) async {
    final q = db.select(db.categoriesTable)
      ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
    if (!includeArchived) q.where((t) => t.archived.equals(false));
    final rows = await q.get();
    return rows.map(_map).toList();
  }
}
