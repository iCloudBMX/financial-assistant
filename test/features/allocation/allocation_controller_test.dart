import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/mortgage/mortgage_engine.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/goals/goal_model.dart';
import 'package:financial_assistant/data/mortgage/mortgage_model.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/allocation/allocation_controller.dart';
import 'package:financial_assistant/features/budgets/budgets_controller.dart';
import 'package:financial_assistant/features/goals/goal_controller.dart';

/// Inserts a real income transaction (mirrors the pattern in
/// `allocation_repository_test.dart`'s `insertIncome`) and returns its id —
/// `goal_contributions.incomeTransactionId` is a real FK, so `confirm` tests
/// that exercise the goal bridge need a genuine transaction row, not a
/// fabricated int.
Future<int> _createIncome(ProviderContainer container, {int minor = 1000000}) {
  final db = container.read(databaseProvider);
  return db.into(db.transactionsTable).insert(
        TransactionsTableCompanion.insert(
          accountId: 1,
          type: 'income',
          amountMinor: minor,
          currencyCode: 'UZS',
          occurredAt: DateTime(2026, 7, 5),
          createdAt: DateTime(2026, 7, 5),
        ),
      );
}

void main() {
  const uzs = CurrencyRegistry.uzs;

  test('preview splits income by the seeded default template', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    final result = await container
        .read(allocationControllerProvider)
        .preview(const Money(1000000, uzs));
    // default template: 10% minReserve, remainder variableBudget
    expect(result.perBucket['minReserve'], const Money(100000, uzs));
    expect(result.perBucket['variableBudget'], const Money(900000, uzs));
    expect(result.income, const Money(1000000, uzs));
    expect(result.allocatedTotal, const Money(1000000, uzs));
    expect(result.unallocated, const Money(0, uzs));
    expect(result.freeAfter, const Money(0, uzs));
    expect(result.shortfall, isEmpty);
  });

  test('confirm writes the split and bumps the revision', () async {
    final db = AppDatabase(NativeDatabase.memory());
    // Migrations turn on `PRAGMA foreign_keys`, so transactions_table's
    // accountId FK must resolve — seed the account row it points at (mirrors
    // the pattern in allocation_repository_test.dart).
    await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(name: 'Cash', type: 'cash'),
        );
    final incomeId = await db.into(db.transactionsTable).insert(
          TransactionsTableCompanion.insert(
            accountId: 1,
            type: 'income',
            amountMinor: 1000000,
            currencyCode: 'UZS',
            occurredAt: DateTime(2026, 7, 5),
            createdAt: DateTime(2026, 7, 5),
          ),
        );
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    final before = container.read(ledgerRevisionProvider);
    await container.read(allocationControllerProvider).confirm(incomeId, {
      'minReserve': const Money(100000, uzs),
      'variableBudget': const Money(900000, uzs),
    });
    expect(container.read(ledgerRevisionProvider), greaterThan(before));
    final row = await (db.select(db.transactionsTable)
          ..where((t) => t.id.equals(incomeId)))
        .getSingle();
    expect(row.allocatedMinor, 1000000);
  });

  test(
      'design §4: confirming a split with a variableBudget bucket, then '
      'applying the offered update, sets settings.variableBudget to that '
      'same amount and safeLimitProvider recomputes with it as the '
      'numerator', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(
            name: 'Cash',
            type: 'cash',
            openingBalanceMinor: const Value(100000000),
          ),
        );
    final incomeId = await db.into(db.transactionsTable).insert(
          TransactionsTableCompanion.insert(
            accountId: 1,
            type: 'income',
            amountMinor: 1000000,
            currencyCode: 'UZS',
            occurredAt: DateTime(2026, 7, 5),
            createdAt: DateTime(2026, 7, 5),
          ),
        );
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    // Sanity: before the offer is applied, the safe-limit numerator is the
    // default (zero) — allocateIncome alone must not move it.
    final before = await container.read(safeLimitProvider.future);
    expect(before.spendable, const Money(0, uzs));

    // Confirm a split that puts 700,000 into variableBudget.
    const variableAmount = Money(700000, uzs);
    await container.read(allocationControllerProvider).confirm(incomeId, {
      'minReserve': const Money(100000, uzs),
      'variableBudget': variableAmount,
    });

    // The bare confirm must not have moved settings.variableBudget — that's
    // the write the "offer" step performs, exercised next via the same
    // reusable path `maybeOfferVariableBudgetUpdate` calls on "Ha".
    final afterConfirmOnly = await container.refresh(settingsProvider.future);
    expect(afterConfirmOnly.variableBudget, isNot(variableAmount));

    // Apply the offered update (the controller-layer effect of tapping "Ha").
    await container
        .read(budgetsControllerProvider)
        .setVariableBudget(variableAmount);

    final settings = await container.refresh(settingsProvider.future);
    expect(settings.variableBudget, variableAmount);

    final after = await container.refresh(safeLimitProvider.future);
    // numerator 700,000 - 0 spent variable = 700,000.
    expect(after.spendable, variableAmount);
  });

  test('confirming an allocation with a goal bucket writes a contribution',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(name: 'Cash', type: 'cash'),
        );
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    final goalRepo = container.read(goalRepositoryProvider);
    final id = await goalRepo.create(GoalDraft(
      name: 'Avto',
      targetAmountMinor: 5000000,
      startDate: DateTime(2026, 1, 1),
    ));
    final ctrl = container.read(allocationControllerProvider);

    final incomeId = await _createIncome(container);
    await ctrl.confirm(incomeId, {'goal:$id': const Money(400000, uzs)});

    expect(await goalRepo.savedFor(id), 400000);
    final hist = await goalRepo.contributions(id);
    expect(hist.single.source, ContributionSource.incomeAllocation);
    expect(hist.single.incomeTransactionId, incomeId);
  });

  test(
      'headline invariant: a manual goal contribution never creates a '
      'ledger transaction (earmark model — it only writes a '
      'goal_contributions row)', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(name: 'Cash', type: 'cash'),
        );
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    final goalRepo = container.read(goalRepositoryProvider);
    final id = await goalRepo.create(GoalDraft(
      name: 'Avto',
      targetAmountMinor: 5000000,
      startDate: DateTime(2026, 1, 1),
    ));

    final before =
        await db.select(db.transactionsTable).get();

    final r = await container.read(goalControllerProvider).contribute(
        goalId: id, amount: const Money(400000, uzs));
    expect(r.isOk, isTrue);

    final after = await db.select(db.transactionsTable).get();
    expect(after.length, before.length,
        reason: 'a manual goal contribution must not create a ledger '
            'transaction — only a goal_contributions row');
    expect(await goalRepo.savedFor(id), 400000);
  });

  test('confirming a mortgage-bucket allocation writes no mortgage payment',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    // Arrange: an income to allocate + a mortgage to (not) auto-pay.
    final accountId = await container.read(accountRepositoryProvider).create(
          name: 'Karta',
          type: AccountType.bankCard,
          openingBalance: const Money(500000000, uzs),
          icon: 'account_balance_wallet',
        );
    final incomeId = await container.read(ledgerRepositoryProvider).addIncome(
          accountId: accountId,
          amount: const Money(10000000, uzs),
          incomeType: IncomeType.salary,
          occurredAt: DateTime(2026, 7, 1),
        );
    final mortgageRepo = container.read(mortgageRepositoryProvider);
    final mortgageId = await mortgageRepo.create(MortgageDraft(
      name: 'Uy',
      initialLoanMinor: 120000000,
      openingPrincipalMinor: 100000000,
      annualRateBp: 1800,
      startDate: DateTime(2025, 1, 1),
      mandatoryPaymentMinor: 5000000,
      nextPaymentDate: DateTime(2026, 7, 10),
      paymentType: PaymentType.annuity,
    ));

    // Act: allocate part of the income to the mortgage:extra bucket.
    final ctrl = container.read(allocationControllerProvider);
    await ctrl.confirm(incomeId, {
      'mortgage:extra': const Money(2000000, uzs),
    });

    // Assert: no mortgage payment was auto-created (planning-only).
    expect(await mortgageRepo.payments(mortgageId), isEmpty);
    expect(await mortgageRepo.currentPrincipalMinor(mortgageId), 100000000);
  });
}
