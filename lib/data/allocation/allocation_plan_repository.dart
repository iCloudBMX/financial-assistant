import 'package:drift/drift.dart';
import '../../core/allocation/allocation_plan.dart';
import '../../core/ledger/balance_engine.dart';
import '../../core/ledger/ledger_entry.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/result/failure.dart';
import '../../core/result/result.dart';
import '../accounts/account_repository.dart';
import '../db/app_database.dart';

abstract class AllocationPlanRepository {
  Future<AllocationPlan> plan();
  Future<void> saveRules(List<AllocationRule> rules);
  Future<void> setSource(int? accountId);

  /// Executes [transfers] from [sourceId] as internal card-to-card transfers
  /// in ONE database transaction — all-or-nothing. Each transfer becomes a
  /// transferOut/transferIn pair (never income/expense).
  Future<Result<void>> applyPlan(int sourceId, List<PlannedTransfer> transfers);
}

class DriftAllocationPlanRepository implements AllocationPlanRepository {
  final AppDatabase db;
  final AccountRepository accounts;
  DriftAllocationPlanRepository(this.db, this.accounts);

  @override
  Future<AllocationPlan> plan() async {
    final settingsRow = await db.select(db.appSettingsTable).getSingle();
    final currency = CurrencyRegistry.byCode(settingsRow.primaryCurrency);
    final rows = await (db.select(db.allocationPlanRulesTable)
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
    final rules = [
      for (final r in rows)
        AllocationRule(
          destinationAccountId: r.destinationAccountId,
          amount: Money(r.amountMinor, currency),
          sortOrder: r.sortOrder,
        ),
    ];
    return AllocationPlan(
      sourceAccountId: settingsRow.allocationSourceAccountId,
      rules: rules,
    );
  }

  @override
  Future<void> saveRules(List<AllocationRule> rules) async {
    await db.transaction(() async {
      await db.delete(db.allocationPlanRulesTable).go();
      for (var i = 0; i < rules.length; i++) {
        final r = rules[i];
        await db.into(db.allocationPlanRulesTable).insert(
              AllocationPlanRulesTableCompanion.insert(
                destinationAccountId: r.destinationAccountId,
                amountMinor: r.amount.minorUnits,
                sortOrder: Value(i),
              ),
            );
      }
    });
  }

  @override
  Future<void> setSource(int? accountId) async {
    await (db.update(db.appSettingsTable)..where((t) => t.id.equals(0))).write(
      AppSettingsTableCompanion(allocationSourceAccountId: Value(accountId)),
    );
  }

  @override
  Future<Result<void>> applyPlan(
      int sourceId, List<PlannedTransfer> transfers) async {
    if (transfers.isEmpty) return const Ok(null);
    final from = await accounts.byId(sourceId);
    if (from == null) {
      return const Err(NotFoundFailure('source account not found'));
    }
    // Resolve and validate every draft BEFORE writing, so a bad transfer
    // aborts the whole apply without a partial write.
    final drafts = <TransferDraft>[];
    final base = DateTime.now();
    for (var i = 0; i < transfers.length; i++) {
      final t = transfers[i];
      final to = await accounts.byId(t.destinationAccountId);
      if (to == null) {
        return const Err(NotFoundFailure('destination account not found'));
      }
      final draft = buildTransfer(
        from: from,
        to: to,
        amount: t.amount,
        occurredAt: base,
        transferId: 'transfer-${base.microsecondsSinceEpoch}-$i',
      );
      final unwrapped = draft.valueOrNull;
      if (unwrapped == null) {
        return draft.when(ok: (_) => const Ok(null), err: (f) => Err<void>(f));
      }
      drafts.add(unwrapped);
    }
    try {
      await db.transaction(() async {
        for (final d in drafts) {
          await _insertDraft(d.outEntry);
          await _insertDraft(d.inEntry);
        }
      });
      return const Ok(null);
    } catch (error) {
      return Err(PersistenceFailure(error.toString()));
    }
  }

  Future<void> _insertDraft(LedgerEntry e) {
    return db.into(db.transactionsTable).insert(
          TransactionsTableCompanion.insert(
            accountId: e.accountId,
            type: e.type.name,
            amountMinor: e.amount.minorUnits,
            currencyCode: e.amount.currency.code,
            transferId: Value(e.transferId),
            note: Value(e.note),
            occurredAt: e.occurredAt,
            createdAt: DateTime.now(),
          ),
        );
  }
}
