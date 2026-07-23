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

  testWidgets(
      'balances right-align across rows with unequal balance widths',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    // Two accounts whose formatted balances have very different widths.
    await container.read(accountsControllerProvider.notifier).createAccount(
        name: 'Katta', type: AccountType.cash,
        openingBalance: const Money(50000000, CurrencyRegistry.uzs),
        icon: 'wallet');
    await container.read(accountsControllerProvider.notifier).createAccount(
        name: 'Kichik', type: AccountType.bankCard,
        openingBalance: const Money(1000, CurrencyRegistry.uzs),
        icon: 'wallet');

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AccountsScreen()),
    ));
    await tester.pumpAndSettle();

    // The balance figures must right-align to the same column.
    final big = tester.getTopRight(
        find.text(const Money(50000000, CurrencyRegistry.uzs).format()));
    final small = tester.getTopRight(
        find.text(const Money(1000, CurrencyRegistry.uzs).format()));
    expect(big.dx, moreOrLessEquals(small.dx, epsilon: 0.5));
  });

  testWidgets('swiping an account row archives it', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    await container.read(accountsControllerProvider.notifier).createAccount(
        name: 'Naqd', type: AccountType.cash,
        openingBalance: const Money(500000, CurrencyRegistry.uzs),
        icon: 'wallet');

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AccountsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Naqd'), findsOneWidget);
    // Swipe the row left (endToStart) to archive it; the list drops the row.
    await tester.drag(find.text('Naqd'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Naqd'), findsNothing);
  });

  testWidgets('selecting an account type does not change the chip width',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AccountsScreen()),
    ));
    await tester.pumpAndSettle();

    // Open the create sheet.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // "Bank kartasi" starts unselected; selecting it must not resize it (a
    // checkmark would widen it and reflow the Wrap).
    final chip = find.byKey(const Key('account-type-bankCard'));
    final before = tester.getSize(chip).width;
    await tester.tap(chip);
    await tester.pumpAndSettle();
    final after = tester.getSize(chip).width;
    expect(after, moreOrLessEquals(before, epsilon: 0.5));
  });

  testWidgets('tapping an account tile opens the full edit sheet', (tester) async {
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

    // Edit-mode title, and the balance field prefilled with the current
    // balance (grouped, symbol-less — Money.formatNumber()).
    expect(find.text('Hisobni tahrirlash'), findsOneWidget);
    expect(
        find.text(const Money(500000, CurrencyRegistry.uzs).formatNumber()),
        findsOneWidget);

    // Edit mode pre-selects the account's current type and role chips.
    expect(
        tester.widget<ChoiceChip>(find.byKey(const Key('account-type-cash'))).selected,
        isTrue);
    expect(
        tester.widget<ChoiceChip>(find.byKey(const Key('account-role-spending'))).selected,
        isTrue);
  });

  testWidgets('clearing the name and saving leaves the account name unchanged',
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

    await tester.enterText(find.byKey(const Key('account-name-field')), '');
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();

    // Empty name is treated as unchanged — the account keeps its name.
    expect(find.text('Naqd'), findsOneWidget);
  });

  testWidgets('editing an account name from the tile updates the list',
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

    await tester.enterText(find.byKey(const Key('account-name-field')), 'Karta');
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();

    expect(find.text('Karta'), findsOneWidget);
    expect(find.text('Naqd'), findsNothing);
  });
}
