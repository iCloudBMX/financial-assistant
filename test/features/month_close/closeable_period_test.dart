import 'package:financial_assistant/features/month_close/month_close_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const startDay = 1;
  // now is 5 Aug 2026 -> current period Aug 1..Sep 1; just-elapsed = Jul 1..Aug 1.
  final now = DateTime(2026, 8, 5);

  test('closeablePeriod returns the just-elapsed period when never closed', () {
    final p = closeablePeriod(now, startDay, null);
    expect(p!.start, DateTime(2026, 7, 1));
    expect(p.endExclusive, DateTime(2026, 8, 1));
  });

  test('closeablePeriod is null once that period is already closed', () {
    expect(closeablePeriod(now, startDay, DateTime(2026, 7, 1)), isNull);
  });

  test('closeablePeriod still offers an older unclosed period', () {
    // last closed was June -> July is still closeable.
    final p = closeablePeriod(now, startDay, DateTime(2026, 6, 1));
    expect(p!.start, DateTime(2026, 7, 1));
  });
}
