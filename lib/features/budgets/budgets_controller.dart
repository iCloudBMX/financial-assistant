import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/money.dart';
import '../../data/categories/category_model.dart';
import '../../data/settings/settings_model.dart';
import '../../providers/app_providers.dart';

class BudgetsController {
  final Ref ref;
  BudgetsController(this.ref);

  void _bump() =>
      ref.read(ledgerRevisionProvider.notifier).update((n) => n + 1);

  Future<void> setKind(int id, CategoryKind kind) async {
    await ref.read(budgetRepositoryProvider).setCategoryKind(id, kind);
    _bump();
  }

  Future<void> setMonthlyLimit(int id, Money? limit) async {
    await ref.read(budgetRepositoryProvider).setCategoryLimits(
          id,
          monthlyLimitMinor: limit?.minorUnits,
          clearMonthly: limit == null,
        );
    _bump();
  }

  Future<void> setWeeklyLimit(int id, Money? limit) async {
    await ref.read(budgetRepositoryProvider).setCategoryLimits(
          id,
          weeklyLimitMinor: limit?.minorUnits,
          clearWeekly: limit == null,
        );
    _bump();
  }

  Future<void> _writeSettings(AppSettings Function(AppSettings) mutate) async {
    final repo = ref.read(settingsRepositoryProvider);
    final current = await repo.read();
    await repo.write(mutate(current));
    ref.invalidate(settingsProvider);
    _bump();
  }

  Future<void> setVariableBudget(Money value) =>
      _writeSettings((s) => s.copyWith(variableBudget: value));

  Future<void> setSafetyBuffer(Money value) =>
      _writeSettings((s) => s.copyWith(safetyBuffer: value));
}

final budgetsControllerProvider =
    Provider<BudgetsController>((ref) => BudgetsController(ref));
