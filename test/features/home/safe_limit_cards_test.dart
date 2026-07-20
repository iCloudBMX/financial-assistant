import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/limit/safe_limit_engine.dart';
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

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    // The card is now a pure value widget; compute the limit through the
    // provider (the real derivation) and feed it in as a plain value, so this
    // still asserts the actual per-day figure renders in the headline.
    final limit = await container.read(safeLimitProvider.future);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SafeLimitCard(limit: limit))),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('BUGUN QOLDI'), findsOneWidget);
    // With no expenses today, remaining == perDay, so the hero's big number
    // still equals the per-day figure. Exact match pins it to the headline Text.
    expect(find.text(limit.todayRemaining.format()), findsOneWidget);
    // The daily allowance now lives in the supporting line.
    expect(find.textContaining('Kunlik limit'), findsOneWidget);
    await db.close();
  });

  testWidgets(
      'on-track hero shows today-remaining, not per-day, as the big number',
      (tester) async {
    const uzs = CurrencyRegistry.uzs;
    // On-track limit where todayRemaining != perDay, so the hero's big
    // number discriminates the new "today-remaining" behavior from the old
    // "per-day" rendering.
    const limit = SafeLimit(
      spendable: Money(150000, uzs),
      perDay: Money(50000, uzs),
      daysLeft: 5,
      todaySpent: Money(20000, uzs),
      todayRemaining: Money(30000, uzs),
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SafeLimitCard(limit: limit))),
    );
    await tester.pumpAndSettle();

    expect(find.text(const Money(30000, CurrencyRegistry.uzs).format()),
        findsOneWidget); // remaining shown
    expect(find.text(const Money(50000, CurrencyRegistry.uzs).format()),
        findsNothing); // per-day NOT the big number
    expect(find.textContaining('BUGUN QOLDI'), findsOneWidget);
  });

  testWidgets('over-limit card renders the offenders line', (tester) async {
    const uzs = CurrencyRegistry.uzs;
    // A limit already over for today (todayRemaining negative → status over).
    const limit = SafeLimit(
      spendable: Money(0, uzs),
      perDay: Money(50000, uzs),
      daysLeft: 5,
      todaySpent: Money(80000, uzs),
      todayRemaining: Money(-30000, uzs),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SafeLimitCard(limit: limit, overspendCategories: ['Oziq']),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Limitdan chiqqan: Oziq'), findsOneWidget);
  });

  testWidgets('over-limit hero shows zero left and plain-language overage',
      (tester) async {
    const uzs = CurrencyRegistry.uzs;
    const limit = SafeLimit(
      spendable: Money(0, uzs),
      perDay: Money(50000, uzs),
      daysLeft: 5,
      todaySpent: Money(80000, uzs),
      todayRemaining: Money(-30000, uzs),
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SafeLimitCard(limit: limit))),
    );
    await tester.pumpAndSettle();

    // Big number is 0, not a negative figure.
    expect(find.text(const Money(0, uzs).format()), findsOneWidget);
    expect(find.textContaining('oshdingiz'), findsOneWidget);
    // No naked negative anywhere on the card.
    expect(find.textContaining('-30'), findsNothing);
    expect(find.textContaining('−30'), findsNothing);
  });
}
