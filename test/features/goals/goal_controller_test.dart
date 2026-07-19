// test/features/goals/goal_controller_test.dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/goals/goal_model.dart';
import 'package:financial_assistant/data/goals/goal_repository.dart';
import 'package:financial_assistant/features/goals/goal_controller.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  Money m(int v) => Money(v, uzs);

  late AppDatabase db;
  late ProviderContainer container;
  late GoalController ctrl;
  late GoalRepository repo;

  Future<int> newGoal({int target = 1000000}) => repo.create(GoalDraft(
        name: 'G',
        targetAmountMinor: target,
        startDate: DateTime(2026, 1, 1),
      ));

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    ctrl = container.read(goalControllerProvider);
    repo = container.read(goalRepositoryProvider);
  });
  tearDown(() {
    container.dispose();
    db.close();
  });

  test('contribute rejects a non-positive amount', () async {
    final id = await newGoal();
    final r = await ctrl.contribute(goalId: id, amount: m(0));
    expect(r.isOk, isFalse);
    expect(await repo.savedFor(id), 0);
  });

  test('contributing to the target marks the goal completed', () async {
    final id = await newGoal(target: 500000);
    final r = await ctrl.contribute(goalId: id, amount: m(500000));
    expect(r.isOk, isTrue);
    final g = (await repo.list()).single;
    expect(g.status, GoalStatus.completed);
  });

  test('withdrawal cannot exceed saved', () async {
    final id = await newGoal();
    await ctrl.contribute(goalId: id, amount: m(200000));
    final r = await ctrl.withdraw(goalId: id, amount: m(300000));
    expect(r.isOk, isFalse);
    expect(await repo.savedFor(id), 200000);
  });

  test('withdrawing below target reverts completed back to active', () async {
    final id = await newGoal(target: 500000);
    await ctrl.contribute(goalId: id, amount: m(500000)); // -> completed
    await ctrl.withdraw(goalId: id, amount: m(100000)); // -> active again
    expect((await repo.list()).single.status, GoalStatus.active);
  });

  test('moveSurplus transfers saved from one goal to another', () async {
    final from = await newGoal();
    final to = await newGoal();
    await ctrl.contribute(goalId: from, amount: m(300000));
    final r = await ctrl.moveSurplus(
        fromGoalId: from, toGoalId: to, amount: m(200000));
    expect(r.isOk, isTrue);
    expect(await repo.savedFor(from), 100000);
    expect(await repo.savedFor(to), 200000);
  });
}
