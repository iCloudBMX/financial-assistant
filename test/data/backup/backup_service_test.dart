import 'dart:io';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:financial_assistant/core/result/failure.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/backup/backup_service.dart';

Future<void> _seedOneAccount(AppDatabase db) => db.into(db.accountsTable).insert(
      AccountsTableCompanion.insert(name: 'Cash', type: 'cash'),
    );

void main() {
  test('exportTo writes an openable backup with the same data + backup timestamp',
      () async {
    final tmp = await Directory.systemTemp.createTemp('bk');
    final dbPath = '${tmp.path}/app.db';
    final db = AppDatabase(NativeDatabase(File(dbPath)));
    await _seedOneAccount(db);
    final service = BackupService(db, dbPath);

    final dest = '${tmp.path}/out.fabackup';
    final r = await service.exportTo(dest);
    expect(r.isOk, isTrue);
    expect(await File(dest).exists(), isTrue);

    final out = AppDatabase(NativeDatabase(File(dest)));
    final n = (await out.customSelect('SELECT count(*) AS n FROM accounts_table')
            .getSingle())
        .read<int>('n');
    expect(n, 1);
    final backupAt = (await out.customSelect(
            'SELECT last_backup_at AS t FROM app_meta_table')
        .getSingle());
    expect(backupAt.data['t'] != null, isTrue); // timestamp recorded before the snapshot
    await out.close();
    await db.close();
    await tmp.delete(recursive: true);
  });

  test('validate returns a preview with counts + backup date for a good backup',
      () async {
    final tmp = await Directory.systemTemp.createTemp('bk');
    final dbPath = '${tmp.path}/app.db';
    final db = AppDatabase(NativeDatabase(File(dbPath)));
    await _seedOneAccount(db);
    final service = BackupService(db, dbPath);
    final backup = '${tmp.path}/out.fabackup';
    await service.exportTo(backup);

    final r = await service.validate(backup, '${tmp.path}/work');
    expect(r.isOk, isTrue);
    final preview = r.valueOrNull!;
    expect(preview.counts['Hisoblar'], 1);
    expect(await File(preview.validatedTempPath).exists(), isTrue);
    await db.close();
    await tmp.delete(recursive: true);
  });

  test('validate rejects a backup whose schema is newer than this app', () async {
    final tmp = await Directory.systemTemp.createTemp('bk');
    final dbPath = '${tmp.path}/app.db';
    final db = AppDatabase(NativeDatabase(File(dbPath)));
    final service = BackupService(db, dbPath);
    final backup = '${tmp.path}/out.fabackup';
    await service.exportTo(backup);
    final raw = sqlite3.open(backup);
    raw.userVersion = 999; // pretend it came from a much newer app version
    raw.dispose();

    final r = await service.validate(backup, '${tmp.path}/work');
    expect(r.isOk, isFalse);
    r.when(ok: (_) => fail('expected failure'),
        err: (f) => expect(f, isA<BackupIncompatibleFailure>()));
    await db.close();
    await tmp.delete(recursive: true);
  });

  test('validate rejects a non-database (corrupt) file', () async {
    final tmp = await Directory.systemTemp.createTemp('bk');
    final db = AppDatabase(NativeDatabase(File('${tmp.path}/app.db')));
    final service = BackupService(db, '${tmp.path}/app.db');
    final junk = '${tmp.path}/junk.fabackup';
    await File(junk).writeAsBytes(List<int>.filled(64, 0xAB));

    final r = await service.validate(junk, '${tmp.path}/work');
    expect(r.isOk, isFalse); // StorageFailure or BackupIncompatibleFailure — never Ok
    await db.close();
    await tmp.delete(recursive: true);
  });
}
