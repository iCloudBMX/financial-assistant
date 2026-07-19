import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/allocation/allocation_models.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/allocation/allocate_sheet.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  Future<int> seedIncome(AppDatabase db, {int amountMinor = 1000000}) async {
    await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(name: 'Cash', type: 'cash'),
        );
    return db.into(db.transactionsTable).insert(
          TransactionsTableCompanion.insert(
            accountId: 1,
            type: 'income',
            amountMinor: amountMinor,
            currencyCode: 'UZS',
            occurredAt: DateTime(2026, 7, 5),
            createdAt: DateTime(2026, 7, 5),
          ),
        );
  }

  Future<ProviderContainer> pumpSheet(
    WidgetTester tester, {
    required int incomeId,
    required Money income,
    required AppDatabase db,
  }) async {
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: AllocateSheet(incomeId: incomeId, income: income),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  FilledButton confirmButton(WidgetTester tester) => tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('allocate-confirm')),
          matching: find.byType(FilledButton),
        ),
      );

  testWidgets(
      'untouched fields keep the previewed split (Taqsimlangan = income, '
      'Taqsimlanmagan = 0) and confirm persists it', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final incomeId = await seedIncome(db);

    await pumpSheet(tester,
        incomeId: incomeId, income: const Money(1000000, uzs), db: db);

    // The seeded default template splits 1 000 000 fully (10% + remainder),
    // so an untouched sheet must show the full income allocated and zero
    // undistributed — NOT the zero-allocated bug where format()'s symbol
    // made every field re-parse to null.
    expect(find.text('Taqsimlangan: ${const Money(1000000, uzs).format()}'),
        findsOneWidget);
    expect(find.text('Taqsimlanmagan: ${const Money(0, uzs).format()}'),
        findsOneWidget);
    expect(confirmButton(tester).onPressed, isNotNull,
        reason: 'a balanced split must not disable confirm');

    // Confirm without editing any field.
    await tester.tap(find.text('Tasdiqlash'));
    await tester.pumpAndSettle();

    final row = await (db.select(db.transactionsTable)
          ..where((t) => t.id.equals(incomeId)))
        .getSingle();
    expect(row.allocatedMinor, 1000000);
  });

  testWidgets(
      'insufficient income: the shortfall is shown and confirm stays '
      'enabled (the natural split never over-allocates)', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(name: 'Cash', type: 'cash'),
        );
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    // A critical direction (mandatoryExpenses) first, a lower-priority
    // direction (minReserve) second — income can't fund both in full.
    await container.read(allocationRepositoryProvider).saveTemplate(const [
      AllocationDirection(
          bucketKey: 'mandatoryExpenses',
          method: AllocationMethod.fixedAmount,
          amount: Money(400000, uzs)),
      AllocationDirection(
          bucketKey: 'minReserve',
          method: AllocationMethod.fixedAmount,
          amount: Money(300000, uzs)),
    ]);
    final incomeId = await db.into(db.transactionsTable).insert(
          TransactionsTableCompanion.insert(
            accountId: 1,
            type: 'income',
            amountMinor: 500000,
            currencyCode: 'UZS',
            occurredAt: DateTime(2026, 7, 5),
            createdAt: DateTime(2026, 7, 5),
          ),
        );

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: AllocateSheet(incomeId: 1, income: Money(500000, uzs)),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // The critical direction is funded in full; the shortfall names the
    // reduced direction and the exact missing amount (§8.5).
    expect(find.textContaining('Minimal zaxira'), findsWidgets);
    expect(find.textContaining(const Money(200000, uzs).format()),
        findsWidgets);
    expect(confirmButton(tester).onPressed, isNotNull,
        reason: 'allocatedTotal (500000) <= income (500000): still valid');

    await tester.tap(find.text('Tasdiqlash'));
    await tester.pumpAndSettle();
    final row = await (db.select(db.transactionsTable)
          ..where((t) => t.id.equals(incomeId)))
        .getSingle();
    expect(row.allocatedMinor, 500000);
  });

  testWidgets(
      'editing a field to push allocatedTotal above income disables '
      'confirm (no over-allocation)', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final incomeId = await seedIncome(db);

    await pumpSheet(tester,
        incomeId: incomeId, income: const Money(1000000, uzs), db: db);
    expect(confirmButton(tester).onPressed, isNotNull);

    // Push the minReserve field well above the remaining room.
    await tester.enterText(
        find.byKey(const Key('allocate-amount-minReserve')), '900000');
    await tester.pumpAndSettle();

    expect(confirmButton(tester).onPressed, isNull,
        reason: 'allocatedTotal now exceeds income — confirm must disable');
  });
}
