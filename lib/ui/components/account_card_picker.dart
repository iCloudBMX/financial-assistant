import 'package:flutter/material.dart';

import '../../core/ledger/account.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import 'velora_card.dart';

/// A controlled account selector. Page and tap interactions are reported to
/// [onSelected]; the caller remains the source of truth for [selectedId].
/// Accounts without a same-currency entry in [availableBalances] are excluded
/// until their derived balance becomes available.
class AccountCardPicker extends StatefulWidget {
  const AccountCardPicker({
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
  State<AccountCardPicker> createState() => _AccountCardPickerState();
}

class _AccountCardPickerState extends State<AccountCardPicker> {
  late final PageController _controller;
  int _suppressedPageMovements = 0;
  int _syncGeneration = 0;
  int? _visibleAccountId;

  List<Account> get _selectableAccounts =>
      _selectableFrom(widget.accounts, widget.availableBalances);

  @override
  void initState() {
    super.initState();
    final selectableAccounts = _selectableAccounts;
    final selectedIndex = selectableAccounts.indexWhere(
      (account) => account.id == widget.selectedId,
    );
    final initialIndex = selectedIndex < 0 ? 0 : selectedIndex;
    if (selectableAccounts.isNotEmpty) {
      _visibleAccountId = selectableAccounts[initialIndex].id;
    }
    _controller = PageController(
      initialPage: initialIndex,
      viewportFraction: 0.88,
    );
  }

  @override
  void didUpdateWidget(covariant AccountCardPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSelectable = _selectableFrom(
      oldWidget.accounts,
      oldWidget.availableBalances,
    );
    final newSelectable = _selectableAccounts;
    if (oldWidget.selectedId == widget.selectedId &&
        _sameAccountOrder(oldSelectable, newSelectable)) {
      return;
    }

    if (newSelectable.isEmpty) {
      _syncGeneration++;
      _visibleAccountId = null;
      return;
    }

    final oldPage = _controller.hasClients
        ? (_controller.page ?? _controller.initialPage.toDouble()).round()
        : _controller.initialPage;
    final selectedIndex = newSelectable.indexWhere(
      (account) => account.id == widget.selectedId,
    );
    final retainedIndex = newSelectable.indexWhere(
      (account) => account.id == _visibleAccountId,
    );
    final targetIndex = selectedIndex >= 0
        ? selectedIndex
        : retainedIndex >= 0
        ? retainedIndex
        : oldPage.clamp(0, newSelectable.length - 1);

    _visibleAccountId = newSelectable[targetIndex].id;
    _scheduleControlledSync(targetIndex);
  }

  @override
  void dispose() {
    _syncGeneration++;
    _controller.dispose();
    super.dispose();
  }

  void _scheduleControlledSync(int targetIndex) {
    final generation = ++_syncGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _syncGeneration) return;
      final selectableAccounts = _selectableAccounts;
      if (!_controller.hasClients || targetIndex >= selectableAccounts.length) {
        return;
      }
      _moveToPage(targetIndex, animate: false);
    });
  }

  void _moveToPage(int index, {required bool animate}) {
    if (!_controller.hasClients) return;
    final currentPage = _controller.page ?? _controller.initialPage.toDouble();
    if ((currentPage - index).abs() < 0.001) return;

    _suppressedPageMovements++;
    if (!animate) {
      try {
        _controller.jumpToPage(index);
      } finally {
        _suppressedPageMovements--;
      }
      return;
    }

    _controller
        .animateToPage(
          index,
          duration: VeloraMotion.standard,
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() => _suppressedPageMovements--);
  }

  void _selectFromUser(Account account, int index) {
    _visibleAccountId = account.id;
    widget.onSelected(account.id);
    _moveToPage(index, animate: true);
  }

  @override
  Widget build(BuildContext context) {
    final selectableAccounts = _selectableAccounts;
    if (selectableAccounts.isEmpty) {
      return const SizedBox(
        key: Key('account-picker-empty'),
        height: 48,
        child: Center(child: Text('Mavjud hisob topilmadi')),
      );
    }

    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final height = 116.0 + ((textScale - 1).clamp(0.0, 1.0) * 156.0);

    return SizedBox(
      height: height,
      child: PageView.builder(
        controller: _controller,
        itemCount: selectableAccounts.length,
        onPageChanged: (index) {
          final account = selectableAccounts[index];
          _visibleAccountId = account.id;
          if (_suppressedPageMovements == 0) {
            widget.onSelected(account.id);
          }
        },
        itemBuilder: (context, index) {
          final account = selectableAccounts[index];
          final availableBalance = widget.availableBalances[account.id]!;
          return Padding(
            padding: EdgeInsetsDirectional.only(
              end: index == selectableAccounts.length - 1
                  ? 0
                  : VeloraSpacing.md,
            ),
            child: Semantics(
              key: Key('account-card-${account.id}'),
              button: true,
              selected: account.id == widget.selectedId,
              label: _accountSemanticLabel(account, availableBalance),
              onTap: () => _selectFromUser(account, index),
              child: ExcludeSemantics(
                child: VeloraAccountCard(
                  account: account,
                  availableBalance: availableBalance,
                  onTap: () => _selectFromUser(account, index),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

List<Account> _selectableFrom(
  List<Account> accounts,
  Map<int, Money> availableBalances,
) => accounts
    .where((account) {
      if (account.archived) return false;
      final balance = availableBalances[account.id];
      return balance != null && balance.currency == account.currency;
    })
    .toList(growable: false);

bool _sameAccountOrder(List<Account> a, List<Account> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index].id != b[index].id) return false;
  }
  return true;
}

class VeloraAccountCard extends StatelessWidget {
  const VeloraAccountCard({
    super.key,
    required this.account,
    required this.availableBalance,
    required this.onTap,
  });

  final Account account;
  final Money availableBalance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox.expand(
      child: VeloraCard(
        onTap: onTap,
        padding: const EdgeInsetsDirectional.fromSTEB(
          VeloraSpacing.sm,
          VeloraSpacing.lg,
          VeloraSpacing.lg,
          VeloraSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: Text(
                    account.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const Spacer(),
                const SizedBox(width: VeloraSpacing.sm),
                Icon(
                  _accountIcon(account.icon, account.type),
                  color: theme.colorScheme.primary,
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
                  availableBalance.format(),
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

String _accountSemanticLabel(Account account, Money availableBalance) =>
    '${account.name}, ${_accountTypeLabel(account.type)}, '
    '${account.currency.code}, ${availableBalance.format()}';

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
