import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/meta/meta_repository.dart';
import 'package:financial_assistant/data/settings/settings_repository.dart';
import 'package:financial_assistant/features/onboarding/onboarding_controller.dart';

void main() {
  late AppDatabase db;
  late OnboardingController c;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    c = OnboardingController(
      settingsRepo: DriftSettingsRepository(db),
      metaRepo: DriftMetaRepository(db),
      stepCount: 5,
    );
  });
  tearDown(() => db.close());

  test('next advances but stops at the last step', () {
    for (var i = 0; i < 10; i++) {
      c.next();
    }
    expect(c.state.index, 4);
    expect(c.isLast, isTrue);
  });

  test('update mutates the draft settings', () {
    c.update((s) => s.copyWith(name: 'Sarvar', periodStartDay: 5));
    expect(c.state.settings.name, 'Sarvar');
    expect(c.state.settings.periodStartDay, 5);
  });

  test('commit persists settings and marks onboarding complete', () async {
    c.update((s) => s.copyWith(name: 'Sarvar'));
    await c.commit();

    final settings = await DriftSettingsRepository(db).read();
    final meta = await DriftMetaRepository(db).read();
    expect(settings.name, 'Sarvar');
    expect(meta.onboardingComplete, isTrue);
  });
}
