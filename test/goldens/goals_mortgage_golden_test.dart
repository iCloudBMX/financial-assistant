import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/mortgage/mortgage_engine.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/goals/goal_model.dart';
import 'package:financial_assistant/data/mortgage/mortgage_model.dart';
import 'package:financial_assistant/features/goals/goals_screen.dart';
import 'package:financial_assistant/features/mortgage/mortgage_payment_sheet.dart';
import 'package:financial_assistant/providers/app_providers.dart';

import '../support/golden_devices.dart';
import '../support/velora_test_app.dart';

/// Seeds two goals in distinct progress states (§6.8: the redesigned goal
/// card hierarchy — saved/target, percent, remaining, projected date, and
/// required monthly all render at once) so the golden captures the full
/// card, not just an empty/near-empty one.
Future<ProviderContainer> _seededGoalsContainer() async {
  final db = AppDatabase(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
  addTearDown(() {
    container.dispose();
    db.close();
  });

  final repo = container.read(goalRepositoryProvider);
  final travelId = await repo.create(GoalDraft(
    name: 'Sayohat',
    targetAmountMinor: 20000000,
    startDate: DateTime(2026, 1, 1),
    targetDate: DateTime(2026, 12, 1),
    priority: GoalPriority.high,
  ));
  await repo.addContribution(
      goalId: travelId,
      signedAmountMinor: 5000000,
      source: ContributionSource.manual,
      occurredAt: DateTime(2026, 3, 1));

  await repo.create(GoalDraft(
    name: 'Zaxira jamg\'armasi',
    targetAmountMinor: 10000000,
    startDate: DateTime(2026, 1, 1),
  ));

  container.read(ledgerRevisionProvider.notifier).update((n) => n + 1);
  await container.read(goalsProvider.future);

  return container;
}

/// Seeds one active annuity mortgage with an account funded to pay it, then
/// returns the mortgage id so the payment sheet has plan data to derive an
/// Auto split from.
Future<(ProviderContainer, int)> _seededMortgageContainer() async {
  final db = AppDatabase(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
  addTearDown(() {
    container.dispose();
    db.close();
  });

  await container.read(accountRepositoryProvider).create(
        name: 'Karta',
        type: AccountType.bankCard,
        openingBalance: const Money(500000000, CurrencyRegistry.uzs),
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
  container.read(ledgerRevisionProvider.notifier).update((n) => n + 1);
  await container.read(mortgagesProvider.future);

  return (container, id);
}

void main() {
  testWidgets('Maqsad list matches the approved goal-card hierarchy at 390px '
      'light', (tester) async {
    final container = await _seededGoalsContainer();

    await pumpVelora(
      tester,
      child: UncontrolledProviderScope(
        container: container,
        child: const GoalsScreen(),
      ),
      size: phone390,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(GoalsScreen),
      matchesGoldenFile('baselines/goals-screen-light-390.png'),
    );
  });

  testWidgets(
      'Maqsad list reflows without overflow at 320px dark 200% text scale',
      (tester) async {
    final container = await _seededGoalsContainer();

    await pumpVelora(
      tester,
      child: UncontrolledProviderScope(
        container: container,
        child: const GoalsScreen(),
      ),
      size: phone320,
      brightness: Brightness.dark,
      textScale: textScale200,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(GoalsScreen),
      matchesGoldenFile('baselines/goals-screen-dark-320-scale200.png'),
    );
  });

  testWidgets(
      'Mortgage Manual split matches the approved explicit-split hierarchy '
      'at 390px light', (tester) async {
    final (container, id) = await _seededMortgageContainer();

    await pumpVelora(
      tester,
      child: UncontrolledProviderScope(
        container: container,
        child: Scaffold(body: MortgagePaymentSheet(mortgageId: id)),
      ),
      size: phone390,
    );
    // Switch to Manual and type an UNBALANCED split so the golden captures
    // the live equation, the difference badge, and the "Asosiy qarzga" /
    // "Foiz to‘lovi" fields together — the novel §6.9 UI this task added.
    await tester.tap(find.byKey(const Key('payment-mode-manual')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('payment-total')), '5000000');
    await tester.enterText(
        find.byKey(const Key('payment-principal')), '3000000');
    await tester.enterText(
        find.byKey(const Key('payment-interest')), '1000000');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MortgagePaymentSheet),
      matchesGoldenFile('baselines/mortgage-split-light-390.png'),
    );
  });

  testWidgets(
      'Mortgage Manual split reflows without overflow at 320px dark 200% '
      'text scale', (tester) async {
    final (container, id) = await _seededMortgageContainer();

    await pumpVelora(
      tester,
      child: UncontrolledProviderScope(
        container: container,
        child: Scaffold(body: MortgagePaymentSheet(mortgageId: id)),
      ),
      size: phone320,
      brightness: Brightness.dark,
      textScale: textScale200,
    );
    await tester.tap(find.byKey(const Key('payment-mode-manual')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('payment-total')), '5000000');
    await tester.enterText(
        find.byKey(const Key('payment-principal')), '3000000');
    await tester.enterText(
        find.byKey(const Key('payment-interest')), '1000000');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MortgagePaymentSheet),
      matchesGoldenFile('baselines/mortgage-split-dark-320-scale200.png'),
    );
  });
}
