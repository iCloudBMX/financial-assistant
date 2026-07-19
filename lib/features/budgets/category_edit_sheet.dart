import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../data/categories/category_model.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/category_icons.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_sheet.dart';
import 'budget_labels.dart';
import 'budgets_controller.dart';

/// Opens the searchable category editor (§6.7). Pass [categoryId] to jump
/// straight to that category's edit form (the fast path from a budget row's
/// edit action); omit it to open the searchable list first, with a
/// "Yangi kategoriya" entry to create one.
Future<void> showCategoryEditSheet(BuildContext context, {int? categoryId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CategoryEditSheet(initialCategoryId: categoryId),
  );
}

class _CategoryEditSheet extends ConsumerStatefulWidget {
  const _CategoryEditSheet({this.initialCategoryId});
  final int? initialCategoryId;

  @override
  ConsumerState<_CategoryEditSheet> createState() =>
      _CategoryEditSheetState();
}

class _CategoryEditSheetState extends ConsumerState<_CategoryEditSheet> {
  late int? _editingId = widget.initialCategoryId;
  bool _creatingNew = false;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Direct edit (opened with a known [Category.id]) skips the list and
  /// has no "back" affordance to it — the caller already knows which
  /// category it wants.
  bool get _directEdit => widget.initialCategoryId != null;

