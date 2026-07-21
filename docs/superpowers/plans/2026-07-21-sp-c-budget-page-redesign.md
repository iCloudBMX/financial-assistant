# SP-C: Budget Page Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the Budget page into (1) a read-only, cards-driven daily-limit summary sourced from SP-B's `safeLimitProvider`, (2) a single active category list with add / remove(=archive, history preserved) / restore ("Olib tashlangan" view) / reorder, and (3) a redesigned category detail sheet (name + icon + monthly plan "Oylik reja" only). Remove the dead abstract variable-budget/safety-buffer UI, and remove the category `kind` (and weekly-limit editor) from the Dart model + UI.

**Architecture:** Presentation + thin controller change over data-layer that already exists. `CategoryRepository` already supports `create` / `setArchived` / `reorder` / `list(includeArchived:)`, and `categoryBudgetsProvider` already yields `CategoryBudgetView`s (non-archived by default). The summary card is a pure value widget reading the existing `SafeLimit` value object. No new engine, no schema-destructive migration: the `kind` and `weeklyLimitMinor` DB columns stay present-but-unused (see Global Constraints). Files touched: `lib/features/budgets/budgets_screen.dart`, `lib/features/budgets/category_edit_sheet.dart`, `lib/features/budgets/budgets_controller.dart`, `lib/features/budgets/budget_labels.dart`, `lib/data/categories/category_model.dart`, `lib/data/categories/category_repository.dart`, `lib/data/budget/budget_repository.dart`, `lib/providers/app_providers.dart`; plus a new `lib/features/budgets/budget_summary_card.dart`. The SP-C HTML prototype is revised first (Task 1).

**Tech Stack:** Flutter/Dart, drift ORM (SQLite), flutter_riverpod 3.x, `flutter_test` widget tests. Velora design tokens.

## Global Constraints

- Flutter/Dart.
- drift ORM.
- flutter_riverpod 3.x (`StateProvider` needs `import 'package:flutter_riverpod/legacy.dart'`).
- Test command: `flutter test --concurrency=1`.
- Commit trailer: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- DEPENDS ON SP-A + SP-B merged. (As of writing, `AccountRole` and the rewritten `safeLimitProvider` are NOT yet in this repo — do not start SP-C until they are. This plan reads `safeLimitProvider`/`SafeLimit` through the fixed contract only, never `Account.role` directly.)
- Velora design tokens (`lib/core/theme/velora_tokens.dart`) — match existing screens (`VeloraColors`, `VeloraSpacing`, `VeloraRadii`, `VeloraStatus`, `VeloraCard`, `VeloraSheetScaffold`, `VeloraPrimaryButton`). Never hardcode hex.
- Some full-screen goldens fail in this environment (pre-existing/environmental) — prefer widget-behaviour tests over new full goldens.
- Terminology on this surface: "Limit" → "Reja" everywhere. Category detail plan field label: "Oylik reja". Empty spending-accounts hint: "Sarf kartasi belgilang".
- Money rendering: `Money.format()` = number **with** the `so'm` suffix; `Money.formatNumber()` = number only.
- Keep the `kind` and `weeklyLimitMinor` DB columns present-but-unused — no destructive migration. Remove `kind` from the Dart model + UI; keep `weeklyLimitMinor` on the Dart model (still mapped/used by `categoryBudgetsProvider`'s week calc) but strip it from the UI.

---

### Task 1: Revise the SP-C prototype to model A

**Files:**
- Modify: the standalone SP-C mockup HTML (artifact `fecf697d-5f78-4640-b292-29d2452606f5`; the engineer edits the local HTML source of that prototype).

**Interfaces:**
- Consumes from SP-B: conceptually the `SafeLimit` figures (per-day limit + spending pool). No code.
- Produces: an updated mockup that the UI tasks below match.

- [ ] **Step 1: Replace the abstract top card with a cards-driven daily-limit summary.** In the prototype's top section, delete the "erkin xarajat / zaxira" (variable-budget + safety-buffer) card entirely. Replace it with a single read-only plum hero card showing:
  - A caption `BUGUNGI LIMIT`.
  - The big per-day figure (e.g. `120 000 so'm`).
  - A supporting line: `Sarf kartalari qoldig'i · <spendable> so'm · <N> kun qoldi`.
  - An empty state variant (no spending cards): the hero collapses to the hint `Sarf kartasi belgilang` with a link/chip to the Accounts screen.
  This card is **read-only** on the Budget page (it links to Accounts to change roles/balances) — it must not show any editable money fields.
- [ ] **Step 2: Rename "Limit" → "Reja" throughout the prototype's budget surface** (section headers, category rows, detail sheet). The category detail plan field is labelled `Oylik reja`. Remove the `Turi` (kind) chooser and the weekly-limit field from the detail mock. Confirm the category list mock shows a single active list plus a manage affordance (remove / add / reorder) and an "Olib tashlangan" (removed) view with restore. No commit (HTML prototype is not in this repo's commit flow) — save the file and proceed.

