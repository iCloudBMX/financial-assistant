# Plan tab → allocation; remove category budgets — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the bottom-nav plan tab show the card-based allocation screen, remove the category-budget (monthly-limit) system entirely, and move limit-free category management into Settings.

**Architecture:** The plan `StatefulShellBranch` repoints from `BudgetsScreen` to the existing `AllocationPlanScreen`; the tab is relabelled "Taqsimlash". The self-contained category-budget cluster (screen, engine, status labels, budget repository, `categoryBudgetsProvider`) is deleted. Categories themselves are untouched (expense tagging + history filters). Category CRUD (add/rename/icon/archive/reorder — no limits) moves to a new `CategoryManagementScreen` reached from Settings, backed by a renamed `CategoriesController`.

**Tech Stack:** Flutter, Riverpod (flutter_riverpod 3.x), Drift (SQLite), go_router.

## Global Constraints

- Test command: `flutter test --concurrency=1` (per repo toolchain notes).
- Riverpod `StateProvider` usage requires the `flutter_riverpod/legacy.dart` import where applicable (existing pattern; don't remove).
- **No schema change.** The `monthlyLimitMinor` / `weeklyLimitMinor` DB columns stay dormant; do not add a migration or bump the schema version.
- All user-facing copy is Uzbek (Latin), matching existing strings.
- Some full-screen goldens are environmentally flaky in this repo; verify *changed* goldens specifically and report pre-existing failures separately (do not mass-regen).
- Follow existing file/naming patterns; keep files focused.

---

## File Structure

**Created**
- `lib/features/categories/category_management_screen.dart` — Settings-reached category manager (reorder + archive/restore + new).

**Moved + edited** (use `git mv`, then edit)
- `lib/features/budgets/budgets_controller.dart` → `lib/features/categories/categories_controller.dart` (rename class/provider, strip limits + `setVariableBudget`).
- `lib/features/budgets/category_edit_sheet.dart` → `lib/features/categories/category_edit_sheet.dart` (strip limit field + status card + budget-engine dependency).

**Deleted**
- `lib/features/budgets/budgets_screen.dart`
- `lib/features/budgets/budget_labels.dart`
- `lib/core/budget/category_budget_engine.dart`
- `lib/data/budget/budget_repository.dart`
- (the `lib/features/budgets/` folder ends up empty → gone)

**Modified**
- `lib/features/shell/routes.dart`, `lib/features/shell/app_shell.dart`
- `lib/providers/app_providers.dart`
- `lib/features/home/dashboard_data.dart`, `lib/features/home/safe_limit_cards.dart`, `lib/features/home/home_screen.dart`
- `lib/features/settings/settings_screen.dart`

**Tests deleted**
- `test/features/budgets/budgets_screen_test.dart`
- `test/features/budgets/budgets_manage_test.dart`
- `test/features/budgets/budgets_removed_view_test.dart`
- `test/core/budget/category_budget_engine_test.dart`
- `test/data/budget/budget_repository_test.dart`
- `test/goldens/plan_budget_golden_test.dart` + its baselines/failures PNGs

**Tests moved + edited**
- `test/features/budgets/budgets_controller_test.dart` → `test/features/categories/categories_controller_test.dart`
- `test/features/budgets/category_edit_sheet_test.dart` → `test/features/categories/category_edit_sheet_test.dart`

**Tests modified**
- `test/features/shell/routes_test.dart`, `test/features/shell/app_shell_test.dart`
- `test/features/home/safe_limit_cards_test.dart`
- `test/providers/safe_limit_providers_test.dart`
- `test/goldens/existing_flow_gallery_test.dart`

**Test created**
- `test/features/categories/category_management_screen_test.dart`

---

## Task 1: Repoint plan tab to allocation, relabel "Taqsimlash", delete BudgetsScreen

**Files:**
- Modify: `lib/features/shell/routes.dart`
- Modify: `lib/features/shell/app_shell.dart`
- Delete: `lib/features/budgets/budgets_screen.dart`
- Delete: `test/features/budgets/budgets_screen_test.dart`, `test/features/budgets/budgets_manage_test.dart`, `test/features/budgets/budgets_removed_view_test.dart`
- Delete: `test/goldens/plan_budget_golden_test.dart` (+ PNGs, see step)
- Modify: `test/features/shell/routes_test.dart`, `test/features/shell/app_shell_test.dart`

**Interfaces:**
- Consumes: `AllocationPlanScreen` (from `lib/features/allocation/allocation_plan_screen.dart`) — already exports `const AllocationPlanScreen()`, self-scaffolded with AppBar "Taqsimlash rejasi".
- Produces: the plan branch now builds `AllocationPlanScreen`; nav label 3 is `'Taqsimlash'`.

- [ ] **Step 1: Update the nav destination label**

In `lib/features/shell/app_shell.dart`, change the third destination:

```dart
    NavigationDestination(
      icon: Icon(Icons.account_tree_outlined),
      label: 'Taqsimlash',
    ),
```

- [ ] **Step 2: Repoint the plan branch to the allocation screen**

In `lib/features/shell/routes.dart`:
- Replace the import `import '../budgets/budgets_screen.dart';` with `import '../allocation/allocation_plan_screen.dart';`.
- In the `RouteNames.plan` `GoRoute` builder, replace `child: BudgetsScreen(),` with `child: AllocationPlanScreen(),` (keep `KeyedSubtree` + `PageStorageKey('plan-tab')`):

```dart
            GoRoute(
              name: RouteNames.plan,
              path: RoutePaths.plan,
              builder: (_, _) => const KeyedSubtree(
                key: PageStorageKey('plan-tab'),
                child: AllocationPlanScreen(),
              ),
            ),
```

- [ ] **Step 3: Delete BudgetsScreen and its now-orphaned tests**

```bash
git rm lib/features/budgets/budgets_screen.dart \
  test/features/budgets/budgets_screen_test.dart \
  test/features/budgets/budgets_manage_test.dart \
  test/features/budgets/budgets_removed_view_test.dart \
  test/goldens/plan_budget_golden_test.dart
git rm test/goldens/baselines/plan-budget-*.png
git rm -f test/goldens/failures/plan-budget-*.png 2>/dev/null || true
```

(`plan_budget_golden_test.dart` renders `BudgetsScreen` and calls `setVariableBudget`/`categoryBudgetsProvider`, all removed. Its baselines/failures PNGs go with it.)

- [ ] **Step 4: Update the shell nav label test**

In `test/features/shell/app_shell_test.dart`, change the label list:

```dart
    for (final label in ['Bugun', 'Tarix', 'Taqsimlash', 'Maqsad', 'Tahlil']) {
```

- [ ] **Step 5: Update routes_test for the new label + screen**

In `test/features/shell/routes_test.dart`:
- Line ~74: `await tester.tap(find.text('Reja'));` → `await tester.tap(find.text('Taqsimlash'));`
- Line ~87: the `expect(find.text('Budjet'), findsOneWidget);` asserted the old budget screen header. Replace with an assertion that the allocation screen rendered, e.g.:

```dart
    expect(find.text('Taqsimlash rejasi'), findsOneWidget); // AllocationPlanScreen AppBar
```

- Lines ~89-93: update the semantics label from `'Reja\nTab 3 of 5'` to `'Taqsimlash\nTab 3 of 5'`.
- Read the rest of the file for any other `'Reja'` / `Budjet` references (e.g. the scroll-retention contract around lines 148-152 uses `'plan-tab'` keys, not labels — leave those) and update only label/header references.

- [ ] **Step 6: Run the shell tests**

Run: `flutter test --concurrency=1 test/features/shell/`
Expected: PASS. If routes_test still references the old screen, fix per step 5.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(shell): plan tab shows card allocation; relabel 'Taqsimlash'; drop BudgetsScreen"
```

---

## Task 2: Remove the Home overspend-categories explanation

**Files:**
- Modify: `lib/features/home/dashboard_data.dart`
- Modify: `lib/features/home/safe_limit_cards.dart`
- Modify: `lib/features/home/home_screen.dart:114-118`
- Modify: `lib/providers/app_providers.dart` (`dashboardProvider` + `_overspendCategories`)
- Modify: `test/features/home/safe_limit_cards_test.dart:88-96`

**Interfaces:**
- Consumes: `DashboardData` (edited to drop `overspendCategories`), `SafeLimitCard` (edited to drop the param).
- Produces: `DashboardData` no longer has `overspendCategories`; `SafeLimitCard({required limit})` only; `buildDashboard` drops the `overspendCategories` param.

- [ ] **Step 1: Update the SafeLimitCard widget test to the new API (failing test first)**

In `test/features/home/safe_limit_cards_test.dart`, find the test at ~88-96 that builds `SafeLimitCard(limit: limit, overspendCategories: ['Oziq'])` and asserts `find.textContaining('Limitdan chiqqan: Oziq')`. Remove that whole test case (the overspend explanation is gone). If it was the only user of a shared `limit` fixture, keep the fixture for the remaining tests.

Run: `flutter test --concurrency=1 test/features/home/safe_limit_cards_test.dart`
Expected: FAIL to compile (`overspendCategories` still a param on the widget until step 2), confirming the test targets the removed behavior.

- [ ] **Step 2: Remove the param + overspend block from SafeLimitCard**

In `lib/features/home/safe_limit_cards.dart`:
- Delete the constructor param `this.overspendCategories = const [],` and the field `final List<String> overspendCategories;`.
- Delete the trailing block (lines ~114-121):

```dart
          if (status == VeloraStatus.over && overspendCategories.isNotEmpty) ...[
            const SizedBox(height: VeloraSpacing.sm),
            Text(
              'Limitdan chiqqan: ${overspendCategories.join(', ')}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: VeloraColors.apricot),
            ),
          ],
```

- Update the doc comment that mentions `[overspendCategories]` to drop it.

- [ ] **Step 3: Remove overspendCategories from DashboardData + buildDashboard**

In `lib/features/home/dashboard_data.dart`:
- Delete the field + its doc comment (lines ~64-66) and the constructor line `this.overspendCategories = const [],`.
- In `buildDashboard`, delete the param `List<String> overspendCategories = const [],` and the assignment `overspendCategories: overspendCategories,`.

- [ ] **Step 4: Stop computing it in dashboardProvider**

In `lib/providers/app_providers.dart` `dashboardProvider`:
- Delete `final budgets = await ref.watch(categoryBudgetsProvider.future);`.
- Delete the argument `overspendCategories: _overspendCategories(budgets),` from the `buildDashboard(...)` call.
- Delete the `_overspendCategories` helper + its doc comment (lines ~120-126).
- Remove now-unused imports if any (e.g. `category_budget_engine.dart` if only used here — the analyzer in Task 4 will confirm; leave the import if `CategoryBudgetView` is still referenced by `categoryBudgetsProvider`, which is deleted in Task 4).

- [ ] **Step 5: Drop the param at the Home call site**

In `lib/features/home/home_screen.dart` (~114-118):

```dart
        if (d.safeLimit != null) ...[
          SafeLimitCard(limit: d.safeLimit!),
          const SizedBox(height: VeloraSpacing.md),
        ],
```

- [ ] **Step 6: Run home tests**

Run: `flutter test --concurrency=1 test/features/home/`
Expected: PASS (the removed test is gone; the hero still renders limit/status).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor(home): drop category-overspend explanation from safe-limit hero"
```

---

## Task 3: Category management in Settings (rename controller, strip limits, new screen)

**Files:**
- Move+edit: `lib/features/budgets/budgets_controller.dart` → `lib/features/categories/categories_controller.dart`
- Move+edit: `lib/features/budgets/category_edit_sheet.dart` → `lib/features/categories/category_edit_sheet.dart`
- Create: `lib/features/categories/category_management_screen.dart`
- Modify: `lib/features/settings/settings_screen.dart`
- Move+edit: `test/features/budgets/budgets_controller_test.dart` → `test/features/categories/categories_controller_test.dart`
- Move+edit: `test/features/budgets/category_edit_sheet_test.dart` → `test/features/categories/category_edit_sheet_test.dart`
- Create: `test/features/categories/category_management_screen_test.dart`

**Interfaces:**
- Consumes: `categoriesProvider` (`FutureProvider<List<Category>>`, all incl. archived; already exists in app_providers), `categoryRepositoryProvider` (`create/rename/setIcon/setArchived/reorder/list`), `databaseProvider.transaction`.
- Produces:
  - `CategoriesController` with `categoriesControllerProvider` (`Provider<CategoriesController>`), methods: `createCategory({name, icon}) → Future<int>`, `renameCategory(id, name)`, `setCategoryIcon(id, icon)`, `setCategoryArchived(id, archived)`, `reorderCategories(orderedIds)`, `saveCategory({int? id, required String name, required String icon}) → Future<Result<int>>`.
  - `showCategoryEditSheet(BuildContext, {int? categoryId})` (limit-free).
  - `CategoryManagementScreen` (`const CategoryManagementScreen()`).

- [ ] **Step 1: Move the controller file**

```bash
mkdir -p lib/features/categories
git mv lib/features/budgets/budgets_controller.dart lib/features/categories/categories_controller.dart
```

- [ ] **Step 2: Rewrite the controller (rename + strip limits/variableBudget)**

Replace the entire contents of `lib/features/categories/categories_controller.dart` with:

```dart
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
```

- [ ] **Step 3: Move the edit-sheet file**

```bash
git mv lib/features/budgets/category_edit_sheet.dart lib/features/categories/category_edit_sheet.dart
```

- [ ] **Step 4: Rewrite the edit sheet (limit-free, categoriesProvider-backed)**

Replace the entire contents of `lib/features/categories/category_edit_sheet.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/result/failure_messages.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/app_snackbar.dart';
import '../../ui/components/category_icons.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_sheet.dart';
import 'categories_controller.dart';

/// Opens the searchable category editor (§6.7). Pass [categoryId] to jump
/// straight to that category's edit form (the fast path from a list row);
/// omit it to open the searchable list first, with a "Yangi kategoriya" entry.
Future<void> showCategoryEditSheet(BuildContext context, {int? categoryId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CategoryEditSheet(initialCategoryId: categoryId),
  );
}

class _CategoryEditSheet extends ConsumerStatefulWidget {
  const _CategoryEditSheet({this.initialCategoryId});
  final int? initialCategoryId;

  @override
  ConsumerState<_CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends ConsumerState<_CategoryEditSheet> {
  late int? _editingId = widget.initialCategoryId;
  bool _creatingNew = false;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _directEdit => widget.initialCategoryId != null;

  @override
  Widget build(BuildContext context) {
    if (_editingId != null || _creatingNew) {
      return _CategoryForm(
        categoryId: _editingId,
        showBack: !_directEdit,
        onBack: () => setState(() {
          _editingId = null;
          _creatingNew = false;
        }),
      );
    }
    return _CategoryList(
      query: _query,
      searchCtrl: _searchCtrl,
      onQueryChanged: (q) => setState(() => _query = q),
      onSelect: (id) => setState(() => _editingId = id),
      onCreateNew: () => setState(() => _creatingNew = true),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({
    required this.query,
    required this.searchCtrl,
    required this.onQueryChanged,
    required this.onSelect,
    required this.onCreateNew,
  });

  final String query;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreateNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    return VeloraSheetScaffold(
      title: 'Kategoriyalar',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SearchBar(
            key: const Key('category-edit-search'),
            controller: searchCtrl,
            hintText: 'Kategoriya qidirish',
            leading: const Icon(Icons.search),
            onChanged: onQueryChanged,
          ),
          const SizedBox(height: VeloraSpacing.md),
          categories.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Text('Xatolik yuz berdi'),
            data: (cats) {
              final q = query.trim().toLowerCase();
              final filtered = cats
                  .where((c) =>
                      !c.archived &&
                      (q.isEmpty || c.name.toLowerCase().contains(q)))
                  .toList(growable: false);
              if (filtered.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: VeloraSpacing.lg),
                  child: Text('Kategoriya topilmadi'),
                );
              }
              return Column(
                children: [
                  for (final c in filtered)
                    Semantics(
                      key: Key('category-edit-option-${c.id}'),
                      button: true,
                      label: c.name,
                      onTap: () => onSelect(c.id),
                      child: ExcludeSemantics(
                        child: ListTile(
                          minTileHeight: 48,
                          leading: Icon(categoryIcon(c.icon)),
                          title: Text(c.name),
                          onTap: () => onSelect(c.id),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      primaryAction: VeloraPrimaryButton(
        key: const Key('category-edit-new'),
        label: 'Yangi kategoriya',
        onPressed: onCreateNew,
      ),
    );
  }
}

class _CategoryForm extends ConsumerStatefulWidget {
  const _CategoryForm({
    required this.categoryId,
    required this.showBack,
    required this.onBack,
  });

  final int? categoryId;
  final bool showBack;
  final VoidCallback onBack;

  @override
  ConsumerState<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends ConsumerState<_CategoryForm> {
  final _nameCtrl = TextEditingController();
  String _icon = 'category';
  bool _archived = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.categoryId == null) {
      _loaded = true;
    } else {
      _load(widget.categoryId!);
    }
    _nameCtrl.addListener(() => setState(() {}));
  }

  Future<void> _load(int id) async {
    final cats = await ref.read(categoriesProvider.future);
    final c = cats.firstWhere((c) => c.id == id);
    _nameCtrl.text = c.name;
    _icon = c.icon;
    _archived = c.archived;
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _canSave => _nameCtrl.text.trim().isNotEmpty;

  Future<void> _save() async {
    final controller = ref.read(categoriesControllerProvider);
    final name = _nameCtrl.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    final result = await controller.saveCategory(
      id: widget.categoryId,
      name: name,
      icon: _icon,
    );
    if (!mounted) return;
    result.when(
      ok: (_) => Navigator.of(context).pop(),
      err: (f) => messenger
          .showAutoDismissSnackBar(SnackBar(content: Text(userMessageFor(f)))),
    );
  }

  Future<void> _toggleArchived() async {
    await ref
        .read(categoriesControllerProvider)
        .setCategoryArchived(widget.categoryId!, !_archived);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const SizedBox(
          height: 160, child: Center(child: CircularProgressIndicator()));
    }
    return VeloraSheetScaffold(
      title: widget.categoryId == null
          ? 'Yangi kategoriya'
          : 'Kategoriyani tahrirlash',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showBack)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Orqaga'),
              ),
            ),
          TextField(
            key: const Key('category-edit-name'),
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Nomi'),
          ),
          const SizedBox(height: VeloraSpacing.md),
          Text('Belgi', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: VeloraSpacing.xs),
          Wrap(
            spacing: VeloraSpacing.xs,
            runSpacing: VeloraSpacing.xs,
            children: [
              for (final key in kCategoryIconKeys)
                _IconChoice(
                  iconKey: key,
                  selected: key == _icon,
                  onTap: () => setState(() => _icon = key),
                ),
            ],
          ),
          if (widget.categoryId != null) ...[
            const SizedBox(height: VeloraSpacing.md),
            TextButton.icon(
              key: const Key('category-edit-archive'),
              onPressed: _toggleArchived,
              icon: Icon(_archived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined),
              label: Text(_archived ? 'Arxivdan chiqarish' : 'Arxivlash'),
            ),
          ],
        ],
      ),
      primaryAction: VeloraPrimaryButton(
        key: const Key('category-edit-save'),
        label: 'Saqlash',
        onPressed: _canSave ? _save : null,
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice(
      {required this.iconKey, required this.selected, required this.onTap});
  final String iconKey;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      key: Key('category-edit-icon-$iconKey'),
      button: true,
      selected: selected,
      label: iconKey,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(VeloraRadii.control),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(VeloraRadii.control),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
              ),
            ),
            child: Icon(
              categoryIcon(iconKey),
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Create the category management screen**

Create `lib/features/categories/category_management_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/category_icons.dart';
import 'categories_controller.dart';
import 'category_edit_sheet.dart';

/// Category manager reached from Settings ▸ Kategoriyalar. A reorderable list
/// of active categories (tap to edit, remove to archive), an archived/restore
/// section, and a "Yangi" entry. Budget limits were removed — this manages
/// only name, icon, archive state, and order.
class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final controller = ref.read(categoriesControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kategoriyalar')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('category-add'),
        onPressed: () => showCategoryEditSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Yangi'),
      ),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Xatolik yuz berdi')),
        data: (cats) {
          final active = [for (final c in cats) if (!c.archived) c];
          final archived = [for (final c in cats) if (c.archived) c];
          return ListView(
            padding: const EdgeInsets.all(VeloraSpacing.lg),
            children: [
              ReorderableListView(
                key: const Key('category-reorder-list'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: (oldIndex, newIndex) {
                  final ids = [for (final c in active) c.id];
                  if (newIndex > oldIndex) newIndex -= 1;
                  final moved = ids.removeAt(oldIndex);
                  ids.insert(newIndex, moved);
                  controller.reorderCategories(ids);
                },
                children: [
                  for (final c in active)
                    ListTile(
                      key: ValueKey(c.id),
                      leading: Icon(categoryIcon(c.icon)),
                      title: Text(c.name),
                      onTap: () =>
                          showCategoryEditSheet(context, categoryId: c.id),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: Key('category-archive-${c.id}'),
                            icon: const Icon(Icons.remove_circle_outline,
                                color: VeloraColors.critical),
                            tooltip: 'Olib tashlash',
                            onPressed: () =>
                                controller.setCategoryArchived(c.id, true),
                          ),
                          const Icon(Icons.drag_handle),
                        ],
                      ),
                    ),
                ],
              ),
              if (archived.isNotEmpty) ...[
                const SizedBox(height: VeloraSpacing.lg),
                Text(
                  'Olib tashlangan',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: VeloraColors.muted,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: VeloraSpacing.sm),
                for (final c in archived)
                  ListTile(
                    key: Key('category-restore-${c.id}'),
                    leading: Icon(categoryIcon(c.icon)),
                    title: Text(c.name),
                    trailing: TextButton(
                      onPressed: () =>
                          controller.setCategoryArchived(c.id, false),
                      child: const Text('Tiklash'),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 6: Wire the Settings entry**

In `lib/features/settings/settings_screen.dart`:
- Add import: `import '../categories/category_management_screen.dart';`.
- In the "Moliyaviy sozlamalar" `_SettingsGroup` (the one starting after `const _SectionHeader('Moliyaviy sozlamalar'),`), add as the first `ListTile` child:

```dart
                  ListTile(
                    key: const Key('settings-categories'),
                    leading: const _RowIcon(Icons.category_outlined),
                    title: const Text('Kategoriyalar'),
                    trailing: const Icon(Icons.chevron_right,
                        color: VeloraColors.muted),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const CategoryManagementScreen()),
                    ),
                  ),
```

- [ ] **Step 7: Move + rewrite the controller test**

```bash
mkdir -p test/features/categories
git mv test/features/budgets/budgets_controller_test.dart test/features/categories/categories_controller_test.dart
```

Rewrite `test/features/categories/categories_controller_test.dart` so it:
- imports `package:financial_assistant/features/categories/categories_controller.dart` (verify the package name from an existing test's import prefix; match it exactly),
- reads `categoriesControllerProvider` (not `budgetsControllerProvider`),
- drops the `setVariableBudget` test and every `categoryBudgetsProvider`/`setMonthlyLimit` reference,
- asserts category CRUD via `categoriesProvider` instead. Concretely:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/categories/categories_controller.dart';
// Reuse the existing in-memory DB / seed harness this test file already used
// (copy its setup from the pre-move version — same ProviderContainer overrides).

void main() {
  test('createCategory then it appears in categoriesProvider', () async {
    final container = /* build test container with in-memory db + seed */;
    addTearDown(container.dispose);

    final id = await container
        .read(categoriesControllerProvider)
        .createCategory(name: 'Sport', icon: 'category');
    final cats = await container.read(categoriesProvider.future);
    expect(cats.any((c) => c.id == id && c.name == 'Sport'), isTrue);
  });

  test('setCategoryArchived hides then restores a category', () async {
    final container = /* build test container */;
    addTearDown(container.dispose);

    await container.read(categoriesControllerProvider).setCategoryArchived(1, true);
    var cats = await container.read(categoriesProvider.future);
    expect(cats.firstWhere((c) => c.id == 1).archived, isTrue);

    await container.read(categoriesControllerProvider).setCategoryArchived(1, false);
    cats = await container.read(categoriesProvider.future);
    expect(cats.firstWhere((c) => c.id == 1).archived, isFalse);
  });

  test('reorderCategories persists new order', () async {
    final container = /* build test container */;
    addTearDown(container.dispose);

    final before = await container.read(categoriesProvider.future);
    final reversed = before.map((c) => c.id).toList().reversed.toList();
    await container.read(categoriesControllerProvider).reorderCategories(reversed);
    final after = await container.read(categoriesProvider.future);
    expect(after.map((c) => c.id).toList(), reversed);
  });

  test('saveCategory (new) creates and returns Ok(id)', () async {
    final container = /* build test container */;
    addTearDown(container.dispose);

    final res = await container
        .read(categoriesControllerProvider)
        .saveCategory(name: 'Kitob', icon: 'category');
    expect(res.isOk, isTrue);
    final cats = await container.read(categoriesProvider.future);
    expect(cats.any((c) => c.name == 'Kitob'), isTrue);
  });
}
```

Keep the exact container/DB setup helper from the original file (copy it verbatim from git history: `git show HEAD:test/features/budgets/budgets_controller_test.dart`). Replace the `/* build test container */` placeholders with that helper.

- [ ] **Step 8: Move + strip the edit-sheet test**

```bash
git mv test/features/budgets/category_edit_sheet_test.dart test/features/categories/category_edit_sheet_test.dart
```

Edit `test/features/categories/category_edit_sheet_test.dart`:
- Update the import path to `.../features/categories/category_edit_sheet.dart` and controller to `categories_controller.dart`.
- Remove every `categoryBudgetsProvider` read and every assertion about the monthly-limit field (`category-edit-monthly`), the "Joriy holat" status card, and limit subtitles.
- Keep/adjust assertions for: opening the sheet, searching, creating a category (name + icon + Saqlash), editing a name, and archive/unarchive. Verify categories via `categoriesProvider`.
- If a test asserted `find.byKey(const Key('category-edit-monthly'))` exists, invert it to `findsNothing`:

```dart
  testWidgets('no monthly-limit field is shown', (tester) async {
    // ... pump the sheet in edit mode for category 1 ...
    expect(find.byKey(const Key('category-edit-monthly')), findsNothing);
  });
```

- [ ] **Step 9: Create the management-screen test**

Create `test/features/categories/category_management_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/categories/category_management_screen.dart';
// Reuse the seed/in-memory-db ProviderScope harness other feature tests use
// (copy from category_edit_sheet_test.dart's setup).

void main() {
  testWidgets('lists active categories and can archive one', (tester) async {
    // Pump CategoryManagementScreen inside a ProviderScope with the in-memory
    // seeded DB (same harness as category_edit_sheet_test).
    // 1. Expect the reorder list is present:
    expect(find.byKey(const Key('category-reorder-list')), findsOneWidget);
    // 2. Tap archive on category 1:
    await tester.tap(find.byKey(const Key('category-archive-1')));
    await tester.pumpAndSettle();
    // 3. It moves to the archived section with a restore action:
    expect(find.byKey(const Key('category-restore-1')), findsOneWidget);
    // 4. No budget/limit UI exists:
    expect(find.textContaining('Oylik reja'), findsNothing);
  });

  testWidgets('opens the create sheet from the add FAB', (tester) async {
    // ... pump screen ...
    await tester.tap(find.byKey(const Key('category-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('category-edit-name')), findsOneWidget);
  });
}
```

Fill the harness/pump comments with the same ProviderScope + in-memory DB setup the sibling category tests use (copy it; do not invent a new one).

- [ ] **Step 10: Run the categories tests**

Run: `flutter test --concurrency=1 test/features/categories/`
Expected: PASS. Fix import prefixes / harness copies as needed.

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "feat(categories): limit-free category manager in Settings; rename controller"
```

---

## Task 4: Delete the dead category-budget cluster

**Files:**
- Delete: `lib/core/budget/category_budget_engine.dart`
- Delete: `lib/features/budgets/budget_labels.dart`
- Delete: `lib/data/budget/budget_repository.dart`
- Modify: `lib/providers/app_providers.dart` (remove `categoryBudgetsProvider`, `archivedCategoriesProvider`, `budgetRepositoryProvider`, dead imports)
- Delete: `test/core/budget/category_budget_engine_test.dart`, `test/data/budget/budget_repository_test.dart`
- Modify: `test/providers/safe_limit_providers_test.dart`, `test/goldens/existing_flow_gallery_test.dart`

**Interfaces:**
- Consumes: nothing new. This task removes symbols no longer referenced after Tasks 1-3.
- Produces: `app_providers.dart` no longer exports `categoryBudgetsProvider`, `archivedCategoriesProvider`, `budgetRepositoryProvider`.

- [ ] **Step 1: Remove the dead providers from app_providers.dart**

In `lib/providers/app_providers.dart`:
- Delete `budgetRepositoryProvider` (the `Provider<BudgetRepository>` at ~180-182).
- Delete `categoryBudgetsProvider` (whole block ~332-365).
- Delete `archivedCategoriesProvider` (whole block ~367-376) — its only consumers (BudgetsScreen, budgets_removed_view_test) are already gone.
- Remove now-unused imports: `import '../core/budget/category_budget_engine.dart';`, `import '../data/budget/budget_repository.dart';`, and any `FinancialPeriod`/`categorySpent`/`startOfWeek` imports that were used ONLY by `categoryBudgetsProvider` (the analyzer will flag unused imports — remove exactly those it flags; keep any still used by `safeLimitProvider` etc.).

- [ ] **Step 2: Delete the cluster source files**

```bash
git rm lib/core/budget/category_budget_engine.dart \
  lib/features/budgets/budget_labels.dart \
  lib/data/budget/budget_repository.dart \
  test/core/budget/category_budget_engine_test.dart \
  test/data/budget/budget_repository_test.dart
```

- [ ] **Step 3: Remove the categoryBudgetsProvider test in safe_limit_providers_test**

In `test/providers/safe_limit_providers_test.dart`, delete the test `'categoryBudgetsProvider reports over-limit status'` (~95-119 and any `categoryBudgetsProvider` reference). Leave the safe-limit tests intact.

- [ ] **Step 4: Remove budget-screen gallery entries from existing_flow_gallery_test**

In `test/goldens/existing_flow_gallery_test.dart`, remove the gallery cases that override `categoryBudgetsProvider` and render `BudgetsScreen` (the blocks around lines ~704, ~746, and ~999-1029). Delete the corresponding import of `BudgetsScreen` if present, and any golden baseline PNGs those specific cases produced (search `test/goldens/` for their file names and `git rm` them). Do not touch unrelated gallery cases.

- [ ] **Step 5: Static analysis — confirm nothing dangles**

Run: `flutter analyze`
Expected: No errors. Fix any straggler references (unused imports, leftover symbol uses) it reports.

- [ ] **Step 6: Full test suite**

Run: `flutter test --concurrency=1`
Expected: PASS, except any pre-existing environmentally-flaky full-screen goldens noted in the repo toolchain notes. If a golden fails, confirm it was failing before this change (check `test/goldens/failures/`) before regenerating; report such cases separately rather than mass-regenerating.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor: delete dead category-budget cluster (engine, labels, repo, providers)"
```

---

## Self-Review Notes (author)

- **Spec coverage:** tab repoint + relabel (Task 1) ✓; full category-budget removal — screen (T1), engine/labels/repo/providers (T4), Home overspend (T2), controller limit methods + limit field (T3) ✓; categories stay + management in Settings (T3) ✓; dormant `monthlyLimitMinor` column (no migration anywhere) ✓; tests deleted/updated/added ✓.
- **Type consistency:** `CategoriesController` / `categoriesControllerProvider` / limit-free `saveCategory({int? id, required String name, required String icon})` used identically in the sheet (Task 3 step 4), the screen (step 5), and tests (steps 7-9). `categoriesProvider` (`List<Category>`) is the single read path for the manager.
- **Ambiguity resolved:** `budget_repository.dart` is deleted outright (all three methods proven dead after Tasks 1-3), not stripped.
- **Package import prefix:** steps that add new test imports say to match the existing prefix (e.g. `package:financial_assistant/...`) — verify against a sibling test before writing.
