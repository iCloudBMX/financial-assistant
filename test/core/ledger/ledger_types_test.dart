// test/core/ledger/ledger_types_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  test('Account exposes its currency from the opening balance', () {
    const acc = Account(
      id: 1,
      name: 'Naqd',
      type: AccountType.cash,
      openingBalance: Money(500000, uzs),
      icon: 'wallet',
      archived: false,
      role: AccountRole.spending,
    );
    expect(acc.currency, uzs);
    expect(acc.type, AccountType.cash);
  });

  test('LedgerEntry holds a signed amount and optional classification', () {
    final e = LedgerEntry(
      id: 10,
      accountId: 1,
      type: LedgerEntryType.expense,
      amount: const Money(-12000, uzs),
      categoryId: 3,
      allocated: const Money(0, uzs),
      occurredAt: DateTime(2026, 7, 18),
    );
    expect(e.amount.isNegative, isTrue);
    expect(e.categoryId, 3);
    expect(e.incomeType, isNull);
    expect(e.transferId, isNull);
  });
}
