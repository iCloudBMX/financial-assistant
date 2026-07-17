import '../../core/money/currency.dart';
import '../../core/money/money.dart';

enum ThemeModeSetting { system, light, dark }
enum DailyLimitMethod { evenSplit, fixedDaily }
enum SavingsRolloverMode { rolloverDays, toGoal, askEachTime }

class AppSettings {
  final String name;
  final Currency primaryCurrency;
  final String dateFormat;
  final int periodStartDay;
  final int weekStartIso;
  final DailyLimitMethod dailyLimitMethod;
  final Money minReserve;
  final ThemeModeSetting themeMode;
  final bool appLockEnabled;
  final bool biometricEnabled;
  final SavingsRolloverMode savingsRolloverMode;

  const AppSettings({
    required this.name,
    required this.primaryCurrency,
    required this.dateFormat,
    required this.periodStartDay,
    required this.weekStartIso,
    required this.dailyLimitMethod,
    required this.minReserve,
    required this.themeMode,
    required this.appLockEnabled,
    required this.biometricEnabled,
    required this.savingsRolloverMode,
  });

  AppSettings copyWith({
    String? name,
    Currency? primaryCurrency,
    String? dateFormat,
    int? periodStartDay,
    int? weekStartIso,
    DailyLimitMethod? dailyLimitMethod,
    Money? minReserve,
    ThemeModeSetting? themeMode,
    bool? appLockEnabled,
    bool? biometricEnabled,
    SavingsRolloverMode? savingsRolloverMode,
  }) =>
      AppSettings(
        name: name ?? this.name,
        primaryCurrency: primaryCurrency ?? this.primaryCurrency,
        dateFormat: dateFormat ?? this.dateFormat,
        periodStartDay: periodStartDay ?? this.periodStartDay,
        weekStartIso: weekStartIso ?? this.weekStartIso,
        dailyLimitMethod: dailyLimitMethod ?? this.dailyLimitMethod,
        minReserve: minReserve ?? this.minReserve,
        themeMode: themeMode ?? this.themeMode,
        appLockEnabled: appLockEnabled ?? this.appLockEnabled,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        savingsRolloverMode: savingsRolloverMode ?? this.savingsRolloverMode,
      );
}
