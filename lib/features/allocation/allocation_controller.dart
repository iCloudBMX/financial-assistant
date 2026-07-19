import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/allocation/allocation_engine.dart';
import '../../core/allocation/allocation_models.dart';
import '../../core/money/money.dart';
import '../../providers/app_providers.dart';

class AllocationController {
  final Ref ref;
  AllocationController(this.ref);

  Future<AllocationResult> preview(Money income) async {
    final template = await ref.read(allocationRepositoryProvider).template();
    return computeAllocation(income, template);
  }

  Future<void> confirm(int incomeId, Map<String, Money> perBucket) async {
    await ref
        .read(allocationRepositoryProvider)
        .allocateIncome(incomeId, perBucket);
    ref.read(ledgerRevisionProvider.notifier).update((n) => n + 1);
  }
}

final allocationControllerProvider =
    Provider<AllocationController>((ref) => AllocationController(ref));
