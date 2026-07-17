import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/l10n/formatters.dart';

void main() {
  test('formatDate applies the supplied pattern', () {
    expect(formatDate(DateTime(2026, 7, 17), 'dd.MM.yyyy'), '17.07.2026');
  });

  test('formatCount groups thousands with spaces', () {
    expect(formatCount(1234567), '1 234 567');
  });
}
