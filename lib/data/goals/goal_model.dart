enum GoalPriority { critical, high, medium, low }

enum GoalStatus { active, completed, closed, archived }

enum ContributionSource { manual, incomeAllocation }

class Goal {
  final int id;
  final String name;
  final String type;
  final String icon;
  final int targetAmountMinor;
  final String currencyCode;
  final DateTime startDate;
  final DateTime? targetDate;
  final GoalPriority priority;
  final GoalStatus status;
  final int? linkedAccountId;
  final String? note;
  final int sortOrder;
  final DateTime createdAt;
  const Goal({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.targetAmountMinor,
    required this.currencyCode,
    required this.startDate,
    required this.targetDate,
    required this.priority,
    required this.status,
    required this.linkedAccountId,
    required this.note,
    required this.sortOrder,
    required this.createdAt,
  });
}

/// The editable fields used to create or update a goal (no id/status/saved).
class GoalDraft {
  final String name;
  final String type;
  final String icon;
  final int targetAmountMinor;
  final String currencyCode;
  final DateTime startDate;
  final DateTime? targetDate;
  final GoalPriority priority;
  final int? linkedAccountId;
  final String? note;
  const GoalDraft({
    required this.name,
    this.type = 'other',
    this.icon = 'flag',
    required this.targetAmountMinor,
    this.currencyCode = 'UZS',
    required this.startDate,
    this.targetDate,
    this.priority = GoalPriority.medium,
    this.linkedAccountId,
    this.note,
  });
}

class GoalContribution {
  final int id;
  final int goalId;
  final int amountMinor; // signed
  final String currencyCode;
  final ContributionSource source;
  final int? sourceAccountId;
  final int? incomeTransactionId;
  final String? note;
  final DateTime occurredAt;
  final DateTime createdAt;
  const GoalContribution({
    required this.id,
    required this.goalId,
    required this.amountMinor,
    required this.currencyCode,
    required this.source,
    required this.sourceAccountId,
    required this.incomeTransactionId,
    required this.note,
    required this.occurredAt,
    required this.createdAt,
  });
}
