import 'package:flutter/material.dart';

import '../../core/theme/velora_tokens.dart';
import '../../data/categories/category_model.dart';

/// A controlled hybrid category selector: four fast choices plus a searchable
/// full list. Selection is always reported to [onSelected].
class CategoryPicker extends StatelessWidget {
  const CategoryPicker({
    super.key,
    required this.categories,
    required this.quickIds,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Category> categories;
  final List<int> quickIds;
  final int? selectedId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final activeCategories = categories
        .where((category) => !category.archived)
        .toList(growable: false);
    final quickCategories = _resolveQuickCategories(activeCategories, quickIds);

    return Padding(
      padding: const EdgeInsets.all(VeloraSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - VeloraSpacing.sm) / 2;
              return Wrap(
                spacing: VeloraSpacing.sm,
                runSpacing: VeloraSpacing.sm,
                children: [
                  for (final category in quickCategories)
                    SizedBox(
                      width: itemWidth,
                      child: _CategoryOption(
                        optionKey: const Key('quick-category'),
                        semanticsKey: Key(
                          'quick-category-option-${category.id}',
                        ),
                        category: category,
                        selected: category.id == selectedId,
                        onTap: () => onSelected(category.id),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: VeloraSpacing.md),
          OutlinedButton.icon(
            key: const Key('category-picker-open'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VeloraRadii.control),
              ),
            ),
            onPressed: activeCategories.isEmpty
                ? null
                : () => _openCategorySheet(context, activeCategories),
            icon: const Icon(Icons.search),
            label: const Text('Kategoriya tanlash'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCategorySheet(
    BuildContext context,
    List<Category> activeCategories,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => FractionallySizedBox(
      key: const Key('category-sheet'),
      heightFactor: 0.85,
      child: _CategorySheet(
        categories: activeCategories,
        selectedId: selectedId,
        onSelected: (id) {
          onSelected(id);
          Navigator.of(sheetContext).pop();
        },
      ),
    ),
  );
}

List<Category> _resolveQuickCategories(
  List<Category> activeCategories,
  List<int> quickIds,
) {
  final byId = {for (final category in activeCategories) category.id: category};
  final resolved = <Category>[];
  final seen = <int>{};

  for (final id in quickIds) {
    final category = byId[id];
    if (category != null && seen.add(id)) resolved.add(category);
    if (resolved.length == 4) return resolved;
  }
  for (final category in activeCategories) {
    if (seen.add(category.id)) resolved.add(category);
    if (resolved.length == 4) break;
  }
  return resolved;
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.optionKey,
    required this.semanticsKey,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Key optionKey;
  final Key semanticsKey;
  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(VeloraRadii.control);
    return Semantics(
      key: semanticsKey,
      button: true,
      selected: selected,
      label: category.name,
      onTap: onTap,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          key: optionKey,
          constraints: const BoxConstraints(minHeight: 64),
          child: Material(
            color: selected
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: borderRadius,
              side: BorderSide(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              borderRadius: borderRadius,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: VeloraSpacing.md,
                  vertical: VeloraSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      _categoryIcon(category.icon),
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: VeloraSpacing.sm),
                    Expanded(
                      child: Text(
                        category.name,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Category> categories;
  final int? selectedId;
  final ValueChanged<int> onSelected;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = widget.categories
        .where(
          (category) =>
              query.isEmpty || category.name.toLowerCase().contains(query),
        )
        .toList(growable: false);
    final mandatory = filtered
        .where((category) => category.kind == CategoryKind.mandatory)
        .toList(growable: false);
    final variable = filtered
        .where((category) => category.kind == CategoryKind.variable)
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VeloraSpacing.lg,
        0,
        VeloraSpacing.lg,
        VeloraSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Kategoriya tanlash',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: VeloraSpacing.md),
          SearchBar(
            hintText: 'Kategoriya qidirish',
            leading: const Icon(Icons.search),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: VeloraSpacing.md),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('Kategoriya topilmadi'))
                : ListView(
                    children: [
                      if (mandatory.isNotEmpty) ...[
                        const _CategoryGroupHeader(label: 'Majburiy'),
                        for (final category in mandatory)
                          _SheetCategoryOption(
                            category: category,
                            selected: category.id == widget.selectedId,
                            onTap: () => widget.onSelected(category.id),
                          ),
                      ],
                      if (variable.isNotEmpty) ...[
                        const _CategoryGroupHeader(label: 'O‘zgaruvchan'),
                        for (final category in variable)
                          _SheetCategoryOption(
                            category: category,
                            selected: category.id == widget.selectedId,
                            onTap: () => widget.onSelected(category.id),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGroupHeader extends StatelessWidget {
  const _CategoryGroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(
      top: VeloraSpacing.md,
      bottom: VeloraSpacing.xs,
    ),
    child: Text(label, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _SheetCategoryOption extends StatelessWidget {
  const _SheetCategoryOption({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    key: Key('category-option-${category.id}'),
    button: true,
    selected: selected,
    label: category.name,
    onTap: onTap,
    child: ExcludeSemantics(
      child: ListTile(
        minTileHeight: 48,
        leading: Icon(_categoryIcon(category.icon)),
        title: Text(category.name),
        trailing: selected ? const Icon(Icons.check) : null,
        onTap: onTap,
      ),
    ),
  );
}

IconData _categoryIcon(String icon) => switch (icon) {
  'restaurant' => Icons.restaurant_outlined,
  'directions_car' => Icons.directions_car_outlined,
  'home' => Icons.home_outlined,
  'bolt' => Icons.bolt_outlined,
  'favorite' => Icons.favorite_outline,
  'school' => Icons.school_outlined,
  'checkroom' => Icons.checkroom_outlined,
  'movie' => Icons.movie_outlined,
  'fastfood' => Icons.fastfood_outlined,
  'subscriptions' => Icons.subscriptions_outlined,
  'card_giftcard' => Icons.card_giftcard_outlined,
  'flight' => Icons.flight_outlined,
  _ => Icons.category_outlined,
};
