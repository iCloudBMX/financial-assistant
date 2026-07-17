import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/features/shell/app_shell.dart';

void main() {
  testWidgets('shell shows five destinations and switches tabs',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.byKey(const Key('placeholder_Bosh sahifa')), findsOneWidget);

    await tester.tap(find.text('Hisobot'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('placeholder_Hisobotlar')), findsOneWidget);
  });
}
