import 'package:drift/drift.dart';
import '../db/app_database.dart';
import 'goal_model.dart';

abstract class GoalRepository {
  Future<List<Goal>> list({bool includeArchived = false});
  Future<int> create(GoalDraft draft);
  Future<void> update(int id, GoalDraft draft);
  Future<void> setStatus(int id, GoalStatus status);
  Future<void> setTarget(int id,
      {required int targetAmountMinor,
      DateTime? targetDate,
      bool clearTargetDate = false});
  Future<void> archive(int id);
  Future<void> delete(int id);
  Future<void> addContribution({
    required int goalId,
    required int signedAmountMinor,
    required ContributionSource source,
    int? sourceAccountId,
    int? incomeTransactionId,
    String? note,
    DateTime? occurredAt,
  });
  Future<List<GoalContribution>> contributions(int goalId);
  Future<int> savedFor(int goalId);
  Future<int> activeReserveMinor();
}

class DriftGoalRepository implements GoalRepository {
  final AppDatabase db;
  DriftGoalRepository(this.db);

  Goal _map(GoalsTableData r) => Goal(
        id: r.id,
        name: r.name,
        type: r.type,
        icon: r.icon,
        targetAmountMinor: r.targetAmountMinor,
        currencyCode: r.currencyCode,
        startDate: r.startDate,
        targetDate: r.targetDate,
        priority: GoalPriority.values.byName(r.priority),
        status: GoalStatus.values.byName(r.status),
        linkedAccountId: r.linkedAccountId,
        note: r.note,
        sortOrder: r.sortOrder,
        createdAt: r.createdAt,
      );

  GoalContribution _mapContribution(GoalContributionsTableData r) =>
      GoalContribution(
        id: r.id,
        goalId: r.goalId,
        amountMinor: r.amountMinor,
        currencyCode: r.currencyCode,
        source: ContributionSource.values.byName(r.source),
        sourceAccountId: r.sourceAccountId,
        incomeTransactionId: r.incomeTransactionId,
        note: r.note,
        occurredAt: r.occurredAt,
        createdAt: r.createdAt,
      );

  @override
  Future<List<Goal>> list({bool includeArchived = false}) async {
    final q = db.select(db.goalsTable)
      ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
    if (!includeArchived) {
      q.where((t) => t.status.equals(GoalStatus.archived.name).not());
    }
    return (await q.get()).map(_map).toList();
  }

  @override
  Future<int> create(GoalDraft d) => db.into(db.goalsTable).insert(
        GoalsTableCompanion.insert(
          name: d.name,
          type: Value(d.type),
          icon: Value(d.icon),
          targetAmountMinor: d.targetAmountMinor,
          currencyCode: Value(d.currencyCode),
          startDate: d.startDate,
          targetDate: Value(d.targetDate),
          priority: Value(d.priority.name),
          linkedAccountId: Value(d.linkedAccountId),
          note: Value(d.note),
        ),
      );

  @override
  Future<void> update(int id, GoalDraft d) async {
    await (db.update(db.goalsTable)..where((t) => t.id.equals(id))).write(
      GoalsTableCompanion(
        name: Value(d.name),
        type: Value(d.type),
        icon: Value(d.icon),
        targetAmountMinor: Value(d.targetAmountMinor),
        currencyCode: Value(d.currencyCode),
        startDate: Value(d.startDate),
        targetDate: Value(d.targetDate),
        priority: Value(d.priority.name),
        linkedAccountId: Value(d.linkedAccountId),
        note: Value(d.note),
      ),
    );
  }

  @override
  Future<void> setStatus(int id, GoalStatus status) async {
    await (db.update(db.goalsTable)..where((t) => t.id.equals(id)))
        .write(GoalsTableCompanion(status: Value(status.name)));
  }

  @override
  Future<void> setTarget(int id,
      {required int targetAmountMinor,
      DateTime? targetDate,
      bool clearTargetDate = false}) async {
    await (db.update(db.goalsTable)..where((t) => t.id.equals(id))).write(
      GoalsTableCompanion(
        targetAmountMinor: Value(targetAmountMinor),
        targetDate: clearTargetDate
            ? const Value(null)
            : (targetDate != null ? Value(targetDate) : const Value.absent()),
      ),
    );
  }

  @override
  Future<void> archive(int id) => setStatus(id, GoalStatus.archived);

  @override
  Future<void> delete(int id) async {
    await db.transaction(() async {
      await (db.delete(db.goalContributionsTable)
            ..where((t) => t.goalId.equals(id)))
          .go();
      await (db.delete(db.goalsTable)..where((t) => t.id.equals(id))).go();
    });
  }

  @override
  Future<void> addContribution({
    required int goalId,
    required int signedAmountMinor,
    required ContributionSource source,
    int? sourceAccountId,
    int? incomeTransactionId,
    String? note,
    DateTime? occurredAt,
  }) async {
    final goal = await (db.select(db.goalsTable)
          ..where((t) => t.id.equals(goalId)))
        .getSingle();
    await db.into(db.goalContributionsTable).insert(
          GoalContributionsTableCompanion.insert(
            goalId: goalId,
            amountMinor: signedAmountMinor,
            currencyCode: goal.currencyCode,
            source: source.name,
            sourceAccountId: Value(sourceAccountId),
            incomeTransactionId: Value(incomeTransactionId),
            note: Value(note),
            occurredAt: occurredAt ?? DateTime.now(),
          ),
        );
  }

  @override
  Future<List<GoalContribution>> contributions(int goalId) async {
    final q = db.select(db.goalContributionsTable)
      ..where((t) => t.goalId.equals(goalId))
      ..orderBy([
        (t) => OrderingTerm(
            expression: t.occurredAt, mode: OrderingMode.desc)
      ]);
    return (await q.get()).map(_mapContribution).toList();
  }

  @override
  Future<int> savedFor(int goalId) async {
    final rows = await (db.select(db.goalContributionsTable)
          ..where((t) => t.goalId.equals(goalId)))
        .get();
    return rows.fold<int>(0, (sum, r) => sum + r.amountMinor);
  }

  @override
  Future<int> activeReserveMinor() async {
    final active = await (db.select(db.goalsTable)
          ..where((t) => t.status.isIn(
              [GoalStatus.active.name, GoalStatus.completed.name])))
        .get();
    var total = 0;
    for (final g in active) {
      total += await savedFor(g.id);
    }
    return total;
  }
}
