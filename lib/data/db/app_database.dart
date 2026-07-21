import 'package:drift/drift.dart';
import 'migrations.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  AppSettingsTable,
  AppMetaTable,
  AccountsTable,
  CategoriesTable,
  TransactionsTable,
  RecurringIncomePlansTable,
  AllocationDirectionsTable,
  IncomeAllocationsTable,
  GoalsTable,
  GoalContributionsTable,
  MortgagesTable,
  MortgagePaymentsTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => buildMigration(this);
}
