import '../money/money.dart';
import '../time/financial_period.dart';

/// All the figures the safe-limit computation needs (§11.2). `goalReserves`
/// and `unpaidMandatory` are 0 in SP2; SP3/SP4 supply real values without
/// changing this engine.
class SafeLimitInputs {
  final Money variableBudget;
  final Money variableSpent;
  final Money manualBuffer;
  final Money totalAvailable;
  final Money minReserve;
  final Money goalReserves;
  final Money unpaidMandatory;
  final Money todaySpent;
  final FinancialPeriod period;
  final DateTime asOf;
  const SafeLimitInputs({
    required this.variableBudget,
    required this.variableSpent,
    required this.manualBuffer,
    required this.totalAvailable,
    required this.minReserve,
    required this.goalReserves,
    required this.unpaidMandatory,
    required this.todaySpent,
    required this.period,
    required this.asOf,
  });
}

class SafeLimit {
  final Money spendable; // remaining variable budget after the free-balance cap
  final Money perDay;
  final int daysLeft;
  final Money todaySpent;
  final Money todayRemaining; // perDay − todaySpent
  const SafeLimit({
    required this.spendable,
    required this.perDay,
    required this.daysLeft,
    required this.todaySpent,
    required this.todayRemaining,
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

/// §11.2 core formula:
///   remainingVariable = max(0, variableBudget − variableSpent − manualBuffer)
///   freeBalance       = totalAvailable − minReserve − goalReserves − unpaidMandatory
///   spendable         = max(0, min(remainingVariable, freeBalance))
///   perDay            = spendable ÷ daysLeft   (integer floor)
/// `daysLeft` counts whole days from the start of [asOf]'s day to the period's
/// exclusive end, floored at 1.
SafeLimit dailySafeLimit(SafeLimitInputs i) {
  final c = i.variableBudget.currency;
  final remainingVariable = _max0(i.variableBudget.minorUnits -
      i.variableSpent.minorUnits -
      i.manualBuffer.minorUnits);
  final freeBalance = i.totalAvailable.minorUnits -
      i.minReserve.minorUnits -
      i.goalReserves.minorUnits -
      i.unpaidMandatory.minorUnits;
  final cap = remainingVariable < freeBalance ? remainingVariable : freeBalance;
  final spendable = _max0(cap);

  final today = DateTime(i.asOf.year, i.asOf.month, i.asOf.day);
  final rawDays = i.period.endExclusive.difference(today).inDays;
  final daysLeft = rawDays < 1 ? 1 : rawDays;

  final perDay = spendable ~/ daysLeft;
  return SafeLimit(
    spendable: Money(spendable, c),
    perDay: Money(perDay, c),
    daysLeft: daysLeft,
    todaySpent: i.todaySpent,
    todayRemaining: Money(perDay - i.todaySpent.minorUnits, c),
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
