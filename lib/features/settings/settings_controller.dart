import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/settings/settings_model.dart';
import '../../providers/app_providers.dart';

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() =>
      ref.watch(settingsRepositoryProvider).read();

  Future<void> save(AppSettings updated) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(settingsRepositoryProvider).write(updated);
      ref.invalidate(settingsProvider);
      return updated;
    });
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
        SettingsController.new);
