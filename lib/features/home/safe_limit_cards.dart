import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/budget/category_budget_engine.dart';
import '../../core/limit/safe_limit_engine.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/velora_async_state.dart';
import '../../ui/components/velora_card.dart';
import '../../ui/components/velora_status.dart';

/// The names of categories whose month spend is over their limit (§11.5),
/// used to explain which category caused an overspend.
List<String> overspendCategories(List<CategoryBudgetView> views) => views
    .where((v) => v.monthStatus == CategoryLimitStatus.over)
    .map((v) => v.category.name)
    .toList();

/// Today's safe-to-spend amount — the dominant decision card (§6.2 step 2).
class SafeLimitCard extends ConsumerWidget {
  const SafeLimitCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(safeLimitProvider);
    final budgets = ref.watch(categoryBudgetsProvider);
    final theme = Theme.of(context);

    return VeloraCard(
      key: const Key('safe-limit-hero'),
      child: async.when(
        loading: () =>
            const VeloraSkeleton(width: double.infinity, height: 96),
        error: (e, _) => VeloraErrorState(
          message: 'Xavfsiz limitni yuklab bo\'lmadi',
          onRetry: () => ref.invalidate(safeLimitProvider),
        ),
        data: (limit) {
          final status = _statusFor(limit);
          final offenders = budgets.maybeWhen(
            orElse: () => const <String>[],
            data: overspendCategories,
          );
          return Column(
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
              if (status == VeloraStatus.over && offenders.isNotEmpty) ...[
                const SizedBox(height: VeloraSpacing.xs),
                Text('Limitdan chiqqan: ${offenders.join(', ')}',
                    style: const TextStyle(color: VeloraColors.critical)),
              ],
            ],
          );
        },
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

/// Weekly limit and monthly free-budget progress (§6.2 step 5).
class WeeklySafeLimitCard extends ConsumerWidget {
  const WeeklySafeLimitCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weeklySafeLimitProvider);
    final monthly = ref.watch(safeLimitProvider);
    final theme = Theme.of(context);

    return VeloraCard(
      key: const Key('weekly-limit-card'),
      child: async.when(
        loading: () => const VeloraSkeleton(width: double.infinity, height: 72),
        error: (e, _) => VeloraErrorState(
          message: 'Haftalik limitni yuklab bo\'lmadi',
          onRetry: () => ref.invalidate(weeklySafeLimitProvider),
        ),
        data: (w) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Haftalik xavfsiz limit', style: theme.textTheme.titleMedium),
            const SizedBox(height: VeloraSpacing.sm),
            Text('Limit: ${w.weeklyLimit.format()}'),
            Text('Sarflangan: ${w.weeklySpent.format()} '
                '· Qoldi: ${w.weeklyRemaining.format()}'),
            const Divider(height: VeloraSpacing.xl),
            Text('Oylik erkin byudjet', style: theme.textTheme.titleMedium),
            const SizedBox(height: VeloraSpacing.sm),
            monthly.when(
              loading: () =>
                  const VeloraSkeleton(width: double.infinity, height: 20),
              error: (_, _) => const Text('—'),
              data: (limit) =>
                  Text("Qoldiq: ${limit.spendable.format()}"),
            ),
          ],
        ),
      ),
    );
  }
}
