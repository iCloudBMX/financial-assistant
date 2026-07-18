import 'dart:io';

import 'package:drift/native.dart';
import '../../core/result/failure.dart';
import '../../core/result/result.dart';
import 'app_database.dart';
import 'recovery.dart';

/// Opens the database with snapshot-before-upgrade protection (PRD §20.3).
/// On any failure while opening/migrating, restores the pre-upgrade snapshot
/// and returns Err(MigrationFailure); the caller then reopens read-safe.
Future<Result<AppDatabase>> openAppDatabase({required String dbPath}) async {
  String? snapshot;
  AppDatabase? db;
  try {
    snapshot = await snapshotDatabase(dbPath);
    db = AppDatabase(NativeDatabase(File(dbPath)));
    // Force the migration to run now by touching the schema. A plain
    // `SELECT 1` does not read the sqlite file header/schema, so a
    // corrupted file can pass it silently; querying a real table forces
    // sqlite to parse the schema and surfaces corruption here rather than
    // on first real query elsewhere in the app.
    await db.customSelect('SELECT * FROM app_meta_table').get();
    await discardSnapshot(dbPath);
    return Ok(db);
  } catch (e) {
    if (db != null) {
      try {
        await db.close();
      } catch (_) {
        // best-effort: ignore secondary close failure
      }
    }
    if (snapshot != null) {
      try {
        await restoreSnapshot(snapshot, dbPath);
      } catch (_) {
        // best-effort: recovery I/O failure must not mask the original error
      }
    }
    return Err(MigrationFailure(e.toString()));
  }
}
