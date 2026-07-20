import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/budget/category_budget_engine.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../data/categories/category_model.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/category_icons.dart';
import '../../ui/components/velora_card.dart';
import '../../ui/components/velora_money_field.dart';
import '../allocation/allocation_template_screen.dart';
import 'budget_labels.dart';
import 'budgets_controller.dart';
import 'category_edit_sheet.dart';

/// Bottom scroll padding so the last budget row clears the global floating
/// "Chiqim" FAB the shell pins to the bottom-left.
const double _fabClearance = 88;

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = ref.watch(categoryBudgetsProvider);
    final settings = ref.watch(settingsProvider);
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
              settings.maybeWhen(
                orElse: () => const SizedBox.shrink(),
                data: (s) => Padding(
                  padding: const EdgeInsets.only(bottom: VeloraSpacing.md),
                  child: _VariableBudgetCard(
                    variableBudget: s.variableBudget,
                    safetyBuffer: s.safetyBuffer,
                    spent: _variableSpent(list, s.variableBudget.currency),
                    onSetBudget: controller.setVariableBudget,
                    onSetBuffer: controller.setSafetyBuffer,
                  ),
                ),
              ),
              for (final v in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: VeloraSpacing.md),
                  child: _CategoryBudgetCard(view: v, controller: controller),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sum of this period's spend across the o‘zgaruvchan (variable) categories,
  /// the figure the variable-budget total card measures itself against.
  Money _variableSpent(List<CategoryBudgetView> list, Currency currency) {
    var minor = 0;
    for (final v in list) {
      if (v.category.kind == CategoryKind.variable) {
        minor += v.monthSpent.minorUnits;
      }
    }
    return Money(minor, currency);
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
                'Kategoriya limitlari',
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

/// The monthly variable-budget "total" card from the mockup: the budget amount
/// with a coral progress bar and a spent/remaining legend, over the two
/// editable money fields (variable budget + safety buffer).
class _VariableBudgetCard extends StatelessWidget {
  const _VariableBudgetCard({
    required this.variableBudget,
    required this.safetyBuffer,
    required this.spent,
    required this.onSetBudget,
    required this.onSetBuffer,
  });

  final Money variableBudget;
  final Money safetyBuffer;
  final Money spent;
  final Future<void> Function(Money) onSetBudget;
  final Future<void> Function(Money) onSetBuffer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final budgetMinor = variableBudget.minorUnits;
    final remaining = Money(
      (budgetMinor - spent.minorUnits).clamp(0, budgetMinor),
      variableBudget.currency,
    );
    final fraction = budgetMinor <= 0
        ? null
        : (spent.minorUnits / budgetMinor).clamp(0.0, 1.0);

    return VeloraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'O‘ZGARUVCHAN BUDJET',
            style: theme.textTheme.labelSmall?.copyWith(
              color: VeloraColors.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: VeloraSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              variableBudget.format(),
              maxLines: 1,
              softWrap: false,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: VeloraColors.plum,
                fontWeight: FontWeight.w800,
              ),
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
                valueColor: const AlwaysStoppedAnimation(VeloraColors.coral),
              ),
            ),
            const SizedBox(height: VeloraSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${spent.format()} sarflandi',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: VeloraColors.muted),
                  ),
                ),
                const SizedBox(width: VeloraSpacing.sm),
                Flexible(
                  child: Text(
                    '${remaining.format()} qoldi',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: VeloraSpacing.xl),
          _BudgetMoneyField(
            label: 'Oylik o‘zgaruvchan budjet',
            value: variableBudget,
            onSubmit: onSetBudget,
          ),
          const SizedBox(height: VeloraSpacing.md),
          _BudgetMoneyField(
            label: 'Xavfsizlik buferi',
            value: safetyBuffer,
            onSubmit: onSetBuffer,
          ),
        ],
      ),
    );
  }
}

class _CategoryBudgetCard extends StatelessWidget {
  const _CategoryBudgetCard({required this.view, required this.controller});

  final CategoryBudgetView view;
  final BudgetsController controller;

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
          if (c.weeklyLimitMinor != null) ...[
            const SizedBox(height: VeloraSpacing.sm),
            _StatusLine(
              label: 'Haftalik',
              status: view.weekStatus,
              spent: view.weekSpent,
              limitMinor: c.weeklyLimitMinor,
            ),
          ],
          const SizedBox(height: VeloraSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: _KindChip(
              kind: c.kind,
              onToggle: () => controller.setKind(
                c.id,
                c.kind == CategoryKind.mandatory
                    ? CategoryKind.variable
                    : CategoryKind.mandatory,
              ),
            ),
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

/// A soft, tappable pill that flips a category between o‘zgaruvchan and
/// majburiy (kept from the previous screen's inline kind toggle).
class _KindChip extends StatelessWidget {
  const _KindChip({required this.kind, required this.onToggle});

  final CategoryKind kind;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: VeloraColors.plumTint,
      borderRadius: BorderRadius.circular(99),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: VeloraSpacing.md, vertical: VeloraSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.swap_horiz, size: 15, color: VeloraColors.plum),
              const SizedBox(width: VeloraSpacing.xs),
              Text(
                categoryKindLabel(kind),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: VeloraColors.plum,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetMoneyField extends StatefulWidget {
  final String label;
  final Money value;
  final Future<void> Function(Money) onSubmit;
  const _BudgetMoneyField(
      {required this.label, required this.value, required this.onSubmit});
  @override
  State<_BudgetMoneyField> createState() => _BudgetMoneyFieldState();
}

class _BudgetMoneyFieldState extends State<_BudgetMoneyField> {
  late final TextEditingController _ctrl = TextEditingController(
      text: widget.value.minorUnits == 0 ? '' : widget.value.formatNumber());
  Money? _pending;

  @override
  Widget build(BuildContext context) {
    // The descriptive label lives in its own free-wrapping Text, not the
    // field's internal floating label: a long label ("Oylik o'zgaruvchan
    // budjet") wrapped onto 2+ lines inside InputDecoration's floating-label
    // slot at 320px/200% text scale overlapped the entered amount, since
    // that slot reserves single-line height. `VeloraMoneyField` still gets
    // a short internal label for its own accessibility contract.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: VeloraSpacing.xs),
        Row(
          children: [
            Expanded(
              child: VeloraMoneyField(
                controller: _ctrl,
                currency: widget.value.currency,
                label: 'Summa',
                onChanged: (m) => _pending = m,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Saqlash',
              onPressed: () {
                final m =
                    _pending ?? Money.tryParse(_ctrl.text, widget.value.currency);
                if (m != null) widget.onSubmit(m);
              },
            ),
          ],
        ),
      ],
    );
  }
}
