import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/core/result/failure.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/recurring/recurring_model.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/recurring/recurring_prompt.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  const usd = CurrencyRegistry.usd;

  Future<({ProviderContainer c, int accId})> seed() async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c =
        ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    final accId = await c.read(accountRepositoryProvider).create(
        name: 'Naqd',
        type: AccountType.cash,
        openingBalance: const Money(0, uzs),
        icon: 'w');
    await c.read(recurringIncomeRepositoryProvider).create(
        accountId: accId,
        amount: const Money(5000000, uzs),
        incomeType: IncomeType.salary,
        intervalKind: IntervalKind.monthly,
        anchorDay: 5,
        nextDueAt: DateTime(2026, 7, 5));
    return (c: c, accId: accId);
  }

  test('confirm records income and clears the plan from due', () async {
    final (:c, accId: _) = await seed();

    final due = await c.read(recurringPromptControllerProvider.future);
    expect(due.length, 1);

    await c.read(recurringPromptControllerProvider.notifier).confirm(due.single);

    final data = await c.read(dashboardProvider.future);
    expect(data.monthIncome.minorUnits, greaterThan(0));
    final stillDue = await c
        .read(recurringIncomeRepositoryProvider)
        .duePlans(DateTime(2026, 7, 6));
    expect(stillDue, isEmpty); // advanced past the current date
  });

  test('skip advances the due date to the next occurrence and records NO income',
      () async {
    final (:c, accId: _) = await seed();
    final due = await c.read(recurringPromptControllerProvider.future);

    await c.read(recurringPromptControllerProvider.notifier).skip(due.single);

    // No income recorded.
    final entries = await c.read(ledgerRepositoryProvider).allEntries();
    expect(entries, isEmpty);
    // Occurrence handled: advanced a full period to the next occurrence.
    final plans = await c.read(recurringIncomeRepositoryProvider).listActive();
    expect(plans.single.nextDueAt, DateTime(2026, 8, 5));
    final stillDue = await c
        .read(recurringIncomeRepositoryProvider)
        .duePlans(DateTime(2026, 7, 6));
    expect(stillDue, isEmpty);
  });

  test('postpone moves the due date to a chosen date, records no income, and differs from skip',
      () async {
    final (:c, accId: _) = await seed();
    final due = await c.read(recurringPromptControllerProvider.future);

    // A specific chosen date, earlier than skip's next-occurrence (2026-08-05)
    // but still after the current due (2026-07-05).
    final chosen = DateTime(2026, 7, 20);
    final result = await c
        .read(recurringPromptControllerProvider.notifier)
        .postpone(due.single, chosen);
    expect(result.isOk, isTrue);

    final entries = await c.read(ledgerRepositoryProvider).allEntries();
    expect(entries, isEmpty); // postpone never records income

    final plans = await c.read(recurringIncomeRepositoryProvider).listActive();
    expect(plans.single.nextDueAt, chosen);
    // Distinct from skip, which would have advanced to 2026-08-05.
    expect(plans.single.nextDueAt, isNot(DateTime(2026, 8, 5)));
  });

  test('postpone rejects a date that is not after the current due date', () async {
    final (:c, accId: _) = await seed();
    final due = await c.read(recurringPromptControllerProvider.future);

    final result = await c
        .read(recurringPromptControllerProvider.notifier)
        .postpone(due.single, DateTime(2026, 7, 1)); // before current due
    expect(result.isOk, isFalse);
    result.when(
      ok: (_) => fail('expected Err'),
      err: (f) => expect(f, isA<ValidationFailure>()),
    );
    final plans = await c.read(recurringIncomeRepositoryProvider).listActive();
    expect(plans.single.nextDueAt, DateTime(2026, 7, 5)); // unchanged
  });

  test('edit records income with the EDITED amount for this occurrence and advances the due date',
      () async {
    final (:c, accId: _) = await seed();
    final due = await c.read(recurringPromptControllerProvider.future);

    final edited = const Money(4200000, uzs); // differs from plan's 5,000,000
    final result = await c
        .read(recurringPromptControllerProvider.notifier)
        .confirmWithAmount(due.single, amount: edited);
    expect(result.isOk, isTrue);

    // The recorded income uses the edited amount, not the plan's amount.
    final entries = await c.read(ledgerRepositoryProvider).allEntries();
    final income =
        entries.where((e) => e.type == LedgerEntryType.income).toList();
    expect(income.length, 1);
    expect(income.single.amount, edited);

    // The plan's own stored amount is unchanged (occurrence-level edit only).
    final plans = await c.read(recurringIncomeRepositoryProvider).listActive();
    expect(plans.single.amount, const Money(5000000, uzs));
    // Due date advanced like a normal confirm.
    expect(plans.single.nextDueAt, DateTime(2026, 8, 5));
  });

  test('edit rejects a non-positive amount and records nothing', () async {
    final (:c, accId: _) = await seed();
    final due = await c.read(recurringPromptControllerProvider.future);

    final result = await c
        .read(recurringPromptControllerProvider.notifier)
        .confirmWithAmount(due.single, amount: const Money(0, uzs));
    expect(result.isOk, isFalse);
    result.when(
      ok: (_) => fail('expected Err'),
      err: (f) => expect(f, isA<ValidationFailure>()),
    );
    expect(await c.read(ledgerRepositoryProvider).allEntries(), isEmpty);
  });

  test('edit returns CurrencyFailure when the amount currency does not match the account',
      () async {
    final (:c, accId: _) = await seed();
    final due = await c.read(recurringPromptControllerProvider.future);

    final result = await c
        .read(recurringPromptControllerProvider.notifier)
        .confirmWithAmount(due.single, amount: const Money(5000, usd));
    expect(result.isOk, isFalse);
    result.when(
      ok: (_) => fail('expected Err'),
      err: (f) => expect(f, isA<CurrencyFailure>()),
    );
    expect(await c.read(ledgerRepositoryProvider).allEntries(), isEmpty);
  });

  testWidgets('the prompt exposes four distinct actions per due plan',
      (tester) async {
    final (:c, accId: _) = await seed();
    final plan =
        (await c.read(recurringPromptControllerProvider.future)).single;

    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        home: Scaffold(body: RecurringPromptBanner()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('recurring-confirm-${plan.id}')), findsOneWidget);
    expect(find.byKey(Key('recurring-edit-${plan.id}')), findsOneWidget);
    expect(find.byKey(Key('recurring-postpone-${plan.id}')), findsOneWidget);
    expect(find.byKey(Key('recurring-skip-${plan.id}')), findsOneWidget);
  });
}
