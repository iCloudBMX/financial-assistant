import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/accounts/accounts_controller.dart';
import 'package:financial_assistant/features/accounts/accounts_screen.dart';

void main() {
  testWidgets('renders an account with its formatted balance', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    await container.read(accountsControllerProvider.notifier).createAccount(
        name: 'Naqd', type: AccountType.cash,
        openingBalance: const Money(500000, CurrencyRegistry.uzs), icon: 'wallet');

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AccountsScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Naqd'), findsOneWidget);
    expect(
        find.text(const Money(500000, CurrencyRegistry.uzs).format()),
        findsOneWidget);
  });

  testWidgets('tapping an account tile opens the balance-adjust sheet',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    await container.read(accountsControllerProvider.notifier).createAccount(
        name: 'Naqd', type: AccountType.cash,
        openingBalance: const Money(500000, CurrencyRegistry.uzs), icon: 'wallet');

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AccountsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Naqd'));
    await tester.pumpAndSettle();

    expect(find.text('Haqiqiy balansni kiriting'), findsOneWidget);
  });
}
