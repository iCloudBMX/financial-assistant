import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/core/result/failure.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/recurring/recurring_model.dart';
import 'package:financial_assistant/data/recurring/recurring_repository.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/income_entry/income_entry_controller.dart';

/// Wraps the real repository but fails `create`, to prove that the income
/// ledger write rolls back when the recurring-plan write in the same
/// transaction fails.
class _ThrowingRecurringIncomeRepository implements RecurringIncomeRepository {
  _ThrowingRecurringIncomeRepository(this._delegate);
  final RecurringIncomeRepository _delegate;

  @override
  Future<int> create({
    required int accountId,
    required Money amount,
    required IncomeType incomeType,
    String? note,
    required IntervalKind intervalKind,
    required int anchorDay,
    required DateTime nextDueAt,
  }) {
    throw Exception('forced recurring-plan failure');
  }

  @override
  Future<List<RecurringIncomePlan>> listActive() => _delegate.listActive();

  @override
  Future<List<RecurringIncomePlan>> duePlans(DateTime asOf) =>
      _delegate.duePlans(asOf);

  @override
  Future<void> markConfirmed(int id) => _delegate.markConfirmed(id);

  @override
  Future<void> deactivate(int id) => _delegate.deactivate(id);
}

void main() {
  const uzs = CurrencyRegistry.uzs;
  const usd = CurrencyRegistry.usd;

  test('income is recorded undistributed and shows on the dashboard', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    final accId = await c.read(accountRepositoryProvider).create(
        name: 'Naqd', type: AccountType.cash, openingBalance: const Money(0, uzs), icon: 'w');

    final result = await c.read(incomeEntryControllerProvider.notifier).save(
        accountId: accId, amount: const Money(5000000, uzs), incomeType: IncomeType.salary);
    expect(result.isOk, isTrue);
    expect(result.valueOrNull!.recurringPlanId, isNull);

    final data = await c.read(dashboardProvider.future);
    expect(data.monthIncome, const Money(5000000, uzs));
    expect(data.undistributedFunds, const Money(5000000, uzs));
  });

  test('a recurring income also creates an active plan, returned in the result',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    final accId = await c.read(accountRepositoryProvider).create(
        name: 'Naqd', type: AccountType.cash, openingBalance: const Money(0, uzs), icon: 'w');

    final result = await c.read(incomeEntryControllerProvider.notifier).save(
        accountId: accId, amount: const Money(5000000, uzs), incomeType: IncomeType.salary,
        occurredAt: DateTime(2026, 7, 5), recurring: true,
        intervalKind: IntervalKind.monthly, anchorDay: 5);

    expect(result.isOk, isTrue);
    expect(result.valueOrNull!.recurringPlanId, isNotNull);

    final plans = await c.read(recurringIncomeRepositoryProvider).listActive();
    expect(plans.length, 1);
    expect(plans.single.anchorDay, 5);
    expect(plans.single.nextDueAt, DateTime(2026, 8, 5)); // next occurrence
  });

  test('save rejects a non-positive amount', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    final accId = await c.read(accountRepositoryProvider).create(
        name: 'Naqd', type: AccountType.cash, openingBalance: const Money(0, uzs), icon: 'w');

    final result = await c.read(incomeEntryControllerProvider.notifier).save(
        accountId: accId, amount: const Money(0, uzs), incomeType: IncomeType.salary);
    expect(result.isOk, isFalse);
    result.when(
      ok: (_) => fail('expected Err'),
      err: (f) => expect(f, isA<ValidationFailure>()),
    );
    expect(await c.read(ledgerRepositoryProvider).allEntries(), isEmpty);
  });

  test('save returns CurrencyFailure when the amount currency does not match the account',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    final accId = await c.read(accountRepositoryProvider).create(
        name: 'Naqd', type: AccountType.cash, openingBalance: const Money(0, uzs), icon: 'w');

    final result = await c.read(incomeEntryControllerProvider.notifier).save(
        accountId: accId, amount: const Money(5000, usd), incomeType: IncomeType.salary);
    expect(result.isOk, isFalse);
    result.when(
      ok: (_) => fail('expected Err'),
      err: (f) => expect(f, isA<CurrencyFailure>()),
    );
    expect(await c.read(ledgerRepositoryProvider).allEntries(), isEmpty);
  });

  test(
      'when the recurring-plan write fails, the income ledger entry rolls back too',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final realRecurring = DriftRecurringIncomeRepository(db);
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      recurringIncomeRepositoryProvider.overrideWithValue(
        _ThrowingRecurringIncomeRepository(realRecurring),
      ),
    ]);
    addTearDown(c.dispose);
    final accId = await c.read(accountRepositoryProvider).create(
        name: 'Naqd', type: AccountType.cash, openingBalance: const Money(0, uzs), icon: 'w');

    final result = await c.read(incomeEntryControllerProvider.notifier).save(
        accountId: accId, amount: const Money(5000000, uzs), incomeType: IncomeType.salary,
        occurredAt: DateTime(2026, 7, 5), recurring: true,
        intervalKind: IntervalKind.monthly, anchorDay: 5);

    expect(result.isOk, isFalse);
    result.when(
      ok: (_) => fail('expected Err'),
      err: (f) => expect(f, isA<PersistenceFailure>()),
    );
    // Rolled back: no ledger entry and no recurring plan survive the failure.
    expect(await c.read(ledgerRepositoryProvider).allEntries(), isEmpty);
    expect(await realRecurring.listActive(), isEmpty);
  });
}
