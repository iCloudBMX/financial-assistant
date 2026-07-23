import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/reports/period_summary.dart';
import '../../core/time/financial_period.dart';

/// Widget-free view-model for the Reports ▸ Oylik (monthly) tab.
class MonthlyReport {
  final MonthlySummary current;
  final MonthlySummary previous;
  final Money goalAllocated;
  final FinancialPeriod period;
  final Currency currency;
  const MonthlyReport({
    required this.current,
    required this.previous,
    required this.goalAllocated,
    required this.period,
    required this.currency,
  });
}
