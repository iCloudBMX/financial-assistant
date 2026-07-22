import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/category_icons.dart';
import 'categories_controller.dart';
import 'category_edit_sheet.dart';

/// Category manager reached from Settings ▸ Kategoriyalar. A reorderable list
/// of active categories (tap to edit, remove to archive), an archived/restore
/// section, and a "Yangi" entry. Budget limits were removed — this manages
/// only name, icon, archive state, and order.
class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final controller = ref.read(categoriesControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kategoriyalar')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('category-add'),
        onPressed: () => showCategoryEditSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Yangi'),
      ),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Xatolik yuz berdi')),
        data: (cats) {
          final active = [for (final c in cats) if (!c.archived) c];
          final archived = [for (final c in cats) if (c.archived) c];
          return ListView(
            padding: const EdgeInsets.all(VeloraSpacing.lg),
            children: [
              ReorderableListView(
                key: const Key('category-reorder-list'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorderItem: (oldIndex, newIndex) {
                  final ids = [for (final c in active) c.id];
                  final moved = ids.removeAt(oldIndex);
                  ids.insert(newIndex, moved);
                  controller.reorderCategories(ids);
                },
                children: [
                  for (final c in active)
                    ListTile(
                      key: ValueKey(c.id),
                      leading: Icon(categoryIcon(c.icon)),
                      title: Text(c.name),
                      onTap: () =>
                          showCategoryEditSheet(context, categoryId: c.id),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: Key('category-archive-${c.id}'),
                            icon: const Icon(Icons.remove_circle_outline,
                                color: VeloraColors.critical),
                            tooltip: 'Olib tashlash',
                            onPressed: () =>
                                controller.setCategoryArchived(c.id, true),
                          ),
                          const Icon(Icons.drag_handle),
                        ],
                      ),
                    ),
                ],
              ),
              if (archived.isNotEmpty) ...[
                const SizedBox(height: VeloraSpacing.lg),
                Text(
                  'Olib tashlangan',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: VeloraColors.muted,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: VeloraSpacing.sm),
                for (final c in archived)
                  ListTile(
                    key: Key('category-restore-${c.id}'),
                    leading: Icon(categoryIcon(c.icon)),
                    title: Text(c.name),
                    trailing: TextButton(
                      onPressed: () =>
                          controller.setCategoryArchived(c.id, false),
                      child: const Text('Tiklash'),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
