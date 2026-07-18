import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/budget/category_budget_engine.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../data/categories/category_model.dart';
import '../../providers/app_providers.dart';
import '../allocation/allocation_template_screen.dart';
import 'budgets_controller.dart';

String budgetStatusLabel(CategoryLimitStatus s) => switch (s) {
      CategoryLimitStatus.noLimit => 'limitsiz',
      CategoryLimitStatus.safe => 'xavfsiz',
      CategoryLimitStatus.near => 'limitga yaqin',
      CategoryLimitStatus.over => 'limitdan oshgan',
    };

IconData budgetStatusIcon(CategoryLimitStatus s) => switch (s) {
      CategoryLimitStatus.noLimit => Icons.remove_circle_outline,
      CategoryLimitStatus.safe => Icons.check_circle_outline,
      CategoryLimitStatus.near => Icons.warning_amber_outlined,
      CategoryLimitStatus.over => Icons.error_outline,
    };

Color budgetStatusColor(CategoryLimitStatus s, ColorScheme cs) => switch (s) {
      CategoryLimitStatus.noLimit => cs.outline,
      CategoryLimitStatus.safe => cs.primary,
      CategoryLimitStatus.near => cs.tertiary,
      CategoryLimitStatus.over => cs.error, // red reserved for over/error
    };

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
          children: [
            settings.maybeWhen(
              orElse: () => const SizedBox.shrink(),
              data: (s) => Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('O‘zgaruvchan budjet',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      _MoneyField(
                        label: 'Oylik o‘zgaruvchan budjet',
                        value: s.variableBudget,
                        onSubmit: controller.setVariableBudget,
                      ),
                      const SizedBox(height: 8),
                      _MoneyField(
                        label: 'Xavfsizlik buferi',
                        value: s.safetyBuffer,
                        onSubmit: controller.setSafetyBuffer,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ...list.map((v) => _CategoryBudgetTile(
                  view: v,
                  controller: controller,
                  color: budgetStatusColor(v.monthStatus, cs),
                )),
          ],
        ),
      ),
    );
  }
}

class _CategoryBudgetTile extends StatelessWidget {
  final CategoryBudgetView view;
  final BudgetsController controller;
  final Color color;
  const _CategoryBudgetTile(
      {required this.view, required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = view.category;
    return ListTile(
      leading: Icon(budgetStatusIcon(view.monthStatus), color: color),
      title: Text(c.name),
      subtitle: Text(
        '${budgetStatusLabel(view.monthStatus)} · '
        'sarflangan ${view.monthSpent.format()}'
        '${c.monthlyLimitMinor == null ? '' : ' / ${Money(c.monthlyLimitMinor!, view.monthSpent.currency).format()}'}',
        style: TextStyle(color: color),
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          if (c.kind == CategoryKind.mandatory)
            const Chip(label: Text('majburiy')),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editLimit(context),
          ),
        ],
      ),
    );
  }

  Future<void> _editLimit(BuildContext context) async {
    final currency = view.monthSpent.currency;
    final result = await showModalBottomSheet<Money?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LimitEditSheet(
        category: view.category,
        currency: currency,
      ),
    );
    if (result != null) {
      // A sentinel of Money(-1) means "clear"; see _LimitEditSheet.
      await controller.setMonthlyLimit(
          view.category.id, result.minorUnits < 0 ? null : result);
    }
  }
}

class _LimitEditSheet extends StatefulWidget {
  final Category category;
  final Currency currency;
  const _LimitEditSheet({required this.category, required this.currency});
  @override
  State<_LimitEditSheet> createState() => _LimitEditSheetState();
}

class _LimitEditSheetState extends State<_LimitEditSheet> {
  late final TextEditingController _ctrl = TextEditingController(
    // Symbol-less numeric form so an unchanged field re-parses to the same
    // limit; format() would embed the currency symbol, which tryParse
    // rejects → "Saqlash" unedited would fall back to the clear sentinel and
    // silently wipe an existing limit (data loss).
    text: widget.category.monthlyLimitMinor == null
        ? ''
        : Money(widget.category.monthlyLimitMinor!, widget.currency)
            .formatNumber(),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${widget.category.name} — oylik limit',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'Summa (bo‘sh = limitsiz)'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.pop(context, Money(-1, widget.currency)),
                  child: const Text('Limitni olib tashlash'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final m = Money.tryParse(_ctrl.text, widget.currency);
                    Navigator.pop(context, m ?? Money(-1, widget.currency));
                  },
                  child: const Text('Saqlash'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoneyField extends StatefulWidget {
  final String label;
  final Money value;
  final Future<void> Function(Money) onSubmit;
  const _MoneyField(
      {required this.label, required this.value, required this.onSubmit});
  @override
  State<_MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<_MoneyField> {
  late final TextEditingController _ctrl = TextEditingController(
      text: widget.value.minorUnits == 0 ? '' : widget.value.formatNumber());

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: widget.label),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.check),
          onPressed: () {
            final m = Money.tryParse(_ctrl.text, widget.value.currency);
            if (m != null) widget.onSubmit(m);
          },
        ),
      ],
    );
  }
}
