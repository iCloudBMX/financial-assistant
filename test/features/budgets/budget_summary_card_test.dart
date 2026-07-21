import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/limit/safe_limit_engine.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/features/budgets/budget_summary_card.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  testWidgets('shows the per-day limit and the spending pool', (tester) async {
    const limit = SafeLimit(
      spendable: Money(1200000, uzs),
      perDay: Money(120000, uzs),
      daysLeft: 10,
      todaySpent: Money(0, uzs),
      todayRemaining: Money(120000, uzs),
    );
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: BudgetSummaryCard(limit: limit)),
    ));

    expect(find.text('BUGUNGI LIMIT'), findsOneWidget);
    expect(find.text(limit.perDay.format()), findsOneWidget);
    // Spending pool + days-left live in the supporting line.
    expect(find.textContaining('Sarf kartalari qoldig'), findsOneWidget);
    expect(find.textContaining('10 kun'), findsOneWidget);
    // Read-only: no editable money fields on this surface.
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('an empty spending pool shows the "Sarf kartasi belgilang" hint',
      (tester) async {
    const limit = SafeLimit(
      spendable: Money(0, uzs),
      perDay: Money(0, uzs),
      daysLeft: 10,
      todaySpent: Money(0, uzs),
      todayRemaining: Money(0, uzs),
      hasSpendingAccounts: false,
    );
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: BudgetSummaryCard(limit: limit)),
    ));

    expect(find.text('Sarf kartasi belgilang'), findsOneWidget);
  });

  testWidgets(
      'a present-but-empty spending pool (cards summing to zero) does NOT '
      'show the "Sarf kartasi belgilang" hint', (tester) async {
    const limit = SafeLimit(
      spendable: Money(0, uzs),
      perDay: Money(0, uzs),
      daysLeft: 10,
      todaySpent: Money(0, uzs),
      todayRemaining: Money(0, uzs),
      hasSpendingAccounts: true,
    );
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: BudgetSummaryCard(limit: limit)),
    ));

    expect(find.text('Sarf kartasi belgilang'), findsNothing);
    expect(find.text('BUGUNGI LIMIT'), findsOneWidget);
  });
}
