// Task 7 (existing-flows plan): visual-fidelity checkpoint.
//
// This gallery closes the golden-coverage gap earlier redesign tasks left
// behind: it locks baselines for every screen/sheet/dialog that Task 3
// (expense, income, recurring, accounts, history), Task 4 (category editor)
// and Task 5 (mortgage setup, goal completion) touched but never captured a
// golden for, and adds the loading/empty/error states the main-screen
// golden files (home/plan-budget/goals-mortgage/onboarding-settings-lock)
// didn't exercise.
//
// Every `testWidgets` asserts `tester.takeException()` is null before
// `matchesGoldenFile`, so a real overflow/exception at 320px or 200% text
// scale fails the test instead of silently rendering into the PNG.
//
// Tests that open a sheet/dialog (a NEW route pushed on top of the pumped
// screen) pass `container:` to `pumpVelora` instead of wrapping `child` in
// `UncontrolledProviderScope` themselves -- see the doc comment on
// `pumpVelora` in `test/support/velora_test_app.dart` for why that
// placement matters (a scope wrapping only the first route isn't an
// ancestor of a route pushed later on the same Navigator).
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/mortgage/mortgage_engine.dart';
import 'package:financial_assistant/core/theme/velora_tokens.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/goals/goal_model.dart';
import 'package:financial_assistant/data/mortgage/mortgage_model.dart';
import 'package:financial_assistant/data/recurring/recurring_model.dart';
import 'package:financial_assistant/features/accounts/accounts_controller.dart';
import 'package:financial_assistant/features/accounts/accounts_screen.dart';
import 'package:financial_assistant/features/accounts/transfer_sheet.dart';
import 'package:financial_assistant/features/budgets/budgets_screen.dart';
import 'package:financial_assistant/features/budgets/category_edit_sheet.dart';
import 'package:financial_assistant/features/expense_entry/expense_entry_sheet.dart';
import 'package:financial_assistant/features/goals/goal_completed_dialog.dart';
import 'package:financial_assistant/features/goals/goal_controller.dart';
import 'package:financial_assistant/features/goals/goals_screen.dart';
import 'package:financial_assistant/features/home/dashboard_data.dart';
import 'package:financial_assistant/features/home/home_screen.dart';
import 'package:financial_assistant/features/income_entry/income_entry_sheet.dart';
import 'package:financial_assistant/features/mortgage/mortgage_dashboard_screen.dart';
import 'package:financial_assistant/features/mortgage/mortgage_edit_sheet.dart';
import 'package:financial_assistant/features/recurring/recurring_prompt.dart';
import 'package:financial_assistant/features/transactions/transactions_controller.dart';
import 'package:financial_assistant/features/transactions/transactions_screen.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/ui/components/velora_sheet.dart';

import '../support/golden_devices.dart';
import '../support/velora_test_app.dart';

const _uzs = CurrencyRegistry.uzs;

/// A future that never completes -- pumps a provider into a permanent
/// `AsyncLoading` so a golden can capture the loading branch deterministically
/// (no timers, so nothing needs to fire for the test to finish).
Future<T> _never<T>() => Completer<T>().future;

/// A future that fails -- pumps a provider into `AsyncError` so a golden can
/// capture the error branch. Throws a `StateError` (an `Error`, not a plain
/// `Exception`) deliberately: Riverpod's default retry policy
/// (`ProviderContainer.defaultRetry`) skips scheduling a retry when `error
/// is Error`, which keeps this deterministic -- a plain `Exception` gets
/// auto-retried on a real `Timer` with exponential backoff, and that timer
/// is still pending (and fails the binding's "no pending timers" teardown
/// invariant) by the time the golden is captured.
Future<T> _boom<T>() async => throw StateError('golden: forced failure');

class _LoadingAccounts extends AccountsController {
  @override
  Future<List<AccountWithBalance>> build() => _never();
}

class _ErrorAccounts extends AccountsController {
  @override
  Future<List<AccountWithBalance>> build() => _boom();
}

class _LoadingTransactions extends TransactionsController {
  @override
  Future<List<LedgerEntry>> build() => _never();
}

