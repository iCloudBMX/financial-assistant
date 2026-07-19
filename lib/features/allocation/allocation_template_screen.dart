import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/allocation/allocation_models.dart';
import '../../core/allocation/allocation_result_labels.dart';
import '../../providers/app_providers.dart';

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
                      ScaffoldMessenger.of(context).showSnackBar(
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
            onReorderItem: (oldI, newI) => setState(() {
              final item = dirs.removeAt(oldI);
              dirs.insert(newI, item);
            }),
            children: [
              for (var i = 0; i < dirs.length; i++)
                ListTile(
                  key: ValueKey('${dirs[i].bucketKey}-$i'),
                  title: Text(bucketLabel(dirs[i].bucketKey)),
                  subtitle: Text(_methodLabel(dirs[i])),
                  trailing: const Icon(Icons.drag_handle),
                ),
            ],
          );
        },
      ),
    );
  }

  String _methodLabel(AllocationDirection d) => switch (d.method) {
        AllocationMethod.fixedAmount =>
          'Belgilangan: ${d.amount?.format() ?? '-'}',
        AllocationMethod.percentage =>
          'Foiz: ${(d.percentBp ?? 0) / 100}%',
        AllocationMethod.remaining => 'Qolgan summa',
        AllocationMethod.goalBased => 'Maqsad asosida',
      };
}
