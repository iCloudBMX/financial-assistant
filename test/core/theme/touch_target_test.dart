import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/theme/app_theme.dart';

/// The accessibility contract requires a 48×48 minimum touch target. Chips
/// and segmented buttons default to ~32–40dp, so the Velora theme pins them
/// up; these tests lock that in at default text scale.
void main() {
  testWidgets('ChoiceChip renders at least 48dp tall under the Velora theme',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(
        body: Center(
          child: ChoiceChip(
            label: const Text('Naqd pul'),
            selected: false,
            onSelected: (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byType(ChoiceChip));
    expect(size.height, greaterThanOrEqualTo(48.0));
  });

  testWidgets('SegmentedButton segments render at least 48dp tall',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(
        body: Center(
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Oylik')),
              ButtonSegment(value: 1, label: Text('Haftalik')),
            ],
            selected: const {0},
            onSelectionChanged: (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byType(SegmentedButton<int>));
    expect(size.height, greaterThanOrEqualTo(48.0));
  });

  testWidgets('ChoiceChip meets 48dp in the dark theme too', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildDarkTheme(),
      home: Scaffold(
        body: Center(
          child: ChoiceChip(
            label: const Text('Bonus'),
            selected: true,
            onSelected: (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byType(ChoiceChip));
    expect(size.height, greaterThanOrEqualTo(48.0));
  });
}
