import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/budget/category_budget_engine.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../data/categories/category_model.dart';
import '../../providers/app_providers.dart';
import '../allocation/allocation_template_screen.dart';
import 'budgets_controller.dart';

String categoryKindLabel(CategoryKind k) => switch (k) {
      CategoryKind.mandatory => 'majburiy',
      CategoryKind.variable => 'o‘zgaruvchan',
    };

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
    final cs = Theme.of(context).colorScheme;
    final weekColor = budgetStatusColor(view.weekStatus, cs);
    return ListTile(
      leading: Icon(budgetStatusIcon(view.monthStatus), color: color),
      title: Text(c.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${budgetStatusLabel(view.monthStatus)} · '
            'sarflangan ${view.monthSpent.format()}'
            '${c.monthlyLimitMinor == null ? '' : ' / ${Money(c.monthlyLimitMinor!, view.monthSpent.currency).format()}'}',
            style: TextStyle(color: color),
          ),
          if (c.weeklyLimitMinor != null)
            Text(
              '${budgetStatusLabel(view.weekStatus)} (hafta) · '
              'sarflangan ${view.weekSpent.format()} / '
              '${Money(c.weeklyLimitMinor!, view.weekSpent.currency).format()}',
              style: TextStyle(color: weekColor),
            ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              ActionChip(
                label: Text(categoryKindLabel(c.kind)),
                onPressed: () => controller.setKind(
                  c.id,
                  c.kind == CategoryKind.mandatory
                      ? CategoryKind.variable
                      : CategoryKind.mandatory,
                ),
              ),
              IconButton(
                tooltip: 'Limitni tahrirlash',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editLimit(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editLimit(BuildContext context) async {
    final currency = view.monthSpent.currency;
    final result = await showModalBottomSheet<_LimitEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LimitEditSheet(
        category: view.category,
        currency: currency,
      ),
    );
    if (result == null) return;
    await _applyLimitEdit(
        result.monthly, (m) => controller.setMonthlyLimit(view.category.id, m));
    await _applyLimitEdit(
        result.weekly, (m) => controller.setWeeklyLimit(view.category.id, m));
  }

  Future<void> _applyLimitEdit(
      _LimitEdit edit, Future<void> Function(Money?) setter) {
    return switch (edit) {
      _LimitSet(:final value) => setter(value),
      _LimitClear() => setter(null),
      _LimitKeep() => Future.value(),
    };
  }
}

/// What to do with one limit field on save: keep the current value
/// (unparseable/garbage input — never silently corrupt data), clear it
/// (field left empty), or set it to a new parsed [Money].
sealed class _LimitEdit {
  const _LimitEdit();
}

class _LimitKeep extends _LimitEdit {
  const _LimitKeep();
}

class _LimitClear extends _LimitEdit {
  const _LimitClear();
}

class _LimitSet extends _LimitEdit {
  final Money value;
  const _LimitSet(this.value);
}

class _LimitEditResult {
  final _LimitEdit monthly;
  final _LimitEdit weekly;
  const _LimitEditResult({required this.monthly, required this.weekly});
}

class _LimitEditSheet extends StatefulWidget {
  final Category category;
  final Currency currency;
  const _LimitEditSheet({required this.category, required this.currency});
  @override
  State<_LimitEditSheet> createState() => _LimitEditSheetState();
}

class _LimitEditSheetState extends State<_LimitEditSheet> {
  // Symbol-less numeric form so an unchanged field re-parses to the same
  // limit; format() would embed the currency symbol, which tryParse
  // rejects → "Saqlash" unedited would otherwise silently wipe an existing
  // limit (data loss) — seed with formatNumber(), never format().
  late final TextEditingController _monthlyCtrl = TextEditingController(
    text: widget.category.monthlyLimitMinor == null
        ? ''
        : Money(widget.category.monthlyLimitMinor!, widget.currency)
            .formatNumber(),
  );
  late final TextEditingController _weeklyCtrl = TextEditingController(
    text: widget.category.weeklyLimitMinor == null
        ? ''
        : Money(widget.category.weeklyLimitMinor!, widget.currency)
            .formatNumber(),
  );

  @override
  void dispose() {
    _monthlyCtrl.dispose();
    _weeklyCtrl.dispose();
    super.dispose();
  }

  _LimitEdit _resolve(String text) {
    if (text.trim().isEmpty) return const _LimitClear();
    final m = Money.tryParse(text, widget.currency);
    return m == null ? const _LimitKeep() : _LimitSet(m);
  }

  void _save() {
    Navigator.pop(
      context,
      _LimitEditResult(
        monthly: _resolve(_monthlyCtrl.text),
        weekly: _resolve(_weeklyCtrl.text),
      ),
    );
  }

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
          Text('${widget.category.name} — limitlar',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _monthlyCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Oylik limit',
              helperText: 'Bo‘sh = limitsiz',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _weeklyCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Haftalik limit',
              helperText: 'Bo‘sh = limitsiz',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _save,
            child: const Text('Saqlash'),
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
