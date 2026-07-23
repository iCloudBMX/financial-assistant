import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/velora_async_state.dart';
import '../../ui/components/velora_button.dart';
import 'mortgage_edit_sheet.dart';
import 'mortgage_payment_sheet.dart';
import 'mortgage_extra_payment_sheet.dart';

// The lighter plum the approved mockup uses for the hero's diagonal gradient
// (linear-gradient(145deg,#5B3A6E,#744D83)). A one-off shade, so it lives here
// as a private const rather than in the shared token set.
const _heroGradientEnd = Color(0xFF744D83);

// ~88px clears the global floating "Chiqim" FAB so the last action button is
// never hidden under it.
const _fabClearance = 88.0;

class MortgageDashboardScreen extends ConsumerWidget {
  const MortgageDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mortgagesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ipoteka')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => VeloraErrorState(
          message: 'Xatolik yuz berdi',
          onRetry: () => ref.invalidate(mortgagesProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return VeloraEmptyState(
              icon: Icons.account_balance_outlined,
              title: 'Ipoteka qo\'shilmagan',
              message: 'Ipotekangizni qo\'shib, to\'lovlarni kuzating.',
              action: VeloraPrimaryButton(
                label: 'Ipoteka qo\'shish',
                onPressed: () => showMortgageEditSheet(context, ref),
              ),
            );
          }
          final m = list.first; // MVP: one primary mortgage on the dashboard
          final cur = CurrencyRegistry.byCode(m.mortgage.currencyCode);
          Money money(int v) => Money(v, cur);
          // Every payoff date is an estimate (§6.9) — never presented as an
          // exact bank figure.
          final payoff = m.projection.neverCloses
              ? 'joriy to\'lovda yopilmaydi'
              : (m.projection.payoffDate?.toString().split(' ').first ?? '—');
          final completion = (m.completionBp / 100).clamp(0, 100).toDouble();

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              VeloraSpacing.lg,
              VeloraSpacing.lg,
              VeloraSpacing.lg,
              _fabClearance,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(m.mortgage.name,
                        style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  IconButton(
                    key: const Key('mortgage-edit'),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Tahrirlash',
                    onPressed: () => showMortgageEditSheet(context, ref,
                        existing: m.mortgage),
                  ),
                ],
              ),
              const SizedBox(height: VeloraSpacing.md),
              _MortgageHero(
                principal: money(m.currentPrincipalMinor),
                completionPercent: completion,
                payoffText: payoff,
              ),
              const SizedBox(height: VeloraSpacing.md),
              _StatsRow(
                rate: _rateText(m.mortgage.annualRateBp),
                monthly: money(m.mortgage.mandatoryPaymentMinor),
                monthsRemaining: m.projection.neverCloses
                    ? '—'
                    : '${m.projection.monthsRemaining} oy',
              ),
              const SizedBox(height: VeloraSpacing.md),
              _NextPaymentCard(
                amount: money(m.mortgage.mandatoryPaymentMinor),
                date: m.mortgage.nextPaymentDate.toString().split(' ').first,
              ),
              const SizedBox(height: VeloraSpacing.lg),
              // Coral is the single primary CTA on this screen (§ pay action).
              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: VeloraColors.coral,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () =>
                      showMortgagePaymentSheet(context, ref, m.mortgage.id),
                  child: const Text('To\'lov kiritish'),
                ),
              ),
              const SizedBox(height: VeloraSpacing.sm),
              // Full-width stacked secondaries stay overflow-safe at 320px /
              // 200% text scale where a two-up Row would clip the labels.
              OutlinedButton(
                onPressed: () =>
                    showMortgageExtraPaymentSheet(context, ref, m.mortgage.id),
                child: const Text('Qo\'shimcha to\'lov'),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _rateText(int annualRateBp) =>
      '${annualRateBp ~/ 100}.${(annualRateBp % 100).toString().padLeft(2, '0')}%';
}

/// The plum hero (§6.9): the dominant "remaining principal" value on a warm
/// diagonal-plum fill, with the completion percent, an estimated-payoff line,
/// and an apricot progress track — mirroring the approved mortgage dashboard.
class _MortgageHero extends StatelessWidget {
  const _MortgageHero({
    required this.principal,
    required this.completionPercent,
    required this.payoffText,
  });

  final Money principal;
  final double completionPercent;
  final String payoffText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const onPlum = Colors.white;
    return Container(
      padding: const EdgeInsets.all(VeloraSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [VeloraColors.plum, _heroGradientEnd],
        ),
        borderRadius: BorderRadius.circular(VeloraRadii.card),
        boxShadow: const [
          BoxShadow(
            color: Color(0x335B3A6E),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Qolgan asosiy qarz',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: onPlum.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: VeloraSpacing.sm),
              Text(
                '${completionPercent.toStringAsFixed(0)}% yopildi',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: onPlum.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: VeloraSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              principal.format(),
              maxLines: 1,
              softWrap: false,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: onPlum,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: VeloraSpacing.xs),
          Text(
            'Joriy sur\'atda: $payoffText',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: onPlum.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: VeloraSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (completionPercent / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: VeloraColors.onPlumTrack,
              valueColor: const AlwaysStoppedAnimation(VeloraColors.apricot),
            ),
          ),
        ],
      ),
    );
  }
}

/// The three headline stats (rate · monthly · months remaining) as a row of
/// bordered tiles, matching the mockup's `stats3` strip.
class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.rate,
    required this.monthly,
    required this.monthsRemaining,
  });

  final String rate;
  final Money monthly;
  final String monthsRemaining;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _StatTile(label: 'Foiz', value: rate)),
          const SizedBox(width: VeloraSpacing.sm),
          Expanded(
              child: _StatTile(label: 'Oylik', value: monthly.formatNumber())),
          const SizedBox(width: VeloraSpacing.sm),
          Expanded(child: _StatTile(label: 'Qoldi', value: monthsRemaining)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VeloraSpacing.md,
        vertical: VeloraSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(VeloraRadii.control),
        border: Border.all(color: VeloraColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: VeloraColors.muted,
            ),
          ),
          const SizedBox(height: VeloraSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// The apricot-tinted "next payment" card from the mockup: an icon tile, the
/// due date, and the mandatory amount.
class _NextPaymentCard extends StatelessWidget {
  const _NextPaymentCard({required this.amount, required this.date});

  final Money amount;
  final String date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(VeloraSpacing.md),
      decoration: BoxDecoration(
        color: VeloraColors.apricotTint,
        borderRadius: BorderRadius.circular(VeloraRadii.card),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: VeloraColors.apricot,
              borderRadius: BorderRadius.circular(VeloraRadii.control),
            ),
            child: const Icon(Icons.event_outlined,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: VeloraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Keyingi to\'lov · $date',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: VeloraColors.muted)),
                const SizedBox(height: VeloraSpacing.xs),
                Text(
                  amount.format(),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
