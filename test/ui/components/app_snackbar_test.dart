import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/ui/components/app_snackbar.dart';

void main() {
  testWidgets('showAutoDismissSnackBar shows and then dismisses the snackbar',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => ScaffoldMessenger.of(context)
                .showAutoDismissSnackBar(const SnackBar(
              content: Text('Saqlandi'),
              duration: Duration(seconds: 2),
            )),
            child: const Text('go'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('go'));
    await tester.pump(); // start the reveal animation
    expect(find.text('Saqlandi'), findsOneWidget);

    // Past the 2s display duration plus the helper's 400ms backstop margin and
    // the exit animation — the snackbar must be gone.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Saqlandi'), findsNothing);
  });

  testWidgets('a tapped action closes the snackbar without a late self-hide',
      (tester) async {
    var undone = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => ScaffoldMessenger.of(context)
                .showAutoDismissSnackBar(SnackBar(
              content: const Text('Saqlandi'),
              duration: const Duration(seconds: 2),
              action: SnackBarAction(label: 'Bekor', onPressed: () => undone++),
            )),
            child: const Text('go'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('go'));
    await tester.pump(); // start the reveal
    await tester.pump(const Duration(milliseconds: 500)); // finish the reveal
    await tester.tap(find.text('Bekor'));
    await tester.pumpAndSettle();

    expect(undone, 1);
    expect(find.text('Saqlandi'), findsNothing);
    // Let the backstop timer elapse; it must be a no-op (no exceptions).
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
