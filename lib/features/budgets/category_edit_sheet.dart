import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/result/failure_messages.dart';
import '../../core/theme/velora_tokens.dart';
import '../../data/categories/category_model.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/app_snackbar.dart';
import '../../ui/components/category_icons.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_money_field.dart';
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

  /// The loaded category's live budget standing, used to render the mockup's
  /// "Joriy holat" summary above the form. Null for a brand-new category.
  CategoryBudgetView? _view;

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
    _view = view;
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
    final monthly = _parseLimit(_monthlyCtrl.text);
    final weekly = _parseLimit(_weeklyCtrl.text);
    final messenger = ScaffoldMessenger.of(context);

    final result = await controller.saveCategory(
      id: widget.categoryId,
      name: name,
      icon: _icon,
      kind: _kind,
      monthlyLimit: monthly.value,
      monthlyLimitUnparseable: monthly.unparseable,
      weeklyLimit: weekly.value,
      weeklyLimitUnparseable: weekly.unparseable,
    );
    if (!mounted) return;
    result.when(
      ok: (_) => Navigator.of(context).pop(),
      err: (f) =>
          messenger.showAutoDismissSnackBar(SnackBar(content: Text(userMessageFor(f)))),
    );
  }

  /// Mirrors the old `_applyLimit`'s three-way parse rule: empty text means
  /// "clear the limit" (`value: null, unparseable: false`); unparseable text
  /// means "leave this field untouched" (`unparseable: true`, so
  /// `saveCategory` skips the write instead of clearing it); otherwise the
  /// parsed [Money].
  ({Money? value, bool unparseable}) _parseLimit(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return (value: null, unparseable: false);
    final m = Money.tryParse(trimmed, _currency);
    if (m == null) return (value: null, unparseable: true);
    return (value: m, unparseable: false);
  }

  Future<void> _toggleArchived() async {
    await ref
        .read(budgetsControllerProvider)
        .setCategoryArchived(widget.categoryId!, !_archived);
    if (mounted) Navigator.of(context).pop();
  }

  /// A monthly/weekly limit money input. The descriptive label ("Oylik
  /// limit") and the "empty = no limit" hint sit ABOVE the field as free-
  /// wrapping captions; the `VeloraMoneyField`'s own internal label is a
  /// short constant ("Summa") so a long label never wraps into the field's
  /// single-line floating-label slot and overlaps the amount at 320px/200%
  /// (the same overlap fix applied to the variable-budget field).
  Widget _limitField(
    BuildContext context, {
    required Key fieldKey,
    required TextEditingController controller,
    required String label,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        Text('Bo‘sh = limitsiz',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: VeloraSpacing.xs),
        VeloraMoneyField(
          key: fieldKey,
          controller: controller,
          currency: _currency,
          label: 'Summa',
        ),
      ],
    );
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
          if (_view != null) ...[
            _CurrentStatusCard(view: _view!),
            const SizedBox(height: VeloraSpacing.md),
          ],
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
          Text('Turi', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: VeloraSpacing.xs),
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
          _limitField(
            context,
            fieldKey: const Key('category-edit-monthly'),
            controller: _monthlyCtrl,
            label: 'Oylik limit',
          ),
          const SizedBox(height: VeloraSpacing.md),
          _limitField(
            context,
            fieldKey: const Key('category-edit-weekly'),
            controller: _weeklyCtrl,
            label: 'Haftalik limit',
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

/// The mockup's "Joriy holat" summary: the category's period spend with a
/// status-colored progress bar and a color + icon + text status line (the
/// design spec's safe/near/over contract; a limitless category shows a neutral
/// tone with no bar).
class _CurrentStatusCard extends StatelessWidget {
  const _CurrentStatusCard({required this.view});

  final CategoryBudgetView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = view.monthStatus;
    final velora = budgetVeloraStatus(status);
    final color = velora?.color ?? VeloraColors.muted;
    final limit = view.category.monthlyLimitMinor;
    final spent = view.monthSpent;
    final fraction = (limit == null || limit == 0)
        ? null
        : (spent.minorUnits / limit).clamp(0.0, 1.0);
    final headline = limit == null
        ? '${spent.format()} sarflandi'
        : '${spent.format()} / ${Money(limit, spent.currency).format()}';

    return Container(
      padding: const EdgeInsets.all(VeloraSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(VeloraRadii.card),
        border: Border.all(color: VeloraColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'JORIY HOLAT',
            style: theme.textTheme.labelSmall?.copyWith(
              color: VeloraColors.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: VeloraSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              headline,
              maxLines: 1,
              softWrap: false,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (fraction != null) ...[
            const SizedBox(height: VeloraSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 7,
                backgroundColor: VeloraColors.line,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
          const SizedBox(height: VeloraSpacing.sm),
          Row(
            children: [
              Icon(budgetStatusIcon(status), size: 16, color: color),
              const SizedBox(width: VeloraSpacing.xs),
              Expanded(
                child: Text(
                  budgetStatusLabel(status),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ],
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
