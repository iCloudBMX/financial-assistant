import 'package:drift/drift.dart';
import '../../core/allocation/allocation_models.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../db/app_database.dart';

abstract class AllocationRepository {
  Future<AllocationTemplate> template();
  Future<void> saveTemplate(List<AllocationDirection> directions);

  /// Replaces [incomeTransactionId]'s allocation with [perBucket] and sets the
  /// income row's `allocatedMinor` to the total, atomically.
  Future<void> allocateIncome(
      int incomeTransactionId, Map<String, Money> perBucket);

  /// Σ of every income allocation per bucketKey, as [currency].
  ///
  /// Not consumed anywhere in `lib/` as of SP2 — this is a forward-facing
  /// read for SP3/SP4 (goal and mortgage bucket reserves feeding
  /// `SafeLimitInputs.goalReserves`/`unpaidMandatory`). It is not dead code
  /// and SP2's safe-limit engine does not read bucket allocations as a
  /// reserve; do not remove it.
  Future<Map<String, Money>> reservedTotals(Currency currency);
}

class DriftAllocationRepository implements AllocationRepository {
  final AppDatabase db;
  DriftAllocationRepository(this.db);

  @override
  Future<AllocationTemplate> template() async {
    final rows = await (db.select(db.allocationDirectionsTable)
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
    final dirs = rows.map((r) {
      final method = AllocationMethod.values.byName(r.method);
      return AllocationDirection(
        bucketKey: r.bucketKey,
        method: method,
        amount: r.valueMinor == null
            ? null
            : Money(r.valueMinor!, CurrencyRegistry.uzs),
        percentBp: r.percentBp,
      );
    }).toList();
    return AllocationTemplate(dirs);
  }

  @override
  Future<void> saveTemplate(List<AllocationDirection> directions) async {
    await db.transaction(() async {
      await db.delete(db.allocationDirectionsTable).go();
      for (var i = 0; i < directions.length; i++) {
        final d = directions[i];
        await db.into(db.allocationDirectionsTable).insert(
              AllocationDirectionsTableCompanion.insert(
                bucketKey: d.bucketKey,
                method: d.method.name,
                valueMinor: Value(d.amount?.minorUnits),
                percentBp: Value(d.percentBp),
                sortOrder: Value(i),
              ),
            );
      }
    });
  }

  @override
  Future<void> allocateIncome(
      int incomeTransactionId, Map<String, Money> perBucket) async {
    await db.transaction(() async {
      await (db.delete(db.incomeAllocationsTable)
            ..where((t) => t.incomeTransactionId.equals(incomeTransactionId)))
          .go();
      var total = 0;
      for (final entry in perBucket.entries) {
        if (entry.value.minorUnits == 0) continue;
        total += entry.value.minorUnits;
        await db.into(db.incomeAllocationsTable).insert(
              IncomeAllocationsTableCompanion.insert(
                incomeTransactionId: incomeTransactionId,
                bucketKey: entry.key,
                amountMinor: entry.value.minorUnits,
              ),
            );
      }
      await (db.update(db.transactionsTable)
            ..where((t) => t.id.equals(incomeTransactionId)))
          .write(TransactionsTableCompanion(allocatedMinor: Value(total)));
    });
  }

  /// See [AllocationRepository.reservedTotals]: unused by SP2, kept for
  /// SP3/SP4 bucket-reserve reads.
  @override
  Future<Map<String, Money>> reservedTotals(Currency currency) async {
    final rows = await db.select(db.incomeAllocationsTable).get();
    final out = <String, Money>{};
    for (final r in rows) {
      final add = Money(r.amountMinor, currency);
      final existing = out[r.bucketKey];
      out[r.bucketKey] = existing == null ? add : existing.add(add);
    }
    return out;
  }
}
