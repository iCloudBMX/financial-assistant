import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/features/accounts/account_labels.dart';

void main() {
  test('role labels match the fixed Uzbek contract', () {
    expect(accountRoleLabel(AccountRole.spending), 'Sarf');
    expect(accountRoleLabel(AccountRole.reserve), 'Zaxira');
    expect(accountRoleLabel(AccountRole.credit), 'Kredit');
    expect(accountRoleLabel(AccountRole.savings), 'Jamg\'arma');
  });

  test('role helpers match the fixed contract', () {
    expect(accountRoleHelper(AccountRole.spending), 'Kundalik xarajatlar uchun');
    expect(accountRoleHelper(AccountRole.reserve), 'Favqulodda holatlar, tegilmaydi');
    expect(accountRoleHelper(AccountRole.credit), "Kredit to'lovlari uchun");
    expect(accountRoleHelper(AccountRole.savings), "Maqsad/jamg'arma uchun");
  });

  test('display order is spending, reserve, credit, savings', () {
    expect(accountRolesInDisplayOrder, const [
      AccountRole.spending,
      AccountRole.reserve,
      AccountRole.credit,
      AccountRole.savings,
    ]);
  });
}
