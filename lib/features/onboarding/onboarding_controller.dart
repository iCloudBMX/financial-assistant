// Riverpod 3.x note: `StateNotifier` / `StateNotifierProvider` moved out of
// the main `flutter_riverpod.dart` export and now live in the legacy
// library. We keep using `StateNotifier` here (per the task brief) so the
// controller's public API — next()/back()/update()/isLast/commit() and a
// readable `state` — stays exactly as specified.
import 'package:flutter_riverpod/legacy.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../data/meta/meta_repository.dart';
import '../../data/settings/settings_model.dart';
import '../../data/settings/settings_repository.dart';

class OnboardingDraft {
  final AppSettings settings;
  final int index;

  /// The id of the account created during the Account step this onboarding
  /// session, or null if none has been created yet. Lifted out of the step
  /// widget's local state because `OnboardingScreen` keys each step by
  /// `step.id`, so backing off the Account step and returning remounts a
  /// fresh widget — local `_created` state would be lost and re-tapping
  /// "Hisob qo'shish" would silently create a DUPLICATE account. Tracking it
  /// on the (session-scoped) draft makes "already created" survive
  /// back/forward navigation.
  final int? createdAccountId;

  const OnboardingDraft(this.settings, this.index, {this.createdAccountId});

  OnboardingDraft copyWith({
    AppSettings? settings,
    int? index,
    int? createdAccountId,
  }) =>
      OnboardingDraft(
        settings ?? this.settings,
        index ?? this.index,
        createdAccountId: createdAccountId ?? this.createdAccountId,
      );
}

AppSettings defaultSettings() => AppSettings(
      name: '',
      primaryCurrency: CurrencyRegistry.uzs,
      dateFormat: 'dd.MM.yyyy',
      periodStartDay: 1,
      weekStartIso: 1,
      dailyLimitMethod: DailyLimitMethod.evenSplit,
      minReserve: Money.zero(CurrencyRegistry.uzs),
      themeMode: ThemeModeSetting.system,
      appLockEnabled: false,
      biometricEnabled: false,
      savingsRolloverMode: SavingsRolloverMode.askEachTime,
    );

class OnboardingController extends StateNotifier<OnboardingDraft> {
  final SettingsRepository settingsRepo;
  final MetaRepository metaRepo;
  final int stepCount;

  OnboardingController({
    required this.settingsRepo,
    required this.metaRepo,
    required this.stepCount,
  }) : super(OnboardingDraft(defaultSettings(), 0));

  // `StateNotifier.state` is `@protected @visibleForTesting` in the base
  // class. `@visibleForTesting` lets test/ files (like the controller test
  // above) read `c.state` directly, but the step widgets under lib/ need
  // the same access from outside a subclass — so we re-declare the getter
  // here, without the annotation, publishing it as part of
  // `OnboardingController`'s own public API.
  @override
  OnboardingDraft get state => super.state;

  void next() {
    if (state.index < stepCount - 1) {
      state = state.copyWith(index: state.index + 1);
    }
  }

  void back() {
    if (state.index > 0) state = state.copyWith(index: state.index - 1);
  }

  void update(AppSettings Function(AppSettings) f) =>
      state = state.copyWith(settings: f(state.settings));

  /// Records the account created during the Account step so re-entering the
  /// step (after back/forward navigation) knows one already exists and does
  /// not create a duplicate.
  void markAccountCreated(int accountId) =>
      state = state.copyWith(createdAccountId: accountId);

  bool get isLast => state.index == stepCount - 1;

  Future<void> commit() async {
    await settingsRepo.write(state.settings);
    await metaRepo.markOnboardingComplete();
  }
}
