import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/result/failure.dart';
import '../../core/result/result.dart';
import '../../providers/app_providers.dart';

/// Category CRUD used by the Settings category manager. Budgets/limits were
/// removed; this is purely name/icon/archive/order plus create.
class CategoriesController {
  final Ref ref;
  CategoriesController(this.ref);

  void _bump() =>
      ref.read(ledgerRevisionProvider.notifier).update((n) => n + 1);

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

  /// The editor's Saqlash write, as one atomic transaction: rename + setIcon
  /// (an existing category) or create (a new one). No budget limit is written.
  Future<Result<int>> saveCategory({
    int? id,
    required String name,
    required String icon,
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

final categoriesControllerProvider =
    Provider<CategoriesController>((ref) => CategoriesController(ref));
