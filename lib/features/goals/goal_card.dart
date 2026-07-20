import 'package:flutter/material.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import 'goal_visuals.dart';

/// §6.8 goal card, rendered in the "Velora Human" style of the Home
/// primary-goal card: an apricot-tinted surface with a rounded apricot icon
/// tile, the goal name + subtitle (target date · priority), a plum percentage,
/// an apricot progress bar on a white track, and the saved / remaining meta —
/// plus the projected completion and required monthly contribution when known.
/// All figures are derived by `computeGoalProgress`; this card only renders.
class GoalCard extends StatelessWidget {
  final GoalWithProgress item;
  final VoidCallback? onTap;
  const GoalCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goal = item.goal;
    final p = item.progress;
    final percent = (p.percentBp / 10000).clamp(0.0, 1.0);
    final percentText = '${(p.percentBp / 100).toStringAsFixed(0)}%';
    final borderRadius = BorderRadius.circular(VeloraRadii.card);

    return Material(
      key: Key('goal-card-${goal.id}'),
      color: VeloraColors.apricotTint,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.all(VeloraSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GoalIconTile(),
                  const SizedBox(width: VeloraSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: VeloraSpacing.xs),
                        Text(
                          '${goalDateLabel(goal.targetDate)} · '
                          '${goalPriorityLabel(goal.priority)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: VeloraColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: VeloraSpacing.sm),
                  Text(
                    percentText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: VeloraColors.plum,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: VeloraSpacing.md),
              GoalProgressBar(value: percent),
              const SizedBox(height: VeloraSpacing.sm),
              GoalMetaLine(
                label: '${p.saved.format()} jamg\'arildi',
                value: '${p.remaining.format()} qoldi',
                emphasize: true,
              ),
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
        ),
      ),
    );
  }
}
