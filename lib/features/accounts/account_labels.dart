import '../../core/ledger/account.dart';

/// Single source of truth for the Uzbek account-type labels shown across the
/// accounts feature (the list screen and the create sheet). Kept here so the
/// label and the create-sheet chip order don't drift apart.
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
