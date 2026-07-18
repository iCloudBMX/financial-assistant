import 'package:drift/drift.dart';
import 'migrations.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [AppSettingsTable, AppMetaTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => buildMigration(this);
}
