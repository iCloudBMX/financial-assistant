import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/core/transactions/transaction_row_content.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  LedgerEntry e({
    LedgerEntryType type = LedgerEntryType.expense,
    String? note,
    IncomeType? incomeType,
  }) =>
      LedgerEntry(
        id: 1,
        accountId: 1,
        type: type,
        amount: const Money(-1000, uzs),
        occurredAt: DateTime(2026, 7, 18),
        allocated: const Money(0, uzs),
        note: note,
        incomeType: incomeType,
      );

  test('expense with a note: title=note, subtitle=category', () {
    final r = resolveRowContent(e(note: 'Coca Cola'),
        accountName: 'Naqd', categoryName: 'Oziq-ovqat');
    expect(r.title, 'Coca Cola');
    expect(r.subtitle, 'Oziq-ovqat');
  });

  test('expense without a note: title=category, subtitle=account', () {
    final r = resolveRowContent(e(note: '  '),
        accountName: 'Naqd', categoryName: 'Oziq-ovqat');
    expect(r.title, 'Oziq-ovqat');
    expect(r.subtitle, 'Naqd');
  });

  test('expense without note or category falls back to Chiqim', () {
    final r = resolveRowContent(e(), accountName: 'Naqd');
    expect(r.title, 'Chiqim');
    expect(r.subtitle, 'Naqd');
  });

  test('income without a note uses the income-type label as title', () {
    final r = resolveRowContent(
      e(type: LedgerEntryType.income, incomeType: IncomeType.salary),
      accountName: 'Karta',
    );
    expect(r.title, 'Maosh');
    expect(r.subtitle, 'Karta');
  });

  test('transfer leg keeps its operation label', () {
    final r = resolveRowContent(e(type: LedgerEntryType.transferOut));
    expect(r.title, "O'tkazma (chiqdi)");
    expect(r.subtitle, isNull);
  });
}
