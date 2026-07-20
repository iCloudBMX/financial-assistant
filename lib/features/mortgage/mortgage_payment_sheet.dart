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
import 'mortgage_controller.dart';

// The dark-apricot ink the mockup uses for the interest figures (#9D5D18), so
// interest reads as visually distinct from the plum principal. A one-off shade
// kept private rather than added to the shared token set.
const _interestInk = Color(0xFF9D5D18);

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
          Text('To\'lovni qanday bo\'lamiz?',
              style: theme.textTheme.labelLarge),
          const SizedBox(height: VeloraSpacing.sm),
          // Segmented pill toggle (Auto / Manual), styled like the mockup.
          Container(
            padding: const EdgeInsets.all(VeloraSpacing.xs),
            decoration: BoxDecoration(
              color: VeloraColors.plumTint,
              borderRadius: BorderRadius.circular(VeloraRadii.control),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ModeButton(
                    key: const Key('payment-mode-auto'),
                    label: 'Avtomatik',
                    selected: _mode == MortgageSplitMode.auto,
                    onTap: () => setState(() => _mode = MortgageSplitMode.auto),
                  ),
                ),
                const SizedBox(width: VeloraSpacing.xs),
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
          ),
          const SizedBox(height: VeloraSpacing.lg),
          if (_mode == MortgageSplitMode.auto) ...[
            _SplitCard(
              tint: VeloraColors.plumTint,
              iconTileColor: VeloraColors.plum,
              icon: Icons.home_outlined,
              title: 'Asosiy qarzga',
              subtitle: 'Qarz qoldig\'ini kamaytiradi',
              valueColor: VeloraColors.plum,
              value: split.principal,
            ),
            const SizedBox(height: VeloraSpacing.sm),
            _SplitCard(
              tint: VeloraColors.apricotTint,
              iconTileColor: VeloraColors.apricot,
              icon: Icons.percent,
              title: 'Foiz to‘lovi',
              subtitle: 'Qarz qoldig\'ini kamaytirmaydi',
              valueColor: _interestInk,
              value: split.interest,
            ),
            const SizedBox(height: VeloraSpacing.sm),
            Text(
              'Taqsimot joriy qarz qoldig\'i va foiz stavkasidan avtomatik '
              'hisoblandi.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: VeloraColors.muted),
            ),
            if (autoOverPayoff) ...[
              const SizedBox(height: VeloraSpacing.sm),
              _EquationBar(
                color: VeloraColors.critical,
                icon: Icons.error_outline,
                title: 'To\'lov qarz qoldig\'idan oshib ketdi '
                    '(ortiqcha: ${split.difference.format()})',
              ),
            ] else if (split.canSave) ...[
              const SizedBox(height: VeloraSpacing.sm),
              _EquationBar(
                color: VeloraColors.success,
                icon: Icons.check_circle,
                title: 'To\'lov tarkibi umumiy summaga teng',
                trailing: split.total.format(),
              ),
            ],
          ] else ...[
            _SplitCard(
              tint: VeloraColors.plumTint,
              iconTileColor: VeloraColors.plum,
              icon: Icons.home_outlined,
              title: 'Asosiy qarzga',
              subtitle: 'Qarz qoldig\'ini kamaytiradi',
              valueColor: VeloraColors.plum,
              field: VeloraMoneyField(
                key: const Key('payment-principal'),
                controller: _principal,
                currency: _uzs,
                label: 'Miqdor',
              ),
            ),
            const SizedBox(height: VeloraSpacing.sm),
            _SplitCard(
              tint: VeloraColors.apricotTint,
              iconTileColor: VeloraColors.apricot,
              icon: Icons.percent,
              title: 'Foiz to‘lovi',
              subtitle: 'Qarz qoldig\'ini kamaytirmaydi',
              valueColor: _interestInk,
              field: VeloraMoneyField(
                key: const Key('payment-interest'),
                controller: _interest,
                currency: _uzs,
                label: 'Miqdor',
              ),
            ),
            const SizedBox(height: VeloraSpacing.sm),
            _EquationBar(
              color: balanced ? VeloraColors.success : VeloraColors.critical,
              icon: balanced ? Icons.check_circle : Icons.error_outline,
              title: balanced
                  ? 'To\'lov tarkibi umumiy summaga teng'
                  : 'Farq: ${split.difference.format()}',
              trailing: balanced ? split.total.format() : null,
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
          style: FilledButton.styleFrom(
            backgroundColor: VeloraColors.coral,
            foregroundColor: Colors.white,
          ),
          onPressed: (!split.canSave || _saving) ? null : () => _save(split),
          child: const Text('Saqlash'),
        ),
      ),
    );
  }
}

/// One tab of the Auto/Manual segmented control. Renders as a flat pill inside
/// the tinted track; the selected tab lifts onto a white surface.
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
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? theme.colorScheme.surfaceContainerLowest
            : Colors.transparent,
        borderRadius: BorderRadius.circular(VeloraRadii.control - 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(VeloraRadii.control - 4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: VeloraSpacing.sm,
                  vertical: VeloraSpacing.sm,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected ? VeloraColors.plum : VeloraColors.muted,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One explicit split component (§6.9): a tinted card with an icon tile, the
/// portion name, the always-on "reduces / does not reduce debt" helper line,
/// and either the derived value (Auto) or an editable field (Manual).
class _SplitCard extends StatelessWidget {
  const _SplitCard({
    required this.tint,
    required this.iconTileColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.valueColor,
    this.value,
    this.field,
  });

  final Color tint;
  final Color iconTileColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color valueColor;
  final Money? value;
  final Widget? field;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(VeloraSpacing.md),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(VeloraRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconTileColor,
                  borderRadius: BorderRadius.circular(VeloraRadii.control),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: VeloraSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: VeloraSpacing.xs),
                    Text(subtitle,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: VeloraColors.muted)),
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: VeloraSpacing.sm),
                Flexible(
                  child: Text(
                    value!.format(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: valueColor,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          if (field != null) ...[
            const SizedBox(height: VeloraSpacing.sm),
            field!,
          ],
        ],
      ),
    );
  }
}

/// The live balance line (§6.9): a tinted bar that turns green when the split
/// balances to the total and critical when it does not — the plain-language
/// half of the "save disabled until balanced" contract.
class _EquationBar extends StatelessWidget {
  const _EquationBar({
    required this.color,
    required this.icon,
    required this.title,
    this.trailing,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VeloraSpacing.md,
        vertical: VeloraSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(VeloraRadii.control),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: VeloraSpacing.sm),
          Expanded(
            child: Text(title, style: theme.textTheme.labelLarge),
          ),
          if (trailing != null) ...[
            const SizedBox(width: VeloraSpacing.sm),
            Text(
              trailing!,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ],
      ),
    );
  }
}
