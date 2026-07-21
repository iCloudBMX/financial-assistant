import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  test('AccountRole has the four fixed roles in order', () {
    expect(AccountRole.values,
        [AccountRole.spending, AccountRole.reserve, AccountRole.credit, AccountRole.savings]);
    expect(AccountRole.spending.name, 'spending');
    expect(AccountRole.savings.name, 'savings');
  });

  test('Account carries a role', () {
    const a = Account(
      id: 1,
      name: 'Naqd',
      type: AccountType.cash,
      openingBalance: Money(0, uzs),
      icon: 'wallet',
      archived: false,
      role: AccountRole.reserve,
    );
    expect(a.role, AccountRole.reserve);
  });
}
