import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  test('safeLimitProvider sums only Sarf-role account balances', () async {
    final db = AppDatabase(NativeDatabase.memory());
    // Spending card: 8,000,000. Reserve card: 5,000,000 (must be excluded).
    await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(
            name: 'Asosiy',
            type: 'bankCard',
            openingBalanceMinor: const Value(8000000),
            role: const Value('spending'),
          ),
        );
    await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(
            name: 'Zaxira',
            type: 'bankCard',
            openingBalanceMinor: const Value(5000000),
            role: const Value('reserve'),
          ),
        );

    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    final limit = await container.read(safeLimitProvider.future);
    // Only the 8,000,000 Sarf balance is in the pool; reserve is excluded.
    expect(limit.spendable.minorUnits, 8000000);
    // perDay = pool / daysLeft; daysLeft depends on the period, so assert the
    // invariant rather than a hard-coded quotient.
    expect(limit.perDay.minorUnits, 8000000 ~/ limit.daysLeft);
    expect(limit.hasSpendingAccounts, isTrue);
    await db.close();
  });

  test('safeLimitProvider flags a present-but-empty spending pool', () async {
    // A Sarf card exists but its balance nets to zero: hasSpendingAccounts is
    // still true, so SP-C must NOT show the "add a spending card" hint here.
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(
            name: 'Asosiy',
            type: 'bankCard',
            openingBalanceMinor: const Value(0),
            role: const Value('spending'),
          ),
        );

    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    final limit = await container.read(safeLimitProvider.future);
    expect(limit.spendable.minorUnits, 0);
    expect(limit.perDay.minorUnits, 0);
    expect(limit.hasSpendingAccounts, isTrue);
    await db.close();
  });

  test('safeLimitProvider is zero and unflagged with no Sarf accounts',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(
            name: 'Jamgarma',
            type: 'savings',
            openingBalanceMinor: const Value(3000000),
            role: const Value('savings'),
          ),
        );

    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    final limit = await container.read(safeLimitProvider.future);
    expect(limit.spendable.minorUnits, 0);
    expect(limit.perDay.minorUnits, 0);
    expect(limit.hasSpendingAccounts, isFalse);
    await db.close();
  });
}
