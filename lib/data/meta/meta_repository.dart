import 'package:drift/drift.dart';
import '../db/app_database.dart';
import 'meta_model.dart';

abstract class MetaRepository {
  Future<AppMeta> read();
  Future<void> markOnboardingComplete();
  Future<void> touchBackup(DateTime at);
}

class DriftMetaRepository implements MetaRepository {
  final AppDatabase db;
  DriftMetaRepository(this.db);

  @override
  Future<AppMeta> read() async {
    final r = await db.select(db.appMetaTable).getSingle();
    return AppMeta(
      schemaVersion: r.schemaVersion,
      installedAt: r.installedAt,
      onboardingComplete: r.onboardingComplete,
      lastBackupAt: r.lastBackupAt,
    );
  }

  @override
  Future<void> markOnboardingComplete() async {
    await (db.update(db.appMetaTable)..where((t) => t.id.equals(0)))
        .write(const AppMetaTableCompanion(onboardingComplete: Value(true)));
  }

  @override
  Future<void> touchBackup(DateTime at) async {
    await (db.update(db.appMetaTable)..where((t) => t.id.equals(0)))
        .write(AppMetaTableCompanion(lastBackupAt: Value(at)));
  }
}
