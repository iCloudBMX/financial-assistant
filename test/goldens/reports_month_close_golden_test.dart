// Task 8 (reports-month-close plan): golden gallery entries for the two
// screens the plan added -- ReportsScreen (Tahlil tab) and MonthCloseScreen
// (§16.1 soft-ceremony close, pushed from the Reports month-close banner).
//
// Mirrors the existing-flow gallery's structure (`_freshContainer`/
// `_seedAccount` helpers, `pumpVelora` at `phone390`, `takeException()` guard
// before `matchesGoldenFile`) rather than inventing a new seeding pattern.
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/features/month_close/month_close_data.dart';
import 'package:financial_assistant/features/month_close/month_close_screen.dart';
import 'package:financial_assistant/features/reports/reports_screen.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/providers/month_close_providers.dart';

import '../support/golden_devices.dart';
import '../support/velora_test_app.dart';

const _uzs = CurrencyRegistry.uzs;

Future<(AppDatabase, ProviderContainer)> _freshContainer(
    WidgetTester tester) async {
  final db = AppDatabase(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
  addTearDown(() {
    container.dispose();
    db.close();
  });
  return (db, container);
}

Future<int> _seedAccount(ProviderContainer container,
    {String name = 'Naqd', int balanceMinor = 5000000}) {
  return container.read(accountRepositoryProvider).create(
        name: name,
        type: AccountType.cash,
        openingBalance: Money(balanceMinor, _uzs),
        icon: 'payments',
      );
}

void main() {
  // ---------------------------------------------------------------------
  // 1. Reports screen -- default Oylik (monthly) tab.
  // ---------------------------------------------------------------------
  group('Reports screen', () {
    Future<ProviderContainer> seeded(WidgetTester tester) async {
      final (_, container) = await _freshContainer(tester);
      final cardId = await _seedAccount(container,
          name: 'Karta', balanceMinor: 8000000);
      final ledger = container.read(ledgerRepositoryProvider);
      final now = DateTime.now();
      await ledger.addIncome(
          accountId: cardId,
          amount: const Money(4500000, _uzs),
          incomeType: IncomeType.salary,
          occurredAt: now);
      await ledger.addExpense(
          accountId: cardId,
          amount: const Money(350000, _uzs),
          categoryId: 1,
          occurredAt: now,
          note: 'Oziq-ovqat');
      container.read(ledgerRevisionProvider.notifier).state++;
      return container;
    }

    testWidgets(
        'matches the approved monthly summary hierarchy at 390px light',
        (tester) async {
      final container = await seeded(tester);
      await pumpVelora(
        tester,
        child: UncontrolledProviderScope(
            container: container, child: const ReportsScreen()),
        size: phone390,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(ReportsScreen),
        matchesGoldenFile('baselines/reports-monthly-light-390.png'),
      );
    });
  });

  // ---------------------------------------------------------------------
  // 2. Month-close screen -- §16.1 summary + leftover-distribution chooser.
  // `monthCloseProvider` only returns non-null when there is an elapsed,
  // unclosed period; a fresh settings row has `lastClosedPeriodStart ==
  // null`, so the just-elapsed calendar period is closeable by default --
  // no special seeding is needed to reach the loaded state. Entries are
  // dated inside that closeable period (via the same `closeablePeriod` pure
  // function the provider uses) so the period's income/expense actually
  // render non-zero.
  // ---------------------------------------------------------------------
  group('Month-close screen', () {
    Future<ProviderContainer> seeded(WidgetTester tester) async {
      final (_, container) = await _freshContainer(tester);
      final cardId = await _seedAccount(container,
          name: 'Karta', balanceMinor: 6000000);
      final period = closeablePeriod(DateTime.now(), 1, null)!;
      final inPeriod = period.start.add(const Duration(days: 5));
      final ledger = container.read(ledgerRepositoryProvider);
      await ledger.addIncome(
          accountId: cardId,
          amount: const Money(4500000, _uzs),
          incomeType: IncomeType.salary,
          occurredAt: inPeriod);
      await ledger.addExpense(
          accountId: cardId,
          amount: const Money(1200000, _uzs),
          categoryId: 1,
          occurredAt: inPeriod,
          note: 'Ijara');
      container.read(ledgerRevisionProvider.notifier).state++;
      await container.read(monthCloseProvider.future);
      return container;
    }

    testWidgets(
        'matches the approved summary + leftover-distribution hierarchy at '
        '390px light', (tester) async {
      final container = await seeded(tester);
      await pumpVelora(
        tester,
        child: UncontrolledProviderScope(
            container: container, child: const MonthCloseScreen()),
        size: phone390,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MonthCloseScreen),
        matchesGoldenFile('baselines/month-close-light-390.png'),
      );
    });
  });
}
