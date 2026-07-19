import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/app_providers.dart';
import '../accounts/transfer_sheet.dart';
import '../expense_entry/expense_entry_sheet.dart';
import '../income_entry/income_entry_sheet.dart';
import '../mortgage/mortgage_summary_card.dart';
import '../recurring/recurring_prompt.dart';
import '../shell/routes.dart';
import 'dashboard_data.dart';
import 'safe_limit_cards.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bosh sahifa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () => context.pushNamed(RouteNames.accounts),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Xatolik yuz berdi')),
        data: (d) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const RecurringPromptBanner(),
            _totalCard(context, d),
            const SafeLimitCard(),
            const WeeklySafeLimitCard(),
            const MortgageSummaryCard(),
            _row('Shu oygi kirim', d.monthIncome.format()),
            _row('Shu oygi chiqim', d.monthExpense.format()),
            _row('Bugun sarflangan', d.todaySpent.format()),
            _row('Taqsimlanmagan mablag\'', d.undistributedFunds.format()),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => showExpenseEntrySheet(context, ref),
                  icon: const Icon(Icons.remove),
                  label: const Text('Chiqim'),
                ),
                FilledButton.icon(
                  onPressed: () => showIncomeEntrySheet(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Kirim'),
                ),
                OutlinedButton.icon(
                  onPressed: () => showTransferSheet(context, ref),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('O\'tkazma'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalCard(BuildContext context, DashboardData d) {
    final lines =
        d.totals.entries.map((e) => e.value.format()).join('\n');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Jami mavjud balans'),
            const SizedBox(height: 8),
            Text(lines.isEmpty ? '—' : lines,
                style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 8),
            Flexible(child: Text(value, textAlign: TextAlign.end)),
          ],
        ),
      );
}
