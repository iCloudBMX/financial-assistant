import 'package:drift/drift.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/mortgage/mortgage_engine.dart';
import '../db/app_database.dart';
import '../ledger/ledger_repository.dart';
import 'mortgage_model.dart';

/// The name of the seeded expense category every mortgage payment books against.
const String kMortgageCategoryName = 'Ipoteka';

abstract class MortgageRepository {
  Future<List<Mortgage>> list({bool includeArchived = false});
  Future<Mortgage?> byId(int id);
  Future<int> create(MortgageDraft draft);
  Future<void> update(int id, MortgageDraft draft);
  Future<void> setStatus(int id, MortgageStatus status);
  Future<void> setNextPaymentDate(int id, DateTime next);
  Future<void> archive(int id);
  Future<void> delete(int id);
  Future<int> recordPayment({
    required int mortgageId,
    required MortgagePaymentSplit split,
    required int accountId,
    bool isExtra,
    String? note,
    DateTime? occurredAt,
  });
  Future<List<MortgagePayment>> payments(int mortgageId);
  Future<int> currentPrincipalMinor(int mortgageId);
  Future<MortgageTotals> totals(int mortgageId);
  Future<int> unpaidMandatoryMinor({
    required DateTime periodStart,
    required DateTime periodEndExclusive,
  });
}

class DriftMortgageRepository implements MortgageRepository {
  final AppDatabase db;
  final LedgerRepository ledger;
  DriftMortgageRepository(this.db, this.ledger);

  Mortgage _map(MortgagesTableData r) => Mortgage(
        id: r.id,
        name: r.name,
        bank: r.bank,
        initialLoanMinor: r.initialLoanMinor,
        openingPrincipalMinor: r.openingPrincipalMinor,
        annualRateBp: r.annualRateBp,
        startDate: r.startDate,
        endDate: r.endDate,
        mandatoryPaymentMinor: r.mandatoryPaymentMinor,
        nextPaymentDate: r.nextPaymentDate,
        paymentType: PaymentType.values.byName(r.paymentType),
        payoffStrategy: PayoffStrategy.values.byName(r.payoffStrategy),
        currencyCode: r.currencyCode,
        status: MortgageStatus.values.byName(r.status),
        sortOrder: r.sortOrder,
        createdAt: r.createdAt,
      );

  MortgagePayment _mapPayment(MortgagePaymentsTableData r) => MortgagePayment(
        id: r.id,
        mortgageId: r.mortgageId,
        totalMinor: r.totalMinor,
        principalPortionMinor: r.principalPortionMinor,
        interestPortionMinor: r.interestPortionMinor,
        commissionMinor: r.commissionMinor,
        insuranceMinor: r.insuranceMinor,
        otherMinor: r.otherMinor,
        isExtra: r.isExtra,
        ledgerTransactionId: r.ledgerTransactionId,
        currencyCode: r.currencyCode,
        occurredAt: r.occurredAt,
        note: r.note,
        createdAt: r.createdAt,
      );

  @override
  Future<List<Mortgage>> list({bool includeArchived = false}) async {
    final q = db.select(db.mortgagesTable)
      ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
    if (!includeArchived) {
      q.where((t) => t.status.equals(MortgageStatus.archived.name).not());
    }
    return (await q.get()).map(_map).toList();
  }

