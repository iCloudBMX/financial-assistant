import '../money/money.dart';

class SafeLimit {
  final Money spendable; // the spending pool, floored at zero
  final Money perDay;
  final int daysLeft;
  final Money todaySpent;
  final Money todayRemaining; // perDay − todaySpent
  // Whether at least one non-archived Sarf-role card exists. Lets Home/SP-C
  // tell "no spending cards" (show "Sarf kartasi belgilang") apart from
  // "spending cards summing to zero" — never inferred from spendable <= 0.
  // Defaulted true so existing value-widget SafeLimit literals stay valid.
  final bool hasSpendingAccounts;
  const SafeLimit({
    required this.spendable,
    required this.perDay,
    required this.daysLeft,
    required this.todaySpent,
    required this.todayRemaining,
    this.hasSpendingAccounts = true,
  });
  bool get isOver => todayRemaining.minorUnits < 0;
}

class WeeklySafeLimit {
  final Money weeklyLimit; // weeklySpent + weeklyRemaining
  final Money weeklySpent;
  final Money weeklyRemaining; // perDay × days left in the week
  const WeeklySafeLimit({
    required this.weeklyLimit,
    required this.weeklySpent,
    required this.weeklyRemaining,
  });
}

int _max0(int v) => v < 0 ? 0 : v;

/// Model-A daily spend limit: the whole spendable pool — the summed balance
/// of the Sarf-role (spending) cards — split evenly across the days left in
/// the current financial period.
///
///   spendable = max(0, spendablePool)
///   perDay    = spendable ÷ daysLeft        (integer floor)
///
/// [daysLeft] is floored at 1 so the last day of a period never divides by
/// zero. [todaySpent] only drives the "today remaining" figure; it does not
/// reduce the pool. Reserve / Kredit / Jamg'arma balances are already
/// excluded upstream by role, so there is no reserve subtraction here.
/// [hasSpendingAccounts] is passed straight through to the result so callers
/// can show an "add a spending card" empty state without inspecting figures.
SafeLimit dailySpendLimit({
  required Money spendablePool,
  required int daysLeft,
  required Money todaySpent,
  bool hasSpendingAccounts = true,
}) {
  final c = spendablePool.currency;
  final days = daysLeft < 1 ? 1 : daysLeft;
  final spendable = _max0(spendablePool.minorUnits);
  final perDay = spendable ~/ days;
  return SafeLimit(
    spendable: Money(spendable, c),
    perDay: Money(perDay, c),
    daysLeft: days,
    todaySpent: todaySpent,
    todayRemaining: Money(perDay - todaySpent.minorUnits, c),
    hasSpendingAccounts: hasSpendingAccounts,
  );
}

/// §11.6 weekly view, derived from the daily figure so there is one budget
/// source. `weeklyRemaining` is the per-day allowance times the days still
/// left in the current week; `weeklyLimit` adds what was already spent.
WeeklySafeLimit weeklySafeLimit(SafeLimit daily,
    {required int daysLeftInWeek, required Money weeklySpent}) {
  final c = daily.perDay.currency;
  final remaining = Money(daily.perDay.minorUnits * daysLeftInWeek, c);
  return WeeklySafeLimit(
    weeklyLimit: remaining.add(weeklySpent),
    weeklySpent: weeklySpent,
    weeklyRemaining: remaining,
  );
}
