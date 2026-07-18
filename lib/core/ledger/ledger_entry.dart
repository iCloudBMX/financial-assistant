import '../money/money.dart';

enum LedgerEntryType { expense, income, transferOut, transferIn, adjustment }

enum IncomeType { salary, bonus, freelance, refund, other }

class LedgerEntry {
  final int id;
  final int accountId;
  final LedgerEntryType type;
  final Money amount; // signed; see Global Constraints sign convention
  final int? categoryId; // set for expense
  final IncomeType? incomeType; // set for income
  final String? transferId; // links the two rows of a transfer
  final Money allocated; // income only; zero otherwise
  final bool? planned; // expense planned-vs-unexpected
  final DateTime occurredAt;
  final String? note;

  const LedgerEntry({
    required this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.occurredAt,
    required this.allocated,
    this.categoryId,
    this.incomeType,
    this.transferId,
    this.planned,
    this.note,
  });
}
