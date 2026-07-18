import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/home/home_screen.dart';

void main() {
  testWidgets('shows the total balance card', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    await container.read(accountRepositoryProvider).create(
        name: 'Naqd', type: AccountType.cash,
        openingBalance: const Money(1000000, CurrencyRegistry.uzs), icon: 'w');

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Jami'), findsWidgets);
    expect(find.textContaining('1 000 000'), findsWidgets);
  });
}
