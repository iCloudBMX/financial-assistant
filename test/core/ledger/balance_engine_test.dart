import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/result/failure.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/core/ledger/balance_engine.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  const usd = CurrencyRegistry.usd;

  Account acc(int id, {Currency c = uzs, int opening = 0}) => Account(
        id: id,
        name: 'A$id',
        type: AccountType.cash,
        openingBalance: Money(opening, c),
        icon: 'wallet',
        archived: false,
      );

  LedgerEntry entry(int accountId, LedgerEntryType type, int minor) => LedgerEntry(
        id: 0,
        accountId: accountId,
        type: type,
        amount: Money(minor, uzs),
        allocated: const Money(0, uzs),
        occurredAt: DateTime(2026, 7, 18),
      );

  test('balance is opening plus only this account\'s entries', () {
    final entries = [
      entry(1, LedgerEntryType.income, 1000000),
      entry(1, LedgerEntryType.expense, -250000),
      entry(2, LedgerEntryType.expense, -999999), // other account, ignored
    ];
    expect(accountBalance(acc(1, opening: 500000), entries),
        const Money(1250000, uzs));
  });

  test('adjustmentDelta is real minus current', () {
    expect(adjustmentDelta(const Money(300000, uzs), const Money(275000, uzs)),
        const Money(-25000, uzs));
  });

  test('buildTransfer produces a linked negative/positive pair', () {
    final r = buildTransfer(
      from: acc(1, opening: 1000000),
      to: acc(2),
      amount: const Money(300000, uzs),
      occurredAt: DateTime(2026, 7, 18),
      transferId: 'tr-1',
    );
    expect(r.isOk, isTrue);
    final d = r.valueOrNull!;
    expect(d.outEntry.accountId, 1);
    expect(d.outEntry.type, LedgerEntryType.transferOut);
    expect(d.outEntry.amount, const Money(-300000, uzs));
    expect(d.inEntry.accountId, 2);
    expect(d.inEntry.type, LedgerEntryType.transferIn);
    expect(d.inEntry.amount, const Money(300000, uzs));
    expect(d.outEntry.transferId, 'tr-1');
    expect(d.inEntry.transferId, 'tr-1');
  });

  test('buildTransfer rejects a cross-currency transfer', () {
    final r = buildTransfer(
      from: acc(1, c: uzs, opening: 1000000),
      to: acc(2, c: usd),
      amount: const Money(300000, uzs),
      occurredAt: DateTime(2026, 7, 18),
      transferId: 'tr-2',
    );
    expect(r.isOk, isFalse);
    r.when(ok: (_) => fail('expected failure'), err: (f) => expect(f, isA<ValidationFailure>()));
  });

  test('buildTransfer rejects a non-positive amount', () {
    final r = buildTransfer(
      from: acc(1, opening: 1000000),
      to: acc(2),
      amount: const Money(0, uzs),
      occurredAt: DateTime(2026, 7, 18),
      transferId: 'tr-3',
    );
    expect(r.isOk, isFalse);
  });
}
