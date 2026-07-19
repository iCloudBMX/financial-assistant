import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/categories/category_model.dart';
import 'package:financial_assistant/data/budget/budget_repository.dart';

void main() {
  late AppDatabase db;
  late DriftBudgetRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftBudgetRepository(db);
  });
  tearDown(() => db.close());

  test('default categories start as variable with no limits', () async {
    final cats = await repo.categoriesWithBudgets();
    expect(cats, isNotEmpty);
    expect(cats.first.kind, CategoryKind.variable);
    expect(cats.first.monthlyLimitMinor, isNull);
  });

  test('setCategoryKind flips a category to mandatory', () async {
    final id = (await repo.categoriesWithBudgets()).first.id;
    await repo.setCategoryKind(id, CategoryKind.mandatory);
    final c = (await repo.categoriesWithBudgets()).firstWhere((x) => x.id == id);
    expect(c.kind, CategoryKind.mandatory);
  });

  test('setCategoryLimits sets and clears monthly/weekly limits', () async {
    final id = (await repo.categoriesWithBudgets()).first.id;
    await repo.setCategoryLimits(id, monthlyLimitMinor: 500000, weeklyLimitMinor: 150000);
    var c = (await repo.categoriesWithBudgets()).firstWhere((x) => x.id == id);
    expect(c.monthlyLimitMinor, 500000);
    expect(c.weeklyLimitMinor, 150000);

    await repo.setCategoryLimits(id, clearMonthly: true);
    c = (await repo.categoriesWithBudgets()).firstWhere((x) => x.id == id);
    expect(c.monthlyLimitMinor, isNull);
    expect(c.weeklyLimitMinor, 150000); // unchanged
  });
}
