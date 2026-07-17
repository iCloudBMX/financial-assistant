import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/db/app_database.dart';
import '../data/meta/meta_model.dart';
import '../data/meta/meta_repository.dart';
import '../data/settings/settings_model.dart';
import '../data/settings/settings_repository.dart';

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
