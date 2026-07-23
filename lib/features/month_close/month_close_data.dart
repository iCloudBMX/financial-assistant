import '../../core/money/money.dart';
import '../../core/reports/period_summary.dart';
import '../../core/time/financial_period.dart';

/// The most recent elapsed period that has not yet been closed, or null.
/// "Elapsed" = its endExclusive is at/behind [now]. The candidate is the
/// period just before the one containing [now]. Considered closed when
/// [lastClosedStart] is at or after the candidate's start.
FinancialPeriod? closeablePeriod(
    DateTime now, int startDay, DateTime? lastClosedStart) {
  final candidate = FinancialPeriod.containing(now, startDay).previous();
  if (lastClosedStart != null && !lastClosedStart.isBefore(candidate.start)) {
    return null;
  }
  return candidate;
}

/// View-model for the §16.1 month-close summary screen. [summary.leftover]
/// doubles as "undistributed" — deliberately the CURRENT spending-account
/// balance, not a historical end-of-period snapshot (soft ceremony).
const _uzMonths = [
  'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
  'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr',
];

/// Uzbek month name for [period]'s start, e.g. "Iyul 2026" — used by both
/// the close-out CTA banner and the summary screen title.
String periodLabel(FinancialPeriod period) =>
    '${_uzMonths[period.start.month - 1]} ${period.start.year}';

class MonthCloseData {
  final FinancialPeriod period;
  final MonthlySummary summary;
  final Money goalAllocated;
  const MonthCloseData({
    required this.period,
    required this.summary,
    required this.goalAllocated,
  });
}
