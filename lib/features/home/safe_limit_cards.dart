import 'package:flutter/material.dart';
import '../../core/limit/safe_limit_engine.dart';
import '../../core/theme/velora_tokens.dart';
import '../../ui/components/velora_card.dart';
import '../../ui/components/velora_status.dart';

/// Today's safe-to-spend amount — the dominant decision card (§6.2 step 2).
///
/// A pure value widget: it renders the already-resolved [limit] and
/// [overspendCategories] that `dashboardProvider` folded into
/// `DashboardData`, per the "widgets consume immutable values, not
/// providers" boundary.
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
    return VeloraCard(
      key: const Key('safe-limit-hero'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bugungi xavfsiz limit', style: theme.textTheme.bodyMedium),
          const SizedBox(height: VeloraSpacing.xs),
          Text(
            limit.perDay.format(),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: status == VeloraStatus.over ? status.color : null,
            ),
          ),
          const SizedBox(height: VeloraSpacing.sm),
          VeloraStatusBadge(
            color: status.color,
            icon: status.icon,
            label: 'Bugun qoldi: ${limit.todayRemaining.format()} '
                '· ${limit.daysLeft} kun qoldi',
          ),
          if (status == VeloraStatus.over && overspendCategories.isNotEmpty) ...[
            const SizedBox(height: VeloraSpacing.xs),
            Text('Limitdan chiqqan: ${overspendCategories.join(', ')}',
                style: TextStyle(color: status.color)),
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
