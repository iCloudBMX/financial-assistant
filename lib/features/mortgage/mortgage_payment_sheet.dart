// §6.9/§13.3: mortgage payment sheet with an explicit Auto/Manual split.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/mortgage/mortgage_engine.dart';
import '../../core/result/failure_messages.dart';
import '../../core/theme/velora_tokens.dart';
import '../../data/mortgage/mortgage_model.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/velora_money_field.dart';
import '../../ui/components/velora_sheet.dart';
import '../../ui/components/velora_status.dart';
import 'mortgage_controller.dart';

Future<void> showMortgagePaymentSheet(
    BuildContext context, WidgetRef ref, int mortgageId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => MortgagePaymentSheet(mortgageId: mortgageId),
  );
}

class MortgagePaymentSheet extends ConsumerStatefulWidget {
  final int mortgageId;
  const MortgagePaymentSheet({super.key, required this.mortgageId});
  @override
  ConsumerState<MortgagePaymentSheet> createState() => _MortgagePaymentSheetState();
}

class _MortgagePaymentSheetState extends ConsumerState<MortgagePaymentSheet> {
  final _total = TextEditingController();
  final _principal = TextEditingController();
  final _interest = TextEditingController();
  MortgageSplitMode _mode = MortgageSplitMode.auto;
  String? _error;
  bool _saving = false;
  static const _uzs = CurrencyRegistry.uzs;

  @override
  void initState() {
    super.initState();
    for (final c in [_total, _principal, _interest]) {
      c.addListener(_onChanged);
    }
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    for (final c in [_total, _principal, _interest]) {
      c.removeListener(_onChanged);
      c.dispose();
    }
    super.dispose();
  }

  MortgageWithProjection? _findItem(List<MortgageWithProjection>? list) {
    for (final e in (list ?? const <MortgageWithProjection>[])) {
      if (e.mortgage.id == widget.mortgageId) return e;
    }
    return null;
  }

  /// Derives the live split (§6.9): Auto reads the plan (current balance +
  /// rate) via the pure `deriveAutoSplit`; Manual reads the two typed fields
  /// via `manualSplit`. Neither branch touches money math directly — both
  /// delegate to the core engine so the invariant (principal+interest==total,
  /// interest never reducing principal) lives in one tested place.
  MortgagePaymentSplitState _computeSplit(MortgageWithProjection? item) {
    final total = Money.tryParse(_total.text, _uzs) ?? Money.zero(_uzs);
    if (_mode == MortgageSplitMode.auto) {
      return deriveAutoSplit(
        total: total,
        currentPrincipalMinor: item?.currentPrincipalMinor ?? 0,
        annualRateBp: item?.mortgage.annualRateBp ?? 0,
      );
    }
    final principal = Money.tryParse(_principal.text, _uzs) ?? Money.zero(_uzs);
    final interest = Money.tryParse(_interest.text, _uzs) ?? Money.zero(_uzs);
    return manualSplit(total: total, principal: principal, interest: interest);
  }

