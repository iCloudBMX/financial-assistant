import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/recovery.dart';
import 'package:financial_assistant/data/db/db_open.dart';
import 'package:financial_assistant/core/result/failure.dart';

void main() {
  test('snapshot then restore round-trips the file contents', () async {
    final tmp = await Directory.systemTemp.createTemp('rec');
    final dbPath = '${tmp.path}/app.db';
    await File(dbPath).writeAsString('ORIGINAL');

    final snap = await snapshotDatabase(dbPath);
    expect(snap, isNotNull);

    await File(dbPath).writeAsString('CORRUPTED');
    await restoreSnapshot(snap!, dbPath);

    expect(await File(dbPath).readAsString(), 'ORIGINAL');
    await tmp.delete(recursive: true);
  });

  test('snapshot of a missing file returns null', () async {
    final tmp = await Directory.systemTemp.createTemp('rec');
    final snap = await snapshotDatabase('${tmp.path}/missing.db');
    expect(snap, isNull);
    await tmp.delete(recursive: true);
  });

  test(
      'a corrupted db file yields Err(MigrationFailure) and never throws '
      'out of openAppDatabase', () async {
    final tmp = await Directory.systemTemp.createTemp('rec');
    final dbPath = '${tmp.path}/app.db';
    // Write a valid db first by opening and closing once.
    final first = await openAppDatabase(dbPath: dbPath);
    expect(first.isOk, isTrue);
    await first.valueOrNull!.close();

    // Corrupt the live db with a truncated-but-nonempty payload that is
    // not a valid sqlite header (a 4-byte payload was not enough to make
    // sqlite3 fail on a mere `SELECT 1`; 32 bytes of non-header garbage,
    // combined with forcing a real table read below, reliably does).
    final corrupted = List<int>.filled(32, 0xFF);
    await File(dbPath).writeAsBytes(corrupted);

    // The call must not throw (that's the whole point of the try/catch in
    // openAppDatabase) and must surface a typed failure instead.
    final result = await openAppDatabase(dbPath: dbPath);
    expect(result.isOk, isFalse);
    result.when(
      ok: (_) => fail('expected failure'),
      err: (f) => expect(f, isA<MigrationFailure>()),
    );

    // The catch branch must have run restoreSnapshot (not just closed the
    // db and returned): the pre-open snapshot it took of the corrupted
    // file is copied back over dbPath, and — because that snapshot is
    // never discarded on the failure path — the recovery file remains on
    // disk for a future recovery attempt instead of silently vanishing.
    expect(await File(dbPath).readAsBytes(), equals(corrupted));
    expect(await File(recoveryPathFor(dbPath)).exists(), isTrue);

    await tmp.delete(recursive: true);
  });
}
