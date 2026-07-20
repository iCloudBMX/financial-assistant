import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../data/goals/goal_model.dart';
import '../../providers/app_providers.dart';
import 'goal_contribute_sheet.dart';
import 'goal_visuals.dart';

/// The goal detail screen in the "Velora Human" style: a plum progress hero
/// with a circular percent ring, an apricot forecast card (projected date +
/// required monthly), the coral contribute / plum withdraw actions, and the
/// full contribution history for one goal.
class GoalDetailScreen extends ConsumerWidget {
  final int goalId;
  const GoalDetailScreen({super.key, required this.goalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final goalsAsync = ref.watch(goalsProvider);
    final historyAsync = ref.watch(goalContributionsProvider(goalId));

    // Explicit null-safe lookup — no `firstOrNull` (no `collection` dep in
    // lib/).
    final matches = goalsAsync.value?.where((g) => g.goal.id == goalId);
    final item = (matches == null || matches.isEmpty) ? null : matches.first;

    final currency = item?.progress.saved.currency ?? CurrencyRegistry.uzs;

    return Scaffold(
      backgroundColor: VeloraColors.blush,
      appBar: AppBar(
        title: Text(item?.goal.name ?? 'Maqsad'),
        backgroundColor: VeloraColors.blush,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: VeloraColors.inkberry,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          VeloraSpacing.lg,
          VeloraSpacing.lg,
          VeloraSpacing.lg,
          88,
        ),
        children: [
          if (item != null) ...[
            _ProgressHero(item: item),
            if (item.progress.projectedDate != null ||
                item.progress.requiredMonthly != null) ...[
              const SizedBox(height: VeloraSpacing.md),
              _ForecastCard(item: item),
            ],
            const SizedBox(height: VeloraSpacing.lg),
            Row(children: [
              Expanded(
                child: _CoralButton(
                  label: "Mablag' qo'shish",
                  onPressed: () =>
                      showGoalContributeSheet(context, ref, goalId: goalId),
                ),
              ),
              const SizedBox(width: VeloraSpacing.sm),
              Expanded(
                child: _TintButton(
                  label: 'Yechish',
                  onPressed: () => showGoalContributeSheet(context, ref,
                      goalId: goalId, withdraw: true),
                ),
              ),
            ]),
            const SizedBox(height: VeloraSpacing.lg),
            const GoalSectionHeader(
                title: 'Contribution tarixi', trailing: 'Hammasi'),
          ],
          historyAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Xatolik: $e'),
            data: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text("Hali hissalar yo'q",
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: VeloraColors.muted)),
                  )
                : Column(
                    children: [
                      for (final c in list)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: VeloraSpacing.sm),
                          child: _HistoryRow(
                            contribution: c,
                            currency: currency,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// The plum hero: a circular apricot percent ring beside the saved / target
/// figures — the mockup's "ring-wrap".
class _ProgressHero extends StatelessWidget {
  const _ProgressHero({required this.item});

  final GoalWithProgress item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = item.progress;
    final value = (p.percentBp / 10000).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(VeloraSpacing.lg),
      decoration: BoxDecoration(
        color: VeloraColors.plum,
        borderRadius: BorderRadius.circular(VeloraRadii.card),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.square(
                  dimension: 76,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 7,
                    backgroundColor: VeloraColors.onPlumTrack,
                    valueColor:
                        const AlwaysStoppedAnimation(VeloraColors.apricot),
                  ),
                ),
                Text(
                  '${(p.percentBp / 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: VeloraSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Jamg\'arilgan',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: Colors.white.withValues(alpha: 0.72)),
                ),
                const SizedBox(height: VeloraSpacing.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    p.saved.format(),
                    maxLines: 1,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: VeloraSpacing.xs),
                Text(
                  '${p.target.format()} dan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.white.withValues(alpha: 0.72)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The apricot forecast card: projected completion and required monthly.
class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.item});

  final GoalWithProgress item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = item.progress;
    return Container(
      padding: const EdgeInsets.all(VeloraSpacing.lg),
      decoration: BoxDecoration(
        color: VeloraColors.apricotTint,
        borderRadius: BorderRadius.circular(VeloraRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.projectedDate != null) ...[
            Text(
              'Taxminiy yetish sanasi',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: VeloraColors.muted),
            ),
            const SizedBox(height: VeloraSpacing.xs),
            Text(
              goalDateLabel(p.projectedDate),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
          if (p.requiredMonthly != null) ...[
            if (p.projectedDate != null)
              const SizedBox(height: VeloraSpacing.sm),
            Text(
              'Oyiga kerak: ${p.requiredMonthly!.format()}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: VeloraColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.contribution, required this.currency});

  final GoalContribution contribution;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = contribution;
    final isWithdraw = c.amountMinor < 0;
    final tone = isWithdraw ? VeloraColors.critical : VeloraColors.success;
    final money = Money(c.amountMinor, currency);
    final signed = isWithdraw ? money.format() : '+${money.format()}';
    return Container(
      key: const Key('contribution-row'),
      padding: const EdgeInsets.all(VeloraSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(VeloraRadii.card),
        border: Border.all(color: VeloraColors.line),
      ),
      child: Row(
        children: [
          GoalIconTile(
            size: 34,
            icon: isWithdraw ? Icons.remove : Icons.add,
            background: tone.withValues(alpha: 0.14),
            foreground: tone,
          ),
          const SizedBox(width: VeloraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_sourceLabel(c.source),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(_formatDate(c.occurredAt),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: VeloraColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: VeloraSpacing.sm),
          Flexible(
            child: Text(
              signed,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: tone, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  static String _sourceLabel(ContributionSource s) => switch (s) {
        ContributionSource.manual => "Qo'lda",
        ContributionSource.incomeAllocation => 'Kirimdan',
      };

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year}';
}

/// The single coral primary action.
class _CoralButton extends StatelessWidget {
  const _CoralButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: VeloraColors.coral,
          foregroundColor: Colors.white,
        ),
        child: Text(label,
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// The soft plum-tint secondary action.
class _TintButton extends StatelessWidget {
  const _TintButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: VeloraColors.plumTint,
          foregroundColor: VeloraColors.plum,
        ),
        child: Text(label,
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
