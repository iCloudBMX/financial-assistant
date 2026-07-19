import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/allocation/allocation_dynamic.dart';
import '../../core/allocation/allocation_engine.dart';
import '../../core/allocation/allocation_models.dart';
import '../../core/goal/goal_engine.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/result/failure.dart';
import '../../core/result/result.dart';
import '../../data/goals/goal_model.dart';
import '../../providers/app_providers.dart';

class AllocationController {
  final Ref ref;
  AllocationController(this.ref);

  Future<AllocationPreview> preview(Money income) async {
    final template = await ref.read(allocationRepositoryProvider).template();
    final resolved = resolveDynamicAmounts(
        template, await _requiredByGoalBucket(income.currency));
    return previewAllocation(income, resolved);
  }

  /// Allocates [incomeId] across [perBucket] and, for every goal bucket,
  /// records the matching goal contribution (earmark model: a goal-bucket
  /// allocation IS a goal contribution) -- a 1+N multi-write that runs
  /// inside one `databaseProvider.transaction` (mirrors
  /// `IncomeEntryController.save`), so a failed contribution write rolls
  /// back the income allocation too instead of leaving a partial earmark.
  Future<Result<void>> confirm(
      int incomeId, Map<String, Money> perBucket) async {
    try {
      await ref.read(databaseProvider).transaction(() async {
        await ref
            .read(allocationRepositoryProvider)
            .allocateIncome(incomeId, perBucket);
        final goalRepo = ref.read(goalRepositoryProvider);
        for (final e in perBucket.entries) {
          if (!e.key.startsWith('goal:') || e.value.minorUnits == 0) continue;
          final goalId = int.tryParse(e.key.substring('goal:'.length));
          if (goalId == null) continue;
          await goalRepo.addContribution(
            goalId: goalId,
            signedAmountMinor: e.value.minorUnits,
            source: ContributionSource.incomeAllocation,
            incomeTransactionId: incomeId,
          );
        }
      });
    } catch (error) {
      // Diagnostic detail stays inside Failure; userMessageFor never
      // interpolates it into presentation text.
      return Err(PersistenceFailure(error.toString()));
    }
    ref.read(ledgerRevisionProvider.notifier).update((n) => n + 1);
    return const Ok(null);
  }

  /// For each active goal that has a `goalBased` direction, the required
  /// monthly amount keyed by its `goal:{id}` bucket.
  Future<Map<String, Money>> _requiredByGoalBucket(Currency currency) async {
    final template = await ref.read(allocationRepositoryProvider).template();
    final goalBuckets = template.directions
        .where((d) => d.method == AllocationMethod.goalBased)
        .map((d) => d.bucketKey)
        .toSet();
    if (goalBuckets.isEmpty) return const {};
    final goalRepo = ref.read(goalRepositoryProvider);
    final goals = await goalRepo.list();
    final now = DateTime.now();
    final out = <String, Money>{};
    for (final g in goals) {
      final key = 'goal:${g.id}';
      if (!goalBuckets.contains(key)) continue;
      final saved = await goalRepo.savedFor(g.id);
      // TODO(multi-currency): assumes the goal's currency matches `currency`.
      final remaining = Money(
          (g.targetAmountMinor - saved).clamp(0, g.targetAmountMinor),
          currency);
      final req = requiredMonthlyContribution(
        remaining: remaining,
        targetDate: g.targetDate,
        asOf: now,
      );
      out[key] = req ?? Money.zero(currency);
    }
    return out;
  }
}

final allocationControllerProvider =
    Provider<AllocationController>((ref) => AllocationController(ref));