class _ErrorTransactions extends TransactionsController {
  @override
  Future<List<LedgerEntry>> build() => _boom();
}

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

/// Pumps a loading-state golden: `pumpVelora(..., settle: false)` (an
/// indeterminate spinner never lets `pumpAndSettle` finish), then a couple
/// of bounded frames so any entrance transition (e.g. a modal sheet sliding
/// up) has time to finish without waiting on the spinner's animation.
Future<void> _pumpLoading(
  WidgetTester tester, {
  required Widget child,
  required Size size,
  ProviderContainer? container,
}) async {
  await pumpVelora(tester,
      child: child, size: size, container: container, settle: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  // ---------------------------------------------------------------------
  // 1. Expense entry sheet (Task 3, previously ungoldened).
  // ---------------------------------------------------------------------
  group('Expense entry sheet', () {
    Future<ProviderContainer> seeded(WidgetTester tester) async {
      final (_, container) = await _freshContainer(tester);
      await _seedAccount(container, name: 'Karta', balanceMinor: 12000000);
      await _seedAccount(container, name: 'Naqd', balanceMinor: 2400000);
      return container;
    }

    Widget trigger() => Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showExpenseEntrySheet(context, ref),
                child: const Text('open'),
              ),
            ),
          ),
        );

    testWidgets('matches the approved amount-first hierarchy at 390px light',
        (tester) async {
      final container = await seeded(tester);
      await pumpVelora(tester,
          container: container, child: trigger(), size: phone390);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(VeloraSheetScaffold),
        matchesGoldenFile('baselines/expense-entry-light-390.png'),
      );
    });

    testWidgets('reflows without overflow at 320px dark 200% text scale',
        (tester) async {
      final container = await seeded(tester);
      await pumpVelora(
        tester,
        container: container,
        child: trigger(),
        size: phone320,
        brightness: Brightness.dark,
        textScale: textScale200,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(VeloraSheetScaffold),
        matchesGoldenFile('baselines/expense-entry-dark-320-scale200.png'),
      );
    });

    testWidgets(
        'empty state: a fresh user with no account is guided to create one '
        'before an expense can be booked', (tester) async {
      final (_, container) = await _freshContainer(tester);
      // No account seeded on purpose -- this is the "empty" state.
      await pumpVelora(tester,
          container: container, child: trigger(), size: phone390);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(AlertDialog),
        matchesGoldenFile('baselines/expense-entry-empty-light-390.png'),
      );
    });
  });

  // ---------------------------------------------------------------------
  // 2. Income entry sheet (Task 3, previously ungoldened). Shares the same
  // amount-first/account-picker/details pattern as expense entry, so this
  // gallery limits itself to the states income entry adds on top: the
  // income-type chips and the recurring-income toggle+interval selector
  // (loading/empty placeholders are structurally identical to expense
  // entry's, already captured above).
  // ---------------------------------------------------------------------
  group('Income entry sheet', () {
    Future<ProviderContainer> seeded(WidgetTester tester) async {
      final (_, container) = await _freshContainer(tester);
      await _seedAccount(container);
      return container;
    }

    Widget trigger() => Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showIncomeEntrySheet(context, ref),
                child: const Text('open'),
              ),
            ),
          ),
        );

    testWidgets(
        'matches the approved income-type + recurring-toggle hierarchy at '
        '390px light', (tester) async {
      final container = await seeded(tester);
      await pumpVelora(tester,
          container: container, child: trigger(), size: phone390);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // Turn the recurring switch on so the interval selector -- the most
      // layout-sensitive addition -- renders in the captured frame.
      await tester.tap(find.byKey(const Key('income-recurring-switch')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(VeloraSheetScaffold),
        matchesGoldenFile('baselines/income-entry-light-390.png'),
      );
    });

    testWidgets('reflows without overflow at 320px dark 200% text scale',
        (tester) async {
      final container = await seeded(tester);
      await pumpVelora(
        tester,
        container: container,
        child: trigger(),
        size: phone320,
        brightness: Brightness.dark,
        textScale: textScale200,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('income-recurring-switch')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(VeloraSheetScaffold),
        matchesGoldenFile('baselines/income-entry-dark-320-scale200.png'),
      );
    });
  });

  // ---------------------------------------------------------------------
  // 3. Recurring-income prompt banner (Task 3, previously ungoldened).
  // ---------------------------------------------------------------------
  group('Recurring income prompt', () {
    Future<ProviderContainer> seededWithDuePlan(WidgetTester tester) async {
      final (_, container) = await _freshContainer(tester);
      final accountId = await _seedAccount(container);
      await container.read(recurringIncomeRepositoryProvider).create(
            accountId: accountId,
            amount: const Money(4500000, _uzs),
            incomeType: IncomeType.salary,
            intervalKind: IntervalKind.monthly,
            anchorDay: 1,
            nextDueAt: DateTime.now().subtract(const Duration(days: 1)),
          );
      await container.read(recurringPromptControllerProvider.future);
      return container;
    }

    Widget banner() => const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(VeloraSpacing.lg),
            child: RecurringPromptBanner(),
          ),
        );

    testWidgets(
        'due-plan card matches the approved confirm/edit/postpone/skip '
        'actions at 390px light', (tester) async {
      final container = await seededWithDuePlan(tester);
      await pumpVelora(
        tester,
        child: UncontrolledProviderScope(container: container, child: banner()),
        size: phone390,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(RecurringPromptBanner),
        matchesGoldenFile('baselines/recurring-prompt-light-390.png'),
      );
    });

    testWidgets('reflows without overflow at 320px dark 200% text scale',
        (tester) async {
      final container = await seededWithDuePlan(tester);
      await pumpVelora(
        tester,
        child: UncontrolledProviderScope(container: container, child: banner()),
        size: phone320,
        brightness: Brightness.dark,
        textScale: textScale200,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(RecurringPromptBanner),
        matchesGoldenFile('baselines/recurring-prompt-dark-320-scale200.png'),
      );
    });
  });

  // ---------------------------------------------------------------------
  // 4. Accounts screen/carousel (Task 3, previously ungoldened). Full
  // loading/empty/error matrix applies -- the screen codes all three.
  // ---------------------------------------------------------------------
  group('Accounts carousel', () {
    Future<ProviderContainer> seeded(WidgetTester tester) async {
      final (_, container) = await _freshContainer(tester);
      await _seedAccount(container, name: 'Karta', balanceMinor: 12500000);
      await _seedAccount(container, name: 'Jamg\'arma', balanceMinor: 3000000);
      await container.read(accountsControllerProvider.future);
      return container;
    }

    testWidgets('matches the approved account-card list at 390px light',
        (tester) async {
      final container = await seeded(tester);
      await pumpVelora(
        tester,
        child: UncontrolledProviderScope(
            container: container, child: const AccountsScreen()),
        size: phone390,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(AccountsScreen),
        matchesGoldenFile('baselines/accounts-light-390.png'),
      );
    });

    testWidgets('reflows without overflow at 320px dark 200% text scale',
        (tester) async {
      final container = await seeded(tester);
      await pumpVelora(
        tester,
        child: UncontrolledProviderScope(
            container: container, child: const AccountsScreen()),
        size: phone320,
        brightness: Brightness.dark,
        textScale: textScale200,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(AccountsScreen),
        matchesGoldenFile('baselines/accounts-dark-320-scale200.png'),
      );
    });

    testWidgets('loading state shows the centered spinner', (tester) async {
      final (_, baseContainer) = await _freshContainer(tester);
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(baseContainer.read(databaseProvider)),
        accountsControllerProvider.overrideWith(_LoadingAccounts.new),
      ]);
      addTearDown(container.dispose);
      await _pumpLoading(tester,
          child: UncontrolledProviderScope(
              container: container, child: const AccountsScreen()),
          size: phone390);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(AccountsScreen),
        matchesGoldenFile('baselines/accounts-loading-light-390.png'),
      );
    });

    testWidgets(
        'empty state guides a fresh user to create their first account',
        (tester) async {
      final (_, container) = await _freshContainer(tester);
      // No account seeded -- genuine empty state.
      await pumpVelora(
        tester,
        child: UncontrolledProviderScope(
            container: container, child: const AccountsScreen()),
        size: phone390,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(AccountsScreen),
        matchesGoldenFile('baselines/accounts-empty-light-390.png'),
      );
    });

    testWidgets('error state offers a retry action', (tester) async {
      final (_, baseContainer) = await _freshContainer(tester);
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(baseContainer.read(databaseProvider)),
        accountsControllerProvider.overrideWith(_ErrorAccounts.new),
      ]);
      addTearDown(container.dispose);
      await pumpVelora(
        tester,
        child: UncontrolledProviderScope(
            container: container, child: const AccountsScreen()),
        size: phone390,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(AccountsScreen),
        matchesGoldenFile('baselines/accounts-error-light-390.png'),
      );
    });
  });

  // ---------------------------------------------------------------------
  // 5. Transfer sheet (Task 3, previously ungoldened). `showTransferSheet`
  // awaits `accountsControllerProvider.future` before the sheet ever
  // mounts, so the sheet's own internal loading/error branches are
  // unreachable through normal navigation -- only default + reflow apply.
  // ---------------------------------------------------------------------
  group('Transfer sheet', () {
    Future<ProviderContainer> seeded(WidgetTester tester) async {
      final (_, container) = await _freshContainer(tester);
      await _seedAccount(container, name: 'Karta', balanceMinor: 8000000);
      await _seedAccount(container, name: 'Naqd', balanceMinor: 1500000);
      return container;
    }

    Widget trigger() => Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showTransferSheet(context, ref),
                child: const Text('open'),
              ),
            ),
          ),
        );

    testWidgets(
        'matches the approved from/to account-picker hierarchy at 390px '
        'light', (tester) async {
      final container = await seeded(tester);
      await pumpVelora(tester,
          container: container, child: trigger(), size: phone390);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(VeloraSheetScaffold),
        matchesGoldenFile('baselines/transfer-light-390.png'),
      );
    });

    testWidgets('reflows without overflow at 320px dark 200% text scale',
        (tester) async {
      final container = await seeded(tester);
      await pumpVelora(
        tester,
        container: container,
        child: trigger(),
        size: phone320,
        brightness: Brightness.dark,
        textScale: textScale200,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(VeloraSheetScaffold),
        matchesGoldenFile('baselines/transfer-dark-320-scale200.png'),
      );
    });
  });

  // ---------------------------------------------------------------------
  // 6. Transactions / history (Task 3, previously ungoldened). Full
  // loading/empty/error matrix applies.
  // ---------------------------------------------------------------------
  group('Transactions / history', () {
    Future<ProviderContainer> seeded(WidgetTester tester) async {
      final (_, container) = await _freshContainer(tester);
      final cardId = await _seedAccount(container, name: 'Karta');
      final cashId =
          await _seedAccount(container, name: 'Naqd', balanceMinor: 1000000);
      final ledger = container.read(ledgerRepositoryProvider);
      // A fixed time-of-day on *today* so entries still group under "Bugun"
      // (and the adjustment a day back under "Kecha") while the rendered row
      // time stays deterministic — seeding raw DateTime.now() made this golden
      // flake whenever the run crossed a minute boundary.
      final today = DateTime.now();
      final now = DateTime(today.year, today.month, today.day, 9, 41);
      await ledger.addExpense(
          accountId: cardId,
          amount: const Money(85000, _uzs),
          categoryId: 1,
          occurredAt: now,
          note: 'Tushlik');
      await ledger.addIncome(
          accountId: cardId,
          amount: const Money(3000000, _uzs),
          incomeType: IncomeType.salary,
          occurredAt: now);
      await ledger.transfer(
          fromId: cardId,
          toId: cashId,
          amount: const Money(200000, _uzs),
          occurredAt: now);
      await ledger.adjustBalance(
          accountId: cashId,
          realBalance: const Money(1100000, _uzs),
          occurredAt: now.subtract(const Duration(days: 1)));
      container.read(ledgerRevisionProvider.notifier).state++;
      await container.read(transactionsControllerProvider.future);
      return container;
    }

    testWidgets(
        'matches the approved grouped-by-day list (expense/income/transfer/'
        'adjustment labels) at 390px light', (tester) async {
      final container = await seeded(tester);
      await pumpVelora(
        tester,
        child: UncontrolledProviderScope(
            container: container, child: const TransactionsScreen()),
        size: phone390,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(TransactionsScreen),
        matchesGoldenFile('baselines/transactions-light-390.png'),
      );
    });

    testWidgets('reflows without overflow at 320px dark 200% text scale',
        (tester) async {
      final container = await seeded(tester);
      await pumpVelora(
        tester,
        child: UncontrolledProviderScope(
            container: container, child: const TransactionsScreen()),
        size: phone320,
        brightness: Brightness.dark,
        textScale: textScale200,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(TransactionsScreen),
        matchesGoldenFile('baselines/transactions-dark-320-scale200.png'),
      );
    });

    testWidgets('loading state shows the centered spinner', (tester) async {
      final (_, baseContainer) = await _freshContainer(tester);
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(baseContainer.read(databaseProvider)),
        transactionsControllerProvider.overrideWith(_LoadingTransactions.new),
      ]);
      addTearDown(container.dispose);
      await _pumpLoading(tester,
          child: UncontrolledProviderScope(
              container: container, child: const TransactionsScreen()),
          size: phone390);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(TransactionsScreen),
        matchesGoldenFile('baselines/transactions-loading-light-390.png'),
      );
    });

    testWidgets('empty state matches the approved first-transaction nudge',
        (tester) async {
      final (_, container) = await _freshContainer(tester);
      await pumpVelora(
        tester,
        child: UncontrolledProviderScope(
            container: container, child: const TransactionsScreen()),
        size: phone390,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(TransactionsScreen),
        matchesGoldenFile('baselines/transactions-empty-light-390.png'),
      );
    });

    testWidgets('error state offers a retry action', (tester) async {
      final (_, baseContainer) = await _freshContainer(tester);
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(baseContainer.read(databaseProvider)),
        transactionsControllerProvider.overrideWith(_ErrorTransactions.new),
      ]);
      addTearDown(container.dispose);
      await pumpVelora(
        tester,
        child: UncontrolledProviderScope(
            container: container, child: const TransactionsScreen()),
        size: phone390,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(TransactionsScreen),
        matchesGoldenFile('baselines/transactions-error-light-390.png'),
      );
    });
  });

  // ---------------------------------------------------------------------
  // 7. Category editor (Task 4, previously ungoldened). Full
  // loading/empty(no search match)/error matrix applies.
  // ---------------------------------------------------------------------
  group('Category editor', () {
    Widget trigger() => Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showCategoryEditSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        );

    testWidgets(
        'matches the approved searchable category list at 390px light',
        (tester) async {
      final (_, container) = await _freshContainer(tester);
      await pumpVelora(tester,
          container: container, child: trigger(), size: phone390);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(VeloraSheetScaffold),
        matchesGoldenFile('baselines/category-editor-light-390.png'),
      );
    });

    testWidgets('reflows without overflow at 320px dark 200% text scale',
        (tester) async {
      final (_, container) = await _freshContainer(tester);
      await pumpVelora(
        tester,
        container: container,
        child: trigger(),
        size: phone320,
        brightness: Brightness.dark,
        textScale: textScale200,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(VeloraSheetScaffold),
        matchesGoldenFile('baselines/category-editor-dark-320-scale200.png'),
      );
    });

    testWidgets('loading state shows the centered spinner', (tester) async {
      final (_, baseContainer) = await _freshContainer(tester);
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(baseContainer.read(databaseProvider)),
        categoryBudgetsProvider.overrideWith((ref) => _never()),
      ]);
      addTearDown(container.dispose);
      // The trigger screen itself has no spinner -- only the sheet it opens
      // does -- so the initial pump can settle normally; only the pump
      // AFTER tapping "open" needs the bounded (non-settling) variant.
      await pumpVelora(tester,
          container: container, child: trigger(), size: phone390);
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(VeloraSheetScaffold),
        matchesGoldenFile('baselines/category-editor-loading-light-390.png'),
      );
    });

    testWidgets('empty state matches the approved "no match" search result',
        (tester) async {
      final (_, container) = await _freshContainer(tester);
      await pumpVelora(tester,
          container: container, child: trigger(), size: phone390);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('category-edit-search')), 'zzz-yoq');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(VeloraSheetScaffold),
        matchesGoldenFile('baselines/category-editor-empty-light-390.png'),
      );
    });

    testWidgets('error state matches the approved inline error text',
        (tester) async {
      final (_, baseContainer) = await _freshContainer(tester);
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(baseContainer.read(databaseProvider)),
        categoryBudgetsProvider.overrideWith((ref) => _boom()),
      ]);
      addTearDown(container.dispose);
      await pumpVelora(tester,
          container: container, child: trigger(), size: phone390);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(VeloraSheetScaffold),
        matchesGoldenFile('baselines/category-editor-error-light-390.png'),
      );
    });
  });

  // ---------------------------------------------------------------------
  // 8. Mortgage setup / mortgage_edit_sheet (Task 5, previously
  // ungoldened -- goals_mortgage_golden_test only covers the payment split
  // sheet, not the create/edit form). The form has no async data source
  // (local-state only), so "loading"/"empty" don't apply; the inline
  // validation message after an invalid save stands in for "error".
  // ---------------------------------------------------------------------
  group('Mortgage setup', () {
    Widget trigger() => Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showMortgageEditSheet(context, ref),
                child: const Text('open'),
              ),
            ),
          ),
        );

    testWidgets('matches the approved new-mortgage form at 390px light',
        (tester) async {
      final (_, container) = await _freshContainer(tester);
      await pumpVelora(tester,
          container: container, child: trigger(), size: phone390);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(VeloraSheetScaffold),
        matchesGoldenFile('baselines/mortgage-setup-light-390.png'),
      );
    });

    testWidgets('reflows without overflow at 320px dark 200% text scale',
        (tester) async {
      final (_, container) = await _freshContainer(tester);
      await pumpVelora(
        tester,
        container: container,
        child: trigger(),
        size: phone320,
        brightness: Brightness.dark,
        textScale: textScale200,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(VeloraSheetScaffold),
        matchesGoldenFile('baselines/mortgage-setup-dark-320-scale200.png'),
      );
    });

    testWidgets(
        'error state shows the inline "fill in the fields" validation '
        'message', (tester) async {
      final (_, container) = await _freshContainer(tester);
      await pumpVelora(tester,
          container: container, child: trigger(), size: phone390);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // All fields are empty -- Saqlash surfaces the validation message
      // instead of a silent no-op.
      await tester.tap(find.byKey(const Key('mortgage-save')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(VeloraSheetScaffold),
        matchesGoldenFile('baselines/mortgage-setup-error-light-390.png'),
      );
    });
  });

  // ---------------------------------------------------------------------
  // 9. Goal-completed dialog (Task 5, previously ungoldened).
  // ---------------------------------------------------------------------
  group('Goal completed dialog', () {
    Future<(ProviderContainer, int)> seededExactlyMet(
        WidgetTester tester) async {
      final (_, container) = await _freshContainer(tester);
      final repo = container.read(goalRepositoryProvider);
      final id = await repo.create(GoalDraft(
        name: 'Mashina',
        targetAmountMinor: 1000000,
        startDate: DateTime(2026, 1, 1),
      ));
      final ok = await container
          .read(goalControllerProvider)
          .contribute(goalId: id, amount: const Money(1000000, _uzs));
      expect(ok.isOk, isTrue);
      return (container, id);
    }

    Future<(ProviderContainer, int)> seededWithSurplus(
        WidgetTester tester) async {
      final (_, container) = await _freshContainer(tester);
      final repo = container.read(goalRepositoryProvider);
      final idA = await repo.create(GoalDraft(
        name: 'Mashina',
        targetAmountMinor: 1000000,
        startDate: DateTime(2026, 1, 1),
      ));
      await repo.create(GoalDraft(
        name: 'Sayohat',
        targetAmountMinor: 2000000,
        startDate: DateTime(2026, 1, 1),
      ));
      final ok = await container
          .read(goalControllerProvider)
          .contribute(goalId: idA, amount: const Money(1500000, _uzs));
      expect(ok.isOk, isTrue);
      return (container, idA);
    }

    Widget trigger(int goalId) => Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    showGoalCompletedDialog(context, ref, goalId: goalId),
                child: const Text('open'),
              ),
            ),
          ),
        );

    testWidgets(
        'matches the approved close/retarget celebration at 390px light',
        (tester) async {
      final (container, id) = await seededExactlyMet(tester);
      await pumpVelora(tester,
          container: container, child: trigger(id), size: phone390);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(AlertDialog),
        matchesGoldenFile('baselines/goal-completed-light-390.png'),
      );
    });

    testWidgets(
        'over-funded variant adds the "move surplus to another goal" action',
        (tester) async {
      final (container, id) = await seededWithSurplus(tester);
      await pumpVelora(tester,
          container: container, child: trigger(id), size: phone390);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(AlertDialog),
        matchesGoldenFile('baselines/goal-completed-surplus-light-390.png'),
      );
    });

    testWidgets('reflows without overflow at 320px dark 200% text scale',
        (tester) async {
      final (container, id) = await seededWithSurplus(tester);
      await pumpVelora(
        tester,
        container: container,
        child: trigger(id),
        size: phone320,
        brightness: Brightness.dark,
        textScale: textScale200,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(AlertDialog),
        matchesGoldenFile('baselines/goal-completed-dark-320-scale200.png'),
      );
    });
  });

  // ---------------------------------------------------------------------
  // 10. Main screens -- gap-closing states. Home/Plan-Budget/Goals-Mortgage
  // already have default + 320/dark/200% goldens from Tasks 2/4/5; this
  // closes the loading/empty/error states those files didn't exercise, and
  // adds the Mortgage dashboard list screen, which no earlier golden file
  // covered (only the payment-split sheet was captured).
  // ---------------------------------------------------------------------
  group('Home -- gap states', () {
    testWidgets('loading state shows the skeleton', (tester) async {
      final (_, baseContainer) = await _freshContainer(tester);
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(baseContainer.read(databaseProvider)),
        dashboardProvider.overrideWith((ref) => _never<DashboardData>()),
      ]);
      addTearDown(container.dispose);
      await pumpVelora(
        tester,
        child: UncontrolledProviderScope(
            container: container, child: const HomeScreen()),
        size: phone390,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('baselines/home-loading-light-390.png'),
      );
    });

    testWidgets('error state offers a retry action', (tester) async {
      final (_, baseContainer) = await _freshContainer(tester);
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(baseContainer.read(databaseProvider)),
        dashboardProvider.overrideWith((ref) => _boom<DashboardData>()),
      ]);
      addTearDown(container.dispose);
      await pumpVelora(
        tester,
        child: UncontrolledProviderScope(
            container: container, child: const HomeScreen()),
        size: phone390,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('baselines/home-error-light-390.png'),
      );
    });
  });

  group('Plan/Budget -- gap states', () {
    testWidgets('loading state shows the centered spinner', (tester) async {
      final (_, baseContainer) = await _freshContainer(tester);
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(baseContainer.read(databaseProvider)),
        categoryBudgetsProvider.overrideWith((ref) => _never()),
      ]);
      addTearDown(container.dispose);
      await _pumpLoading(tester,
          child: UncontrolledProviderScope(
              container: container, child: const BudgetsScreen()),
          size: phone390);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(BudgetsScreen),
        matchesGoldenFile('baselines/plan-budget-loading-light-390.png'),
      );
    });

    testWidgets('error state shows the approved inline error text',
        (tester) async {
      final (_, baseContainer) = await _freshContainer(tester);
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(baseContainer.read(databaseProvider)),
        categoryBudgetsProvider.overrideWith((ref) => _boom()),
      ]);
      addTearDown(container.dispose);
      await pumpVelora(
        tester,
        child: UncontrolledProviderScope(
            container: container, child: const BudgetsScreen()),
        size: phone390,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(BudgetsScreen),
        matchesGoldenFile('baselines/plan-budget-error-light-390.png'),
      );
    });
  });

  group('Goals -- gap states', () {
    testWidgets('loading state shows the centered spinner', (tester) async {
      final (_, baseContainer) = await _freshContainer(tester);
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(baseContainer.read(databaseProvider)),
        goalsProvider.overrideWith((ref) => _never()),
      ]);
      addTearDown(container.dispose);
      await _pumpLoading(tester,
          child: UncontrolledProviderScope(
              container: container, child: const GoalsScreen()),
          size: phone390);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(GoalsScreen),
        matchesGoldenFile('baselines/goals-loading-light-390.png'),
      );
    });

    testWidgets('error state offers a retry action', (tester) async {
      final (_, baseContainer) = await _freshContainer(tester);
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(baseContainer.read(databaseProvider)),
        goalsProvider.overrideWith((ref) => _boom()),
      ]);
      addTearDown(container.dispose);
      await pumpVelora(
        tester,
        child: UncontrolledProviderScope(
            container: container, child: const GoalsScreen()),
        size: phone390,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(GoalsScreen),
        matchesGoldenFile('baselines/goals-error-light-390.png'),
      );
    });

    testWidgets(
        'empty state matches the approved first-goal nudge (a genuine gap: '
        'the seeded goals golden never exercises zero goals)', (tester) async {
      final (_, container) = await _freshContainer(tester);
      await pumpVelora(
        tester,
        child: UncontrolledProviderScope(
            container: container, child: const GoalsScreen()),
        size: phone390,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(GoalsScreen),
        matchesGoldenFile('baselines/goals-empty-light-390.png'),
      );
    });
  });

  group('Mortgage dashboard -- previously ungoldened screen', () {
    Future<(ProviderContainer, int)> seededMortgage(WidgetTester tester) async {
      final (_, container) = await _freshContainer(tester);
      await container.read(accountRepositoryProvider).create(
            name: 'Karta',
            type: AccountType.bankCard,
            openingBalance: const Money(500000000, _uzs),
            icon: 'credit_card',
          );
      final id = await container.read(mortgageRepositoryProvider).create(
            MortgageDraft(
              name: 'Uy',
              initialLoanMinor: 120000000,
              openingPrincipalMinor: 100000000,
              annualRateBp: 1800,
              startDate: DateTime(2025, 1, 1),
              mandatoryPaymentMinor: 5000000,
              nextPaymentDate: DateTime(2026, 8, 10),
              paymentType: PaymentType.annuity,
            ),
          );
      container.read(ledgerRevisionProvider.notifier).state++;
      await container.read(mortgagesProvider.future);
      return (container, id);
    }

    testWidgets('matches the approved mortgage-summary hierarchy at 390px '
        'light', (tester) async {
      final (container, _) = await seededMortgage(tester);
      await pumpVelora(
        tester,
        child: UncontrolledProviderScope(
            container: container, child: const MortgageDashboardScreen()),
        size: phone390,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MortgageDashboardScreen),
        matchesGoldenFile('baselines/mortgage-dashboard-light-390.png'),
      );
    });

    testWidgets('reflows without overflow at 320px dark 200% text scale',
        (tester) async {
      final (container, _) = await seededMortgage(tester);
      await pumpVelora(
        tester,
        child: UncontrolledProviderScope(
            container: container, child: const MortgageDashboardScreen()),
        size: phone320,
        brightness: Brightness.dark,
        textScale: textScale200,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MortgageDashboardScreen),
        matchesGoldenFile('baselines/mortgage-dashboard-dark-320-scale200.png'),
      );
    });

    testWidgets(
        'empty state matches the approved first-mortgage nudge', (tester) async {
      final (_, container) = await _freshContainer(tester);
      await pumpVelora(
        tester,
        child: UncontrolledProviderScope(
            container: container, child: const MortgageDashboardScreen()),
        size: phone390,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MortgageDashboardScreen),
        matchesGoldenFile('baselines/mortgage-dashboard-empty-light-390.png'),
      );
    });
  });
}
