// test/data/goals/goal_repository_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/goals/goal_model.dart';
import 'package:financial_assistant/data/goals/goal_repository.dart';

void main() {
  late AppDatabase db;
  late DriftGoalRepository repo;

  GoalDraft draft({String name = 'Sayohat', int target = 1000000}) => GoalDraft(
        name: name,
        targetAmountMinor: target,
        startDate: DateTime(2026, 1, 1),
        targetDate: DateTime(2026, 12, 1),
      );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftGoalRepository(db);
  });
  tearDown(() => db.close());

  test('create then list returns the goal with defaults', () async {
    final id = await repo.create(draft());
    final goals = await repo.list();
    expect(goals.single.id, id);
    expect(goals.single.name, 'Sayohat');
    expect(goals.single.priority, GoalPriority.medium);
    expect(goals.single.status, GoalStatus.active);
  });

  test('saved amount is derived from signed contributions', () async {
    final id = await repo.create(draft());
    await repo.addContribution(
        goalId: id, signedAmountMinor: 300000, source: ContributionSource.manual);
    await repo.addContribution(
        goalId: id, signedAmountMinor: 200000, source: ContributionSource.manual);
    expect(await repo.savedFor(id), 500000);
  });

  test('withdrawal is a negative contribution and lowers saved', () async {
    final id = await repo.create(draft());
    await repo.addContribution(
        goalId: id, signedAmountMinor: 500000, source: ContributionSource.manual);
    await repo.addContribution(
        goalId: id, signedAmountMinor: -200000, source: ContributionSource.manual);
    expect(await repo.savedFor(id), 300000);
    final hist = await repo.contributions(id);
    expect(hist.length, 2);
  });

  test('activeReserve sums active + completed but not archived goals', () async {
    final a = await repo.create(draft(name: 'A'));
    final b = await repo.create(draft(name: 'B'));
    await repo.addContribution(
        goalId: a, signedAmountMinor: 100000, source: ContributionSource.manual);
    await repo.addContribution(
        goalId: b, signedAmountMinor: 400000, source: ContributionSource.manual);
    await repo.archive(b); // releases its reserve
    expect(await repo.activeReserveMinor(), 100000);
  });

  test('archive hides from the default list but delete removes contributions', () async {
    final id = await repo.create(draft());
    await repo.addContribution(
        goalId: id, signedAmountMinor: 100000, source: ContributionSource.manual);
    await repo.archive(id);
    expect(await repo.list(), isEmpty);
    expect((await repo.list(includeArchived: true)).length, 1);
    await repo.delete(id);
    expect(await repo.list(includeArchived: true), isEmpty);
    expect(await repo.contributions(id), isEmpty);
  });
}
