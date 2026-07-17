import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/features/onboarding/onboarding_screen.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  testWidgets('onboarding renders the welcome step first', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: OnboardingScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Minimal zaxira'), findsNothing); // not on first page
    expect(find.byType(TextField), findsWidgets); // welcome name field present
  });
}