---

### Task 2: Cards-driven daily-limit summary widget (reads `safeLimitProvider`)

**Files:**
- Create: `lib/features/budgets/budget_summary_card.dart` (new pure value widget `BudgetSummaryCard`).
- Modify: `lib/features/budgets/budgets_screen.dart` (import + render the summary at the top of the `ListView`, replacing the `settings.maybeWhen(... _VariableBudgetCard ...)` block, lines ~51-63).
- Test: `test/features/budgets/budget_summary_card_test.dart` (new).

**Interfaces:**
- Consumes from SP-B: `safeLimitProvider` → `SafeLimit { Money perDay; Money spendable; int daysLeft; Money todaySpent; Money todayRemaining; bool get isOver; }` (`lib/core/limit/safe_limit_engine.dart`). READ ONLY — never recompute.
- Produces: `BudgetSummaryCard({required SafeLimit limit})` — a read-only plum hero. Empty/zero-pool state (`limit.spendable.minorUnits <= 0`) renders the `Sarf kartasi belgilang` hint instead of the figures.

- [ ] **Step 1: Failing widget test.** Create `test/features/budgets/budget_summary_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/limit/safe_limit_engine.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/features/budgets/budget_summary_card.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  testWidgets('shows the per-day limit and the spending pool', (tester) async {
    const limit = SafeLimit(
      spendable: Money(1200000, uzs),
      perDay: Money(120000, uzs),
      daysLeft: 10,
      todaySpent: Money(0, uzs),
      todayRemaining: Money(120000, uzs),
    );
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: BudgetSummaryCard(limit: limit)),
    ));

    expect(find.text('BUGUNGI LIMIT'), findsOneWidget);
    expect(find.text(limit.perDay.format()), findsOneWidget);
    // Spending pool + days-left live in the supporting line.
    expect(find.textContaining('Sarf kartalari qoldig'), findsOneWidget);
    expect(find.textContaining('10 kun'), findsOneWidget);
    // Read-only: no editable money fields on this surface.
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('an empty spending pool shows the "Sarf kartasi belgilang" hint',
      (tester) async {
    const limit = SafeLimit(
      spendable: Money(0, uzs),
      perDay: Money(0, uzs),
      daysLeft: 10,
      todaySpent: Money(0, uzs),
      todayRemaining: Money(0, uzs),
    );
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: BudgetSummaryCard(limit: limit)),
    ));

    expect(find.text('Sarf kartasi belgilang'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run — expect FAIL** (missing file `budget_summary_card.dart`):
  `flutter test --concurrency=1 test/features/budgets/budget_summary_card_test.dart`
- [ ] **Step 3: Minimal impl.** Create `lib/features/budgets/budget_summary_card.dart` (a read-only plum hero mirroring `SafeLimitCard`'s look, no progress interaction needed):

```dart
import 'package:flutter/material.dart';
import '../../core/limit/safe_limit_engine.dart';
import '../../core/theme/velora_tokens.dart';

