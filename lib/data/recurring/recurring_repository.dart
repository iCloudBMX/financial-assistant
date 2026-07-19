import 'package:drift/drift.dart';
import '../../core/ledger/ledger_entry.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../db/app_database.dart';
import 'recurring_model.dart';

abstract class RecurringIncomeRepository {
  Future<int> create({
    required int accountId,
    required Money amount,
    required IncomeType incomeType,
    String? note,
    required IntervalKind intervalKind,
    required int anchorDay,
    required DateTime nextDueAt,
  });
  Future<List<RecurringIncomePlan>> listActive();
  Future<List<RecurringIncomePlan>> duePlans(DateTime asOf);
  Future<void> markConfirmed(int id);

  /// Moves this plan's due date to an explicit [newDueAt] without advancing a
  /// whole period (postpone this occurrence, distinct from skip). The anchor
  /// day is untouched, so the following occurrence still derives from it.
  Future<void> postponeTo(int id, DateTime newDueAt);
  Future<void> deactivate(int id);
}

class DriftRecurringIncomeRepository implements RecurringIncomeRepository {
  final AppDatabase db;
  DriftRecurringIncomeRepository(this.db);

  RecurringIncomePlan _map(dynamic r) => RecurringIncomePlan(
        id: r.id as int,
        accountId: r.accountId as int,
        amount: Money(r.amountMinor as int,
            CurrencyRegistry.byCode(r.currencyCode as String)),
        incomeType: IncomeType.values.byName(r.incomeType as String),
        note: r.note as String?,
        intervalKind: IntervalKind.values.byName(r.intervalKind as String),
        anchorDay: r.anchorDay as int,
        nextDueAt: r.nextDueAt as DateTime,
        active: r.active as bool,
      );

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
    return db.into(db.recurringIncomePlansTable).insert(
          RecurringIncomePlansTableCompanion.insert(
            accountId: accountId,
            amountMinor: amount.minorUnits,
            currencyCode: amount.currency.code,
            incomeType: incomeType.name,
            note: Value(note),
            intervalKind: intervalKind.name,
            anchorDay: anchorDay,
            nextDueAt: nextDueAt,
          ),
        );
  }

  @override
  Future<List<RecurringIncomePlan>> listActive() async {
    final rows = await (db.select(db.recurringIncomePlansTable)
          ..where((t) => t.active.equals(true)))
        .get();
    return rows.map(_map).toList();
  }

  @override
  Future<List<RecurringIncomePlan>> duePlans(DateTime asOf) async {
    final rows = await (db.select(db.recurringIncomePlansTable)
          ..where((t) =>
              t.active.equals(true) &
              t.nextDueAt.isSmallerOrEqualValue(asOf)))
        .get();
    return rows.map(_map).toList();
  }

  @override
  Future<void> markConfirmed(int id) async {
    final row = await (db.select(db.recurringIncomePlansTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    final plan = _map(row);
    final next = nextRecurringDate(
        plan.nextDueAt, plan.intervalKind, plan.anchorDay);
    await (db.update(db.recurringIncomePlansTable)
          ..where((t) => t.id.equals(id)))
        .write(RecurringIncomePlansTableCompanion(nextDueAt: Value(next)));
  }

  @override
  Future<void> postponeTo(int id, DateTime newDueAt) async {
    await (db.update(db.recurringIncomePlansTable)
          ..where((t) => t.id.equals(id)))
        .write(RecurringIncomePlansTableCompanion(nextDueAt: Value(newDueAt)));
  }

  @override
  Future<void> deactivate(int id) async {
    await (db.update(db.recurringIncomePlansTable)
          ..where((t) => t.id.equals(id)))
        .write(const RecurringIncomePlansTableCompanion(active: Value(false)));
  }
}
