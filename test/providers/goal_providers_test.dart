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

  test('goal reserve reduces the daily safe limit', () async {
    // Seed an account with a modest opening balance and a variable budget
    // that's larger than that balance, so `freeBalance` (which the goal
    // reserve eats into) — not `remainingVariable` — is the binding
    // constraint on `spendable`. Mirrors the account/budget seeding pattern
    // in safe_limit_providers_test.dart.
    await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(
            name: 'Naqd',
            type: 'cash',
            openingBalanceMinor: const Value(300000),
          ),
        );
    final settingsRepo = container.read(settingsRepositoryProvider);
    final baseSettings = await settingsRepo.read();
    await settingsRepo.write(baseSettings.copyWith(
      variableBudget: const Money(1400000, CurrencyRegistry.uzs),
    ));
    container.read(ledgerRevisionProvider.notifier).update((n) => n + 1);

    final before = await container.read(safeLimitProvider.future);
    // Sanity check: the setup actually produces a positive spendable amount
    // before the goal exists, otherwise a decrease wouldn't be observable.
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
    // The goal reserve must strictly reduce spendable, and not simply floor
    // it at 0 (which would also pass a non-strict `<=` check vacuously).
    expect(after.spendable.minorUnits, lessThan(before.spendable.minorUnits));
    expect(after.spendable.minorUnits, greaterThan(0));
  });
}
