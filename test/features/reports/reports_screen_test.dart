import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/features/reports/reports_screen.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  testWidgets('ReportsScreen renders the monthly report without error',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ReportsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ReportsScreen), findsOneWidget);
    // The monthly section header (Uzbek) is present.
    expect(find.text('Oylik hisobot'), findsOneWidget);
  });
}
