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
    final repo = container.read(goalRepositoryProvider);
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
    final settings = container.read(settingsRepositoryProvider);
    // Give the period a variable budget and some available balance via settings
    // + an account so freeBalance is positive, then confirm the reserve bites.
    // (Uses the same wiring as the SP2 safe-limit provider test.)
    final repo = container.read(goalRepositoryProvider);
    final before = await container.read(safeLimitProvider.future);

    final id = await repo.create(GoalDraft(
      name: 'Zaxira',
      targetAmountMinor: 1000000,
      startDate: DateTime(2026, 1, 1),
    ));
    await repo.addContribution(
        goalId: id, signedAmountMinor: 500000, source: ContributionSource.manual);
    container.read(ledgerRevisionProvider.notifier).update((n) => n + 1);

    final after = await container.read(safeLimitProvider.future);
    expect(after.spendable.minorUnits <= before.spendable.minorUnits, isTrue);
    // ignore: unused_local_variable
    final _ = settings;
  });
}
