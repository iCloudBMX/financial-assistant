import '../money/currency.dart';
import '../money/money.dart';

enum AccountType { bankCard, cash, savings, other }

enum AccountRole { spending, reserve, credit, savings }

class Account {
  final int id;
  final String name;
  final AccountType type;
  final Money openingBalance;
  final String icon;
  final bool archived;
  final AccountRole role;

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.openingBalance,
    required this.icon,
    required this.archived,
    required this.role,
  });

  Currency get currency => openingBalance.currency;
}
