import 'package:flutter/material.dart';

import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';

/// The Home header from the approved mockup: the `velora.` wordmark, a warm
/// greeting, a status headline, and the balance privacy toggle. It replaces
/// the plain Material AppBar so the first screen leads with brand and intent
/// rather than a generic title bar.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.name,
    required this.title,
    required this.hidden,
    required this.onToggleHidden,
    required this.onOpenAccounts,
  });

  /// The user's preferred name (may be empty before onboarding sets it).
  final String name;

  /// The status headline under the greeting (e.g. "Pul rejangiz joyida").
  final String title;
  final bool hidden;
  final VoidCallback onToggleHidden;
  final VoidCallback onOpenAccounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greeting = name.trim().isEmpty ? 'Xayrli kun' : 'Xayrli kun, $name';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // The wordmark is a logo, not body copy: it keeps a fixed size
            // (no text scaling) and can ellipsize, so it never pushes the
            // header icons off-screen at large accessibility text scales.
            // `Expanded` (not `Flexible` + a `Spacer`): a loose `Flexible`
            // competing with a flex-1 `Spacer` splits the row's free space
            // 50/50, so the wordmark reserves a half it doesn't use and the
            // leftover lands as trailing space that shoves the icons ~60px
            // in from the right edge. `Expanded` lets the wordmark's box
            // absorb all the slack (the text stays left-aligned) so the
            // icons pin flush to the right, level with the cards below.
            Expanded(
              child: Text(
                'velora.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: VeloraColors.plum,
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            _HeaderIconButton(
              key: const Key('balance-privacy-toggle'),
              icon: hidden ? Icons.visibility_off : Icons.visibility,
              tooltip: hidden ? "Balansni ko'rsatish" : 'Balansni yashirish',
              onPressed: onToggleHidden,
            ),
            const SizedBox(width: VeloraSpacing.sm),
            _HeaderIconButton(
              key: const Key('accounts-open'),
              icon: Icons.account_balance_wallet_outlined,
              tooltip: 'Hisoblar',
              onPressed: onOpenAccounts,
            ),
          ],
        ),
        const SizedBox(height: VeloraSpacing.md),
        Text(
          greeting,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: VeloraColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: VeloraSpacing.xs),
        Text(title, style: theme.textTheme.headlineSmall),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VeloraRadii.control),
        side: const BorderSide(color: VeloraColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: Icon(icon, size: 20, color: VeloraColors.plum),
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      ),
    );
  }
}

/// The three balance minis under the safe-to-spend hero — total, reserved, and
/// free — mirroring the mockup's `Hamma pul / Rezerv / Erkin` row. All three
/// mask together when the privacy toggle is on.
class MiniBalanceRow extends StatelessWidget {
  const MiniBalanceRow({
    super.key,
    required this.total,
    required this.reserved,
    required this.free,
    required this.hidden,
  });

  final Money total;

  /// Reserved and free may be null when the safe-limit engine has not resolved
  /// a spendable figure yet; those minis then show an em dash instead of a
  /// fabricated split.
  final Money? reserved;
  final Money? free;
  final bool hidden;

  static const _mask = '••••••';

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight bounds the row's cross-axis so the three minis can
    // stretch to a common height without the circular constraint a bare
    // `CrossAxisAlignment.stretch` Row hits inside a vertical ListView.
    return IntrinsicHeight(
      child: Row(
        key: const Key('balance-card'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Mini(
              label: 'Jami',
              value: hidden ? _mask : total.formatNumber(),
              valueKey: const Key('balance-amount'),
              semantics: hidden ? 'Balans yashirilgan' : total.format(),
            ),
          ),
          const SizedBox(width: VeloraSpacing.sm),
          Expanded(
            child: _Mini(
              label: 'Rezerv',
              value: reserved == null
                  ? '—'
                  : (hidden ? _mask : reserved!.formatNumber()),
            ),
          ),
          const SizedBox(width: VeloraSpacing.sm),
          Expanded(
            child: _Mini(
              label: 'Erkin',
              value:
                  free == null ? '—' : (hidden ? _mask : free!.formatNumber()),
            ),
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({
    required this.label,
    required this.value,
    this.valueKey,
    this.semantics,
  });

  final String label;
  final String value;
  final Key? valueKey;
  final String? semantics;

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
              key: valueKey,
              maxLines: 1,
              softWrap: false,
              semanticsLabel: semantics,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// One distribution segment: a color, a label, and an amount.
class DistributionSegment {
  const DistributionSegment(this.label, this.amount, this.color);
  final String label;
  final Money amount;
  final Color color;
}

/// The "Pul taqsimoti" card: a single stacked bar over the free-expense,
/// goals, and mortgage totals, followed by a labeled row per segment. Segments
/// with a zero amount are dropped so the bar always reflects real money.
class DistributionCard extends StatelessWidget {
  const DistributionCard({super.key, required this.segments});

  final List<DistributionSegment> segments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active =
        segments.where((s) => s.amount.minorUnits > 0).toList();
    if (active.isEmpty) return const SizedBox.shrink();
    final total =
        active.fold<int>(0, (sum, s) => sum + s.amount.minorUnits);

    return Container(
      key: const Key('distribution-card'),
      padding: const EdgeInsets.all(VeloraSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(VeloraRadii.card),
        border: Border.all(color: VeloraColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pul taqsimoti', style: theme.textTheme.titleMedium),
          const SizedBox(height: VeloraSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Row(
              children: [
                for (final s in active)
                  Expanded(
                    flex: (s.amount.minorUnits * 1000 ~/ total).clamp(1, 1000),
                    child: Container(height: 9, color: s.color),
                  ),
              ],
            ),
          ),
          const SizedBox(height: VeloraSpacing.md),
          for (final s in active)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: VeloraSpacing.xs),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: s.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: VeloraSpacing.sm),
                  Expanded(
                    child: Text(s.label, style: theme.textTheme.bodyMedium),
                  ),
                  Text(
                    s.amount.formatNumber(),
                    style: theme.textTheme.bodyMedium
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
