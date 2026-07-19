import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/mortgage/mortgage_engine.dart';
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

  test('an unpaid mandatory payment reduces the daily safe limit', () async {
    // Total available (8,000,000) is the binding constraint below the
    // variable budget (30,000,000), so subtracting the mortgage's unpaid
    // mandatory payment from freeBalance must move `spendable` — this makes
    // the assertion a genuine test of the wiring rather than a vacuous
    // `<=` that would also pass if both figures were floored at 0.
    final accounts = container.read(accountRepositoryProvider);
    await accounts.create(
      name: 'Karta',
      type: AccountType.bankCard,
      openingBalance: const Money(8000000, CurrencyRegistry.uzs),
      icon: 'account_balance_wallet',
    );
    // give a variable budget so the limit is not already floored at 0
    final settingsRepo = container.read(settingsRepositoryProvider);
    final s = await settingsRepo.read();
    await settingsRepo.write(s.copyWith(
      variableBudget: const Money(30000000, CurrencyRegistry.uzs),
    ));
    container.read(ledgerRevisionProvider.notifier).update((n) => n + 1);

    final before = await container.read(safeLimitProvider.future);

    final repo = container.read(mortgageRepositoryProvider);
    // nextPaymentDate must fall inside the current period for the reserve to bite
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
    expect(after.spendable.minorUnits, lessThan(before.spendable.minorUnits));
  });
}
