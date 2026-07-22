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
  IntColumn get variableBudgetMinor =>
      integer().withDefault(const Constant(0))();
  IntColumn get safetyBufferMinor =>
      integer().withDefault(const Constant(0))();
  IntColumn get allocationSourceAccountId => integer().nullable()();

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
  TextColumn get role => text().withDefault(const Constant('spending'))(); // AccountRole.name
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
  TextColumn get kind => text().withDefault(const Constant('variable'))();
  IntColumn get monthlyLimitMinor => integer().nullable()();
  IntColumn get weeklyLimitMinor => integer().nullable()();
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

class AllocationDirectionsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bucketKey => text()();
  TextColumn get method => text()(); // AllocationMethod.name
  IntColumn get valueMinor => integer().nullable()(); // fixedAmount
  IntColumn get percentBp => integer().nullable()(); // percentage, basis points
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class IncomeAllocationsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get incomeTransactionId =>
      integer().references(TransactionsTable, #id)();
  TextColumn get bucketKey => text()();
  IntColumn get amountMinor => integer()();
}

class AllocationPlanRulesTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get destinationAccountId =>
      integer().references(AccountsTable, #id)();
  IntColumn get amountMinor => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class GoalsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text().withDefault(const Constant('other'))();
  TextColumn get icon => text().withDefault(const Constant('flag'))();
  IntColumn get targetAmountMinor => integer()();
  TextColumn get currencyCode => text().withDefault(const Constant('UZS'))();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get priority => text().withDefault(const Constant('medium'))();
  TextColumn get status => text().withDefault(const Constant('active'))();
  IntColumn get linkedAccountId =>
      integer().nullable().references(AccountsTable, #id)();
  TextColumn get note => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
}

class GoalContributionsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get goalId => integer().references(GoalsTable, #id)();
  IntColumn get amountMinor => integer()(); // signed: + contribution, − withdrawal
  TextColumn get currencyCode => text()();
  TextColumn get source => text()(); // ContributionSource.name
  IntColumn get sourceAccountId =>
      integer().nullable().references(AccountsTable, #id)();
  IntColumn get incomeTransactionId =>
      integer().nullable().references(TransactionsTable, #id)();
  TextColumn get note => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
}

class MortgagesTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get bank => text().withDefault(const Constant(''))();
  IntColumn get initialLoanMinor => integer()();
  IntColumn get openingPrincipalMinor => integer()();
  IntColumn get annualRateBp => integer().withDefault(const Constant(0))();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  IntColumn get mandatoryPaymentMinor => integer()();
  DateTimeColumn get nextPaymentDate => dateTime()();
  TextColumn get paymentType => text().withDefault(const Constant('annuity'))();
  TextColumn get payoffStrategy => text().withDefault(const Constant('unclear'))();
  TextColumn get currencyCode => text().withDefault(const Constant('UZS'))();
  TextColumn get status => text().withDefault(const Constant('active'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
}

class MortgagePaymentsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get mortgageId => integer().references(MortgagesTable, #id)();
  IntColumn get totalMinor => integer()();
  IntColumn get principalPortionMinor => integer()();
  IntColumn get interestPortionMinor => integer().withDefault(const Constant(0))();
  IntColumn get commissionMinor => integer().withDefault(const Constant(0))();
  IntColumn get insuranceMinor => integer().withDefault(const Constant(0))();
  IntColumn get otherMinor => integer().withDefault(const Constant(0))();
  BoolColumn get isExtra => boolean().withDefault(const Constant(false))();
  IntColumn get ledgerTransactionId =>
      integer().nullable().references(TransactionsTable, #id)();
  TextColumn get currencyCode => text()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
}
