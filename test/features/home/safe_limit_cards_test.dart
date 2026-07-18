import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/settings/settings_repository.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/home/safe_limit_cards.dart';

void main() {
  testWidgets('daily safe-limit card shows the per-day figure', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(
            name: 'Naqd',
            type: 'cash',
            openingBalanceMinor: const Value(100000000),
          ),
        );
    final base = await DriftSettingsRepository(db).read();
    await DriftSettingsRepository(db)
        .write(base.copyWith(variableBudget: const Money(1400000, CurrencyRegistry.uzs)));

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: Scaffold(body: SafeLimitCard())),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bugungi xavfsiz limit'), findsOneWidget);
    await db.close();
  });
}