/// The Budget page's read-only daily-limit summary. It renders SP-B's already
/// resolved [SafeLimit] (per-day figure + spending pool); it does not recompute
/// anything and it exposes no editable fields — the user changes the pool by
/// setting card roles/balances on the Accounts screen.
class BudgetSummaryCard extends StatelessWidget {
  const BudgetSummaryCard({super.key, required this.limit});

  final SafeLimit limit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const onPlum = Colors.white;
    final empty = limit.spendable.minorUnits <= 0;

    return Container(
      key: const Key('budget-summary-card'),
      padding: const EdgeInsets.all(VeloraSpacing.lg),
      decoration: BoxDecoration(
        color: VeloraColors.plum,
        borderRadius: BorderRadius.circular(VeloraRadii.card),
        boxShadow: const [
          BoxShadow(color: Color(0x335B3A6E), blurRadius: 26, offset: Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BUGUNGI LIMIT',
            style: theme.textTheme.labelSmall?.copyWith(
              color: onPlum.withValues(alpha: 0.68),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: VeloraSpacing.sm),
          if (empty)
            Text(
              'Sarf kartasi belgilang',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: onPlum, fontWeight: FontWeight.w700),
            )
          else ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                limit.perDay.format(),
                maxLines: 1,
                softWrap: false,
                style: theme.textTheme.headlineMedium
                    ?.copyWith(color: onPlum, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: VeloraSpacing.sm),
            Text(
              "Sarf kartalari qoldig'i ${limit.spendable.format()} "
              '· ${limit.daysLeft} kun qoldi',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: onPlum.withValues(alpha: 0.82)),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Wire it into the screen.** In `budgets_screen.dart`, add `import 'budget_summary_card.dart';`, add `final safeLimit = ref.watch(safeLimitProvider);` in `build`, and replace the `settings.maybeWhen(... _VariableBudgetCard ...)` block (lines ~51-63) with:

```dart
              safeLimit.maybeWhen(
                orElse: () => const SizedBox.shrink(),
                data: (l) => Padding(
                  padding: const EdgeInsets.only(bottom: VeloraSpacing.md),
                  child: BudgetSummaryCard(limit: l),
                ),
              ),
```

  (The `settings` watch and the `_variableSpent` helper become unused here — they are removed in Task 7 together with `_VariableBudgetCard`; keeping them un-referenced temporarily is fine, but delete the now-dead `settings`/`controller.setVariableBudget` usages in this same edit to keep the tree compiling.)
- [ ] **Step 5: Run — expect PASS:** `flutter test --concurrency=1 test/features/budgets/budget_summary_card_test.dart`
- [ ] **Step 6: Commit** `feat(budgets): read-only cards-driven daily-limit summary` with the required trailer.

---

### Task 3: Active category list with a "Rejalar" section header

**Files:**
- Modify: `lib/features/budgets/budgets_screen.dart` (list body + `_PlanHeader` subtitle copy; `_CategoryBudgetCard` row).
- Modify: `lib/features/budgets/budget_labels.dart` (`budgetStatusLabel` copy uses "reja").
- Test: `test/features/budgets/budgets_screen_test.dart` (adjust existing).

**Interfaces:**
- Consumes: `categoryBudgetsProvider` → `List<CategoryBudgetView>` where `CategoryBudgetView { Category category; Money monthSpent; Money weekSpent; CategoryLimitStatus monthStatus; CategoryLimitStatus weekStatus; }` (`lib/providers/app_providers.dart`, ~L313). Provider already returns non-archived categories only (`categoriesWithBudgets()` defaults `includeArchived:false`).
- Produces: a single active list, each row read-only-plus-edit, terminology "Reja". No `kind` chip, no weekly status line (both removed in Tasks 6/7).

- [ ] **Step 1: Failing test.** In `budgets_screen_test.dart`, update the header subtitle expectation and add a "Reja" list-header assertion. Replace the header subtitle copy check (the screen currently renders `'Kategoriya limitlari'`) with a new test:

```dart
  testWidgets('the category section renders under a "Rejalar" header with '
      'the seeded categories', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: BudgetsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Rejalar'), findsOneWidget);
    expect(find.text('Oziq-ovqat'), findsOneWidget); // seeded category #1
  });
```

- [ ] **Step 2: Run — expect FAIL** (`Rejalar` header not present):
  `flutter test --concurrency=1 test/features/budgets/budgets_screen_test.dart -p vm --plain-name "Rejalar"`
- [ ] **Step 3: Minimal impl.** In `budgets_screen.dart`:
  - Change `_PlanHeader`'s subtitle text from `'Kategoriya limitlari'` to `'Kategoriya rejalari'`.
  - Insert a section header row above the category cards in the `ListView` children (after the summary card):

```dart
              const SizedBox(height: VeloraSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text('Rejalar',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  TextButton.icon(
                    key: const Key('budgets-manage'),
                    onPressed: () {/* Task 4 wires manage mode */},
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Boshqarish'),
                  ),
                ],
              ),
              const SizedBox(height: VeloraSpacing.sm),
```

  - In `budget_labels.dart`, update `budgetStatusLabel` copy to the "reja" wording: `noLimit => 'rejasiz'`, `safe => 'xavfsiz'`, `near => 'rejaga yaqin'`, `over => 'rejadan oshgan'`. Update the corresponding assertions in `budgets_screen_test.dart` (the over-status test expects `find.textContaining('limitdan oshgan')` → `find.textContaining('rejadan oshgan')`).
- [ ] **Step 4: Run — expect PASS:** `flutter test --concurrency=1 test/features/budgets/budgets_screen_test.dart`
- [ ] **Step 5: Commit** `feat(budgets): active category list under a Rejalar section header`.

---

### Task 4: Manage mode — remove(archive) / add / reorder

**Files:**
- Modify: `lib/features/budgets/budgets_controller.dart` (add `reorderCategories`).
- Modify: `lib/features/budgets/budgets_screen.dart` (a manage mode: `ReorderableListView`, per-row archive button, add entry, and an entry to the "Olib tashlangan" view of Task 5).
- Test: `test/features/budgets/budgets_manage_test.dart` (new) + `test/features/budgets/budgets_controller_test.dart` (add reorder test).

**Interfaces:**
- Consumes: `CategoryRepository.reorder(List<int> orderedIds)`, `CategoryRepository.setArchived(int id, bool archived)`, `CategoryRepository.create(...)` (all exist, `lib/data/categories/category_repository.dart`). `categoryRepositoryProvider` (`app_providers.dart`).
- Produces: `BudgetsController.reorderCategories(List<int> orderedIds)`; a manage UI that archives a category (history preserved), adds one (opens the detail sheet's create path), and reorders.

- [ ] **Step 1: Failing controller test.** In `budgets_controller_test.dart` add:

```dart
  test('reorderCategories persists the new sortOrder and bumps the revision',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    final before = await container.read(categoryBudgetsProvider.future);
    final ids = before.map((v) => v.category.id).toList();
    final reversed = ids.reversed.toList();

    final rev = container.read(ledgerRevisionProvider);
    await container.read(budgetsControllerProvider).reorderCategories(reversed);
    expect(container.read(ledgerRevisionProvider), greaterThan(rev));

    final after = await container.read(categoryBudgetsProvider.future);
    expect(after.map((v) => v.category.id).toList(), reversed);
  });
```

- [ ] **Step 2: Run — expect FAIL** (`reorderCategories` undefined):
  `flutter test --concurrency=1 test/features/budgets/budgets_controller_test.dart --plain-name "reorderCategories"`
- [ ] **Step 3: Minimal impl.** In `budgets_controller.dart` add:

```dart
  Future<void> reorderCategories(List<int> orderedIds) async {
    await ref.read(categoryRepositoryProvider).reorder(orderedIds);
    _bump();
  }
```

- [ ] **Step 4: Run — expect PASS:** `flutter test --concurrency=1 test/features/budgets/budgets_controller_test.dart`
- [ ] **Step 5: Failing manage-UI test.** Create `test/features/budgets/budgets_manage_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/budgets/budgets_screen.dart';

void main() {
  testWidgets('manage mode archives a category (removed from the active list, '
      'history preserved via archived flag)', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: BudgetsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('budgets-manage')));
    await tester.pumpAndSettle();

    // Archive the first category via its manage-mode remove button.
    await tester.tap(find.byKey(const Key('budgets-remove-1')));
    await tester.pumpAndSettle();

    final views = await container.read(categoryBudgetsProvider.future);
    expect(views.any((v) => v.category.id == 1), isFalse);
    // Still present when archived rows are included (history preserved).
    final all = await container
        .read(budgetRepositoryProvider)
        .categoriesWithBudgets(includeArchived: true);
    expect(all.any((c) => c.id == 1 && c.archived), isTrue);
  });
}
```

- [ ] **Step 6: Run — expect FAIL** (manage mode / keys absent):
  `flutter test --concurrency=1 test/features/budgets/budgets_manage_test.dart`
- [ ] **Step 7: Minimal impl.** In `budgets_screen.dart` add a `bool _manage` to a new `StatefulWidget`/`ConsumerStatefulWidget` wrapper (or lift `BudgetsScreen` to `ConsumerStatefulWidget`). When `_manage` is true, render the category list as a `ReorderableListView` whose rows carry a remove button and a drag handle; the "Boshqarish" button toggles `_manage`. Manage-mode row:

```dart
  Widget _manageRow(CategoryBudgetView v, BudgetsController controller) {
    return ListTile(
      key: ValueKey(v.category.id),
      leading: IconButton(
        key: Key('budgets-remove-${v.category.id}'),
        icon: const Icon(Icons.remove_circle_outline, color: VeloraColors.critical),
        tooltip: 'Olib tashlash',
        onPressed: () => controller.setCategoryArchived(v.category.id, true),
      ),
      title: Text(v.category.name),
      trailing: const Icon(Icons.drag_handle),
    );
  }
```

  and the reorderable list wiring:

```dart
              if (_manage)
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  onReorder: (oldIndex, newIndex) {
                    final ids = [for (final v in list) v.category.id];
                    if (newIndex > oldIndex) newIndex -= 1;
                    final moved = ids.removeAt(oldIndex);
                    ids.insert(newIndex, moved);
                    controller.reorderCategories(ids);
                  },
                  children: [for (final v in list) _manageRow(v, controller)],
                )
              else
                for (final v in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: VeloraSpacing.md),
                    child: _CategoryBudgetCard(view: v, controller: controller),
                  ),
```

  Wire the "Boshqarish" `TextButton` (`Key('budgets-manage')`) to `setState(() => _manage = !_manage)`. Add an "Yangi kategoriya" add entry in manage mode that calls `showCategoryEditSheet(context)` (create path), and an "Olib tashlangan" entry that opens the Task 5 view.
- [ ] **Step 8: Run — expect PASS:** `flutter test --concurrency=1 test/features/budgets/budgets_manage_test.dart`
- [ ] **Step 9: Commit** `feat(budgets): manage mode with archive/add/reorder`.

---

### Task 5: "Olib tashlangan" restore view

**Files:**
- Modify: `lib/providers/app_providers.dart` (add `archivedCategoriesProvider`).
- Modify: `lib/features/budgets/budgets_screen.dart` (an "Olib tashlangan" screen/sheet listing archived categories with a restore action).
- Test: `test/features/budgets/budgets_removed_view_test.dart` (new).

**Interfaces:**
- Consumes: `budgetRepositoryProvider.categoriesWithBudgets(includeArchived: true)` filtered to `archived == true`; `BudgetsController.setCategoryArchived(id, false)` to restore (exists).
- Produces: `archivedCategoriesProvider` → `FutureProvider<List<Category>>`; a restore UI.

- [ ] **Step 1: Failing test.** Create `test/features/budgets/budgets_removed_view_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/budgets/budgets_controller.dart';

void main() {
  test('archivedCategoriesProvider lists only archived categories, and '
      'restoring returns the category to the active list', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    await container.read(budgetsControllerProvider).setCategoryArchived(1, true);
    final archived = await container.read(archivedCategoriesProvider.future);
    expect(archived.map((c) => c.id), contains(1));
    expect(archived.every((c) => c.archived), isTrue);

    await container.read(budgetsControllerProvider).setCategoryArchived(1, false);
    final active = await container.read(categoryBudgetsProvider.future);
    expect(active.any((v) => v.category.id == 1), isTrue);
  });
}
```

- [ ] **Step 2: Run — expect FAIL** (`archivedCategoriesProvider` undefined):
  `flutter test --concurrency=1 test/features/budgets/budgets_removed_view_test.dart`
- [ ] **Step 3: Minimal impl.** In `app_providers.dart`, near `categoryBudgetsProvider`, add:

```dart
/// Archived (removed) categories, for the Budget page's "Olib tashlangan"
/// restore view. History is preserved: removal is `archived = true`, never a
/// delete, so these can be restored.
final archivedCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  ref.watch(ledgerRevisionProvider);
  final cats = await ref
      .watch(budgetRepositoryProvider)
      .categoriesWithBudgets(includeArchived: true);
  return cats.where((c) => c.archived).toList(growable: false);
});
```

  In `budgets_screen.dart` add an "Olib tashlangan" view (a `showModalBottomSheet` using `VeloraSheetScaffold`, or a pushed screen) that watches `archivedCategoriesProvider` and renders each archived category with a restore button:

```dart
                ListTile(
                  key: Key('budgets-restore-${c.id}'),
                  leading: Icon(categoryIcon(c.icon)),
                  title: Text(c.name),
                  trailing: TextButton(
                    onPressed: () => ref
                        .read(budgetsControllerProvider)
                        .setCategoryArchived(c.id, false),
                    child: const Text('Tiklash'),
                  ),
                ),
```

- [ ] **Step 4: Run — expect PASS:** `flutter test --concurrency=1 test/features/budgets/budgets_removed_view_test.dart`
- [ ] **Step 5: Commit** `feat(budgets): "Olib tashlangan" restore view`.

---

### Task 6: Redesigned category detail sheet (name / icon / Oylik reja; no kind, no weekly)

**Files:**
- Modify: `lib/features/budgets/category_edit_sheet.dart` (`_CategoryFormState`: drop `_kind`, `_weeklyCtrl`, the "Turi" ChoiceChips, the weekly `_limitField`; relabel monthly field "Oylik reja"; the list subtitle stops showing `categoryKindLabel`).
- Modify: `lib/features/budgets/budgets_controller.dart` (`saveCategory` loses `kind`/`weekly` params — see Task 7; keep `setMonthlyLimit`).
- Test: `test/features/budgets/category_edit_sheet_test.dart` (rewrite kind/weekly cases).

**Interfaces:**
- Consumes: `BudgetsController.saveCategory({int? id, required String name, required String icon, Money? monthlyLimit, bool monthlyLimitUnparseable})` (post-Task-7 signature), `categoryBudgetsProvider` for the "Joriy holat" summary card.
- Produces: a detail sheet with name field, icon picker, and a single "Oylik reja" money field. Archive/restore stays.

- [ ] **Step 1: Failing tests.** In `category_edit_sheet_test.dart`:
  - Delete the `toggling kind to majburiy persists` test and the `editing the name and a weekly limit` test (weekly is gone).
  - Add a monthly-plan test using the new key/label:

```dart
  testWidgets('editing the name and the Oylik reja persists both', (tester) async {
    final container = await pumpDirectEdit(tester, categoryId: 1);

    await tester.enterText(
        find.byKey(const Key('category-edit-name')), 'Ovqatlanish');
    await tester.enterText(
        find.byKey(const Key('category-edit-monthly')), '500 000');
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();

    final views = await container.read(categoryBudgetsProvider.future);
    final cat1 = views.firstWhere((v) => v.category.id == 1).category;
    expect(cat1.name, 'Ovqatlanish');
    expect(cat1.monthlyLimitMinor, 500000);
  });

  testWidgets('there is no Turi (kind) chooser and no weekly field', (tester) async {
    await pumpDirectEdit(tester, categoryId: 1);
    expect(find.text('Turi'), findsNothing);
    expect(find.byKey(const Key('category-edit-weekly')), findsNothing);
    expect(find.text('Oylik reja'), findsOneWidget);
  });
```

  Also update the `_ThrowingBudgetRepository` in this test file: it implements `BudgetRepository`, so once `setCategoryKind` is removed from that interface (Task 7) its `setCategoryKind` override must be deleted too.
- [ ] **Step 2: Run — expect FAIL:** `flutter test --concurrency=1 test/features/budgets/category_edit_sheet_test.dart`
- [ ] **Step 3: Minimal impl.** In `_CategoryFormState`:
  - Remove `final _weeklyCtrl`, `CategoryKind _kind`, and their `initState`/`_load`/`dispose` usages.
  - Remove the `Text('Turi', ...)` + `Wrap` of `ChoiceChip`s block (lines ~351-363).
  - Remove the weekly `_limitField(...)` call (lines ~372-377).
  - Relabel the monthly field: `label: 'Oylik reja'` (was `'Oylik limit'`); keep `Key('category-edit-monthly')`. Change the hint in `_limitField` from `'Bo‘sh = limitsiz'` to `'Bo‘sh = rejasiz'`.
  - `_save` calls `controller.saveCategory(id:, name:, icon:, monthlyLimit: monthly.value, monthlyLimitUnparseable: monthly.unparseable)` (no `kind`/`weekly`).
  - `_CategoryList` subtitle: replace `Text(categoryKindLabel(v.category.kind))` with the monthly-plan summary, e.g. `Text(v.category.monthlyLimitMinor == null ? 'Rejasiz' : Money(v.category.monthlyLimitMinor!, v.monthSpent.currency).format())`.
- [ ] **Step 4: Run — expect PASS:** `flutter test --concurrency=1 test/features/budgets/category_edit_sheet_test.dart`
- [ ] **Step 5: Commit** `refactor(budgets): category detail sheet = name/icon/Oylik reja only`.

---

### Task 7: Remove abstract-settings UI + controller methods + `kind` from the model

**Files:**
- Modify: `lib/features/budgets/budgets_screen.dart` (delete `_VariableBudgetCard`, `_BudgetMoneyField`, `_KindChip`, `_variableSpent`, the weekly `_StatusLine`, and the `c.kind`/`c.weeklyLimitMinor` reads in `_CategoryBudgetCard`).
- Modify: `lib/features/budgets/budgets_controller.dart` (delete `setKind`, `setVariableBudget`, `setSafetyBuffer`, `setWeeklyLimit`, `_writeSettings`; drop `kind`/`weekly` from `saveCategory`).
- Modify: `lib/features/budgets/budget_labels.dart` (delete `categoryKindLabel`).
- Modify: `lib/data/categories/category_model.dart` (remove `CategoryKind` enum + `kind` field).
- Modify: `lib/data/categories/category_repository.dart` and `lib/data/budget/budget_repository.dart` (`_map` stops reading `r.kind`; `BudgetRepository.setCategoryKind` + `DriftBudgetRepository.setCategoryKind` removed).
- Test: `test/features/budgets/budgets_controller_test.dart`, `test/features/budgets/budgets_screen_test.dart` (remove `kind`/`setVariableBudget`/kind-chip tests).

**Interfaces:**
- Consumes from SP-B: the rewritten `safeLimitProvider` that no longer references `CategoryKind` (SP-B dropped `variableIds`). This task is only safe once SP-B is merged — otherwise removing `CategoryKind` breaks `safeLimitProvider`'s `c.kind == CategoryKind.variable` filter (`app_providers.dart` ~L376).
- Produces: a `Category` with no `kind`; `weeklyLimitMinor` retained on the model (mapped from the still-present DB column) but unused by the UI. DB columns `kind` and `weeklyLimitMinor` are left present-but-unused (no destructive migration).

- [ ] **Step 1: Prune the dead tests first.** In `budgets_controller_test.dart` delete the `setVariableBudget updates settings` test and the `setKind toggles...` test (and the weekly-status test if it references `setWeeklyLimit`; keep it only if you retain `setWeeklyLimit` — this plan removes it, so delete that test). In `budgets_screen_test.dart` delete the kind-chip toggle test and the weekly-limit-via-sheet test. Run to confirm the remaining suite still references only surviving symbols:
  `flutter test --concurrency=1 test/features/budgets/` (expect FAIL only from the not-yet-removed impl symbols).
- [ ] **Step 2: Remove `CategoryKind` from the model.** In `category_model.dart`:

```dart
class Category {
  final int id;
  final String name;
  final String icon;
  final bool isDefault;
  final bool archived;
  final int? monthlyLimitMinor;
  final int? weeklyLimitMinor;
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.isDefault,
    required this.archived,
    this.monthlyLimitMinor,
    this.weeklyLimitMinor,
  });
}
```

  In `category_repository.dart` and `budget_repository.dart`, delete `kind: CategoryKind.values.byName(r.kind as String),` from `_map`. In `budget_repository.dart` delete both the `setCategoryKind` interface method and its `DriftBudgetRepository` override.
- [ ] **Step 3: Prune the controller.** In `budgets_controller.dart` delete `setKind`, `setWeeklyLimit`, `setVariableBudget`, `setSafetyBuffer`, `_writeSettings`, and simplify `saveCategory` to:

```dart
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
      return Err(PersistenceFailure(error.toString()));
    }
    _bump();
    return Ok(categoryId);
  }
```

  Remove the now-unused imports (`settings_model.dart`, `CategoryKind`).
- [ ] **Step 4: Prune the screen + labels.** In `budgets_screen.dart` delete `_VariableBudgetCard`, `_BudgetMoneyField`, `_KindChip`, the `_variableSpent` method, the weekly `_StatusLine` render (`if (c.weeklyLimitMinor != null) ...`), and the `_KindChip` `Align` block in `_CategoryBudgetCard`. Remove the unused `settings`/`Currency`/`Money` imports if now dangling. In `budget_labels.dart` delete `categoryKindLabel` and its `import '../../data/categories/category_model.dart';` if that import becomes unused.
- [ ] **Step 5: Verify `safeLimitProvider` (SP-B) has no `CategoryKind` reference.** Grep `rg "CategoryKind" lib/` — it must return nothing. If `app_providers.dart` still has the `variableIds`/`c.kind` block (SP-B not merged), STOP: SP-B is a hard dependency for this step.
- [ ] **Step 6: Run — expect PASS** (whole budget suite + providers):
  `flutter test --concurrency=1 test/features/budgets/ test/providers/`
- [ ] **Step 7: Full run** to catch cross-feature fallout (Home, allocation, category-icon consumers):
  `flutter test --concurrency=1`
- [ ] **Step 8: Commit** `refactor(budgets): drop abstract variable-budget settings + category kind`.

---

## Notes / open coordination points

- **DB columns kept, not dropped.** `categoriesTable.kind` and `categoriesTable.weeklyLimitMinor` remain in the schema (present-but-unused for `kind`; still mapped for `weeklyLimitMinor`) to avoid a destructive drift migration. If a later cleanup wants to drop `kind`, do it as its own schema-version bump with a table recreate.
- **SP-B contract gap (empty state).** `SafeLimit` exposes no "how many spending accounts" signal, so `BudgetSummaryCard` infers the empty state from `spendable.minorUnits <= 0`. This conflates "no Sarf cards" with "Sarf cards that sum to zero". If SP-B can add a `hasSpendingAccounts`/account-count field to `SafeLimit`, prefer that; flagged for SP-B.
- **SP-A/SP-B not yet in-repo.** Verified 2026-07-21: `AccountRole` is absent from `lib/`, and `safeLimitProvider` still computes the old `variableBudget/minReserve` formula and filters by `CategoryKind`. Task 7's `CategoryKind` removal and Task 2's reliance on the role-sourced pool both require those merges first.
