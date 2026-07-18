import 'package:drift/drift.dart';

class AppSettingsTable extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get primaryCurrency =>
      text().withDefault(const Constant('UZS'))();
  TextColumn get dateFormat =>
      text().withDefault(const Constant('dd.MM.yyyy'))();
  IntColumn get periodStartDay => integer().withDefault(const Constant(1))();
  IntColumn get weekStartIso => integer().withDefault(const Constant(1))();
  TextColumn get dailyLimitMethod =>
      text().withDefault(const Constant('evenSplit'))();
  IntColumn get minReserveMinor => integer().withDefault(const Constant(0))();
  TextColumn get minReserveCurrency =>
      text().withDefault(const Constant('UZS'))();
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  BoolColumn get appLockEnabled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get biometricEnabled =>
      boolean().withDefault(const Constant(false))();
  TextColumn get savingsRolloverMode =>
      text().withDefault(const Constant('askEachTime'))();
  TextColumn get notificationFlagsJson =>
      text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

class AppMetaTable extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  IntColumn get schemaVersion => integer().withDefault(const Constant(1))();
  DateTimeColumn get installedAt => dateTime()();
  BoolColumn get onboardingComplete =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastBackupAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
