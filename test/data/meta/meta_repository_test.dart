import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/meta/meta_repository.dart';

void main() {
  late AppDatabase db;
  late MetaRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftMetaRepository(db);
  });
  tearDown(() => db.close());

  test('onboarding starts incomplete and can be marked complete', () async {
    expect((await repo.read()).onboardingComplete, isFalse);
    await repo.markOnboardingComplete();
    expect((await repo.read()).onboardingComplete, isTrue);
  });

  test('touchBackup records the timestamp', () async {
    final at = DateTime(2026, 7, 17);
    await repo.touchBackup(at);
    expect((await repo.read()).lastBackupAt, at);
  });
}
