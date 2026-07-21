import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/mortgage/mortgage_engine.dart';
import 'package:financial_assistant/core/time/financial_period.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/mortgage/mortgage_model.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });
  tearDown(() {
    container.dispose();
    db.close();
  });

  MortgageDraft draft() => MortgageDraft(
        name: 'Uy',
        initialLoanMinor: 120000000,
        openingPrincipalMinor: 100000000,
        annualRateBp: 1800,
        startDate: DateTime(2025, 1, 1),
        mandatoryPaymentMinor: 5000000,
        nextPaymentDate: DateTime(2026, 7, 10),
        paymentType: PaymentType.annuity,
      );

  test('mortgagesProvider returns each mortgage with a projection', () async {
    final repo = container.read(mortgageRepositoryProvider);
    await repo.create(draft());
    container.read(ledgerRevisionProvider.notifier).update((n) => n + 1);

    final list = await container.read(mortgagesProvider.future);
    expect(list.single.mortgage.name, 'Uy');
    expect(list.single.currentPrincipalMinor, 100000000);
    expect(list.single.projection.monthsRemaining, greaterThan(0));
  });

  test(
      'an unpaid mandatory payment does not change the daily safe limit '
      '(model A: role-based exclusion, not subtraction)', () async {
    // Karta defaults to the Sarf (spending) role, so its balance is the
    // entire spendable pool under model A. Money reserved for credit lives
    // on Kredit-role cards instead — excluded from the pool by role, not by
    // subtracting the mortgage's unpaid mandatory payment here.
    final accounts = container.read(accountRepositoryProvider);
    await accounts.create(
      name: 'Karta',
      type: AccountType.bankCard,
      openingBalance: const Money(8000000, CurrencyRegistry.uzs),
      icon: 'account_balance_wallet',
    );
    container.read(ledgerRevisionProvider.notifier).update((n) => n + 1);

    final before = await container.read(safeLimitProvider.future);
    // Sanity check: the setup actually produces a positive spendable amount,
    // otherwise "unchanged" would be a vacuous 0 == 0.
    expect(before.spendable.minorUnits, greaterThan(0));

    final repo = container.read(mortgageRepositoryProvider);
    // nextPaymentDate falls inside the current period, which is exactly the
    // case the old model treated as "mandatory reserve bites".
    final now = DateTime.now();
    await repo.create(MortgageDraft(
      name: 'Uy',
      initialLoanMinor: 120000000,
      openingPrincipalMinor: 100000000,
      annualRateBp: 1800,
      startDate: DateTime(2025, 1, 1),
      mandatoryPaymentMinor: 5000000,
      nextPaymentDate: DateTime(now.year, now.month, now.day),
      paymentType: PaymentType.annuity,
    ));
    container.read(ledgerRevisionProvider.notifier).update((n) => n + 1);

    final after = await container.read(safeLimitProvider.future);
    // Creating a mortgage writes no ledger entry against the Karta account,
    // so the daily safe limit must be exactly unchanged.
    expect(after.spendable, before.spendable);
    // The unpaid-mandatory calculation itself still works correctly — it's
    // just no longer wired into the safe limit.
    final settings = await container.read(settingsRepositoryProvider).read();
    final period = FinancialPeriod.containing(now, settings.periodStartDay);
    expect(
      await repo.unpaidMandatoryMinor(
        periodStart: period.start,
        periodEndExclusive: period.endExclusive,
      ),
      5000000,
    );
  });
}
