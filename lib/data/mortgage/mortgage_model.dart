import '../../core/mortgage/mortgage_engine.dart';

enum MortgageStatus { active, closed, archived }

class Mortgage {
  final int id;
  final String name;
  final String bank;
  final int initialLoanMinor;
  final int openingPrincipalMinor;
  final int annualRateBp;
  final DateTime startDate;
  final DateTime? endDate;
  final int mandatoryPaymentMinor;
  final DateTime nextPaymentDate;
  final PaymentType paymentType;
  final PayoffStrategy payoffStrategy;
  final String currencyCode;
  final MortgageStatus status;
  final int sortOrder;
  final DateTime createdAt;
  const Mortgage({
    required this.id,
    required this.name,
    required this.bank,
    required this.initialLoanMinor,
    required this.openingPrincipalMinor,
    required this.annualRateBp,
    required this.startDate,
    required this.endDate,
    required this.mandatoryPaymentMinor,
    required this.nextPaymentDate,
    required this.paymentType,
    required this.payoffStrategy,
    required this.currencyCode,
    required this.status,
    required this.sortOrder,
    required this.createdAt,
  });
}

/// Editable fields for create/update (no id/status/derived balance).
class MortgageDraft {
  final String name;
  final String bank;
  final int initialLoanMinor;
  final int openingPrincipalMinor;
  final int annualRateBp;
  final DateTime startDate;
  final DateTime? endDate;
  final int mandatoryPaymentMinor;
  final DateTime nextPaymentDate;
  final PaymentType paymentType;
  final PayoffStrategy payoffStrategy;
  final String currencyCode;
  const MortgageDraft({
    required this.name,
    this.bank = '',
    required this.initialLoanMinor,
    required this.openingPrincipalMinor,
    this.annualRateBp = 0,
    required this.startDate,
    this.endDate,
    required this.mandatoryPaymentMinor,
    required this.nextPaymentDate,
    this.paymentType = PaymentType.annuity,
    this.payoffStrategy = PayoffStrategy.unclear,
    this.currencyCode = 'UZS',
  });
}

/// The parts of one recorded payment (§13.3). Must sum to [totalMinor].
class MortgagePaymentSplit {
  final int totalMinor;
  final int principalMinor;
  final int interestMinor;
  final int commissionMinor;
  final int insuranceMinor;
  final int otherMinor;
  const MortgagePaymentSplit({
    required this.totalMinor,
    required this.principalMinor,
    this.interestMinor = 0,
    this.commissionMinor = 0,
    this.insuranceMinor = 0,
    this.otherMinor = 0,
  });
  int get sumOfParts =>
      principalMinor + interestMinor + commissionMinor + insuranceMinor + otherMinor;
  bool get isBalanced => sumOfParts == totalMinor;
}

class MortgagePayment {
  final int id;
  final int mortgageId;
  final int totalMinor;
  final int principalPortionMinor;
  final int interestPortionMinor;
  final int commissionMinor;
  final int insuranceMinor;
  final int otherMinor;
  final bool isExtra;
  final int? ledgerTransactionId;
  final String currencyCode;
  final DateTime occurredAt;
  final String? note;
  final DateTime createdAt;
  const MortgagePayment({
    required this.id,
    required this.mortgageId,
    required this.totalMinor,
    required this.principalPortionMinor,
    required this.interestPortionMinor,
    required this.commissionMinor,
    required this.insuranceMinor,
    required this.otherMinor,
    required this.isExtra,
    required this.ledgerTransactionId,
    required this.currencyCode,
    required this.occurredAt,
    required this.note,
    required this.createdAt,
  });
}

/// Aggregate figures for the §13.2 dashboard.
class MortgageTotals {
  final int paidMinor; // Σ total
  final int principalPaidMinor; // Σ principal portion
  final int interestPaidMinor; // Σ interest portion
  final int extraPaidMinor; // Σ total where isExtra
  const MortgageTotals({
    required this.paidMinor,
    required this.principalPaidMinor,
    required this.interestPaidMinor,
    required this.extraPaidMinor,
  });
}
