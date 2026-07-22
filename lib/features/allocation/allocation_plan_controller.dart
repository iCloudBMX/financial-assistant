import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/allocation/allocation_plan.dart';
import '../../core/result/result.dart';
import '../../providers/app_providers.dart';

/// Thin command surface over [AllocationPlanRepository]. Every mutation bumps
/// [ledgerRevisionProvider] so balances, the daily limit, and the plan view
/// recompute.
class AllocationPlanController {
  final Ref ref;
  AllocationPlanController(this.ref);

  Future<Result<void>> apply(
      int sourceId, List<PlannedTransfer> transfers) async {
    final r = await ref
        .read(allocationPlanRepositoryProvider)
        .applyPlan(sourceId, transfers);
    if (r.isOk) ref.read(ledgerRevisionProvider.notifier).state++;
    return r;
  }

  Future<void> setSource(int? accountId) async {
    await ref.read(allocationPlanRepositoryProvider).setSource(accountId);
    ref.read(ledgerRevisionProvider.notifier).state++;
  }

  Future<void> saveRules(List<AllocationRule> rules) async {
    await ref.read(allocationPlanRepositoryProvider).saveRules(rules);
    ref.read(ledgerRevisionProvider.notifier).state++;
  }
}

final allocationPlanControllerProvider =
    Provider<AllocationPlanController>((ref) => AllocationPlanController(ref));
