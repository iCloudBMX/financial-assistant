import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/mortgage/mortgage_engine.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/mortgage/mortgage_model.dart';
import 'package:financial_assistant/features/mortgage/mortgage_scenarios_screen.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/ui/components/velora_card.dart';

void main() {
  testWidgets('scenarios screen lists the four scenario rows', (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    final id = await container.read(mortgageRepositoryProvider).create(
        MortgageDraft(
            name: 'Uy',
            initialLoanMinor: 120000000,
            openingPrincipalMinor: 100000000,
            annualRateBp: 1800,
            startDate: DateTime(2025, 1, 1),
            mandatoryPaymentMinor: 5000000,
            nextPaymentDate: DateTime(2026, 7, 10),
            paymentType: PaymentType.annuity));
    container.read(ledgerRevisionProvider.notifier).update((n) => n + 1);

    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: MortgageScenariosScreen(mortgageId: id)),
    ));
    await t.pumpAndSettle();

    // Baseline scenario row (ScenarioKind.mandatoryOnly) renders with its
    // exact label, and all four scenario rows render as VeloraCards.
    expect(find.text('Faqat majburiy to\'lov'), findsOneWidget);
    expect(find.byType(VeloraCard), findsNWidgets(4));

    // §6.9: scenario projections are always labeled as estimates.
    expect(find.textContaining('Taxminiy'), findsWidgets);
  });
}
