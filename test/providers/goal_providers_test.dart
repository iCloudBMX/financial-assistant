import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/goals/goal_model.dart';
import 'package:financial_assistant/data/goals/goal_repository.dart';
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

  test('goalsProvider computes progress for each goal', () async {
    final GoalRepository repo = container.read(goalRepositoryProvider);
    final id = await repo.create(GoalDraft(
      name: 'Sayohat',
      targetAmountMinor: 1000000,
      startDate: DateTime(2026, 1, 1),
      targetDate: DateTime(2026, 12, 1),
    ));
    await repo.addContribution(
        goalId: id, signedAmountMinor: 250000, source: ContributionSource.manual);
    container.read(ledgerRevisionProvider.notifier).update((n) => n + 1);

    final goals = await container.read(goalsProvider.future);
    expect(goals.single.goal.name, 'Sayohat');
    expect(goals.single.progress.percentBp, 2500);
    expect(goals.single.progress.saved, const Money(250000, CurrencyRegistry.uzs));
  });

  test(
      'a goal reserve does not change the daily safe limit (model A: '
      'role-based exclusion, not subtraction)', () async {
    // Seed a Sarf-role (spending) account — the default role — with an
    // opening balance. Under model A this balance is the entire spendable
    // pool; goal money instead lives on Jamg'arma-role cards, which are
    // excluded from the pool by role, not by subtracting a reserve here.
    await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(
            name: 'Naqd',
            type: 'cash',
            openingBalanceMinor: const Value(300000),
          ),
        );
    container.read(ledgerRevisionProvider.notifier).update((n) => n + 1);

    final before = await container.read(safeLimitProvider.future);
    // Sanity check: the setup actually produces a positive spendable amount,
    // otherwise "unchanged" would be a vacuous 0 == 0.
    expect(before.spendable.minorUnits, greaterThan(0));

    final GoalRepository repo = container.read(goalRepositoryProvider);
    final id = await repo.create(GoalDraft(
      name: 'Zaxira',
      targetAmountMinor: 1000000,
      startDate: DateTime(2026, 1, 1),
    ));
    await repo.addContribution(
        goalId: id, signedAmountMinor: 100000, source: ContributionSource.manual);
    container.read(ledgerRevisionProvider.notifier).update((n) => n + 1);

    final after = await container.read(safeLimitProvider.future);
    // A goal contribution writes a `goal_contributions` earmark row, not a
    // ledger transfer out of the Sarf-role account, so the daily safe limit
    // must be exactly unchanged.
    expect(after.spendable, before.spendable);
    // The reserve calculation itself still works correctly — it's just no
    // longer wired into the safe limit.
    expect(await repo.activeReserveMinor(), 100000);
  });
}
