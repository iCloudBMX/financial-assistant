import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/budget/category_budget_engine.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../data/categories/category_model.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/category_icons.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_card.dart';
import '../../ui/components/velora_sheet.dart';
import '../allocation/allocation_template_screen.dart';
import 'budget_labels.dart';
import 'budgets_controller.dart';
import 'category_edit_sheet.dart';

/// Bottom scroll padding so the last budget row clears the global floating
/// "Chiqim" FAB the shell pins to the bottom-left.
const double _fabClearance = 88;

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  bool _manage = false;

  @override
  Widget build(BuildContext context) {
    final views = ref.watch(categoryBudgetsProvider);
    final controller = ref.read(budgetsControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: views.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text('Xatolik yuz berdi')),
          data: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(
              VeloraSpacing.lg,
              VeloraSpacing.lg,
              VeloraSpacing.lg,
              VeloraSpacing.lg + _fabClearance,
            ),
            children: [
              _PlanHeader(
                onOpenCategories: () => showCategoryEditSheet(context),
                onOpenAllocation: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const AllocationTemplateScreen()),
                ),
              ),
              const SizedBox(height: VeloraSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Text('Rejalar',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  TextButton.icon(
                    key: const Key('budgets-manage'),
                    onPressed: () => setState(() => _manage = !_manage),
                    icon: const Icon(Icons.tune, size: 18),
                    label: Text(_manage ? 'Tayyor' : 'Boshqarish'),
                  ),
                ],
              ),
              const SizedBox(height: VeloraSpacing.sm),
              if (_manage) ...[
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  onReorder: (oldIndex, newIndex) {
                    final ids = [for (final v in list) v.category.id];
                    if (newIndex > oldIndex) newIndex -= 1;
                    final moved = ids.removeAt(oldIndex);
                    ids.insert(newIndex, moved);
                    controller.reorderCategories(ids);
                  },
                  children: [for (final v in list) _manageRow(v, controller)],
                ),
                const SizedBox(height: VeloraSpacing.sm),
                ListTile(
                  key: const Key('budgets-add-category'),
                  leading: const Icon(Icons.add_circle_outline,
                      color: VeloraColors.plum),
                  title: const Text('Yangi kategoriya'),
                  onTap: () => showCategoryEditSheet(context),
                ),
                ListTile(
                  key: const Key('budgets-removed-entry'),
                  leading: const Icon(Icons.inventory_2_outlined,
                      color: VeloraColors.muted),
                  title: const Text('Olib tashlangan'),
                  onTap: () => showRemovedCategoriesSheet(context),
                ),
              ] else
                for (final v in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: VeloraSpacing.md),
                    child: _CategoryBudgetCard(view: v),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  /// A manage-mode row: drag handle + remove(=archive) button, no detail
  /// content (mirrors the mockup's compact reorder list).
  Widget _manageRow(CategoryBudgetView v, BudgetsController controller) {
    return ListTile(
      key: ValueKey(v.category.id),
      leading: IconButton(
        key: Key('budgets-remove-${v.category.id}'),
        icon: const Icon(Icons.remove_circle_outline,
            color: VeloraColors.critical),
        tooltip: 'Olib tashlash',
        onPressed: () => controller.setCategoryArchived(v.category.id, true),
      ),
      title: Text(v.category.name),
      trailing: const Icon(Icons.drag_handle),
    );
  }

}

/// Opens the "Olib tashlangan" (removed) sheet: archived categories with a
/// restore action each, reached from the manage-mode entry row.
Future<void> showRemovedCategoriesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _RemovedCategoriesSheet(),
  );
}

class _RemovedCategoriesSheet extends ConsumerWidget {
  const _RemovedCategoriesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archived = ref.watch(archivedCategoriesProvider);
    return VeloraSheetScaffold(
      title: 'Olib tashlangan',
      body: archived.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Text('Xatolik yuz berdi'),
        data: (cats) {
          if (cats.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: VeloraSpacing.lg),
              child: Text('Olib tashlangan kategoriyalar yo‘q'),
            );
          }
          return Column(
            children: [
              for (final c in cats)
                ListTile(
                  key: Key('budgets-restore-${c.id}'),
                  leading: Icon(categoryIcon(c.icon)),
                  title: Text(c.name),
                  trailing: TextButton(
                    onPressed: () => ref
                        .read(budgetsControllerProvider)
                        .setCategoryArchived(c.id, false),
                    child: const Text('Tiklash'),
                  ),
                ),
            ],
          );
        },
      ),
      primaryAction: VeloraPrimaryButton(
        key: const Key('budgets-removed-close'),
        label: 'Yopish',
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }
}

