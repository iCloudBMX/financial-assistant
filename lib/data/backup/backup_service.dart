import 'dart:io';
import '../../core/result/failure.dart';
import '../../core/result/result.dart';
import '../db/app_database.dart';
import '../meta/meta_repository.dart';

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
}
