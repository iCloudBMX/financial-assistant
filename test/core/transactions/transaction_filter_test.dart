import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/core/transactions/transaction_filter.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  LedgerEntry entry({
    int id = 1,
    int accountId = 1,
    LedgerEntryType type = LedgerEntryType.expense,
    required DateTime at,
  }) =>
      LedgerEntry(
        id: id,
        accountId: accountId,
        type: type,
        amount: const Money(-1000, uzs),
        occurredAt: at,
        allocated: const Money(0, uzs),
      );

  final e18 = entry(id: 1, at: DateTime(2026, 7, 18, 10));
  final e20 = entry(id: 2, at: DateTime(2026, 7, 20, 23, 59));
  final eAug = entry(id: 3, at: DateTime(2026, 8, 1, 0, 1));

  test('null period keeps every entry', () {
    final out = applyTransactionFilter([e18, e20, eAug], const TransactionFilter());
    expect(out, hasLength(3));
  });

  test('period is inclusive on both whole-day edges', () {
    final f = TransactionFilter(
      period: DateTimeRange(start: DateTime(2026, 7, 18), end: DateTime(2026, 7, 20)),
    );
    final out = applyTransactionFilter([e18, e20, eAug], f);
    expect(out.map((e) => e.id), [1, 2]);
  });

  test('accountIds keeps only matching accounts; empty set keeps all', () {
    final a = entry(id: 1, accountId: 5, at: DateTime(2026, 7, 18));
    final b = entry(id: 2, accountId: 9, at: DateTime(2026, 7, 18));
    expect(applyTransactionFilter([a, b], const TransactionFilter()).length, 2);
    expect(
      applyTransactionFilter([a, b], const TransactionFilter(accountIds: {5}))
          .map((e) => e.id),
      [1],
    );
  });

  test('types filter keeps matching types but always keeps adjustments', () {
    final inc = entry(id: 1, type: LedgerEntryType.income, at: DateTime(2026, 7, 18));
    final exp = entry(id: 2, type: LedgerEntryType.expense, at: DateTime(2026, 7, 18));
    final adj = entry(id: 3, type: LedgerEntryType.adjustment, at: DateTime(2026, 7, 18));
    final out = applyTransactionFilter(
      [inc, exp, adj],
      const TransactionFilter(types: {LedgerEntryType.income}),
    );
    expect(out.map((e) => e.id), [1, 3]);
  });

  test('currentMonthFilter spans the whole month and is labelled Bu oy', () {
    final f = currentMonthFilter(DateTime(2026, 7, 21, 14));
    expect(f.periodLabel, 'Bu oy');
    expect(f.period!.start, DateTime(2026, 7, 1));
    expect(f.period!.end, DateTime(2026, 7, 31));
  });
}
