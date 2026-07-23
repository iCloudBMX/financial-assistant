import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/features/reports/goal_report_view.dart';
import 'package:financial_assistant/features/reports/mortgage_report_view.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  testWidgets('goal & mortgage report views render empty-state without error',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    for (final view in const [GoalReportView(), MortgageReportView()]) {
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: view)),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
