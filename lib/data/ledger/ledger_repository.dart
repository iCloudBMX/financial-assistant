import 'package:drift/drift.dart';
import '../../core/ledger/balance_engine.dart';
import '../../core/ledger/ledger_entry.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/result/failure.dart';
import '../../core/result/result.dart';
import '../accounts/account_repository.dart';
import '../db/app_database.dart';

abstract class LedgerRepository {
  Future<int> addExpense({
    required int accountId,
    required Money amount,
    int? categoryId,
    required DateTime occurredAt,
    String? note,
    bool? planned,
  });
  Future<int> addIncome({
    required int accountId,
    required Money amount,
    required IncomeType incomeType,
    required DateTime occurredAt,
    String? note,
  });
  Future<Result<void>> transfer({
    required int fromId,
    required int toId,
    required Money amount,
    required DateTime occurredAt,
    String? note,
  });
  Future<void> adjustBalance({
    required int accountId,
    required Money realBalance,
    required DateTime occurredAt,
    String? note,
  });
  Future<Result<void>> editEntry({
    required int id,
    Money? amount,
    int? categoryId,
    DateTime? occurredAt,
    String? note,
  });
  Future<void> deleteEntry(int id);
  Future<List<LedgerEntry>> entriesForAccount(int accountId);
  Future<List<LedgerEntry>> entriesInPeriod(DateTime start, DateTime endExclusive);
  Future<List<LedgerEntry>> allEntries();
}

class DriftLedgerRepository implements LedgerRepository {
  final AppDatabase db;
  final AccountRepository accounts;
  DriftLedgerRepository(this.db, this.accounts);

  LedgerEntry _map(dynamic r) {
    final currency = CurrencyRegistry.byCode(r.currencyCode as String);
    return LedgerEntry(
      id: r.id as int,
      accountId: r.accountId as int,
      type: LedgerEntryType.values.byName(r.type as String),
      amount: Money(r.amountMinor as int, currency),
      categoryId: r.categoryId as int?,
      incomeType: (r.incomeType as String?) == null
          ? null
          : IncomeType.values.byName(r.incomeType as String),
      transferId: r.transferId as String?,
      allocated: Money(r.allocatedMinor as int, currency),
      planned: r.planned as bool?,
      occurredAt: r.occurredAt as DateTime,
      note: r.note as String?,
    );
  }

  @override
  // TODO(multi-currency): guard amount.currency == account's currency before writing (see editEntry).
  Future<int> addExpense({
    required int accountId,
    required Money amount,
    int? categoryId,
    required DateTime occurredAt,
    String? note,
    bool? planned,
  }) {
    return db.into(db.transactionsTable).insert(
          TransactionsTableCompanion.insert(
            accountId: accountId,
            type: LedgerEntryType.expense.name,
            amountMinor: -amount.minorUnits,
            currencyCode: amount.currency.code,
            categoryId: Value(categoryId),
            planned: Value(planned),
            note: Value(note),
            occurredAt: occurredAt,
            createdAt: DateTime.now(),
          ),
        );
  }

  @override
  // TODO(multi-currency): guard amount.currency == account's currency before writing (see editEntry).
  Future<int> addIncome({
    required int accountId,
    required Money amount,
    required IncomeType incomeType,
    required DateTime occurredAt,
    String? note,
  }) {
    return db.into(db.transactionsTable).insert(
          TransactionsTableCompanion.insert(
            accountId: accountId,
            type: LedgerEntryType.income.name,
            amountMinor: amount.minorUnits,
            currencyCode: amount.currency.code,
            incomeType: Value(incomeType.name),
            note: Value(note),
            occurredAt: occurredAt,
            createdAt: DateTime.now(),
          ),
        );
  }

