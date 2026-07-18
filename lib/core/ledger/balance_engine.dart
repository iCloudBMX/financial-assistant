import '../money/money.dart';
import '../result/failure.dart';
import '../result/result.dart';
import 'account.dart';
import 'ledger_entry.dart';

Money accountBalance(Account account, Iterable<LedgerEntry> entries) {
  var total = account.openingBalance;
  for (final e in entries) {
    if (e.accountId != account.id) continue;
    total = total.add(e.amount); // same-currency; throws on mismatch
  }
  return total;
}

Money adjustmentDelta(Money currentBalance, Money realBalance) =>
    realBalance.subtract(currentBalance);

class TransferDraft {
  final LedgerEntry outEntry;
  final LedgerEntry inEntry;
  const TransferDraft(this.outEntry, this.inEntry);
}

Result<TransferDraft> buildTransfer({
  required Account from,
  required Account to,
  required Money amount,
  required DateTime occurredAt,
  required String transferId,
  String? note,
}) {
  if (from.currency != to.currency || amount.currency != from.currency) {
    return const Err(ValidationFailure('transfer currencies must match'));
  }
  if (amount.minorUnits <= 0) {
    return const Err(ValidationFailure('transfer amount must be positive'));
  }
  final out = LedgerEntry(
    id: 0,
    accountId: from.id,
    type: LedgerEntryType.transferOut,
    amount: amount.negate(),
    allocated: Money.zero(from.currency),
    occurredAt: occurredAt,
    transferId: transferId,
    note: note,
  );
  final inbound = LedgerEntry(
    id: 0,
    accountId: to.id,
    type: LedgerEntryType.transferIn,
    amount: amount,
    allocated: Money.zero(to.currency),
    occurredAt: occurredAt,
    transferId: transferId,
    note: note,
  );
  return Ok(TransferDraft(out, inbound));
}
