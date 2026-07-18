import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/shell/app_shell.dart';

void main() {
  testWidgets('shell shows Home then switches to Transactions', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AppShell()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Bosh sahifa'), findsOneWidget); // Home app bar

    await tester.tap(find.text('Tranzaksiya'));
    await tester.pumpAndSettle();
    expect(find.text('Tranzaksiyalar'), findsOneWidget); // Transactions app bar
  });
}