/// The warm plan header: a screen title with the two entry points from the
/// mockup — the searchable category editor and the allocation template — as
/// bordered icon tiles (mirroring Home's header buttons).
class _PlanHeader extends StatelessWidget {
  const _PlanHeader({
    required this.onOpenCategories,
    required this.onOpenAllocation,
  });

  final VoidCallback onOpenCategories;
  final VoidCallback onOpenAllocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Budjet',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: VeloraSpacing.xs),
              Text(
                'Kategoriya rejalari',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: VeloraColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: VeloraSpacing.sm),
        _HeaderIconButton(
          icon: Icons.category_outlined,
          tooltip: 'Kategoriyalar',
          onPressed: onOpenCategories,
        ),
        const SizedBox(width: VeloraSpacing.sm),
        _HeaderIconButton(
          icon: Icons.tune,
          tooltip: 'Taqsimlash rejasi',
          onPressed: onOpenAllocation,
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VeloraRadii.control),
        side: const BorderSide(color: VeloraColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: Icon(icon, size: 20, color: VeloraColors.plum),
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      ),
    );
  }
}

class _CategoryBudgetCard extends StatelessWidget {
  const _CategoryBudgetCard({required this.view});

  final CategoryBudgetView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = view.category;

    return VeloraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: VeloraColors.plumTint,
                  borderRadius: BorderRadius.circular(VeloraRadii.control),
                ),
                child: Icon(categoryIcon(c.icon),
                    color: VeloraColors.plum, size: 20),
              ),
              const SizedBox(width: VeloraSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.monthSpentSubtitle(view.monthSpent),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: VeloraColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: VeloraSpacing.sm),
              _PercentBadge(
                status: view.monthStatus,
                spent: view.monthSpent,
                limitMinor: c.monthlyLimitMinor,
              ),
              IconButton(
                tooltip: 'Limitni tahrirlash',
                icon: const Icon(Icons.edit_outlined),
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    showCategoryEditSheet(context, categoryId: c.id),
              ),
            ],
          ),
          const SizedBox(height: VeloraSpacing.sm),
          _StatusLine(
            label: 'Oylik',
            status: view.monthStatus,
            spent: view.monthSpent,
            limitMinor: c.monthlyLimitMinor,
          ),
        ],
      ),
    );
  }
}

extension on Category {
  /// The row subtitle: "spent / limit" when a monthly limit exists, otherwise
  /// the mockup's limitless phrasing.
  String monthSpentSubtitle(Money spent) {
    final limit = monthlyLimitMinor;
    if (limit == null) return 'Limitsiz · ${spent.format()} sarflandi';
    return '${spent.formatNumber()} / '
        '${Money(limit, spent.currency).formatNumber()}';
  }
}

/// The colored percentage on the right of a budget row (or an em dash for a
/// limitless category), matching the mockup's `budget-status`.
class _PercentBadge extends StatelessWidget {
  const _PercentBadge({
    required this.status,
    required this.spent,
    required this.limitMinor,
  });

  final CategoryLimitStatus status;
  final Money spent;
  final int? limitMinor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final velora = budgetVeloraStatus(status);
    final color = velora?.color ?? VeloraColors.muted;
    final limit = limitMinor;
    final text = (limit == null || limit == 0)
        ? '—'
        : '${(spent.minorUnits * 100 / limit).round()}%';
    return Text(
      text,
      style: theme.textTheme.labelLarge
          ?.copyWith(color: color, fontWeight: FontWeight.w800),
    );
  }
}

/// A progress bar + status line under a budget row. Keeps the design-spec
/// contract that safe/near/over each read as color + icon + text (red only for
/// over); a limitless period shows a neutral tone with no bar.
class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.label,
    required this.status,
    required this.spent,
    required this.limitMinor,
  });

  final String label;
  final CategoryLimitStatus status;
  final Money spent;
  final int? limitMinor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final velora = budgetVeloraStatus(status);
    final color = velora?.color ?? VeloraColors.muted;
    final icon = budgetStatusIcon(status);
    final limit = limitMinor;
    final fraction = (limit == null || limit == 0)
        ? null
        : (spent.minorUnits / limit).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (fraction != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: VeloraColors.line,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: VeloraSpacing.xs),
        ],
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: VeloraSpacing.xs),
            Expanded(
              child: Text(
                '$label: ${budgetStatusLabel(status)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

