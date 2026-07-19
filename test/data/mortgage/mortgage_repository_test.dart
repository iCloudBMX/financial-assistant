import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/mortgage/mortgage_engine.dart';
import 'package:financial_assistant/data/accounts/account_repository.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/ledger/ledger_repository.dart';
import 'package:financial_assistant/data/mortgage/mortgage_model.dart';
import 'package:financial_assistant/data/mortgage/mortgage_repository.dart';

/// A [LedgerRepository] that performs the real expense write (so a row is
/// genuinely inserted inside the ambient `db.transaction` that
/// `recordPayment` opens) and THEN throws — simulating a fault that occurs
/// after the first write of the two-write atomic operation but before the
/// payment insert. Every other member delegates to [inner].
class _FaultAfterLedgerWrite implements LedgerRepository {
  final LedgerRepository inner;
  _FaultAfterLedgerWrite(this.inner);

  @override
  Future<int> addExpense({
    required int accountId,
    required Money amount,
    int? categoryId,
    required DateTime occurredAt,
    String? note,
    bool? planned,
  }) async {
    // Real write — this row lives inside the ambient transaction.
    await inner.addExpense(
      accountId: accountId,
      amount: amount,
      categoryId: categoryId,
      occurredAt: occurredAt,
      note: note,
      planned: planned,
    );
    // ...then fail, before recordPayment can insert the payment row.
    throw StateError('injected failure after the ledger write');
  }

  // Only addExpense is exercised by recordPayment; nothing else on this
  // decorator is called, so the catch-all just satisfies the interface.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  late DriftMortgageRepository repo;
  late AccountRepository accounts;
  late LedgerRepository ledger;

