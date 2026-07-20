import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/allocation/allocation_models.dart';
import '../../core/allocation/allocation_result_labels.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/app_snackbar.dart';
import '../../ui/components/velora_card.dart';

/// Allocation template editor (§8.3): reorder the template's directions and
/// save the new priority order. Row add/edit/delete is deliberately deferred
/// to a follow-up task — this screen covers reorder + save only.
class AllocationTemplateScreen extends ConsumerStatefulWidget {
  const AllocationTemplateScreen({super.key});
  @override
  ConsumerState<AllocationTemplateScreen> createState() =>
      _AllocationTemplateScreenState();
}

class _AllocationTemplateScreenState
    extends ConsumerState<AllocationTemplateScreen> {
  List<AllocationDirection>? _dirs;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(allocationTemplateProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Taqsimlash rejasi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Saqlash',
            onPressed: _dirs == null
                ? null
                : () async {
                    await ref
                        .read(allocationRepositoryProvider)
                        .saveTemplate(_dirs!);
                    ref
                        .read(ledgerRevisionProvider.notifier)
                        .update((n) => n + 1);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showAutoDismissSnackBar(
                        const SnackBar(content: Text('Reja saqlandi')),
                      );
                    }
                  },
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Xatolik yuz berdi')),
        data: (template) {
          final dirs = _dirs ??= List.of(template.directions);
          return ReorderableListView(
            padding: const EdgeInsets.symmetric(
              horizontal: VeloraSpacing.lg,
              vertical: VeloraSpacing.md,
            ),
            buildDefaultDragHandles: false,
            onReorderItem: (oldI, newI) => setState(() {
              final item = dirs.removeAt(oldI);
              dirs.insert(newI, item);
            }),
            children: [
              for (var i = 0; i < dirs.length; i++)
                _RuleCard(
                  // Stable per-bucket key so drag-driven rebuilds diff
                  // correctly (an index-based key would change identity on
                  // every reorder).
                  key: ValueKey(dirs[i].bucketKey),
                  index: i,
                  priority: i + 1,
                  direction: dirs[i],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required super.key,
    required this.index,
    required this.priority,
    required this.direction,
  });

  final int index;
  final int priority;
  final AllocationDirection direction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeLabel = allocationMethodLabel(direction.method);
    final valueLabel = _valueLabel(direction);

    return Padding(
      padding: const EdgeInsets.only(bottom: VeloraSpacing.sm),
      child: VeloraCard(
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: VeloraColors.plumTint,
                borderRadius: BorderRadius.circular(VeloraRadii.control),
              ),
              child: Text('$priority',
                  style: theme.textTheme.labelLarge?.copyWith(
                      color: VeloraColors.plum, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: VeloraSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bucketLabel(direction.bucketKey),
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: VeloraSpacing.xs),
                  Wrap(
                    spacing: VeloraSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // The rule TYPE (fixed / percentage / goal /
                      // remaining) as its own tag, distinct from the
                      // direction's specific value below.
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: VeloraSpacing.sm, vertical: 2),
                        decoration: BoxDecoration(
                          color: VeloraColors.plumTint,
                          borderRadius:
                              BorderRadius.circular(VeloraRadii.control),
                        ),
                        child: Text(typeLabel,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: VeloraColors.plum)),
                      ),
                      if (valueLabel != null)
                        Text(valueLabel,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: VeloraColors.coral,
                                fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
            ReorderableDragStartListener(
              index: index,
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Icon(Icons.drag_handle,
                      semanticLabel: 'Tartibni o‘zgartirish'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The specific value for a rule that has one — fixed amount or percent.
  /// `remaining`/`goalBased` carry no distinct value beyond their type
  /// label, so this returns null and the card shows the type label alone.
  String? _valueLabel(AllocationDirection d) => switch (d.method) {
        AllocationMethod.fixedAmount => d.amount?.format(),
        AllocationMethod.percentage => '${(d.percentBp ?? 0) / 100}%',
        AllocationMethod.remaining => null,
        AllocationMethod.goalBased => null,
      };
}