  @override
  Future<Result<void>> transfer({
    required int fromId,
    required int toId,
    required Money amount,
    required DateTime occurredAt,
    String? note,
  }) async {
    final from = await accounts.byId(fromId);
    final to = await accounts.byId(toId);
    if (from == null || to == null) {
      return const Err(NotFoundFailure('account not found'));
    }
    final transferId = 'transfer-${DateTime.now().microsecondsSinceEpoch}';
    final draft = buildTransfer(
      from: from,
      to: to,
      amount: amount,
      occurredAt: occurredAt,
      transferId: transferId,
      note: note,
    );
    return draft.when(
      err: (f) async => Err<void>(f),
      ok: (d) async {
        await db.transaction(() async {
          await _insertDraft(d.outEntry);
          await _insertDraft(d.inEntry);
        });
        return const Ok(null);
      },
    );
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

  @override
  // TODO(multi-currency): guard amount.currency == account's currency before writing (see editEntry).
  Future<void> adjustBalance({
    required int accountId,
    required Money realBalance,
    required DateTime occurredAt,
    String? note,
  }) async {
    final account = await accounts.byId(accountId);
    if (account == null) return;
    final current = accountBalance(account, await entriesForAccount(accountId));
    final delta = adjustmentDelta(current, realBalance);
    await db.into(db.transactionsTable).insert(
          TransactionsTableCompanion.insert(
            accountId: accountId,
            type: LedgerEntryType.adjustment.name,
            amountMinor: delta.minorUnits,
            currencyCode: delta.currency.code,
            note: Value(note),
            occurredAt: occurredAt,
            createdAt: DateTime.now(),
          ),
        );
  }

  @override
  Future<Result<void>> editEntry({
    required int id,
    Money? amount,
    int? categoryId,
    DateTime? occurredAt,
    String? note,
  }) async {
    final row = await (db.select(db.transactionsTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return const Err(NotFoundFailure('entry not found'));
    final entry = _map(row);
    if (entry.type == LedgerEntryType.transferOut ||
        entry.type == LedgerEntryType.transferIn) {
      return const Err(
          ValidationFailure('edit a transfer by deleting and re-creating it'));
    }
    if (amount != null && amount.currency != entry.amount.currency) {
      return const Err(ValidationFailure(
          'cannot change an entry to a different currency; delete and re-create it instead'));
    }
    int? newMinor;
    if (amount != null) {
      newMinor = entry.type == LedgerEntryType.expense
          ? -amount.minorUnits
          : amount.minorUnits;
    }
    await (db.update(db.transactionsTable)..where((t) => t.id.equals(id)))
        .write(TransactionsTableCompanion(
      amountMinor: newMinor == null ? const Value.absent() : Value(newMinor),
      categoryId: categoryId == null ? const Value.absent() : Value(categoryId),
      occurredAt:
          occurredAt == null ? const Value.absent() : Value(occurredAt),
      note: note == null ? const Value.absent() : Value(note),
    ));
    return const Ok(null);
  }

  @override
  Future<void> deleteEntry(int id) async {
    final row = await (db.select(db.transactionsTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    final transferId = row.transferId;
    if (transferId != null) {
      await (db.delete(db.transactionsTable)
            ..where((t) => t.transferId.equals(transferId)))
          .go();
    } else {
      await (db.delete(db.transactionsTable)..where((t) => t.id.equals(id)))
          .go();
    }
  }

  @override
  Future<List<LedgerEntry>> entriesForAccount(int accountId) async {
    final rows = await (db.select(db.transactionsTable)
          ..where((t) => t.accountId.equals(accountId)))
        .get();
    return rows.map(_map).toList();
  }

  @override
  Future<List<LedgerEntry>> entriesInPeriod(
      DateTime start, DateTime endExclusive) async {
    final rows = await (db.select(db.transactionsTable)
          ..where((t) =>
              t.occurredAt.isBiggerOrEqualValue(start) &
              t.occurredAt.isSmallerThanValue(endExclusive)))
        .get();
    return rows.map(_map).toList();
  }

  @override
  Future<List<LedgerEntry>> allEntries() async {
    final rows = await (db.select(db.transactionsTable)
          ..orderBy([(t) => OrderingTerm(expression: t.id)]))
        .get();
    return rows.map(_map).toList();
  }
}
