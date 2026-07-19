import 'package:flutter/material.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/velora_card.dart';

/// §6.8 goal card: saved/target, percent, remaining, target date, projected
/// completion, and required monthly contribution — all figures already
/// derived by `computeGoalProgress` (core/goal/goal_engine.dart), this card
/// only renders them.
class GoalCard extends StatelessWidget {
  final GoalWithProgress item;
  final VoidCallback? onTap;
  const GoalCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = item.progress;
    final percent = (p.percentBp / 10000).clamp(0.0, 1.0);
    return VeloraCard(
      key: Key('goal-card-${item.goal.id}'),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: VeloraSpacing.sm),
              Expanded(
                child: Text(item.goal.name, style: theme.textTheme.titleMedium),
              ),
              Text('${(p.percentBp / 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: VeloraSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(VeloraRadii.control),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: VeloraColors.apricot,
            ),
          ),
          const SizedBox(height: VeloraSpacing.sm),
          Text('${p.saved.format()} / ${p.target.format()}',
              style: theme.textTheme.bodyMedium),
          Text('Qoldi: ${p.remaining.format()}',
              style: theme.textTheme.bodySmall),
          if (p.requiredMonthly != null)
            Text('Oyiga kerak: ${p.requiredMonthly!.format()}',
                style: theme.textTheme.bodySmall),
          if (p.projectedDate != null)
            Text(
              'Taxminiy yetish sanasi: '
              '${p.projectedDate!.toIso8601String().split('T').first}',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
