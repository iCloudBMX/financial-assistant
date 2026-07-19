import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/allocation/allocation_engine.dart';
import '../../core/allocation/allocation_models.dart';
import '../../core/allocation/allocation_result_labels.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_card.dart';
import '../../ui/components/velora_money_field.dart';
import '../../ui/components/velora_sheet.dart';
import 'allocation_controller.dart';
import 'variable_budget_offer.dart';

/// §8.4 confirm screen: total income, each direction (editable), the funded
/// total, what remains unallocated, and what stays free once this commits.
/// Confirm is disabled unless `allocatedTotal <= income` — no
/// over-allocation. Returns true when the user confirms.
class AllocateSheet extends ConsumerStatefulWidget {
  final int incomeId;
  final Money income;
  const AllocateSheet(
      {super.key, required this.incomeId, required this.income});

  @override
  ConsumerState<AllocateSheet> createState() => _AllocateSheetState();
}

class _AllocateSheetState extends ConsumerState<AllocateSheet> {
  final Map<String, TextEditingController> _ctrls = {};
  // The template-computed preview, loaded once: it carries the directions
  // (priority order) and the §8.5 shortfall list, which stays informational
  // even as the user edits amounts by hand below.
  AllocationPreview? _initial;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preview =
        await ref.read(allocationControllerProvider).preview(widget.income);
    for (final d in preview.directions) {
      final funded = preview.perBucket[d.bucketKey];
      // Seed with the symbol-less numeric form so an untouched field
      // re-parses back to the same Money (format() would embed the currency
      // symbol, which tryParse rejects → the field would read as null/zero).
      _ctrls[d.bucketKey] = TextEditingController(
          text: (funded ?? Money.zero(widget.income.currency)).formatNumber());
    }
    if (mounted) setState(() => _initial = preview);
  }

  Map<String, Money> _current() {
    final c = widget.income.currency;
    final out = <String, Money>{};
    _ctrls.forEach((k, ctrl) {
      final m = Money.tryParse(ctrl.text, c);
      if (m != null && m.minorUnits > 0) out[k] = m;
    });
    return out;
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial = _initial;
    if (initial == null) {
      return const SizedBox(
          height: 160, child: Center(child: CircularProgressIndicator()));
    }
    final current = _current();
    final live =
        editedAllocationPreview(widget.income, initial.directions, current);
    final canConfirm = live.allocatedTotal.minorUnits <= live.income.minorUnits;

    // Re-evaluate the §8.5 shortfall against the CURRENT edited amounts, not
    // the initial template split: a direction the template underfunded is no
    // longer short once the user types its full requested amount in. Each
    // initial shortfall carries the amount that direction wanted
    // (`requested`); compare it to what the field now funds.
    final liveShortfall = [
      for (final s in initial.shortfall)
        if ((current[s.bucketKey]?.minorUnits ?? 0) < s.requested.minorUnits)
          Shortfall(
            s.bucketKey,
            s.requested,
            current[s.bucketKey] ?? Money.zero(widget.income.currency),
          ),
    ];

    return VeloraSheetScaffold(
      title: 'Kirimni taqsimlash',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Jami kirim: ${widget.income.format()}',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: VeloraSpacing.lg),
          for (final d in initial.directions) ...[
            // The bucket + rule-type description lives in its own free-
            // wrapping caption ABOVE the field — never as the money field's
            // internal floating label, which reserves single-line height and
            // would overlap the entered amount when a long label
            // ("O‘zgaruvchan budjet") wraps at 320px/200% text scale. The
            // field's own label is a short constant instead.
            Text(
              allocationMethodLabel(d.method) == bucketLabel(d.bucketKey)
                  ? bucketLabel(d.bucketKey)
                  : '${bucketLabel(d.bucketKey)} · ${allocationMethodLabel(d.method)}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: VeloraSpacing.xs),
            VeloraMoneyField(
              key: Key('allocate-amount-${d.bucketKey}'),
              controller: _ctrls[d.bucketKey]!,
              currency: widget.income.currency,
              label: 'Summa',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: VeloraSpacing.md),
          ],
          if (liveShortfall.isNotEmpty) ...[
            VeloraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          color: VeloraColors.critical, size: 18),
                      const SizedBox(width: VeloraSpacing.xs),
                      Text('Mablag‘ yetarli emas',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: VeloraColors.critical)),
                    ],
                  ),
                  const SizedBox(height: VeloraSpacing.xs),
                  for (final s in liveShortfall)
                    Text(
                      '${bucketLabel(s.bucketKey)} uchun ${s.shortBy.format()} '
                      'yetishmayapti',
                      style: const TextStyle(color: VeloraColors.critical),
                    ),
                ],
              ),
            ),
            const SizedBox(height: VeloraSpacing.md),
          ],
          const Divider(),
          Text('Taqsimlangan: ${live.allocatedTotal.format()}'),
          Text('Taqsimlanmagan: ${live.unallocated.format()}',
              style: TextStyle(
                  color: live.unallocated.isNegative
                      ? Theme.of(context).colorScheme.error
                      : null)),
          Text('Taqsimlashdan keyin erkin: ${live.freeAfter.format()}'),
        ],
      ),
      primaryAction: VeloraPrimaryButton(
        key: const Key('allocate-confirm'),
        label: 'Tasdiqlash',
        onPressed: !canConfirm
            ? null
            : () async {
                final current = _current();
                await ref
                    .read(allocationControllerProvider)
                    .confirm(widget.incomeId, current);
                if (context.mounted) {
                  await maybeOfferVariableBudgetUpdate(context, ref, current);
                }
                if (context.mounted) Navigator.pop(context, true);
              },
      ),
    );
  }
}
