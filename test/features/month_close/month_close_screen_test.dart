import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/features/month_close/month_close_screen.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/providers/month_close_providers.dart';

void main() {
  testWidgets('MonthCloseScreen shows the summary and closes the period',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    // A fresh DB has never closed a period, so the just-elapsed period is
    // always offered.
    final before = await container.read(monthCloseProvider.future);
    expect(before, isNotNull);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: MonthCloseScreen()),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Oyni yopish'), findsWidgets); // app bar + button

    await tester.tap(find.widgetWithText(FilledButton, 'Oyni yopish'));
    await tester.pumpAndSettle();

    final after = await container.read(monthCloseProvider.future);
    expect(after, isNull);
  });
}
