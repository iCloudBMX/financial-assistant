import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/db/app_database.dart';
import '../data/meta/meta_model.dart';
import '../data/meta/meta_repository.dart';
import '../data/settings/settings_model.dart';
import '../data/settings/settings_repository.dart';
import '../features/security/app_lock_controller.dart';

/// Overridden in the composition root with the opened database.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => DriftSettingsRepository(ref.watch(databaseProvider)),
);

final metaRepositoryProvider = Provider<MetaRepository>(
  (ref) => DriftMetaRepository(ref.watch(databaseProvider)),
);

final settingsProvider = FutureProvider<AppSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).read(),
);

final metaProvider = FutureProvider<AppMeta>(
  (ref) => ref.watch(metaRepositoryProvider).read(),
);

/// Device-backed app-lock controller (PIN hash + biometric), constructed
/// once at the composition root and reused across rebuilds so unlocking
/// doesn't get reset by unrelated provider changes.
final appLockControllerProvider = Provider<AppLockController>(
  (ref) => AppLockController(const SecureSecretStore()),
);
