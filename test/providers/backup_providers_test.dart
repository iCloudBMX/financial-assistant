import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/backup/backup_service.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  test('backupServiceProvider builds a service from db + dbPath overrides', () {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      dbPathProvider.overrideWithValue('/tmp/app.db'),
    ]);
    addTearDown(container.dispose);

    final service = container.read(backupServiceProvider);
    expect(service, isA<BackupService>());
    expect(service.dbPath, '/tmp/app.db');
  });
}
