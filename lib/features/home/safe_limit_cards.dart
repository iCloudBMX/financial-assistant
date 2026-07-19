import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/budget/category_budget_engine.dart';
import '../../providers/app_providers.dart';

/// The names of categories whose month spend is over their limit (§11.5),
/// used to explain which category caused an overspend.
List<String> overspendCategories(List<CategoryBudgetView> views) => views
    .where((v) => v.monthStatus == CategoryLimitStatus.over)
    .map((v) => v.category.name)
    .toList();

class SafeLimitCard extends ConsumerWidget {
  const SafeLimitCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(safeLimitProvider);
    final budgets = ref.watch(categoryBudgetsProvider);
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: async.when(
          loading: () => const SizedBox(
              height: 48, child: Center(child: CircularProgressIndicator())),
          error: (_, _) => const Text('Xatolik yuz berdi'),
          data: (limit) {
            final over = limit.isOver;
            final offenders = budgets.maybeWhen(
              orElse: () => const <String>[],
              data: overspendCategories,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(over ? Icons.error_outline : Icons.savings_outlined,
                        color: over ? cs.error : cs.primary),
                    const SizedBox(width: 8),
                    Text('Bugungi xavfsiz limit',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  limit.perDay.format(),
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(color: over ? cs.error : null),
                ),
                const SizedBox(height: 4),
                Text('Bugun qoldi: ${limit.todayRemaining.format()} '
                    '· ${limit.daysLeft} kun qoldi'),
                if (over && offenders.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Limitdan chiqqan: ${offenders.join(', ')}',
                      style: TextStyle(color: cs.error)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class WeeklySafeLimitCard extends ConsumerWidget {
  const WeeklySafeLimitCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weeklySafeLimitProvider);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: async.when(
          loading: () => const SizedBox(
              height: 40, child: Center(child: CircularProgressIndicator())),
          error: (_, _) => const Text('Xatolik yuz berdi'),
          data: (w) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Haftalik xavfsiz limit',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Limit: ${w.weeklyLimit.format()}'),
              Text('Sarflangan: ${w.weeklySpent.format()} '
                  '· Qoldi: ${w.weeklyRemaining.format()}'),
            ],
          ),
        ),
      ),
    );
  }
}
