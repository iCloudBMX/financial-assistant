import '../money/currency.dart';
import '../money/money.dart';

enum AccountType { bankCard, cash, savings, other }

class Account {
  final int id;
  final String name;
  final AccountType type;
  final Money openingBalance;
  final String icon;
  final bool archived;

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.openingBalance,
    required this.icon,
    required this.archived,
  });

  Currency get currency => openingBalance.currency;
}
