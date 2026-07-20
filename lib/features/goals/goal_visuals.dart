import 'package:flutter/material.dart';
import '../../core/theme/velora_tokens.dart';
import '../../data/goals/goal_model.dart';

/// Shared "Velora Human" building blocks for the Maqsad (goals) screens.
/// These mirror the Home primary-goal card visual language (apricot icon tile
/// + apricot progress bar with rounded ends) so goals read as the same warm,
/// payment-app surface rather than plain Material. Presentation only — every
/// figure is derived upstream by `computeGoalProgress`.

/// A rounded, filled icon tile — the apricot square behind a goal's glyph on
/// Home. Reused for goal cards (apricot) and history rows (success/critical).
class GoalIconTile extends StatelessWidget {
  const GoalIconTile({
    super.key,
    this.icon = Icons.flag_outlined,
    this.size = 40,
    this.background = VeloraColors.apricot,
    this.foreground = Colors.white,
  });

  final IconData icon;
  final double size;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(VeloraRadii.control),
      ),
      child: Icon(icon, color: foreground, size: size * 0.5),
    );
  }
}

/// The apricot progress bar with fully rounded ends on a soft track, matching
/// the mockup's goal bars. Defaults to a white track for use on the apricot
/// goal-card fill; pass [track] for other surfaces.
class GoalProgressBar extends StatelessWidget {
  const GoalProgressBar({
    super.key,
    required this.value,
    this.color = VeloraColors.apricot,
    this.track = Colors.white,
    this.minHeight = 8,
  });

  final double value;
  final Color color;
  final Color track;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: minHeight,
        backgroundColor: track,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

/// A section title row ("Asosiy maqsad", "Boshqa maqsadlar", …) with an
/// optional muted trailing hint, as used above each list block in the mockup.
class GoalSectionHeader extends StatelessWidget {
  const GoalSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        left: VeloraSpacing.xs,
        right: VeloraSpacing.xs,
        bottom: VeloraSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: VeloraColors.muted),
            ),
        ],
      ),
    );
  }
}

/// One label/value meta line ("… jamg'arildi", "… qoldi"). The label flexes
/// and the value can shrink, so the row stays intact at 320px / 200% text
/// scale instead of overflowing.
class GoalMetaLine extends StatelessWidget {
  const GoalMetaLine({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool emphasize;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: VeloraSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style:
                  theme.textTheme.bodySmall?.copyWith(color: VeloraColors.muted),
            ),
          ),
          const SizedBox(width: VeloraSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(
                color: valueColor ?? VeloraColors.inkberry,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Uzbek label for a goal's priority, used as part of the card subtitle.
String goalPriorityLabel(GoalPriority p) => switch (p) {
      GoalPriority.critical => 'Eng yuqori prioritet',
      GoalPriority.high => 'Yuqori prioritet',
      GoalPriority.medium => "O'rta prioritet",
      GoalPriority.low => 'Past prioritet',
    };

/// dd.MM.yyyy, or the "no deadline" copy when [d] is null.
String goalDateLabel(DateTime? d) => d == null
    ? 'Muddat belgilanmagan'
    : '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.${d.year}';
