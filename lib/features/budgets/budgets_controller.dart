import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/money.dart';
import '../../core/result/failure.dart';
import '../../core/result/result.dart';
import '../../providers/app_providers.dart';

class BudgetsController {
  final Ref ref;
  BudgetsController(this.ref);

  void _bump() =>
      ref.read(ledgerRevisionProvider.notifier).update((n) => n + 1);

  /// Sets `settings.variableBudget`, the numerator of the daily safe limit.
  /// The budget page no longer has its own variable-budget editor, but the
  /// allocation flow still writes this (see
  /// `allocation/variable_budget_offer.dart`'s post-confirm "update variable
  /// budget?" prompt), so this stays even though the rest of Task 7 removed
  /// its sibling budget-page settings methods.
  Future<void> setVariableBudget(Money value) async {
    final repo = ref.read(settingsRepositoryProvider);
    final current = await repo.read();
    await repo.write(current.copyWith(variableBudget: value));
    ref.invalidate(settingsProvider);
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

  /// Creates a new category and returns its id (§6.7 category creation).
  Future<int> createCategory({required String name, required String icon}) async {
    final id =
        await ref.read(categoryRepositoryProvider).create(name: name, icon: icon);
    _bump();
    return id;
  }

  Future<void> renameCategory(int id, String name) async {
    await ref.read(categoryRepositoryProvider).rename(id, name);
    _bump();
  }

  Future<void> setCategoryIcon(int id, String icon) async {
    await ref.read(categoryRepositoryProvider).setIcon(id, icon);
    _bump();
  }

  /// Used categories can only be archived, never deleted (§6.7).
  Future<void> setCategoryArchived(int id, bool archived) async {
    await ref.read(categoryRepositoryProvider).setArchived(id, archived);
    _bump();
  }

  /// Persists a manage-mode drag reorder as the new sortOrder (§6.7).
  Future<void> reorderCategories(List<int> orderedIds) async {
    await ref.read(categoryRepositoryProvider).reorder(orderedIds);
    _bump();
  }

  /// The category editor's full Saqlash write, as one atomic transaction
  /// (mirrors `IncomeEntryController.save`): rename/setIcon (an existing
  /// category) or create (a new one; its `kind` stays at the model default
  /// `variable` -- the budget page no longer offers a kind chooser), then
  /// the monthly limit write. Previously these ran as unguarded sequential
  /// writes with no rollback -- a failure partway (e.g. the limit write)
  /// left the rename/icon changes persisted with no error shown.
  ///
  /// [monthlyLimit] follows `_applyLimit`'s three-way rule: null value +
  /// not-unparseable means "clear the limit"; a non-null value sets it;
  /// `monthlyLimitUnparseable: true` means the typed text didn't parse and
  /// the field is left untouched (skips the write instead of clearing it).
  Future<Result<int>> saveCategory({
    int? id,
    required String name,
    required String icon,
    Money? monthlyLimit,
    bool monthlyLimitUnparseable = false,
  }) async {
    late int categoryId;
    try {
      await ref.read(databaseProvider).transaction(() async {
        if (id != null) {
          categoryId = id;
          await ref.read(categoryRepositoryProvider).rename(categoryId, name);
          await ref.read(categoryRepositoryProvider).setIcon(categoryId, icon);
        } else {
          categoryId = await ref
              .read(categoryRepositoryProvider)
              .create(name: name, icon: icon);
        }
        if (!monthlyLimitUnparseable) {
          await ref.read(budgetRepositoryProvider).setCategoryLimits(
                categoryId,
                monthlyLimitMinor: monthlyLimit?.minorUnits,
                clearMonthly: monthlyLimit == null,
              );
        }
      });
    } catch (error) {
      // Diagnostic detail stays inside Failure; userMessageFor never
      // interpolates it into presentation text.
      return Err(PersistenceFailure(error.toString()));
    }
    _bump();
    return Ok(categoryId);
  }
}

final budgetsControllerProvider =
    Provider<BudgetsController>((ref) => BudgetsController(ref));
