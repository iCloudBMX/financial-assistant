import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/result/failure.dart';
import 'package:financial_assistant/core/result/result.dart';
import 'package:financial_assistant/core/result/failure_messages.dart';

void main() {
  test('Ok carries a value', () {
    final Result<int> r = const Ok(42);
    expect(r.isOk, isTrue);
    expect(r.valueOrNull, 42);
  });

  test('Err carries a failure and no value', () {
    final Result<int> r = const Err(ValidationFailure('negative amount'));
    expect(r.isOk, isFalse);
    expect(r.valueOrNull, isNull);
  });

  test('when dispatches to the right branch', () {
    final Result<int> r = const Ok(1);
    final s = r.when(ok: (v) => 'ok:$v', err: (f) => 'err');
    expect(s, 'ok:1');
  });

  test('userMessage is non-technical and mentions no jargon', () {
    final msg = userMessage(const MigrationFailure('SQLITE_ERROR 1'));
    expect(msg.toLowerCase(), isNot(contains('sqlite')));
    expect(msg, isNotEmpty);
  });
}
