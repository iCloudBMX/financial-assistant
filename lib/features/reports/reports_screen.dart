import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/month_close_providers.dart';
import '../../providers/reports_providers.dart';
import '../../ui/components/velora_async_state.dart';
import '../../ui/components/velora_card.dart';
import '../month_close/month_close_data.dart';
import '../month_close/month_close_screen.dart';
import 'category_report_view.dart';
import 'goal_report_view.dart';
import 'mortgage_report_view.dart';
import 'report_data.dart';

/// The Tahlil (Reports) tab: Oylik, Kategoriya, Maqsad, Ipoteka sections.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: VeloraColors.blush,
        appBar: AppBar(
          title: const Text('Hisobotlar'),
          backgroundColor: VeloraColors.blush,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: VeloraColors.inkberry,
          bottom: const TabBar(
            isScrollable: true,
            labelColor: VeloraColors.plum,
            unselectedLabelColor: VeloraColors.muted,
            indicatorColor: VeloraColors.plum,
            tabs: [
              Tab(text: 'Oylik'),
              Tab(text: 'Kategoriya'),
              Tab(text: 'Maqsad'),
              Tab(text: 'Ipoteka'),
            ],
          ),
        ),
        body: Column(
          children: [
            const _MonthCloseBanner(),
            Expanded(
              child: TabBarView(
                children: [
                  const _MonthlyTab(),
                  ListView(
                    padding: const EdgeInsets.all(VeloraSpacing.lg),
                    children: const [CategoryReportView()],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(VeloraSpacing.lg),
                    children: const [GoalReportView()],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(VeloraSpacing.lg),
                    children: const [MortgageReportView()],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows only once there is an elapsed, unclosed period (Task 6, §16.1
/// soft-ceremony close). Tapping it pushes [MonthCloseScreen]; nothing is
/// forced — silence (loading/error/null) just renders nothing.
class _MonthCloseBanner extends ConsumerWidget {
  const _MonthCloseBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthClose = ref.watch(monthCloseProvider).asData?.value;
    if (monthClose == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          VeloraSpacing.lg, VeloraSpacing.lg, VeloraSpacing.lg, 0),
      child: VeloraCard(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MonthCloseScreen()),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_available, color: VeloraColors.plum),
            const SizedBox(width: VeloraSpacing.sm),
            Expanded(
              child: Text(
                '${periodLabel(monthClose.period)} oyini yopish vaqti keldi',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _MonthlyTab extends ConsumerWidget {
  const _MonthlyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(monthlyReportProvider);
    return report.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => VeloraErrorState(
        message: 'Xatolik yuz berdi',
        onRetry: () => ref.invalidate(monthlyReportProvider),
      ),
      data: (data) => ListView(
        padding: const EdgeInsets.all(VeloraSpacing.lg),
        children: [
          _MonthlySection(report: data),
        ],
      ),
    );
  }
}

class _MonthlySection extends StatelessWidget {
  const _MonthlySection({required this.report});

  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = report.current;
    final previous = report.previous;
    return VeloraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Oylik hisobot', style: theme.textTheme.titleLarge),
          const SizedBox(height: VeloraSpacing.md),
          _row(context, 'Daromad', current.income),
          _row(context, 'Xarajat', current.expense),
          _row(context, 'Majburiy xarajat', current.mandatoryExpense),
          _row(context, "O'zgaruvchan xarajat", current.variableExpense),
          _row(context, "Maqsadga ajratilgan", report.goalAllocated),
          _row(context, 'Taqsimlanmagan', current.leftover),
          const SizedBox(height: VeloraSpacing.md),
          Text(
            'Daromad: ${_delta(current.income, previous.income)} · '
            'Xarajat: ${_delta(current.expense, previous.expense)} '
            'vs oldingi oy',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, Money value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: VeloraSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: VeloraSpacing.sm),
          Text(
            value.format(),
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  String _delta(Money currentValue, Money previousValue) {
    final diff = currentValue.subtract(previousValue);
    final sign = diff.isNegative ? '' : '+';
    return '$sign${diff.format()}';
  }
}
