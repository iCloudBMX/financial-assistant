import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../providers/app_providers.dart';
import 'goal_completed_dialog.dart';
import 'goal_controller.dart';

Future<void> showGoalContributeSheet(BuildContext context, WidgetRef ref,
    {required int goalId, bool withdraw = false}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ContributeSheet(goalId: goalId, withdraw: withdraw),
  );
}

class _ContributeSheet extends ConsumerStatefulWidget {
  final int goalId;
  final bool withdraw;
  const _ContributeSheet({required this.goalId, required this.withdraw});
  @override
  ConsumerState<_ContributeSheet> createState() => _ContributeSheetState();
}

class _ContributeSheetState extends ConsumerState<_ContributeSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = Money.tryParse(_amount.text, CurrencyRegistry.uzs);
    if (amount == null || amount.minorUnits <= 0) {
      setState(() => _error = "Summa 0 dan katta bo'lishi kerak");
      return;
    }
    final ctrl = ref.read(goalControllerProvider);
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final result = widget.withdraw
        ? await ctrl.withdraw(goalId: widget.goalId, amount: amount, note: note)
        : await ctrl.contribute(
            goalId: widget.goalId, amount: amount, note: note);
    await result.when(
      ok: (_) async {
        if (mounted) Navigator.of(context).pop();
        if (widget.withdraw) return;
        // Detect completion off the freshly-recomputed goalsProvider — NOT
        // the possibly-stale `.valueOrNull` — since goalsProvider only
        // recomputes after the ledgerRevisionProvider bump the controller
        // just triggered.
        final goals = await ref.read(goalsProvider.future);
        final matches = goals.where((g) => g.goal.id == widget.goalId);
        final done = matches.isNotEmpty &&
            matches.first.progress.remaining.minorUnits == 0;
        if (done && context.mounted) {
          // ignore: use_build_context_synchronously
          await showGoalCompletedDialog(context, ref, goalId: widget.goalId);
        }
      },
      err: (f) async => setState(() => _error = widget.withdraw
          ? "Jamg'armadan ko'p yechib bo'lmaydi"
          : "Summani tekshiring"),
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
          Text(widget.withdraw ? 'Yechish' : "Hissa qo'shish",
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            key: const Key('contrib-amount'),
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Summa'),
          ),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Izoh (ixtiyoriy)'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('contrib-save'),
            onPressed: _submit,
            child: Text(widget.withdraw ? 'Yechish' : 'Saqlash'),
          ),
        ],
      ),
    );
  }
}
