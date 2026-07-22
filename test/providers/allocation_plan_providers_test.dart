import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/allocation/allocation_plan.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/features/allocation/allocation_plan_controller.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  Money m(int v) => Money(v, uzs);

  test('apply moves money and the daily limit recomputes from Sarf balance',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    final src = await db.into(db.accountsTable).insert(
        AccountsTableCompanion.insert(
            name: 'Sarf', type: 'bankCard',
            openingBalanceMinor: const Value(3000000), role: const Value('spending')));
    final dst = await db.into(db.accountsTable).insert(
        AccountsTableCompanion.insert(
            name: 'Zaxira', type: 'bankCard',
            openingBalanceMinor: const Value(0), role: const Value('reserve')));

    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    final before = await container.read(safeLimitProvider.future);
    expect(before.spendable, m(3000000));

    final controller = container.read(allocationPlanControllerProvider);
    final r = await controller.apply(src, [PlannedTransfer(dst, m(1000000))]);
    expect(r.isOk, isTrue);

    final after = await container.read(safeLimitProvider.future);
    expect(after.spendable, m(2000000)); // 1M moved to the excluded reserve card
    await db.close();
  });
}
