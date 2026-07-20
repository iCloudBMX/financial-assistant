import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/allocation/allocation_engine.dart';
import '../../core/allocation/allocation_models.dart';
import '../../core/allocation/allocation_result_labels.dart';
import '../../core/money/money.dart';
import '../../core/result/failure_messages.dart';
import '../../core/theme/velora_tokens.dart';
import '../../ui/components/app_snackbar.dart';
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
          _IncomeHeaderCard(income: widget.income),
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
          _AllocationSummaryCard(
            directions: initial.directions,
            current: current,
            allocatedTotal: live.allocatedTotal,
            unallocated: live.unallocated,
            freeAfter: live.freeAfter,
          ),
        ],
      ),
      primaryAction: _CoralPrimaryAction(
        child: VeloraPrimaryButton(
        key: const Key('allocate-confirm'),
        label: 'Tasdiqlash',
        onPressed: !canConfirm
            ? null
            : () async {
                final current = _current();
                final messenger = ScaffoldMessenger.of(context);
                final result = await ref
                    .read(allocationControllerProvider)
                    .confirm(widget.incomeId, current);
                if (!result.isOk) {
                  result.when(
                    ok: (_) {},
                    err: (f) => messenger
                        .showAutoDismissSnackBar(SnackBar(content: Text(userMessageFor(f)))),
                  );
                  return;
                }
                if (context.mounted) {
                  await maybeOfferVariableBudgetUpdate(context, ref, current);
                }
                if (context.mounted) Navigator.pop(context, true);
              },
        ),
      ),
    );
  }
}

/// The plum "total income" banner from the money-flow mockups: the amount the
/// user is about to distribute, shown as the sheet's anchor before the
/// editable directions.
class _IncomeHeaderCard extends StatelessWidget {
  const _IncomeHeaderCard({required this.income});

  final Money income;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(VeloraSpacing.lg),
      decoration: BoxDecoration(
        color: VeloraColors.plum,
        borderRadius: BorderRadius.circular(VeloraRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'JAMI KIRIM',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.68),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: VeloraSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              income.format(),
              maxLines: 1,
              softWrap: false,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The §8.4 balance readout, restyled as Home's distribution card: a single
/// stacked bar over the currently-funded buckets, then the funded total, the
/// unallocated remainder (red when over-allocated), and the free balance after
/// this split commits. The three summary strings are preserved verbatim.
class _AllocationSummaryCard extends StatelessWidget {
  const _AllocationSummaryCard({
    required this.directions,
    required this.current,
    required this.allocatedTotal,
    required this.unallocated,
    required this.freeAfter,
  });

  final List<AllocationDirection> directions;
  final Map<String, Money> current;
  final Money allocatedTotal;
  final Money unallocated;
  final Money freeAfter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Bar segments follow the priority order of the directions, plus a
    // trailing "free" segment for whatever stays unallocated (never negative).
    final segments = <({Color color, int units})>[
      for (final d in directions)
        if ((current[d.bucketKey]?.minorUnits ?? 0) > 0)
          (color: _bucketColor(d.bucketKey), units: current[d.bucketKey]!.minorUnits),
      if (freeAfter.minorUnits > 0)
        (color: VeloraColors.line, units: freeAfter.minorUnits),
    ];
    final total = segments.fold<int>(0, (sum, s) => sum + s.units);

    return Container(
      padding: const EdgeInsets.all(VeloraSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(VeloraRadii.card),
        border: Border.all(color: VeloraColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (total > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: Row(
                children: [
                  for (final s in segments)
                    Expanded(
                      flex: (s.units * 1000 ~/ total).clamp(1, 1000),
                      child: Container(height: 9, color: s.color),
                    ),
                ],
              ),
            ),
            const SizedBox(height: VeloraSpacing.md),
          ],
          Text(
            'Taqsimlangan: ${allocatedTotal.format()}',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: VeloraSpacing.xs),
          Text(
            'Taqsimlanmagan: ${unallocated.format()}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: unallocated.isNegative ? theme.colorScheme.error : null,
            ),
          ),
          const SizedBox(height: VeloraSpacing.xs),
          Text(
            'Taqsimlashdan keyin erkin: ${freeAfter.format()}',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: VeloraColors.muted),
          ),
        ],
      ),
    );
  }
}

/// Stable stacked-bar colour per system bucket; unknown keys (goal:{id},
/// mortgage, …) cycle through the warm accent palette so every direction still
/// reads as its own segment.
Color _bucketColor(String bucketKey) => switch (bucketKey) {
      'mandatoryExpenses' => VeloraColors.plum,
      'variableBudget' => VeloraColors.coral,
      'minReserve' => VeloraColors.apricot,
      _ => _fallbackPalette[bucketKey.hashCode.abs() % _fallbackPalette.length],
    };

const _fallbackPalette = [
  VeloraColors.success,
  VeloraColors.plum,
  VeloraColors.coral,
  VeloraColors.apricot,
];

/// Recolors its subtree's primary to Velora coral so the pinned confirm CTA is
/// the single coral primary action from the mockups.
class _CoralPrimaryAction extends StatelessWidget {
  const _CoralPrimaryAction({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: VeloraColors.coral,
          onPrimary: Colors.white,
        ),
      ),
      child: child,
    );
  }
}
