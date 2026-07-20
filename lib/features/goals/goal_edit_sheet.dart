import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../data/goals/goal_model.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_money_field.dart';
import '../../ui/components/velora_sheet.dart';
import 'goal_controller.dart';
import 'goal_visuals.dart';

/// Opens the goal create/edit sheet. Pass [existing] to edit; omit to
/// create a new goal.
Future<void> showGoalEditSheet(BuildContext context, WidgetRef ref,
    {Goal? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _GoalEditSheet(existing: existing),
  );
}

class _GoalEditSheet extends ConsumerStatefulWidget {
  final Goal? existing;
  const _GoalEditSheet({this.existing});
  @override
  ConsumerState<_GoalEditSheet> createState() => _GoalEditSheetState();
}

class _GoalEditSheetState extends ConsumerState<_GoalEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _target;
  late final TextEditingController _note;
  GoalPriority _priority = GoalPriority.medium;
  DateTime _start = DateTime.now();
  DateTime? _targetDate;
  String? _error;

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    _name = TextEditingController(text: g?.name ?? '');
    // Seed the money field with formatNumber (symbol-less, round-trips
    // through Money.tryParse) — NEVER .format(): a symbol-prefixed seed
    // fails to re-parse and silently clears the amount on an unedited save.
    _target = TextEditingController(
        text: g == null
            ? ''
            : Money(g.targetAmountMinor, CurrencyRegistry.uzs).formatNumber());
    _note = TextEditingController(text: g?.note ?? '');
    _priority = g?.priority ?? GoalPriority.medium;
    _start = g?.startDate ?? DateTime.now();
    _targetDate = g?.targetDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final target = Money.tryParse(_target.text, CurrencyRegistry.uzs);
    if (name.isEmpty) {
      setState(() => _error = 'Nom kiriting');
      return;
    }
    if (target == null || target.minorUnits <= 0) {
      setState(() => _error = "Target summa 0 dan katta bo'lishi kerak");
      return;
    }
    setState(() => _error = null);
    final draft = GoalDraft(
      name: name,
      // type/icon/currencyCode/linkedAccountId have no UI controls yet
      // (picker is deferred) — carry them through from the existing goal
      // so an edit doesn't silently reset them to GoalDraft's defaults.
      type: widget.existing?.type ?? 'other',
      icon: widget.existing?.icon ?? 'flag',
      targetAmountMinor: target.minorUnits,
      currencyCode: widget.existing?.currencyCode ?? 'UZS',
      startDate: _start,
      targetDate: _targetDate,
      priority: _priority,
      linkedAccountId: widget.existing?.linkedAccountId,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    final repo = ref.read(goalRepositoryProvider);
    if (widget.existing == null) {
      await repo.create(draft);
    } else {
      await repo.update(widget.existing!.id, draft);
      // A retarget can flip active<->completed (e.g. raising the target on
      // a completed goal, or lowering it on an active one) — re-derive
      // status instead of waiting for the next contribute/withdraw.
      await ref
          .read(goalControllerProvider)
          .recomputeCompletion(widget.existing!.id);
    }
    ref.read(ledgerRevisionProvider.notifier).update((n) => n + 1);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return VeloraSheetScaffold(
      title: widget.existing == null ? 'Yangi maqsad' : 'Maqsadni tahrirlash',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('goal-name'),
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nom'),
          ),
          const SizedBox(height: VeloraSpacing.md),
          VeloraMoneyField(
            key: const Key('goal-target'),
            controller: _target,
            currency: CurrencyRegistry.uzs,
            label: 'Target summa',
          ),
          const SizedBox(height: VeloraSpacing.md),
          DropdownButtonFormField<GoalPriority>(
            initialValue: _priority,
            decoration: const InputDecoration(labelText: 'Prioritet'),
            items: GoalPriority.values
                .map((p) => DropdownMenuItem(
                    value: p, child: Text(goalPriorityLabel(p))))
                .toList(),
            onChanged: (v) => setState(() => _priority = v ?? _priority),
          ),
          const SizedBox(height: VeloraSpacing.md),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Izoh (ixtiyoriy)'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: VeloraSpacing.sm),
              child: Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      primaryAction: VeloraPrimaryButton(
        key: const Key('goal-save'),
        label: 'Saqlash',
        onPressed: _save,
      ),
    );
  }
}
