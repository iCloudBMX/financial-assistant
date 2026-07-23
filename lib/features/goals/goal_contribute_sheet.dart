import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_money_field.dart';
import '../../ui/components/velora_sheet.dart';
import 'goal_completed_dialog.dart';
import 'goal_controller.dart';
import 'goal_visuals.dart';

Future<void> showGoalContributeSheet(BuildContext context, WidgetRef ref,
    {required int goalId, bool withdraw = false, Money? initialAmount}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ContributeSheet(
        goalId: goalId, withdraw: withdraw, initialAmount: initialAmount),
  );
}

class _ContributeSheet extends ConsumerStatefulWidget {
  final int goalId;
  final bool withdraw;
  final Money? initialAmount;
  const _ContributeSheet(
      {required this.goalId, required this.withdraw, this.initialAmount});
  @override
  ConsumerState<_ContributeSheet> createState() => _ContributeSheetState();
}

class _ContributeSheetState extends ConsumerState<_ContributeSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialAmount != null) {
      _amount.text = widget.initialAmount!.formatNumber();
    }
  }

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
    final theme = Theme.of(context);
    final goals = ref.watch(goalsProvider).value;
    final matches = goals?.where((g) => g.goal.id == widget.goalId);
    final item = (matches == null || matches.isEmpty) ? null : matches.first;
    final currency = item?.progress.saved.currency ?? CurrencyRegistry.uzs;
    final amount = Money.tryParse(_amount.text, currency);

    // §6.8: contribution and withdrawal show their effect before commit — the
    // mockup's apricot "Targetga ta'siri" impact card with the progress shift.
    Widget? preview;
    if (item != null && amount != null && amount.minorUnits > 0) {
      final saved = item.progress.saved.minorUnits;
      final target = item.progress.target.minorUnits;
      final afterMinor = widget.withdraw
          ? saved - amount.minorUnits
          : saved + amount.minorUnits;
      final after = Money(afterMinor < 0 ? 0 : afterMinor, currency);
      final remainingAfter =
          Money((target - after.minorUnits).clamp(0, target), currency);
      final beforePct = (item.progress.percentBp / 100).toStringAsFixed(0);
      final afterBp = target <= 0
          ? 10000
          : (after.minorUnits * 10000 ~/ target).clamp(0, 10000);
      final afterPct = (afterBp / 100).toStringAsFixed(0);
      preview = Container(
        padding: const EdgeInsets.all(VeloraSpacing.lg),
        decoration: BoxDecoration(
          color: VeloraColors.apricotTint,
          borderRadius: BorderRadius.circular(VeloraRadii.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Targetga ta'siri",
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: VeloraColors.muted)),
            const SizedBox(height: VeloraSpacing.xs),
            Text('Progress $beforePct% → $afterPct%',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: VeloraSpacing.md),
            GoalProgressBar(value: afterBp / 10000),
            const SizedBox(height: VeloraSpacing.md),
            GoalMetaLine(
              label: widget.withdraw
                  ? "Yechishdan so'ng jamg'arma"
                  : "Hissadan so'ng jamg'arma",
              value: after.format(),
              emphasize: true,
            ),
            GoalMetaLine(
              label: 'Maqsadgacha qoldi',
              value: remainingAfter.format(),
            ),
          ],
        ),
      );
    }

    return VeloraSheetScaffold(
      title: widget.withdraw ? 'Yechish' : "Hissa qo'shish",
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VeloraMoneyField(
            key: const Key('contrib-amount'),
            controller: _amount,
            currency: currency,
            label: 'Summa',
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: VeloraSpacing.md),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Izoh (ixtiyoriy)'),
          ),
          if (preview != null) ...[
            const SizedBox(height: VeloraSpacing.md),
            preview,
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: VeloraSpacing.sm),
              child: Text(_error!,
                  style: TextStyle(color: theme.colorScheme.error)),
            ),
        ],
      ),
      primaryAction: VeloraPrimaryButton(
        key: const Key('contrib-save'),
        label: widget.withdraw ? 'Yechish' : 'Saqlash',
        onPressed: _submit,
      ),
    );
  }
}
