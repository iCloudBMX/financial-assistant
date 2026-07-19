import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/mortgage/mortgage_engine.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/mortgage/mortgage_model.dart';
import 'package:financial_assistant/data/mortgage/mortgage_repository.dart';
import 'package:financial_assistant/features/mortgage/mortgage_controller.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  Money m(int v) => Money(v, uzs);

  late AppDatabase db;
  late ProviderContainer container;
  late MortgageController ctrl;
  late MortgageRepository repo;
  late int accountId;

  MortgageDraft draft({int opening = 100000000}) => MortgageDraft(
        name: 'Uy',
        initialLoanMinor: 120000000,
        openingPrincipalMinor: opening,
        annualRateBp: 1800,
        startDate: DateTime(2025, 1, 1),
        mandatoryPaymentMinor: 5000000,
        nextPaymentDate: DateTime(2026, 7, 10),
        paymentType: PaymentType.annuity,
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    ctrl = container.read(mortgageControllerProvider);
    repo = container.read(mortgageRepositoryProvider);
    accountId = await container.read(accountRepositoryProvider).create(
        name: 'Karta',
        type: AccountType.bankCard,
        openingBalance: const Money(500000000, CurrencyRegistry.uzs),
        icon: 'account_balance_wallet');
  });
  tearDown(() {
    container.dispose();
    db.close();
  });

  test('recordPayment rejects a split that does not sum to total', () async {
    final id = (await ctrl.create(draft())).valueOrNull!;
    final res = await ctrl.recordPayment(
      mortgageId: id,
      accountId: accountId,
      split: const MortgagePaymentSplit(
          totalMinor: 5000000, principalMinor: 3000000, interestMinor: 1000000),
    );
    expect(res.isOk, isFalse);
    expect(await repo.payments(id), isEmpty);
  });

  test('recordPayment accepts a balanced split and advances the due date', () async {
    final id = (await ctrl.create(draft())).valueOrNull!;
    final res = await ctrl.recordPayment(
      mortgageId: id,
      accountId: accountId,
      split: const MortgagePaymentSplit(
          totalMinor: 5000000, principalMinor: 3500000, interestMinor: 1500000),
    );
    expect(res.isOk, isTrue);
    final after = await repo.byId(id);
    expect(after!.nextPaymentDate, DateTime(2026, 8, 10)); // +1 month
  });

  test('recordExtraPayment books 100% principal and lowers the balance', () async {
    final id = (await ctrl.create(draft())).valueOrNull!;
    await ctrl.recordExtraPayment(
        mortgageId: id, accountId: accountId, amount: m(2000000));
    expect(await repo.currentPrincipalMinor(id), 100000000 - 2000000);
    final pay = (await repo.payments(id)).single;
    expect(pay.isExtra, isTrue);
    expect(pay.principalPortionMinor, 2000000);
  });

  test('paying off the balance closes the mortgage', () async {
    final id = (await ctrl.create(draft(opening: 3000000))).valueOrNull!;
    await ctrl.recordPayment(
      mortgageId: id,
      accountId: accountId,
      split: const MortgagePaymentSplit(
          totalMinor: 3000000, principalMinor: 3000000),
    );
    expect((await repo.byId(id))!.status, MortgageStatus.closed);
  });

  test('recordPayment advancing a day-31 due date clamps to the month end', () async {
    final id = (await ctrl.create(MortgageDraft(
      name: 'Uy',
      initialLoanMinor: 120000000,
      openingPrincipalMinor: 100000000,
      annualRateBp: 1800,
      startDate: DateTime(2025, 1, 1),
      mandatoryPaymentMinor: 5000000,
      nextPaymentDate: DateTime(2026, 1, 31),
      paymentType: PaymentType.annuity,
    )))
        .valueOrNull!;
    final res = await ctrl.recordPayment(
      mortgageId: id,
      accountId: accountId,
      split: const MortgagePaymentSplit(
          totalMinor: 5000000, principalMinor: 3500000, interestMinor: 1500000),
    );
    expect(res.isOk, isTrue);
    // Jan 31 + 1 month clamps to Feb 28 (2026 is not a leap year), not Mar 3.
    expect((await repo.byId(id))!.nextPaymentDate, DateTime(2026, 2, 28));
  });

  test('recordPayment rejects a split with a negative part', () async {
    final id = (await ctrl.create(draft())).valueOrNull!;
    final res = await ctrl.recordPayment(
      mortgageId: id,
      accountId: accountId,
      split: const MortgagePaymentSplit(
          totalMinor: 5000000,
          principalMinor: -1000000,
          interestMinor: 6000000),
    );
    expect(res.isOk, isFalse);
    expect(await repo.payments(id), isEmpty);
  });

  test('closeMortgage sets status closed', () async {
    final id = (await ctrl.create(draft())).valueOrNull!;
    await ctrl.closeMortgage(id);
    expect((await repo.byId(id))!.status, MortgageStatus.closed);
  });

  test('update changes a field and persists it', () async {
    final id = (await ctrl.create(draft())).valueOrNull!;
    final res = await ctrl.update(
      id,
      MortgageDraft(
        name: 'Yangi uy',
        initialLoanMinor: 120000000,
        openingPrincipalMinor: 100000000,
        annualRateBp: 1800,
        startDate: DateTime(2025, 1, 1),
        mandatoryPaymentMinor: 6000000,
        nextPaymentDate: DateTime(2026, 7, 10),
        paymentType: PaymentType.annuity,
      ),
    );
    expect(res.isOk, isTrue);
    final after = await repo.byId(id);
    expect(after!.name, 'Yangi uy');
    expect(after.mandatoryPaymentMinor, 6000000);
  });
}
