import 'package:drift/drift.dart';
import '../db/app_database.dart';
import '../categories/category_model.dart';

abstract class BudgetRepository {
  Future<void> setCategoryKind(int id, CategoryKind kind);

  /// Sets or clears the monthly/weekly limit. Pass a value to set it; pass
  /// `clearMonthly`/`clearWeekly` true to null it out. Omitting both leaves
  /// that limit unchanged.
  Future<void> setCategoryLimits(
    int id, {
    int? monthlyLimitMinor,
    bool clearMonthly = false,
    int? weeklyLimitMinor,
    bool clearWeekly = false,
  });

  Future<List<Category>> categoriesWithBudgets({bool includeArchived = false});
}

class DriftBudgetRepository implements BudgetRepository {
  final AppDatabase db;
  DriftBudgetRepository(this.db);

  Category _map(dynamic r) => Category(
        id: r.id as int,
        name: r.name as String,
        icon: r.icon as String,
        isDefault: r.isDefault as bool,
        archived: r.archived as bool,
        kind: CategoryKind.values.byName(r.kind as String),
        monthlyLimitMinor: r.monthlyLimitMinor as int?,
        weeklyLimitMinor: r.weeklyLimitMinor as int?,
      );

  @override
  Future<void> setCategoryKind(int id, CategoryKind kind) async {
    await (db.update(db.categoriesTable)..where((t) => t.id.equals(id)))
        .write(CategoriesTableCompanion(kind: Value(kind.name)));
  }

  @override
  Future<void> setCategoryLimits(
    int id, {
    int? monthlyLimitMinor,
    bool clearMonthly = false,
    int? weeklyLimitMinor,
    bool clearWeekly = false,
  }) async {
    await (db.update(db.categoriesTable)..where((t) => t.id.equals(id))).write(
      CategoriesTableCompanion(
        monthlyLimitMinor: clearMonthly
            ? const Value(null)
            : (monthlyLimitMinor == null
                ? const Value.absent()
                : Value(monthlyLimitMinor)),
        weeklyLimitMinor: clearWeekly
            ? const Value(null)
            : (weeklyLimitMinor == null
                ? const Value.absent()
                : Value(weeklyLimitMinor)),
      ),
    );
  }

  @override
  Future<List<Category>> categoriesWithBudgets(
      {bool includeArchived = false}) async {
    final q = db.select(db.categoriesTable)
      ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
    if (!includeArchived) q.where((t) => t.archived.equals(false));
    final rows = await q.get();
    return rows.map(_map).toList();
  }
}
