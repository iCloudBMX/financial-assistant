import '../../core/ledger/ledger_entry.dart';
import '../../core/money/money.dart';

enum IntervalKind { monthly, weekly }

class RecurringIncomePlan {
  final int id;
  final int accountId;
  final Money amount;
  final IncomeType incomeType;
  final String? note;
  final IntervalKind intervalKind;
  final int anchorDay;
  final DateTime nextDueAt;
  final bool active;
  const RecurringIncomePlan({
    required this.id,
    required this.accountId,
    required this.amount,
    required this.incomeType,
    required this.note,
    required this.intervalKind,
    required this.anchorDay,
    required this.nextDueAt,
    required this.active,
  });
}

/// The next occurrence strictly after [after]. Monthly clamps the anchor day
/// to the target month's length (e.g. 31 -> Feb 28/29); weekly adds 7 days.
DateTime nextRecurringDate(DateTime after, IntervalKind kind, int anchorDay) {
  switch (kind) {
    case IntervalKind.weekly:
      return after.add(const Duration(days: 7));
    case IntervalKind.monthly:
      final base = DateTime(after.year, after.month + 1, 1);
      final lastDay = DateTime(base.year, base.month + 1, 0).day;
      final day = anchorDay > lastDay ? lastDay : anchorDay;
      return DateTime(base.year, base.month, day);
  }
}
