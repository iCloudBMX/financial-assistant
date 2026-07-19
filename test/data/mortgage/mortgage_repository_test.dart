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
