import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../providers/app_providers.dart';
import 'goal_contribute_sheet.dart';

/// The goal detail screen: progress header, contribute/withdraw actions,
/// and the full contribution history for one goal.
class GoalDetailScreen extends ConsumerWidget {
  final int goalId;
  const GoalDetailScreen({super.key, required this.goalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);
    final historyAsync = ref.watch(goalContributionsProvider(goalId));

    // Explicit null-safe lookup — no `firstOrNull` (no `collection` dep in
    // lib/).
    final matches =
        goalsAsync.value?.where((g) => g.goal.id == goalId);
    final item = (matches == null || matches.isEmpty) ? null : matches.first;

    final currency = item?.progress.saved.currency ?? CurrencyRegistry.uzs;

    return Scaffold(
      appBar: AppBar(title: Text(item?.goal.name ?? 'Maqsad')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (item != null) ...[
            Text('${item.progress.saved.format()} / ${item.progress.target.format()}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            LinearProgressIndicator(
                value: (item.progress.percentBp / 10000).clamp(0.0, 1.0)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      showGoalContributeSheet(context, ref, goalId: goalId),
                  child: const Text("Hissa qo'shish"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => showGoalContributeSheet(context, ref,
                      goalId: goalId, withdraw: true),
                  child: const Text('Yechish'),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Text('Tarix', style: Theme.of(context).textTheme.titleSmall),
          ],
          historyAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Xatolik: $e'),
            data: (list) => list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text("Hali hissalar yo'q"),
                  )
                : Column(
                    children: list
                        .map((c) => ListTile(
                              key: const Key('contribution-row'),
                              leading: Icon(c.amountMinor < 0
                                  ? Icons.remove_circle_outline
                                  : Icons.add_circle_outline),
                              title: Text(
                                  Money(c.amountMinor, currency).format()),
                              subtitle: Text(
                                  '${c.source.name} · ${_formatDate(c.occurredAt)}'),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
