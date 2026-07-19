import 'package:flutter/material.dart';

import '../../core/ledger/account.dart';

/// Single source of truth for the Uzbek account-type labels shown across the
/// accounts feature (the list screen, the create sheet, and the account
/// picker card). Kept here so the label and the create-sheet chip order
/// don't drift apart -- previously `account_card_picker.dart` carried its
/// own copy that had drifted (curly vs straight apostrophe in "Jamg'arma",
/// and "Boshqa hisob" vs "Boshqa" for `AccountType.other`).
String accountTypeLabel(AccountType type) => switch (type) {
      AccountType.cash => 'Naqd pul',
      AccountType.bankCard => 'Bank kartasi',
      AccountType.savings => 'Jamg\'arma',
      AccountType.other => 'Boshqa',
    };

/// The order account types are offered in the create sheet.
const List<AccountType> accountTypesInDisplayOrder = [
  AccountType.cash,
  AccountType.bankCard,
  AccountType.savings,
  AccountType.other,
];

/// Single source of truth for the account-type icon shown across the
/// accounts feature. [icon] is the account's own stored icon key (from
/// `account_edit_sheet`'s icon picker); when it doesn't match a known key
/// this falls back to a per-type default.
IconData accountTypeIcon(AccountType type, {String? icon}) => switch (icon) {
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
