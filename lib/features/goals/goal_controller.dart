import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/money.dart';
import '../../core/result/failure.dart';
import '../../core/result/result.dart';
import '../../data/goals/goal_model.dart';
import '../../data/goals/goal_repository.dart';
import '../../providers/app_providers.dart';

/// Mediates all goal mutations (contribute/withdraw/close/retarget/move)
/// with validation guards and the active<->completed status transition.
class GoalController {
  final Ref ref;
  GoalController(this.ref);

  GoalRepository get _repo => ref.read(goalRepositoryProvider);

  void _bump() =>
      ref.read(ledgerRevisionProvider.notifier).update((n) => n + 1);

  Future<Result<void>> contribute({
    required int goalId,
    required Money amount,
    ContributionSource source = ContributionSource.manual,
    int? sourceAccountId,
    String? note,
  }) async {
    if (amount.minorUnits <= 0) {
      return const Err(ValidationFailure('contribution must be > 0'));
    }
    // TODO(multi-currency): amount is assumed to already be in the goal's
    // currency; cross-currency contributions are out of MVP scope.
    await _repo.addContribution(
      goalId: goalId,
      signedAmountMinor: amount.minorUnits,
      source: source,
      sourceAccountId: sourceAccountId,
      note: note,
    );
    await _recomputeCompletion(goalId);
    _bump();
    return const Ok(null);
  }

  Future<Result<void>> withdraw({
    required int goalId,
    required Money amount,
    String? note,
  }) async {
    if (amount.minorUnits <= 0) {
      return const Err(ValidationFailure('withdrawal must be > 0'));
    }
    final saved = await _repo.savedFor(goalId);
    if (amount.minorUnits > saved) {
      return const Err(ValidationFailure('cannot withdraw more than saved'));
    }
    await _repo.addContribution(
      goalId: goalId,
      signedAmountMinor: -amount.minorUnits,
      source: ContributionSource.manual,
      note: note,
    );
    await _recomputeCompletion(goalId);
    _bump();
    return const Ok(null);
  }

  /// Closes the goal (releases its reserve). Not auto-reactivated by
  /// subsequent completion checks.
  Future<void> closeGoal(int id) async {
    await _repo.setStatus(id, GoalStatus.closed);
    _bump();
  }

  Future<Result<void>> setNewTarget(
    int id, {
    required Money target,
    DateTime? targetDate,
    bool clearTargetDate = false,
  }) async {
    if (target.minorUnits <= 0) {
      return const Err(ValidationFailure('target must be > 0'));
    }
    await _repo.setTarget(id,
        targetAmountMinor: target.minorUnits,
        targetDate: targetDate,
        clearTargetDate: clearTargetDate);
    // A new target reactivates the goal regardless of current status.
    await _repo.setStatus(id, GoalStatus.active);
    await _recomputeCompletion(id);
    _bump();
    return const Ok(null);
  }

  /// Withdraws [amount] from [fromGoalId] and contributes it to
  /// [toGoalId]. Both legs are guarded (positive amount, sufficient
  /// saved balance on the source); if the withdrawal fails, the
  /// contribution is never attempted.
  Future<Result<void>> moveSurplus({
    required int fromGoalId,
    required int toGoalId,
    required Money amount,
  }) async {
    if (amount.minorUnits <= 0) {
      return const Err(ValidationFailure('move amount must be > 0'));
    }
    final w = await withdraw(goalId: fromGoalId, amount: amount);
    if (!w.isOk) return w;
    return contribute(goalId: toGoalId, amount: amount);
  }

  Future<void> _recomputeCompletion(int goalId) async {
    final goals = await _repo.list(includeArchived: true);
    final g = goals.firstWhere((x) => x.id == goalId);
    final saved = await _repo.savedFor(goalId);
    if (saved >= g.targetAmountMinor && g.status == GoalStatus.active) {
      await _repo.setStatus(goalId, GoalStatus.completed);
    } else if (saved < g.targetAmountMinor &&
        g.status == GoalStatus.completed) {
      await _repo.setStatus(goalId, GoalStatus.active);
    }
  }
}

final goalControllerProvider =
    Provider<GoalController>((ref) => GoalController(ref));
