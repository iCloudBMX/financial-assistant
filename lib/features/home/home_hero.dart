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

/// The Home balance card: total on top, then a two-part Erkin/Rezerv split of
/// that total. `reserved` is `total − free`, so goal earmarks and mandatory
/// amounts are already inside it — the split is Erkin/Rezerv only, and always
/// sums to the total. Goals and mortgage keep their own cards, so nothing is
/// lost. Replaces the former `MiniBalanceRow` + `DistributionCard`. All amounts
/// mask together under the privacy toggle; a null figure shows an em dash.
class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.total,
    required this.free,
    required this.reserved,
    required this.hidden,
  });

  final Money total;
  final Money? free; // "Erkin" — spendable
  final Money? reserved; // "Rezerv" — total − free
  final bool hidden;

  static const _mask = '••••••';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final freeMinor = free?.minorUnits ?? 0;
    final reservedMinor = reserved?.minorUnits ?? 0;
    final barTotal = freeMinor + reservedMinor;
    final showBar = !hidden && free != null && reserved != null && barTotal > 0;

    String amount(Money? m) =>
        m == null ? '—' : (hidden ? _mask : m.formatNumber());

    return Container(
      key: const Key('balance-card'),
      padding: const EdgeInsets.all(VeloraSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(VeloraRadii.card),
        border: Border.all(color: VeloraColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Balans', style: theme.textTheme.titleMedium),
          const SizedBox(height: VeloraSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              hidden ? _mask : total.formatNumber(),
              key: const Key('balance-amount'),
              maxLines: 1,
              softWrap: false,
              semanticsLabel: hidden ? 'Balans yashirilgan' : total.format(),
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (showBar) ...[
            const SizedBox(height: VeloraSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: Row(
                children: [
                  if (freeMinor > 0)
                    Expanded(
                      flex: (freeMinor * 1000 ~/ barTotal).clamp(1, 1000),
                      child: Container(height: 9, color: VeloraColors.coral),
                    ),
                  if (reservedMinor > 0)
                    Expanded(
                      flex: (reservedMinor * 1000 ~/ barTotal).clamp(1, 1000),
                      child: Container(height: 9, color: VeloraColors.plum),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: VeloraSpacing.md),
          _BalanceLegendRow(
              color: VeloraColors.coral, label: 'Erkin', value: amount(free)),
          const SizedBox(height: VeloraSpacing.xs),
          _BalanceLegendRow(
              color: VeloraColors.plum,
              label: 'Rezerv',
              value: amount(reserved)),
        ],
      ),
    );
  }
}

class _BalanceLegendRow extends StatelessWidget {
  const _BalanceLegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: VeloraSpacing.sm),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
