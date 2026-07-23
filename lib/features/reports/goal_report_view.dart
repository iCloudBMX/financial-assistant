import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/velora_async_state.dart';
import '../../ui/components/velora_card.dart';
import '../goals/goal_visuals.dart';

/// The Maqsad (goal) report tab (§15.5): re-surfaces each goal's
/// already-computed [GoalWithProgress] (from `goalsProvider`) as a read-only
/// list of cards. Per-goal contribution history stays on the existing
/// goal-detail screen; this is summary-only.
class GoalReportView extends ConsumerWidget {
  const GoalReportView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    return goals.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => VeloraErrorState(
        message: 'Xatolik yuz berdi',
        onRetry: () => ref.invalidate(goalsProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const VeloraEmptyState(
            icon: Icons.flag_outlined,
            title: "Hali maqsad yo'q",
            message: "Maqsad qo'shilgach, shu yerda hisobot ko'rinadi.",
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in list) ...[
              _GoalReportCard(item: item),
              const SizedBox(height: VeloraSpacing.sm),
            ],
          ],
        );
      },
    );
  }
}

class _GoalReportCard extends StatelessWidget {
  const _GoalReportCard({required this.item});

  final GoalWithProgress item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goal = item.goal;
    final p = item.progress;
    final percent = (p.percentBp / 10000).clamp(0.0, 1.0);
    return VeloraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const GoalIconTile(size: 32),
              const SizedBox(width: VeloraSpacing.md),
              Expanded(
                child: Text(
                  goal.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: VeloraSpacing.sm),
              Text(
                '${(p.percentBp / 100).toStringAsFixed(0)}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: VeloraColors.plum,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: VeloraSpacing.sm),
          GoalProgressBar(value: percent, track: VeloraColors.line),
          const SizedBox(height: VeloraSpacing.sm),
          GoalMetaLine(
            label: '${p.saved.format()} jamg\'arildi',
            value: '${p.remaining.format()} qoldi',
            emphasize: true,
          ),
          GoalMetaLine(label: 'Maqsad summasi', value: p.target.format()),
          if (p.requiredMonthly != null)
            GoalMetaLine(
              label: 'Oyiga kerak',
              value: p.requiredMonthly!.format(),
            ),
          if (p.projectedDate != null)
            GoalMetaLine(
              label: 'Taxminiy yetish',
              value: goalDateLabel(p.projectedDate),
            ),
        ],
      ),
    );
  }
}
