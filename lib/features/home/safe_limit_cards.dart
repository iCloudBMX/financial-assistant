import 'package:flutter/material.dart';
import '../../core/limit/safe_limit_engine.dart';
import '../../core/theme/velora_tokens.dart';
import '../../ui/components/velora_card.dart';

/// Today's safe-to-spend amount — the dominant decision card (§6.2 step 2).
///
/// The approved mockup makes this the one filled plum hero on Home: white
/// amount on Velora Plum, an apricot progress track showing how much of the
/// day's limit is left, and a plain-language note. A pure value widget: it
/// renders the already-resolved [limit] and [overspendCategories] that
/// `dashboardProvider` folded into `DashboardData`, per the "widgets consume
/// immutable values, not providers" boundary.
class SafeLimitCard extends StatelessWidget {
  const SafeLimitCard({
    super.key,
    required this.limit,
    this.overspendCategories = const [],
  });

  final SafeLimit limit;
  final List<String> overspendCategories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _statusFor(limit);
    // Fraction of today's limit still available (0..1). Over-limit clamps to
    // an empty track; a zero/negative per-day limit hides the track entirely.
    final perDay = limit.perDay.minorUnits;
    final remaining = limit.todayRemaining.minorUnits;
    final fraction =
        perDay <= 0 ? null : (remaining / perDay).clamp(0.0, 1.0);
    const onPlum = Colors.white;

    return Container(
      key: const Key('safe-limit-hero'),
      padding: const EdgeInsets.all(VeloraSpacing.lg),
      decoration: BoxDecoration(
        color: VeloraColors.plum,
        borderRadius: BorderRadius.circular(VeloraRadii.card),
        boxShadow: const [
          BoxShadow(
            color: Color(0x335B3A6E),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BUGUN BEMALOL',
            style: theme.textTheme.labelSmall?.copyWith(
              color: onPlum.withValues(alpha: 0.68),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: VeloraSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              limit.perDay.format(),
              maxLines: 1,
              softWrap: false,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: onPlum,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: VeloraSpacing.sm),
          Row(
            children: [
              Icon(status.icon,
                  size: 16, color: onPlum.withValues(alpha: 0.85)),
              const SizedBox(width: VeloraSpacing.xs),
              Expanded(
                child: Text(
                  'Bugun qoldi: ${limit.todayRemaining.format()} '
                  '· ${limit.daysLeft} kun qoldi',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: onPlum.withValues(alpha: 0.82)),
                ),
              ),
            ],
          ),
          if (fraction != null) ...[
            const SizedBox(height: VeloraSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 7,
                backgroundColor: VeloraColors.onPlumTrack,
                valueColor:
                    const AlwaysStoppedAnimation(VeloraColors.apricot),
              ),
            ),
          ],
          if (status == VeloraStatus.over && overspendCategories.isNotEmpty) ...[
            const SizedBox(height: VeloraSpacing.sm),
            Text(
              'Limitdan chiqqan: ${overspendCategories.join(', ')}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: VeloraColors.apricot),
            ),
          ],
        ],
      ),
    );
  }

  VeloraStatus _statusFor(SafeLimit limit) {
    if (limit.isOver) return VeloraStatus.over;
    if (limit.perDay.minorUnits > 0 &&
        limit.todayRemaining.minorUnits <= limit.perDay.minorUnits ~/ 5) {
      return VeloraStatus.near;
    }
    return VeloraStatus.safe;
  }
}

/// Weekly limit and monthly free-budget progress (§6.2 step 5). A pure value
/// widget over the resolved [weekly] and [monthly] safe-limit figures.
class WeeklySafeLimitCard extends StatelessWidget {
  const WeeklySafeLimitCard({
    super.key,
    required this.weekly,
    required this.monthly,
  });

  final WeeklySafeLimit weekly;
  final SafeLimit monthly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return VeloraCard(
      key: const Key('weekly-limit-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Haftalik xavfsiz limit', style: theme.textTheme.titleMedium),
          const SizedBox(height: VeloraSpacing.sm),
          Text('Limit: ${weekly.weeklyLimit.format()}'),
          Text('Sarflangan: ${weekly.weeklySpent.format()} '
              '· Qoldi: ${weekly.weeklyRemaining.format()}'),
          const Divider(height: VeloraSpacing.xl),
          Text('Oylik erkin byudjet', style: theme.textTheme.titleMedium),
          const SizedBox(height: VeloraSpacing.sm),
          Text('Qoldiq: ${monthly.spendable.format()}'),
        ],
      ),
    );
  }
}
