import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/month_close_providers.dart';
import '../../ui/components/velora_async_state.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_card.dart';
import 'month_close_data.dart';

/// §16.1 soft-ceremony month-close summary: what happened last period, plus
/// a single "Oyni yopish" action that marks it closed. No forced flow — the
/// user can dismiss (back button) and be offered the same period again next
/// visit to Reports.
class MonthCloseScreen extends ConsumerWidget {
  const MonthCloseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(monthCloseProvider);
    return Scaffold(
      backgroundColor: VeloraColors.blush,
      appBar: AppBar(
        title: const Text('Oyni yopish'),
        backgroundColor: VeloraColors.blush,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: VeloraColors.inkberry,
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => VeloraErrorState(
          message: 'Xatolik yuz berdi',
          onRetry: () => ref.invalidate(monthCloseProvider),
        ),
        data: (value) => value == null
            ? const VeloraEmptyState(
                icon: Icons.check_circle_outline,
                title: 'Yopiladigan davr yo\'q',
              )
            : _MonthCloseBody(data: value),
      ),
    );
  }
}

class _MonthCloseBody extends ConsumerWidget {
  const _MonthCloseBody({required this.data});

  final MonthCloseData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final leftover = data.summary.leftover;
    final overspent = leftover.isNegative;
    final saveOrOverLabel = overspent ? 'Oshib ketdi' : 'Tejaldi';
    final saveOrOverValue = overspent ? leftover.negate() : leftover;

    return ListView(
      padding: const EdgeInsets.all(VeloraSpacing.lg),
      children: [
        VeloraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(periodLabel(data.period), style: theme.textTheme.titleLarge),
              const SizedBox(height: VeloraSpacing.md),
              _row(context, 'Daromad', data.summary.income),
              _row(context, 'Xarajat', data.summary.expense),
              _row(context, saveOrOverLabel, saveOrOverValue),
              _row(context, "Maqsadga ajratilgan", data.goalAllocated),
              _row(context, 'Taqsimlanmagan', leftover),
            ],
          ),
        ),
        const SizedBox(height: VeloraSpacing.lg),
        // Task 7: leftover-distribution chooser goes here (spend/save/goal
        // split for `leftover`). Intentionally not built in this task.
        const SizedBox(height: VeloraSpacing.lg),
        VeloraPrimaryButton(
          label: 'Oyni yopish',
          onPressed: () async {
            await ref.read(closePeriodProvider)(data.period.start);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ],
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
}