  Future<void> _save(MortgagePaymentSplitState split) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    // A `finally` always clears `_saving` so a throwing repository call can
    // never leave Save permanently disabled; typed failures map through
    // `userMessageFor`, raw exceptions get a plain-language fallback.
    var popped = false;
    try {
      final accounts = await ref.read(accountRepositoryProvider).list();
      if (!mounted) return;
      if (accounts.isEmpty) {
        setState(() => _error = 'Avval hisob qo\'shing');
        return;
      }
      final res = await ref.read(mortgageControllerProvider).recordPayment(
            mortgageId: widget.mortgageId,
            split: MortgagePaymentSplit(
              totalMinor: split.total.minorUnits,
              principalMinor: split.principal.minorUnits,
              interestMinor: split.interest.minorUnits,
            ),
            accountId: accounts.first.id,
          );
      if (!mounted) return;
      res.when(
        ok: (_) => popped = true,
        err: (f) => setState(() => _error = userMessageFor(f)),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Saqlashda kutilmagan xatolik yuz berdi.');
      }
    } finally {
      // Skip the setState when we're about to pop — the widget is on its way
      // out and there is no field left to re-enable.
      if (mounted && !popped) setState(() => _saving = false);
    }
    if (popped && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = _findItem(ref.watch(mortgagesProvider).value);
    final split = _computeSplit(item);
    final balanced = split.difference.minorUnits == 0;
    // In Auto mode an entered total beyond payoff can't be saved (the engine
    // clamps principal to the outstanding balance) — explain why Save is off.
    final autoOverPayoff = _mode == MortgageSplitMode.auto &&
        split.total.minorUnits > 0 &&
        !split.canSave;

    return VeloraSheetScaffold(
      title: 'To\'lov kiritish',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VeloraMoneyField(
            key: const Key('payment-total'),
            controller: _total,
            currency: _uzs,
            label: 'Umumiy to\'lov',
            autofocus: true,
          ),
          const SizedBox(height: VeloraSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _ModeButton(
                  key: const Key('payment-mode-auto'),
                  label: 'Avtomatik',
                  selected: _mode == MortgageSplitMode.auto,
                  onTap: () => setState(() => _mode = MortgageSplitMode.auto),
                ),
              ),
              const SizedBox(width: VeloraSpacing.sm),
              Expanded(
                child: _ModeButton(
                  key: const Key('payment-mode-manual'),
                  label: 'Qo\'lda',
                  selected: _mode == MortgageSplitMode.manual,
                  onTap: () =>
                      setState(() => _mode = MortgageSplitMode.manual),
                ),
              ),
            ],
          ),
          const SizedBox(height: VeloraSpacing.lg),
          if (_mode == MortgageSplitMode.auto) ...[
            _SplitRow(label: 'Asosiy qarzga', value: split.principal),
            const SizedBox(height: VeloraSpacing.sm),
            _SplitRow(label: 'Foiz to‘lovi', value: split.interest),
            const SizedBox(height: VeloraSpacing.sm),
            Text(
              'Taqsimot joriy qarz qoldig\'i va foiz stavkasidan avtomatik '
              'hisoblandi.',
              style: theme.textTheme.bodySmall,
            ),
            if (autoOverPayoff) ...[
              const SizedBox(height: VeloraSpacing.sm),
              VeloraStatusBadge(
                color: VeloraColors.critical,
                icon: Icons.error_outline,
                label: 'To\'lov qarz qoldig\'idan oshib ketdi '
                    '(ortiqcha: ${split.difference.format()})',
              ),
            ],
          ] else ...[
            VeloraMoneyField(
              key: const Key('payment-principal'),
              controller: _principal,
              currency: _uzs,
              label: 'Asosiy qarzga',
            ),
            const SizedBox(height: VeloraSpacing.md),
            VeloraMoneyField(
              key: const Key('payment-interest'),
              controller: _interest,
              currency: _uzs,
              label: 'Foiz to‘lovi',
            ),
            const SizedBox(height: VeloraSpacing.sm),
            Text(
              'Asosiy qarz summasi qarzni kamaytiradi, foiz summasi qarzni '
              'kamaytirmaydi.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: VeloraSpacing.sm),
            VeloraStatusBadge(
              color: balanced ? VeloraColors.success : VeloraColors.critical,
              icon: balanced ? Icons.check_circle : Icons.error_outline,
              label: balanced
                  ? 'Jami to\'lovga teng'
                  : 'Farq: ${split.difference.format()}',
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: VeloraSpacing.sm),
            Text(_error!,
                style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
      primaryAction: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          key: const Key('payment-save'),
          onPressed: (!split.canSave || _saving) ? null : () => _save(split),
          child: const Text('Saqlash'),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : null,
          side: BorderSide(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Semantics(
          selected: selected,
          child: Text(label),
        ),
      ),
    );
  }
}

class _SplitRow extends StatelessWidget {
  const _SplitRow({required this.label, required this.value});

  final String label;
  final Money value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Flexible(
          child: Text(
            value.format(),
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
