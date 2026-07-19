// Task 7 (existing-flows plan): timing evidence for AC 2-3 ("quick expense
// completes in 3-5 seconds and opens within 300ms on target hardware").
//
// Flakiness note (read before touching the thresholds below): this suite
// runs under `IntegrationTestWidgetsFlutterBinding`, which -- unlike a plain
// `flutter test` widget test -- pumps against a REAL wall clock rather than
// a fake/simulated one, so `Stopwatch` readings here are meaningful when the
// suite runs on an actual device/emulator via `flutter test
// integration_test/quick_expense_flow_test.dart -d <device>` or `flutter
// drive`. They are NOT meaningful as a hard pass/fail gate in a shared CI
// environment: CI hardware is not the "target device" AC2/AC3 reference,
// and a CI hiccup unrelated to the app itself (GC pause, noisy neighbor VM,
// cold artifact cache) can blow past 300ms without the app itself
// regressing. So this test:
//   1. ALWAYS measures and prints both durations -- usable directly as
//      QA-checklist / profiling evidence.
//   2. ALWAYS asserts a generous, non-flaky upper bound (an actual hang or
//      correctness regression, not a device-speed budget).
//   3. Only enforces the strict AC2 (<300ms open) / AC3 (<5s flow) bounds
//      when explicitly opted into via `--dart-define=PROFILE_TIMING=true`,
//      intended for a real target-device profiling run, never for default
//      CI.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:financial_assistant/app.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/ui/components/velora_money_field.dart';
import 'package:financial_assistant/ui/components/velora_sheet.dart';

/// Set via `flutter test integration_test/quick_expense_flow_test.dart
/// --dart-define=PROFILE_TIMING=true` on a real target-device run to also
/// enforce the strict AC2/AC3 numeric bounds. Left false (the default) for
/// ordinary/CI runs so hardware variance can't flake a functional test.
const _profileTiming = bool.fromEnvironment('PROFILE_TIMING');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'quick expense: sheet opens fast and the full save flow completes '
      'quickly (AC 2-3 timing evidence)', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    // A returning user, past onboarding, with an account and the default
    // categories already in place -- the steady-state most quick-expense
    // taps happen from, matching the AC's "quick expense" scenario rather
    // than the first-run empty state.
    await container.read(accountRepositoryProvider).create(
          name: 'Naqd',
          type: AccountType.cash,
          openingBalance: const Money(5000000, CurrencyRegistry.uzs),
          icon: 'payments',
        );
    await container.read(metaRepositoryProvider).markOnboardingComplete();

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const App(),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quick-action-expense')), findsOneWidget,
        reason: 'app did not boot straight into the Home quick-actions row');

    // --- AC2: tap "Chiqim" -> sheet ready.
    final openStopwatch = Stopwatch()..start();
    await tester.tap(find.byKey(const Key('quick-action-expense')));
    await tester.pumpAndSettle();
    openStopwatch.stop();

    expect(find.byType(VeloraSheetScaffold), findsOneWidget,
        reason: 'quick-expense sheet did not open');
    // ignore: avoid_print
    print('[timing] quick-expense sheet open: '
        '${openStopwatch.elapsedMilliseconds}ms');
    // Generous, non-flaky guard: catches a real hang/regression on the open
    // path without asserting a device-speed budget on shared CI hardware.
    expect(openStopwatch.elapsedMilliseconds, lessThan(3000),
        reason: 'quick-expense sheet took unreasonably long to open');
    if (_profileTiming) {
      expect(openStopwatch.elapsedMilliseconds, lessThan(300),
          reason: 'AC2: sheet must be ready under 300ms on target hardware');
    }

    // --- AC3: amount -> quick category (preselected default) -> account
    // (preselected default) -> Saqlash.
    final flowStopwatch = Stopwatch()..start();
    await tester.enterText(find.byType(VeloraMoneyField), '45000');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick-category')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();
    flowStopwatch.stop();

    expect(find.text('Chiqim saqlandi'), findsOneWidget,
        reason: 'expense was not saved');
    // ignore: avoid_print
    print('[timing] quick-expense flow (amount -> category -> save): '
        '${flowStopwatch.elapsedMilliseconds}ms');
    expect(flowStopwatch.elapsedMilliseconds, lessThan(5000),
        reason:
            'AC3: quick-expense flow must complete under 5s on target '
            'hardware');
  });
}
