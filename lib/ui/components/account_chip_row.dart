import 'package:flutter/material.dart';

import '../../core/ledger/account.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../features/accounts/account_labels.dart';

/// A compact horizontal account selector: a scrollable row of chips (name +
/// available balance), the selected one highlighted. Kept separate from the
/// swipe-carousel [AccountCardPicker] so the expense-sheet simplification does
/// not ripple into income/mortgage/transfer, which still use the carousel.
/// Accounts without a same-currency balance in [availableBalances] are hidden.
class AccountChipRow extends StatelessWidget {
  const AccountChipRow({
    super.key,
    required this.accounts,
    required this.availableBalances,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Account> accounts;
  final Map<int, Money> availableBalances;
  final int? selectedId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final visible = accounts
        .where(
          (account) =>
              !account.archived && availableBalances[account.id] != null,
        )
        .toList(growable: false);
    if (visible.isEmpty) {
      return const SizedBox(
        key: Key('account-picker-empty'),
        height: 48,
        child: Center(child: Text('Mavjud hisob topilmadi')),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final account in visible)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: VeloraSpacing.sm),
              child: _AccountChip(
                account: account,
                balance: availableBalances[account.id]!,
                selected: account.id == selectedId,
                onTap: () => onSelected(account.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({
    required this.account,
    required this.balance,
    required this.selected,
    required this.onTap,
  });

  final Account account;
  final Money balance;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(VeloraRadii.control);
    return Semantics(
      key: Key('account-card-${account.id}'),
      button: true,
      selected: selected,
      label: '${account.name}, ${accountTypeLabel(account.type)}, '
          '${balance.format()}',
      onTap: onTap,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Material(
            color: selected
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: borderRadius,
              side: BorderSide(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              borderRadius: borderRadius,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: VeloraSpacing.md,
                  vertical: VeloraSpacing.sm,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          accountTypeIcon(account.type, icon: account.icon),
                          size: 18,
                          color: selected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: VeloraSpacing.xs),
                        Text(account.name, style: theme.textTheme.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      balance.format(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: selected
                            ? theme.colorScheme.primary
                            : VeloraColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
