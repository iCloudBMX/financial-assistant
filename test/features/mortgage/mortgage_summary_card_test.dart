import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/features/home/dashboard_data.dart';
import 'package:financial_assistant/features/mortgage/mortgage_dashboard_screen.dart';
import 'package:financial_assistant/features/mortgage/mortgage_summary_card.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  testWidgets(
      'empty summary card shows an add-mortgage CTA that opens the dashboard',
      (t) async {
    // The card is pure, but the CTA navigates into MortgageDashboardScreen,
    // which reads providers — so a ProviderScope with an in-memory DB is
    // needed for the navigation target to build.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // A null summary is how dashboardProvider represents "no mortgage yet".
    await t.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(
        home: Scaffold(body: MortgageSummaryCard(summary: null)),
      ),
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
    const uzs = CurrencyRegistry.uzs;
    final summary = MortgageSummaryView(
      id: 1,
      name: 'Uy',
      currentPrincipal: const Money(100000000, uzs),
      nextPaymentAmount: const Money(5000000, uzs),
      nextPaymentDate: DateTime(2026, 7, 10),
      completionBp: 1667,
    );

    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: MortgageSummaryCard(summary: summary)),
    ));
    await t.pumpAndSettle();

    expect(find.text('Ipoteka qo\'shish'), findsNothing);
    expect(find.textContaining('Uy'), findsWidgets);
  });
}
