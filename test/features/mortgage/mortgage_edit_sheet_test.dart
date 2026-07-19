import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/features/mortgage/mortgage_edit_sheet.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  testWidgets('creating a mortgage persists it with the parsed rate',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            return ElevatedButton(
              onPressed: () => showMortgageEditSheet(context, ref),
              child: const Text('open'),
            );
          }),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('mortgage-name')), 'Uy');
    await tester.enterText(
        find.byKey(const Key('mortgage-initial')), '120000000');
    await tester.enterText(
        find.byKey(const Key('mortgage-opening')), '100000000');
    await tester.enterText(find.byKey(const Key('mortgage-rate')), '18.5');
    await tester.enterText(
        find.byKey(const Key('mortgage-mandatory')), '5000000');
    await tester.tap(find.byKey(const Key('mortgage-save')));
    await tester.pumpAndSettle();

    final list = await container.read(mortgageRepositoryProvider).list();
    expect(list.single.name, 'Uy');
    expect(list.single.annualRateBp, 1850); // 18.5% -> 1850 bp
    expect(list.single.openingPrincipalMinor, 100000000);
  });

  testWidgets('a malformed rate blocks save and keeps the sheet open',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            return ElevatedButton(
              onPressed: () => showMortgageEditSheet(context, ref),
              child: const Text('open'),
            );
          }),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('mortgage-name')), 'Uy');
    await tester.enterText(
        find.byKey(const Key('mortgage-initial')), '120000000');
    await tester.enterText(
        find.byKey(const Key('mortgage-opening')), '100000000');
    await tester.enterText(find.byKey(const Key('mortgage-rate')), '18.5.5');
    await tester.enterText(
        find.byKey(const Key('mortgage-mandatory')), '5000000');
    await tester.tap(find.byKey(const Key('mortgage-save')));
    await tester.pumpAndSettle();

    // Sheet is still open (save was rejected) and nothing was persisted.
    expect(find.byKey(const Key('mortgage-save')), findsOneWidget);
    expect((await container.read(mortgageRepositoryProvider).list()).isEmpty,
        isTrue);
  });

  test('parseRateToBp parses percent to basis points, integer-only', () {
    expect(parseRateToBp('18'), 1800);
    expect(parseRateToBp('18.5'), 1850);
    expect(parseRateToBp('18.55'), 1855);
    expect(parseRateToBp(''), isNull);
    expect(parseRateToBp('x'), isNull);
  });
}
