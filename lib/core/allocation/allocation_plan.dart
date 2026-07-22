import '../money/money.dart';

/// One line of the allocation plan: send [amount] to [destinationAccountId].
/// Only fixed amounts are supported (no percentage / remaining). Lines are
/// applied in [sortOrder] priority order.
class AllocationRule {
  final int destinationAccountId;
  final Money amount;
  final int sortOrder;
  const AllocationRule({
    required this.destinationAccountId,
    required this.amount,
    required this.sortOrder,
  });

  AllocationRule copyWith({int? destinationAccountId, Money? amount, int? sortOrder}) =>
      AllocationRule(
        destinationAccountId: destinationAccountId ?? this.destinationAccountId,
        amount: amount ?? this.amount,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}

/// The single reusable plan: a designated source card plus ordered rules.
class AllocationPlan {
  final int? sourceAccountId;
  final List<AllocationRule> rules; // sortOrder order
  const AllocationPlan({required this.sourceAccountId, required this.rules});
}

/// A resolved transfer the plan will execute: [amount] to [destinationAccountId].
class PlannedTransfer {
  final int destinationAccountId;
  final Money amount;
  const PlannedTransfer(this.destinationAccountId, this.amount);
}

/// A rule the source balance could not fully fund.
class PlanShortfall {
  final int destinationAccountId;
  final Money requested;
  final Money funded;
  const PlanShortfall({
    required this.destinationAccountId,
    required this.requested,
    required this.funded,
  });
  Money get shortBy => requested.subtract(funded);
}

/// The outcome of splitting a source balance across the plan's rules.
class PlanApplyResult {
  final List<PlannedTransfer> transfers;
  final Money totalMoved;
  final Money sourceRemaining;
  final List<PlanShortfall> shortfalls;
  const PlanApplyResult({
    required this.transfers,
    required this.totalMoved,
    required this.sourceRemaining,
    required this.shortfalls,
  });

  bool get hasShortfall => shortfalls.isNotEmpty;
}
