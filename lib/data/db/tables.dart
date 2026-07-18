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

class AccountsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // AccountType.name
  IntColumn get openingBalanceMinor =>
      integer().withDefault(const Constant(0))();
  TextColumn get currencyCode => text().withDefault(const Constant('UZS'))();
  TextColumn get icon => text().withDefault(const Constant('wallet'))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
}

class CategoriesTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(const Constant('category'))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class TransactionsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(AccountsTable, #id)();
  TextColumn get type => text()(); // LedgerEntryType.name
  IntColumn get amountMinor => integer()(); // signed
  TextColumn get currencyCode => text()();
  IntColumn get categoryId =>
      integer().nullable().references(CategoriesTable, #id)();
  TextColumn get incomeType => text().nullable()(); // IncomeType.name
  TextColumn get transferId => text().nullable()();
  IntColumn get allocatedMinor => integer().withDefault(const Constant(0))();
  BoolColumn get planned => boolean().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
}

class RecurringIncomePlansTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(AccountsTable, #id)();
  IntColumn get amountMinor => integer()();
  TextColumn get currencyCode => text()();
  TextColumn get incomeType => text()();
  TextColumn get note => text().nullable()();
  TextColumn get intervalKind => text()(); // IntervalKind.name
  IntColumn get anchorDay => integer()();
  DateTimeColumn get nextDueAt => dateTime()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}
