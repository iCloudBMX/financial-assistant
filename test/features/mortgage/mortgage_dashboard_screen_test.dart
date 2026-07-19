import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/mortgage/mortgage_engine.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/mortgage/mortgage_model.dart';
import 'package:financial_assistant/features/mortgage/mortgage_dashboard_screen.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  testWidgets('dashboard shows the derived balance and empty state', (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: MortgageDashboardScreen()),
    ));
    await t.pumpAndSettle();
    // empty state — the CTA text is specific to the empty state (unlike the
    // AppBar title, which also contains 'Ipoteka' and would match vacuously).
    expect(find.text('Ipoteka qo\'shilmagan'), findsOneWidget);

    // add a mortgage and rebuild
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
    await t.pumpAndSettle();
    expect(find.textContaining('Uy'), findsWidgets);
    expect(find.byKey(const Key('mortgage-recommendations')), findsOneWidget);
  });
}
