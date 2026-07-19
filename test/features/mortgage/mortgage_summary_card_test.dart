import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/mortgage/mortgage_engine.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/mortgage/mortgage_model.dart';
import 'package:financial_assistant/features/mortgage/mortgage_dashboard_screen.dart';
import 'package:financial_assistant/features/mortgage/mortgage_summary_card.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  testWidgets(
      'empty summary card shows an add-mortgage CTA that opens the dashboard',
      (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: MortgageSummaryCard())),
    ));
    await t.pumpAndSettle();

    // Empty state must be a reachable CTA, not SizedBox.shrink — otherwise the
    // whole mortgage feature is unreachable from a fresh install.
    expect(find.text('Ipoteka qo\'shish'), findsOneWidget);

    // Tapping it navigates into the dashboard (the only entry point).
    await t.tap(find.text('Ipoteka qo\'shish'));
    await t.pumpAndSettle();
    expect(find.byType(MortgageDashboardScreen), findsOneWidget);
  });

  testWidgets('populated summary card shows the mortgage and no CTA',
      (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await container.read(mortgageRepositoryProvider).create(MortgageDraft(
          name: 'Uy',
          initialLoanMinor: 120000000,
          openingPrincipalMinor: 100000000,
          annualRateBp: 1800,
          startDate: DateTime(2025, 1, 1),
          mandatoryPaymentMinor: 5000000,
          nextPaymentDate: DateTime(2026, 7, 10),
          paymentType: PaymentType.annuity,
        ));
    container.read(ledgerRevisionProvider.notifier).update((n) => n + 1);

    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: MortgageSummaryCard())),
    ));
    await t.pumpAndSettle();

    expect(find.text('Ipoteka qo\'shish'), findsNothing);
    expect(find.textContaining('Uy'), findsWidgets);
  });
}
