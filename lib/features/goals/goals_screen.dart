import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../data/goals/goal_model.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/velora_async_state.dart';
import '../../ui/components/velora_button.dart';
import 'goal_card.dart';
import 'goal_detail_screen.dart';
import 'goal_edit_sheet.dart';
import 'goal_visuals.dart';

/// The Maqsad tab. In the "Velora Human" style it leads with a plum summary of
/// everything saved, then the primary goal, then the rest — each an
/// apricot-tinted goal card. Keeps its own add-goal FAB; extra bottom padding
/// clears the global floating "Chiqim" FAB so both stay reachable.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  // Clears the shell's floating "Chiqim" FAB plus this screen's own add FAB.
  static const _bottomClearance = 88.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    return Scaffold(
      backgroundColor: VeloraColors.blush,
      appBar: AppBar(
        title: const Text('Maqsadlar'),
        backgroundColor: VeloraColors.blush,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: VeloraColors.inkberry,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showGoalEditSheet(context, ref),
        backgroundColor: VeloraColors.coral,
        foregroundColor: Colors.white,
        tooltip: "Maqsad qo'shish",
        child: const Icon(Icons.add),
      ),
      body: goals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => VeloraErrorState(
          message: 'Xatolik yuz berdi',
          onRetry: () => ref.invalidate(goalsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return VeloraEmptyState(
              icon: Icons.flag_outlined,
              iconColor: VeloraColors.apricot,
              title: "Hali maqsad yo'q",
              message: "Birinchi moliyaviy maqsadingizni qo'shing.",
              action: VeloraPrimaryButton(
                label: 'Maqsad qo\'shish',
                onPressed: () => showGoalEditSheet(context, ref),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              VeloraSpacing.lg,
              VeloraSpacing.lg,
              VeloraSpacing.lg,
              _bottomClearance,
            ),
            children: [
              _GoalsSummaryHeader(goals: list),
              const SizedBox(height: VeloraSpacing.lg),
              const GoalSectionHeader(title: 'Asosiy maqsad'),
              _card(context, list.first),
              if (list.length > 1) ...[
                const SizedBox(height: VeloraSpacing.lg),
                const GoalSectionHeader(title: 'Boshqa maqsadlar'),
                for (final g in list.skip(1)) ...[
                  _card(context, g),
                  const SizedBox(height: VeloraSpacing.md),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, GoalWithProgress item) => GoalCard(
        item: item,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => GoalDetailScreen(goalId: item.goal.id),
        )),
      );
}

/// The plum "Jami jamg'arilgan" summary at the top of the tab: total saved
/// across all goals plus a two-cell grid of active / total goal counts.
class _GoalsSummaryHeader extends StatelessWidget {
  const _GoalsSummaryHeader({required this.goals});

  final List<GoalWithProgress> goals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = goals.first.progress.saved.currency;
    final totalSaved = Money(
      goals.fold<int>(0, (s, g) => s + g.progress.saved.minorUnits),
      currency,
    );
    final activeCount =
        goals.where((g) => g.goal.status == GoalStatus.active).length;

    return Container(
      padding: const EdgeInsets.all(VeloraSpacing.lg),
      decoration: BoxDecoration(
        color: VeloraColors.plum,
        borderRadius: BorderRadius.circular(VeloraRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Jami jamg\'arilgan',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: Colors.white.withValues(alpha: 0.72)),
          ),
          const SizedBox(height: VeloraSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              totalSaved.format(),
              maxLines: 1,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: VeloraSpacing.md),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  label: 'Faol',
                  value: '$activeCount maqsad',
                ),
              ),
              const SizedBox(width: VeloraSpacing.sm),
              Expanded(
                child: _SummaryStat(
                  label: 'Jami',
                  value: '${goals.length} maqsad',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(VeloraSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(VeloraRadii.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: Colors.white.withValues(alpha: 0.72)),
          ),
          const SizedBox(height: VeloraSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
