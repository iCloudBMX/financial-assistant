import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import '../../core/result/failure.dart';
import '../../core/result/result.dart';
import '../db/app_database.dart';
import '../db/db_open.dart';
import '../meta/meta_repository.dart';
import 'backup_preview.dart';

/// File-level backup operations (PRD §18–19). Path-driven and plugin-free so it
/// is fully unit-testable; the controller supplies temp/share/picker paths.
class BackupService {
  final AppDatabase db;
  final String dbPath;
  BackupService(this.db, this.dbPath);

  /// Writes a transactionally-consistent single-file SQLite snapshot to
  /// [destPath] (PRD §18.1). Records the backup time first so the snapshot
  /// carries its own creation timestamp.
  Future<Result<void>> exportTo(String destPath) async {
    try {
      await DriftMetaRepository(db).touchBackup(DateTime.now());
      final dest = File(destPath);
      if (await dest.exists()) await dest.delete(); // VACUUM INTO fails if it exists
      // ponytail: escape single quotes; temp paths have none, but be safe.
      final escaped = destPath.replaceAll("'", "''");
      await db.customStatement("VACUUM INTO '$escaped'");
      return const Ok(null);
    } catch (e) {
      return Err(StorageFailure(e.toString()));
    }
  }

  /// Copies [pickedPath] into [workDir], checks it is a readable SQLite file no
  /// newer than this app (PRD §20.4), migrates the copy to the current schema,
  /// and returns its counts + backup date (PRD §19.2). The original DB is never
  /// touched. The returned [BackupPreview.validatedTempPath] is the migrated copy.
  Future<Result<BackupPreview>> validate(String pickedPath, String workDir) async {
    final copyPath = p.join(workDir, 'validate.db');
    try {
      await Directory(workDir).create(recursive: true);
      await File(pickedPath).copy(copyPath);
    } catch (e) {
      return Err(StorageFailure(e.toString()));
    }

    // Version gate BEFORE migration: read user_version without touching schema.
    int backupVersion;
    try {
      final raw = sqlite3.open(copyPath);
      try {
        backupVersion = raw.userVersion;
      } finally {
        raw.dispose(); // must run even if userVersion throws (corrupt file), or
        // the native handle leaks and locks copyPath (Windows can't delete it).
      }
    } catch (e) {
      return Err(StorageFailure(e.toString())); // not a readable sqlite db
    }
    if (backupVersion < 1 || backupVersion > db.schemaVersion) {
      return Err(BackupIncompatibleFailure(
          'backup schema $backupVersion vs app ${db.schemaVersion}'));
    }

    // Open + migrate the copy (upgrades older backups; rollback-on-failure).
    final opened = await openAppDatabase(dbPath: copyPath);
    if (opened is Err<AppDatabase>) return Err(opened.failure);
    final copyDb = opened.valueOrNull!;
    try {
      final meta = await DriftMetaRepository(copyDb).read();
      final counts = await _counts(copyDb);
      return Ok(BackupPreview(
        schemaVersion: backupVersion,
        backupDate: meta.lastBackupAt ?? meta.installedAt,
        counts: counts,
        validatedTempPath: copyPath,
      ));
    } catch (e) {
      return Err(StorageFailure(e.toString()));
    } finally {
      await copyDb.close();
    }
  }

  Future<Map<String, int>> _counts(AppDatabase d) async {
    Future<int> c(String table) async =>
        (await d.customSelect('SELECT count(*) AS n FROM $table').getSingle())
            .read<int>('n');
    return {
      'Hisoblar': await c('accounts_table'),
      'Tranzaksiyalar': await c('transactions_table'),
      'Goal': await c('goals_table'),
      'Ipoteka': await c('mortgages_table'),
    };
  }
}
