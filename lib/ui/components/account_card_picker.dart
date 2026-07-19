import 'package:flutter/material.dart';

import '../../core/ledger/account.dart';
import '../../core/theme/velora_tokens.dart';
import 'velora_card.dart';

/// A controlled account selector. Page and tap interactions are reported to
/// [onSelected]; the caller remains the source of truth for [selectedId].
class AccountCardPicker extends StatefulWidget {
  const AccountCardPicker({
    super.key,
    required this.accounts,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Account> accounts;
  final int? selectedId;
  final ValueChanged<int> onSelected;

  @override
  State<AccountCardPicker> createState() => _AccountCardPickerState();
}

class _AccountCardPickerState extends State<AccountCardPicker> {
  late final PageController _controller;

  List<Account> get _activeAccounts => widget.accounts
      .where((account) => !account.archived)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    final activeAccounts = _activeAccounts;
    final selectedIndex = activeAccounts.indexWhere(
      (account) => account.id == widget.selectedId,
    );
    _controller = PageController(
      initialPage: selectedIndex < 0 ? 0 : selectedIndex,
      viewportFraction: 0.88,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeAccounts = _activeAccounts;
    if (activeAccounts.isEmpty) return const SizedBox.shrink();

    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final height = 116.0 + ((textScale - 1).clamp(0.0, 1.0) * 150.0);

    return SizedBox(
      height: height,
      child: PageView.builder(
        controller: _controller,
        padEnds: false,
        itemCount: activeAccounts.length,
        onPageChanged: (index) => widget.onSelected(activeAccounts[index].id),
        itemBuilder: (context, index) {
          final account = activeAccounts[index];
          return Padding(
            padding: EdgeInsetsDirectional.only(
              end: index == activeAccounts.length - 1 ? 0 : VeloraSpacing.md,
            ),
            child: Semantics(
              key: Key('account-card-${account.id}'),
              button: true,
              selected: account.id == widget.selectedId,
              label: _accountSemanticLabel(account),
              child: ExcludeSemantics(
                child: VeloraAccountCard(
                  account: account,
                  onTap: () => widget.onSelected(account.id),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class VeloraAccountCard extends StatelessWidget {
  const VeloraAccountCard({
    super.key,
    required this.account,
    required this.onTap,
  });

  final Account account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox.expand(
      child: VeloraCard(
        onTap: onTap,
        padding: const EdgeInsets.all(VeloraSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _accountIcon(account.icon, account.type),
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: VeloraSpacing.sm),
                Flexible(
                  fit: FlexFit.loose,
                  child: Text(
                    account.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: VeloraSpacing.sm,
              runSpacing: VeloraSpacing.xs,
              children: [
                Text(_accountTypeLabel(account.type)),
                Text(
                  account.currency.code,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  account.openingBalance.format(),
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _accountSemanticLabel(Account account) =>
    '${account.name}, ${_accountTypeLabel(account.type)}, '
    '${account.currency.code}, ${account.openingBalance.format()}';

String _accountTypeLabel(AccountType type) => switch (type) {
  AccountType.bankCard => 'Bank kartasi',
  AccountType.cash => 'Naqd pul',
  AccountType.savings => 'Jamg‘arma',
  AccountType.other => 'Boshqa hisob',
};

IconData _accountIcon(String icon, AccountType type) => switch (icon) {
  'credit_card' => Icons.credit_card_outlined,
  'payments' => Icons.payments_outlined,
  'savings' => Icons.savings_outlined,
  'account_balance' => Icons.account_balance_outlined,
  _ => switch (type) {
    AccountType.bankCard => Icons.credit_card_outlined,
    AccountType.cash => Icons.payments_outlined,
    AccountType.savings => Icons.savings_outlined,
    AccountType.other => Icons.account_balance_wallet_outlined,
  },
};
