import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/allocation/allocate_sheet.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  Future<int> seedIncome(AppDatabase db) async {
    await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(name: 'Cash', type: 'cash'),
        );
    return db.into(db.transactionsTable).insert(
          TransactionsTableCompanion.insert(
            accountId: 1,
            type: 'income',
            amountMinor: 1000000,
            currencyCode: 'UZS',
            occurredAt: DateTime(2026, 7, 5),
            createdAt: DateTime(2026, 7, 5),
          ),
        );
  }

  testWidgets(
      'untouched fields keep the previewed split (Taqsimlangan = income, '
      'Taqsimlanmagan = 0) and confirm persists it', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final incomeId = await seedIncome(db);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: AllocateSheet(
            incomeId: 1,
            income: Money(1000000, uzs),
          ),
        ),
      ),
    ));
    // Wait for the async preview() load to complete and rebuild.
    await tester.pumpAndSettle();

    // The seeded default template splits 1 000 000 fully (10% + remainder),
    // so an untouched sheet must show the full income allocated and zero
    // undistributed — NOT the zero-allocated bug where format()'s symbol
    // made every field re-parse to null.
    expect(find.text('Taqsimlangan: ${const Money(1000000, uzs).format()}'),
        findsOneWidget);
    expect(find.text('Taqsimlanmagan: ${const Money(0, uzs).format()}'),
        findsOneWidget);

    // Confirm without editing any field.
    await tester.tap(find.text('Tasdiqlash'));
    await tester.pumpAndSettle();

    final row = await (db.select(db.transactionsTable)
          ..where((t) => t.id.equals(incomeId)))
        .getSingle();
    expect(row.allocatedMinor, 1000000);
  });
}
