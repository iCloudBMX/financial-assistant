import 'dart:io';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
