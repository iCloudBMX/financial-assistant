import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/budget/category_budget_engine.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../data/categories/category_model.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/category_icons.dart';
import '../../ui/components/velora_card.dart';
import '../../ui/components/velora_money_field.dart';
import '../../ui/components/velora_status.dart';
import '../allocation/allocation_template_screen.dart';
import 'budget_labels.dart';
import 'budgets_controller.dart';
import 'category_edit_sheet.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = ref.watch(categoryBudgetsProvider);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(budgetsControllerProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budjet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Kategoriyalar',
            onPressed: () => showCategoryEditSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Taqsimlash rejasi',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const AllocationTemplateScreen()),
            ),
          ),
        ],
      ),
      body: views.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Xatolik yuz berdi')),
        data: (list) => ListView(
          padding: const EdgeInsets.all(VeloraSpacing.md),
          children: [
            settings.maybeWhen(
              orElse: () => const SizedBox.shrink(),
              data: (s) => Padding(
                padding: const EdgeInsets.only(bottom: VeloraSpacing.sm),
                child: VeloraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('O‘zgaruvchan budjet',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: VeloraSpacing.md),
                      _BudgetMoneyField(
                        label: 'Oylik o‘zgaruvchan budjet',
                        value: s.variableBudget,
                        onSubmit: controller.setVariableBudget,
                      ),
                      const SizedBox(height: VeloraSpacing.md),
                      _BudgetMoneyField(
                        label: 'Xavfsizlik buferi',
                        value: s.safetyBuffer,
                        onSubmit: controller.setSafetyBuffer,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            for (final v in list)
              Padding(
                padding: const EdgeInsets.only(bottom: VeloraSpacing.sm),
                child: _CategoryBudgetCard(view: v, controller: controller, cs: cs),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBudgetCard extends StatelessWidget {
  const _CategoryBudgetCard(
      {required this.view, required this.controller, required this.cs});

  final CategoryBudgetView view;
  final BudgetsController controller;
  final ColorScheme cs;

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
              Icon(categoryIcon(c.icon), color: cs.primary),
              const SizedBox(width: VeloraSpacing.sm),
              Expanded(
                child: Text(c.name, style: theme.textTheme.titleMedium),
              ),
              IconButton(
                tooltip: 'Limitni tahrirlash',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    showCategoryEditSheet(context, categoryId: c.id),
              ),
            ],
          ),
          const SizedBox(height: VeloraSpacing.sm),
          _StatusRow(
            label: 'Oylik',
            status: view.monthStatus,
            spent: view.monthSpent,
            limitMinor: c.monthlyLimitMinor,
          ),
          if (c.weeklyLimitMinor != null) ...[
            const SizedBox(height: VeloraSpacing.xs),
            _StatusRow(
              label: 'Haftalik',
              status: view.weekStatus,
              spent: view.weekSpent,
              limitMinor: c.weeklyLimitMinor,
            ),
          ],
          const SizedBox(height: VeloraSpacing.sm),
          ActionChip(
            label: Text(categoryKindLabel(c.kind)),
            onPressed: () => controller.setKind(
              c.id,
              c.kind == CategoryKind.mandatory
                  ? CategoryKind.variable
                  : CategoryKind.mandatory,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
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
    final velora = budgetVeloraStatus(status);
    final color = velora?.color ?? Theme.of(context).colorScheme.outline;
    final icon = velora?.icon ?? Icons.remove_circle_outline;
    final amountText = limitMinor == null
        ? spent.format()
        : '${spent.format()} / ${Money(limitMinor!, spent.currency).format()}';

    return VeloraStatusBadge(
      color: color,
      icon: icon,
      label: '$label: ${budgetStatusLabel(status)} · $amountText',
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
