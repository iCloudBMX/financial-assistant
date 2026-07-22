import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/features/allocation/allocation_rule_sheet.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  testWidgets(
      'Saqlash enables from the shown destination card without an explicit tap',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final src = await db.into(db.accountsTable).insert(
        AccountsTableCompanion.insert(
            name: 'Sarf',
            type: 'bankCard',
            openingBalanceMinor: const Value(2000000),
            role: const Value('spending')));
    final dst1 = await db.into(db.accountsTable).insert(
        AccountsTableCompanion.insert(
            name: 'Kredit',
            type: 'bankCard',
            openingBalanceMinor: const Value(0),
            role: const Value('credit')));
    await db.into(db.accountsTable).insert(AccountsTableCompanion.insert(
        name: 'Jamgarma',
        type: 'bankCard',
        openingBalanceMinor: const Value(0),
        role: const Value('savings')));

    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(() {
      container.dispose();
      db.close();
    });

    ({int destinationAccountId, Money amount})? result;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => ElevatedButton(
              onPressed: () async {
                result = await showAllocationRuleSheet(context, ref,
                    sourceAccountId: src);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The sheet is open with a destination card shown. Enter an amount but do
    // NOT tap any destination card.
    await tester.enterText(find.byType(TextField).last, '5000');
    await tester.pumpAndSettle();

    // Saqlash must be enabled (the visible first card is the effective
    // destination) and must return that first destination.
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();

    expect(result, isNotNull,
        reason: 'Saqlash should be enabled from the shown card without a tap');
    expect(result!.amount.minorUnits, 5000);
    expect(result!.destinationAccountId, dst1,
        reason: 'first non-source card (Kredit) is the default destination');
  });
}
