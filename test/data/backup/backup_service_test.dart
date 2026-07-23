import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:financial_assistant/core/result/failure.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/backup/backup_service.dart';
import 'package:financial_assistant/data/backup/backup_preview.dart';
import 'package:financial_assistant/data/meta/meta_repository.dart';

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

  test('commit replaces the live DB with the backup, then it reopens with the data',
      () async {
    final tmp = await Directory.systemTemp.createTemp('bk');
    // Source DB with 1 account -> a backup file.
    final srcPath = '${tmp.path}/src.db';
    final src = AppDatabase(NativeDatabase(File(srcPath)));
    await _seedOneAccount(src);
    final backup = '${tmp.path}/out.fabackup';
    await BackupService(src, srcPath).exportTo(backup);
    await src.close();

    // Target DB is empty; restore the backup over it.
    final targetPath = '${tmp.path}/target.db';
    final target = AppDatabase(NativeDatabase(File(targetPath)));
    final service = BackupService(target, targetPath);
    final preview = (await service.validate(backup, '${tmp.path}/work')).valueOrNull!;

    final r = await service.commit(preview);
    expect(r.isOk, isTrue);
    expect(await File('$targetPath.importbak').exists(), isFalse); // snapshot cleaned up

    final reopened = AppDatabase(NativeDatabase(File(targetPath)));
    final n = (await reopened.customSelect('SELECT count(*) AS n FROM accounts_table')
            .getSingle())
        .read<int>('n');
    expect(n, 1);
    await reopened.close();
    await tmp.delete(recursive: true);
  });

  test('commit swaps a pre-existing live DB with the backup and cleans up the snapshot',
      () async {
    final tmp = await Directory.systemTemp.createTemp('bk');
    // Source DB with 2 accounts -> a backup file (distinguishable from target).
    final srcPath = '${tmp.path}/src.db';
    final src = AppDatabase(NativeDatabase(File(srcPath)));
    await _seedOneAccount(src);
    await _seedOneAccount(src);
    final backup = '${tmp.path}/out.fabackup';
    await BackupService(src, srcPath).exportTo(backup);
    await src.close();

    // Target DB is materialized on disk with its own (different) data.
    final targetPath = '${tmp.path}/target.db';
    final target = AppDatabase(NativeDatabase(File(targetPath)));
    await _seedOneAccount(target); // 1 account, so the file exists on disk
    final n0 = (await target.customSelect('SELECT count(*) AS n FROM accounts_table')
            .getSingle())
        .read<int>('n');
    expect(n0, 1);
    final service = BackupService(target, targetPath);
    final preview = (await service.validate(backup, '${tmp.path}/work')).valueOrNull!;

    final r = await service.commit(preview);
    expect(r.isOk, isTrue);
    expect(await File('$targetPath.importbak').exists(), isFalse); // snapshot cleaned up

    final reopened = AppDatabase(NativeDatabase(File(targetPath)));
    final n = (await reopened.customSelect('SELECT count(*) AS n FROM accounts_table')
            .getSingle())
        .read<int>('n');
    expect(n, 2); // target now holds the backup's data, not its own
    await reopened.close();
    await tmp.delete(recursive: true);
  });

  test('factoryReset deletes the DB so it reopens empty and pre-onboarding',
      () async {
    final tmp = await Directory.systemTemp.createTemp('bk');
    final dbPath = '${tmp.path}/app.db';
    final db = AppDatabase(NativeDatabase(File(dbPath)));
    await _seedOneAccount(db);
    await DriftMetaRepository(db).markOnboardingComplete();
    final service = BackupService(db, dbPath);

    final r = await service.factoryReset();
    expect(r.isOk, isTrue);
    expect(await File(dbPath).exists(), isFalse);

    // Reopening recreates a fresh DB via onCreate: no accounts, onboarding not
    // complete — the app is back to its first-run state.
    final reopened = AppDatabase(NativeDatabase(File(dbPath)));
    final n = (await reopened
            .customSelect('SELECT count(*) AS n FROM accounts_table')
            .getSingle())
        .read<int>('n');
    expect(n, 0);
    final meta = await DriftMetaRepository(reopened).read();
    expect(meta.onboardingComplete, isFalse);
    await reopened.close();
    await tmp.delete(recursive: true);
  });

  test('commit leaves the original data intact when the swap fails', () async {
    final tmp = await Directory.systemTemp.createTemp('bk');
    final targetPath = '${tmp.path}/target.db';
    final target = AppDatabase(NativeDatabase(File(targetPath)));
    await _seedOneAccount(target); // 1 account we must not lose
    final service = BackupService(target, targetPath);

    // A preview whose validatedTempPath does not exist forces the copy to fail.
    final preview = BackupPreview(
      schemaVersion: target.schemaVersion,
      backupDate: DateTime(2026, 1, 1),
      counts: const {},
      validatedTempPath: '${tmp.path}/does-not-exist.db',
    );
    final r = await service.commit(preview);
    expect(r.isOk, isFalse);

    final reopened = AppDatabase(NativeDatabase(File(targetPath)));
    final n = (await reopened.customSelect('SELECT count(*) AS n FROM accounts_table')
            .getSingle())
        .read<int>('n');
    expect(n, 1); // original restored from the .importbak snapshot
    await reopened.close();
    await tmp.delete(recursive: true);
  });
}