  MortgageDraft draft({int opening = 100000000, int mandatory = 5000000}) =>
      MortgageDraft(
        name: 'Uy',
        initialLoanMinor: 120000000,
        openingPrincipalMinor: opening,
        annualRateBp: 1800,
        startDate: DateTime(2025, 1, 1),
        mandatoryPaymentMinor: mandatory,
        nextPaymentDate: DateTime(2026, 7, 10),
        paymentType: PaymentType.annuity,
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    accounts = DriftAccountRepository(db);
    ledger = DriftLedgerRepository(db, accounts);
    repo = DriftMortgageRepository(db, ledger);
  });
  tearDown(() => db.close());

  Future<int> anAccount() => accounts.create(
        name: 'Karta',
        type: AccountType.bankCard,
        openingBalance: const Money(500000000, CurrencyRegistry.uzs),
        icon: 'card',
      );

  test('create then list returns the mortgage with defaults', () async {
    final id = await repo.create(draft());
    final list = await repo.list();
    expect(list.single.id, id);
    expect(list.single.name, 'Uy');
    expect(list.single.status, MortgageStatus.active);
    expect(list.single.paymentType, PaymentType.annuity);
  });

  test('current principal is opening minus recorded principal portions', () async {
    final acc = await anAccount();
    final id = await repo.create(draft(opening: 100000000));
    await repo.recordPayment(
      mortgageId: id,
      accountId: acc,
      split: const MortgagePaymentSplit(
          totalMinor: 5000000, principalMinor: 3500000, interestMinor: 1500000),
    );
    expect(await repo.currentPrincipalMinor(id), 100000000 - 3500000);
  });

  test('recordPayment writes a linked ledger expense for the full total', () async {
    final acc = await anAccount();
    final id = await repo.create(draft());
    await repo.recordPayment(
      mortgageId: id,
      accountId: acc,
      split: const MortgagePaymentSplit(
          totalMinor: 5000000, principalMinor: 3500000, interestMinor: 1500000),
    );
    final entries = await ledger.entriesForAccount(acc);
    // one expense of the full total (amount stored signed-negative by the ledger)
    expect(entries.length, 1);
    expect(entries.single.amount.minorUnits, -5000000);
    // the payment row links back to that ledger transaction
    final pay = (await repo.payments(id)).single;
    expect(pay.ledgerTransactionId, entries.single.id);
    expect(pay.totalMinor, 5000000);
    expect(pay.principalPortionMinor, 3500000);
  });

  test('totals aggregate paid / principal / interest / extra', () async {
    final acc = await anAccount();
    final id = await repo.create(draft());
    await repo.recordPayment(
      mortgageId: id, accountId: acc,
      split: const MortgagePaymentSplit(
          totalMinor: 5000000, principalMinor: 3500000, interestMinor: 1500000),
    );
    await repo.recordPayment(
      mortgageId: id, accountId: acc, isExtra: true,
      split: const MortgagePaymentSplit(
          totalMinor: 2000000, principalMinor: 2000000),
    );
    final t = await repo.totals(id);
    expect(t.paidMinor, 7000000);
    expect(t.principalPaidMinor, 5500000);
    expect(t.interestPaidMinor, 1500000);
    expect(t.extraPaidMinor, 2000000);
  });

  test('unpaidMandatory is the mandatory payment when due this period and unpaid', () async {
    final id = await repo.create(draft(mandatory: 5000000)); // nextPaymentDate 2026-07-10
    final periodStart = DateTime(2026, 7, 1);
    final periodEnd = DateTime(2026, 8, 1);
    expect(
      await repo.unpaidMandatoryMinor(
          periodStart: periodStart, periodEndExclusive: periodEnd),
      5000000,
    );
    // record a (non-extra) payment inside the period -> reserve releases
    final acc = await anAccount();
    await repo.recordPayment(
      mortgageId: id, accountId: acc,
      occurredAt: DateTime(2026, 7, 11),
      split: const MortgagePaymentSplit(
          totalMinor: 5000000, principalMinor: 3500000, interestMinor: 1500000),
    );
    expect(
      await repo.unpaidMandatoryMinor(
          periodStart: periodStart, periodEndExclusive: periodEnd),
      0,
    );
  });

  test('an extra payment does NOT release the mandatory reserve', () async {
    final id = await repo.create(draft(mandatory: 5000000)); // nextPaymentDate 2026-07-10
    final periodStart = DateTime(2026, 7, 1);
    final periodEnd = DateTime(2026, 8, 1);
    // record an EXTRA payment inside the period -> reserve must NOT release
    final acc = await anAccount();
    await repo.recordPayment(
      mortgageId: id, accountId: acc, isExtra: true,
      occurredAt: DateTime(2026, 7, 11),
      split: const MortgagePaymentSplit(
          totalMinor: 5000000, principalMinor: 5000000),
    );
    expect(
      await repo.unpaidMandatoryMinor(
          periodStart: periodStart, periodEndExclusive: periodEnd),
      5000000,
    );
  });

  test(
      'recordPayment rejects an unbalanced split at the repository layer '
      '(defense in depth below the controller)', () async {
    final acc = await anAccount();
    final id = await repo.create(draft());
    await expectLater(
      repo.recordPayment(
        mortgageId: id,
        accountId: acc,
        split: const MortgagePaymentSplit(
            totalMinor: 5000000, principalMinor: 3000000, interestMinor: 1000000),
      ),
      throwsArgumentError,
    );
    expect(await repo.payments(id), isEmpty);
  });

  test(
      'a rejected unbalanced split leaves no ledger expense either — the '
      'payment row and its ledger entry are written or rejected together',
      () async {
    final acc = await anAccount();
    final id = await repo.create(draft());
    await expectLater(
      repo.recordPayment(
        mortgageId: id,
        accountId: acc,
        split: const MortgagePaymentSplit(
            totalMinor: 5000000, principalMinor: 1000000, interestMinor: 1000000),
      ),
      throwsArgumentError,
    );
    expect(await repo.payments(id), isEmpty);
    expect(await ledger.entriesForAccount(acc), isEmpty);
  });

  test(
      'a fault AFTER the ledger write (balanced split) rolls the ledger '
      'entry back — the two writes commit together or not at all', () async {
    final acc = await anAccount();
    final id = await repo.create(draft());

    // A mortgage repo whose ledger writes the real expense row inside the
    // transaction and THEN throws, so the failure lands between the two
    // writes — the split IS balanced, so it passes the pre-transaction
    // guard and genuinely enters `db.transaction`.
    final faultyRepo =
        DriftMortgageRepository(db, _FaultAfterLedgerWrite(ledger));

    await expectLater(
      faultyRepo.recordPayment(
        mortgageId: id,
        accountId: acc,
        split: const MortgagePaymentSplit(
            totalMinor: 5000000, principalMinor: 3500000, interestMinor: 1500000),
      ),
      throwsStateError,
    );

    // The ledger expense that WAS written inside the transaction must have
    // been rolled back along with the (never-inserted) payment row.
    expect(await ledger.entriesForAccount(acc), isEmpty,
        reason: 'the in-transaction ledger write was not rolled back');
    expect(await repo.payments(id), isEmpty);
  });

  test('archive hides from the default list; delete removes payments only', () async {
    final acc = await anAccount();
    final id = await repo.create(draft());
    await repo.recordPayment(
      mortgageId: id, accountId: acc,
      split: const MortgagePaymentSplit(
          totalMinor: 5000000, principalMinor: 3500000, interestMinor: 1500000),
    );
    await repo.archive(id);
    expect(await repo.list(), isEmpty);
    expect((await repo.list(includeArchived: true)).length, 1);
    await repo.delete(id);
    expect(await repo.list(includeArchived: true), isEmpty);
    expect(await repo.payments(id), isEmpty);
    // the ledger expense survives the mortgage delete
    expect((await ledger.entriesForAccount(acc)).length, 1);
  });
}