  @override
  Future<Mortgage?> byId(int id) async {
    final r = await (db.select(db.mortgagesTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return r == null ? null : _map(r);
  }

  @override
  Future<int> create(MortgageDraft d) => db.into(db.mortgagesTable).insert(
        MortgagesTableCompanion.insert(
          name: d.name,
          bank: Value(d.bank),
          initialLoanMinor: d.initialLoanMinor,
          openingPrincipalMinor: d.openingPrincipalMinor,
          annualRateBp: Value(d.annualRateBp),
          startDate: d.startDate,
          endDate: Value(d.endDate),
          mandatoryPaymentMinor: d.mandatoryPaymentMinor,
          nextPaymentDate: d.nextPaymentDate,
          paymentType: Value(d.paymentType.name),
          payoffStrategy: Value(d.payoffStrategy.name),
          currencyCode: Value(d.currencyCode),
        ),
      );

  @override
  Future<void> update(int id, MortgageDraft d) async {
    await (db.update(db.mortgagesTable)..where((t) => t.id.equals(id))).write(
      MortgagesTableCompanion(
        name: Value(d.name),
        bank: Value(d.bank),
        initialLoanMinor: Value(d.initialLoanMinor),
        openingPrincipalMinor: Value(d.openingPrincipalMinor),
        annualRateBp: Value(d.annualRateBp),
        startDate: Value(d.startDate),
        endDate: Value(d.endDate),
        mandatoryPaymentMinor: Value(d.mandatoryPaymentMinor),
        nextPaymentDate: Value(d.nextPaymentDate),
        paymentType: Value(d.paymentType.name),
        payoffStrategy: Value(d.payoffStrategy.name),
        currencyCode: Value(d.currencyCode),
      ),
    );
  }

  @override
  Future<void> setStatus(int id, MortgageStatus status) async {
    await (db.update(db.mortgagesTable)..where((t) => t.id.equals(id)))
        .write(MortgagesTableCompanion(status: Value(status.name)));
  }

  @override
  Future<void> setNextPaymentDate(int id, DateTime next) async {
    await (db.update(db.mortgagesTable)..where((t) => t.id.equals(id)))
        .write(MortgagesTableCompanion(nextPaymentDate: Value(next)));
  }

  @override
  Future<void> archive(int id) => setStatus(id, MortgageStatus.archived);

  @override
  Future<void> delete(int id) async {
    await db.transaction(() async {
      await (db.delete(db.mortgagePaymentsTable)
            ..where((t) => t.mortgageId.equals(id)))
          .go();
      await (db.delete(db.mortgagesTable)..where((t) => t.id.equals(id))).go();
    });
  }

  /// Find-or-create the seeded "Ipoteka" expense category and return its id.
  Future<int> _mortgageCategoryId() async {
    final existing = await (db.select(db.categoriesTable)
          ..where((t) => t.name.equals(kMortgageCategoryName)))
        .getSingleOrNull();
    if (existing != null) return existing.id;
    return db.into(db.categoriesTable).insert(
          CategoriesTableCompanion.insert(
            name: kMortgageCategoryName,
            icon: const Value('account_balance'),
            isDefault: const Value(true),
            kind: const Value('mandatory'),
          ),
        );
  }

  @override
  Future<int> recordPayment({
    required int mortgageId,
    required MortgagePaymentSplit split,
    required int accountId,
    bool isExtra = false,
    String? note,
    DateTime? occurredAt,
  }) async {
    final mortgage = await (db.select(db.mortgagesTable)
          ..where((t) => t.id.equals(mortgageId)))
        .getSingle();
    final currency = CurrencyRegistry.byCode(mortgage.currencyCode);
    final when = occurredAt ?? DateTime.now();
    final categoryId = await _mortgageCategoryId();
    return db.transaction(() async {
      // Real money leaves the account: one ledger expense for the full total.
      final txnId = await ledger.addExpense(
        accountId: accountId,
        amount: Money(split.totalMinor, currency),
        categoryId: categoryId,
        occurredAt: when,
        note: note ?? mortgage.name,
      );
      return db.into(db.mortgagePaymentsTable).insert(
            MortgagePaymentsTableCompanion.insert(
              mortgageId: mortgageId,
              totalMinor: split.totalMinor,
              principalPortionMinor: split.principalMinor,
              interestPortionMinor: Value(split.interestMinor),
              commissionMinor: Value(split.commissionMinor),
              insuranceMinor: Value(split.insuranceMinor),
              otherMinor: Value(split.otherMinor),
              isExtra: Value(isExtra),
              ledgerTransactionId: Value(txnId),
              currencyCode: mortgage.currencyCode,
              occurredAt: when,
              note: Value(note),
            ),
          );
    });
  }

  @override
  Future<List<MortgagePayment>> payments(int mortgageId) async {
    final q = db.select(db.mortgagePaymentsTable)
      ..where((t) => t.mortgageId.equals(mortgageId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.occurredAt, mode: OrderingMode.desc)
      ]);
    return (await q.get()).map(_mapPayment).toList();
  }

  Future<List<MortgagePaymentsTableData>> _rows(int mortgageId) =>
      (db.select(db.mortgagePaymentsTable)
            ..where((t) => t.mortgageId.equals(mortgageId)))
          .get();

  @override
  Future<int> currentPrincipalMinor(int mortgageId) async {
    final m = await byId(mortgageId);
    if (m == null) return 0;
    final rows = await _rows(mortgageId);
    final paid = rows.fold<int>(0, (s, r) => s + r.principalPortionMinor);
    return m.openingPrincipalMinor - paid;
  }

  @override
  Future<MortgageTotals> totals(int mortgageId) async {
    final rows = await _rows(mortgageId);
    var paid = 0, principal = 0, interest = 0, extra = 0;
    for (final r in rows) {
      paid += r.totalMinor;
      principal += r.principalPortionMinor;
      interest += r.interestPortionMinor;
      if (r.isExtra) extra += r.totalMinor;
    }
    return MortgageTotals(
      paidMinor: paid,
      principalPaidMinor: principal,
      interestPaidMinor: interest,
      extraPaidMinor: extra,
    );
  }

  @override
  Future<int> unpaidMandatoryMinor({
    required DateTime periodStart,
    required DateTime periodEndExclusive,
  }) async {
    final active = await (db.select(db.mortgagesTable)
          ..where((t) => t.status.equals(MortgageStatus.active.name)))
        .get();
    var total = 0;
    for (final m in active) {
      // TODO(multi-currency): assumes the mortgage currency is the primary.
      if (m.nextPaymentDate.isAfter(periodEndExclusive)) continue;
      final rows = await _rows(m.id);
      final paidThisPeriod = rows.any((r) =>
          !r.isExtra &&
          !r.occurredAt.isBefore(periodStart) &&
          r.occurredAt.isBefore(periodEndExclusive));
      if (!paidThisPeriod) total += m.mandatoryPaymentMinor;
    }
    return total;
  }
}