  @override
  Widget build(BuildContext context) {
    if (_editingId != null || _creatingNew) {
      return _CategoryForm(
        categoryId: _editingId,
        showBack: !_directEdit,
        onBack: () => setState(() {
          _editingId = null;
          _creatingNew = false;
        }),
      );
    }
    return _CategoryList(
      query: _query,
      searchCtrl: _searchCtrl,
      onQueryChanged: (q) => setState(() => _query = q),
      onSelect: (id) => setState(() => _editingId = id),
      onCreateNew: () => setState(() => _creatingNew = true),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({
    required this.query,
    required this.searchCtrl,
    required this.onQueryChanged,
    required this.onSelect,
    required this.onCreateNew,
  });

  final String query;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreateNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(categoryBudgetsProvider);
    return VeloraSheetScaffold(
      title: 'Kategoriyalar',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SearchBar(
            key: const Key('category-edit-search'),
            controller: searchCtrl,
            hintText: 'Kategoriya qidirish',
            leading: const Icon(Icons.search),
            onChanged: onQueryChanged,
          ),
          const SizedBox(height: VeloraSpacing.md),
          budgets.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Text('Xatolik yuz berdi'),
            data: (views) {
              final q = query.trim().toLowerCase();
              final filtered = views
                  .where((v) =>
                      q.isEmpty || v.category.name.toLowerCase().contains(q))
                  .toList(growable: false);
              if (filtered.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: VeloraSpacing.lg),
                  child: Text('Kategoriya topilmadi'),
                );
              }
              return Column(
                children: [
                  for (final v in filtered)
                    Semantics(
                      key: Key('category-edit-option-${v.category.id}'),
                      button: true,
                      label: v.category.name,
                      onTap: () => onSelect(v.category.id),
                      child: ExcludeSemantics(
                        child: ListTile(
                          minTileHeight: 48,
                          leading: Icon(categoryIcon(v.category.icon)),
                          title: Text(v.category.name),
                          subtitle: Text(categoryKindLabel(v.category.kind)),
                          onTap: () => onSelect(v.category.id),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      primaryAction: VeloraPrimaryButton(
        key: const Key('category-edit-new'),
        label: 'Yangi kategoriya',
        onPressed: onCreateNew,
      ),
    );
  }
}

class _CategoryForm extends ConsumerStatefulWidget {
  const _CategoryForm({
    required this.categoryId,
    required this.showBack,
    required this.onBack,
  });

  final int? categoryId;
  final bool showBack;
  final VoidCallback onBack;

  @override
  ConsumerState<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends ConsumerState<_CategoryForm> {
  final _nameCtrl = TextEditingController();
  final _monthlyCtrl = TextEditingController();
  final _weeklyCtrl = TextEditingController();
  String _icon = 'category';
  CategoryKind _kind = CategoryKind.variable;
  bool _archived = false;
  bool _loaded = false;
  Currency _currency = CurrencyRegistry.uzs;

  @override
  void initState() {
    super.initState();
    if (widget.categoryId == null) {
      // New category: nothing to load.
      _loaded = true;
    } else {
      _load(widget.categoryId!);
    }
    _nameCtrl.addListener(() => setState(() {}));
  }

  Future<void> _load(int id) async {
    final views = await ref.read(categoryBudgetsProvider.future);
    final view = views.firstWhere((v) => v.category.id == id);
    final c = view.category;
    _currency = view.monthSpent.currency;
    _nameCtrl.text = c.name;
    _monthlyCtrl.text = c.monthlyLimitMinor == null
        ? ''
        : Money(c.monthlyLimitMinor!, _currency).formatNumber();
    _weeklyCtrl.text = c.weeklyLimitMinor == null
        ? ''
        : Money(c.weeklyLimitMinor!, _currency).formatNumber();
    _icon = c.icon;
    _kind = c.kind;
    _archived = c.archived;
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _monthlyCtrl.dispose();
    _weeklyCtrl.dispose();
    super.dispose();
  }

  bool get _canSave => _nameCtrl.text.trim().isNotEmpty;

  Future<void> _save() async {
    final controller = ref.read(budgetsControllerProvider);
    final name = _nameCtrl.text.trim();
    final int id;
    if (widget.categoryId != null) {
      id = widget.categoryId!;
      await controller.renameCategory(id, name);
      await controller.setCategoryIcon(id, _icon);
      await controller.setKind(id, _kind);
    } else {
      id = await controller.createCategory(name: name, icon: _icon);
      if (_kind != CategoryKind.variable) {
        await controller.setKind(id, _kind);
      }
    }
    await _applyLimit(
        _monthlyCtrl.text, (m) => controller.setMonthlyLimit(id, m));
    await _applyLimit(
        _weeklyCtrl.text, (m) => controller.setWeeklyLimit(id, m));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _applyLimit(
      String text, Future<void> Function(Money?) setter) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return setter(null);
    final m = Money.tryParse(trimmed, _currency);
    if (m == null) return Future.value(); // unparseable: keep as-is
    return setter(m);
  }

  Future<void> _toggleArchived() async {
    await ref
        .read(budgetsControllerProvider)
        .setCategoryArchived(widget.categoryId!, !_archived);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const SizedBox(
          height: 160, child: Center(child: CircularProgressIndicator()));
    }
    return VeloraSheetScaffold(
      title: widget.categoryId == null
          ? 'Yangi kategoriya'
          : 'Kategoriyani tahrirlash',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showBack)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Orqaga'),
              ),
            ),
          TextField(
            key: const Key('category-edit-name'),
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Nomi'),
          ),
          const SizedBox(height: VeloraSpacing.md),
          Text('Belgi', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: VeloraSpacing.xs),
          Wrap(
            spacing: VeloraSpacing.xs,
            runSpacing: VeloraSpacing.xs,
            children: [
              for (final key in kCategoryIconKeys)
                _IconChoice(
                  iconKey: key,
                  selected: key == _icon,
                  onTap: () => setState(() => _icon = key),
                ),
            ],
          ),
          const SizedBox(height: VeloraSpacing.md),
          Wrap(
            spacing: VeloraSpacing.sm,
            children: [
              for (final kind in CategoryKind.values)
                ChoiceChip(
                  label: Text(categoryKindLabel(kind)),
                  selected: _kind == kind,
                  onSelected: (_) => setState(() => _kind = kind),
                ),
            ],
          ),
          const SizedBox(height: VeloraSpacing.md),
          TextField(
            key: const Key('category-edit-monthly'),
            controller: _monthlyCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Oylik limit',
              helperText: 'Bo‘sh = limitsiz',
            ),
          ),
          const SizedBox(height: VeloraSpacing.md),
          TextField(
            key: const Key('category-edit-weekly'),
            controller: _weeklyCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Haftalik limit',
              helperText: 'Bo‘sh = limitsiz',
            ),
          ),
          if (widget.categoryId != null) ...[
            const SizedBox(height: VeloraSpacing.md),
            TextButton.icon(
              key: const Key('category-edit-archive'),
              onPressed: _toggleArchived,
              icon: Icon(_archived ? Icons.unarchive_outlined
                  : Icons.archive_outlined),
              label:
                  Text(_archived ? 'Arxivdan chiqarish' : 'Arxivlash'),
            ),
          ],
        ],
      ),
      primaryAction: VeloraPrimaryButton(
        key: const Key('category-edit-save'),
        label: 'Saqlash',
        onPressed: _canSave ? _save : null,
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice(
      {required this.iconKey, required this.selected, required this.onTap});
  final String iconKey;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      key: Key('category-edit-icon-$iconKey'),
      button: true,
      selected: selected,
      label: iconKey,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(VeloraRadii.control),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(VeloraRadii.control),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
              ),
            ),
            child: Icon(
              categoryIcon(iconKey),
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
