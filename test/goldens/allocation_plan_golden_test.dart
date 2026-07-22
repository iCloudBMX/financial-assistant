import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/allocation/allocation_plan.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/features/accounts/accounts_controller.dart';
import 'package:financial_assistant/features/allocation/allocation_plan_controller.dart';
import 'package:financial_assistant/features/allocation/allocation_plan_screen.dart';
import 'package:financial_assistant/providers/app_providers.dart';

import '../support/golden_devices.dart';
import '../support/velora_test_app.dart';

Future<ProviderContainer> _seeded() async {
  const uzs = CurrencyRegistry.uzs;
  final db = AppDatabase(NativeDatabase.memory());
  final src = await db.into(db.accountsTable).insert(
      AccountsTableCompanion.insert(
          name: 'Asosiy Sarf', type: 'bankCard',
          openingBalanceMinor: const Value(3000000), role: const Value('spending')));
  final dst1 = await db.into(db.accountsTable).insert(
      AccountsTableCompanion.insert(
          name: 'Kredit', type: 'bankCard',
          openingBalanceMinor: const Value(0), role: const Value('credit')));
  final dst2 = await db.into(db.accountsTable).insert(
      AccountsTableCompanion.insert(
          name: "Jamg'arma", type: 'bankCard',
          openingBalanceMinor: const Value(0), role: const Value('savings')));
  final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)]);
  addTearDown(() {
    container.dispose();
    db.close();
  });
  await container.read(allocationPlanControllerProvider).setSource(src);
  await container.read(allocationPlanControllerProvider).saveRules([
    AllocationRule(destinationAccountId: dst1, amount: const Money(500000, uzs), sortOrder: 0),
    AllocationRule(destinationAccountId: dst2, amount: const Money(300000, uzs), sortOrder: 1),
  ]);
  await container.read(allocationPlanProvider.future);
  await container.read(accountsControllerProvider.future);
  return container;
}

void main() {
  testWidgets('allocation plan screen at 390px light', (tester) async {
    final container = await _seeded();
    await pumpVelora(
      tester,
      child: UncontrolledProviderScope(
        container: container,
        child: const AllocationPlanScreen(),
      ),
      size: phone390,
      brightness: Brightness.light,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(AllocationPlanScreen),
      matchesGoldenFile('baselines/allocation-plan-light-390.png'),
    );
  });
}
