# Plan tab → card allocation; remove category budgets

**Date:** 2026-07-22
**Status:** Approved (pending spec review)

## Problem

On the **Reja** (plan) bottom tab the app currently shows the **category-budget**
feature (`BudgetsScreen`): per-category monthly limits, a category editor, and an
overspend alert that feeds the Home screen. The new card-based allocation
("Taqsimlash rejasi", `AllocationPlanScreen`) is a *secondary* screen reached from
that page's header and only becomes usable once an account (source card) exists.

The desired behavior: the plan tab should be the **card-based allocation** and
nothing else. The old category-budget / category-selection UI should be removed
from it.

## Decisions (from brainstorming)

1. **Full removal** of the category-budget (monthly-limit) system — not a move.
2. **Categories themselves stay.** They are load-bearing: every expense must be
   tagged (`CategoryPicker` in expense entry; `_categoryId != null` required to
   save), and history filters by category. Category **management** (add / rename /
   icon / archive / reorder, **no limit**) **moves to Settings**.
3. **Reja tab is renamed to "Taqsimlash"** (label). Its content becomes
   `AllocationPlanScreen`.
4. **`Category.monthlyLimitMinor` DB column stays dormant** — no migration, no
   schema bump. We stop reading/writing it.

## Scope

### In scope
- Repoint the plan nav branch to `AllocationPlanScreen`; rename the tab label to
  "Taqsimlash".
- Delete the category-budget cluster (screen, engine, status labels, provider,
  limit repo/controller methods, Home overspend explanation).
- Add a category-management entry + screen in Settings (limit-free).
- Update/remove/add tests accordingly.

### Out of scope
- Dropping the `monthlyLimitMinor` column (kept dormant — explicit decision).
- Any change to expense categorization, transactions category filters, or the
  card allocation feature itself.
- Removing other already-dormant settings/model fields (`variableBudget`,
  `minReserve`, `allocatedMinor`, etc.) — untouched.

## Design

### 1. Navigation (`lib/features/shell/`)
- `routes.dart`: the `plan` `StatefulShellBranch` builder returns
  `AllocationPlanScreen` instead of `BudgetsScreen`. Keep
  `PageStorageKey('plan-tab')`. `RouteNames.plan` / `RoutePaths.plan` unchanged.
- `app_shell.dart`: the third `NavigationDestination` label changes from `'Reja'`
  to `'Taqsimlash'`. Icon stays `account_tree_outlined`.
- `AllocationPlanScreen` already provides its own `Scaffold` + `AppBar`
  ("Taqsimlash rejasi"), so it renders correctly as a tab body. Its previous
  entry point (the Budjet header `tune` button) disappears with `BudgetsScreen`.

### 2. Delete the category-budget cluster
Contained in these 7 files (confirmed blast radius):

| File | Action |
|------|--------|
| `lib/features/budgets/budgets_screen.dart` | **Delete** (was the Reja tab) |
| `lib/core/budget/category_budget_engine.dart` | **Delete** (`CategoryBudgetView`, `CategoryLimitStatus`, builders) |
| `lib/features/budgets/budget_labels.dart` | **Delete** (`budgetVeloraStatus` / `budgetStatusLabel` / `budgetStatusIcon`) |
| `lib/providers/app_providers.dart` | Remove `categoryBudgetsProvider` + `_overspendCategories` helper + related imports |
| `lib/data/budget/budget_repository.dart` | Remove `setCategoryLimits`; if the file/provider becomes empty of real use, delete it and `budgetRepositoryProvider` |
| `lib/features/budgets/budgets_controller.dart` | Remove `setMonthlyLimit`; drop the limit write from `saveCategory` (see §4). Keep category CRUD |
| `lib/features/budgets/category_edit_sheet.dart` | **Rework** → limit-free category screen (see §4) |

`Category.monthlyLimitMinor` field: left on the model/table, **no reads/writes**.

### 3. Home — drop the overspend explanation
The Home screen only consumes a derived `List<String> overspendCategories`, so
removal is shallow:
- `dashboardProvider` (`app_providers.dart`): remove the `categoryBudgetsProvider`
  fetch and the `overspendCategories:` argument to `buildDashboard`.
- `lib/features/home/dashboard_data.dart`: remove the `overspendCategories` field
  (from `DashboardData`, its constructor, and `buildDashboard`'s param).
- `lib/features/home/safe_limit_cards.dart`: remove the `overspendCategories`
  param and the `if (status == over && overspendCategories.isNotEmpty)` block that
  renders "Limitdan chiqqan: …".
- `lib/features/home/home_screen.dart`: stop passing `overspendCategories`.

The safe-limit hero itself (daily limit, over/near/safe status) is **unchanged** —
only the category-name explanation line is removed.

### 4. Category management → Settings
- **Controller:** rename `BudgetsController` → `CategoriesController`
  (`budgets_controller.dart` → `categories_controller.dart`,
  `budgetsControllerProvider` → `categoriesControllerProvider`). It now exposes
  only category operations: `createCategory`, `renameCategory`, `setCategoryIcon`,
  `setCategoryArchived`, `reorderCategories`, and a limit-free `saveCategory`
  (drops `monthlyLimit` / `monthlyLimitUnparseable` params and the
  `setCategoryLimits` call). `setVariableBudget` (dormant) stays or moves — keep as
  a no-op-adjacent method to avoid churn.
- **Screen:** rework `category_edit_sheet.dart` into a limit-free category
  manager. Reads `categoriesProvider` (already exists: all categories incl.
  archived, ledger-revision aware). Removals from the current sheet:
  - the `_monthlyCtrl` field + `_limitField` ("Oylik reja") widget,
  - the `_CurrentStatusCard` ("Joriy holat") + its `CategoryBudgetView` load,
  - the `categoryBudgetsProvider` dependency (list subtitle no longer shows a
    limit; show the category icon/name only).
  Kept: search, create-new, rename, icon picker, archive/unarchive, reorder.
  Where the current manage/reorder UX lived in `BudgetsScreen`, fold reorder into
  this screen (or a simple list) so it isn't lost.
- **Settings entry:** `settings_screen.dart` gets a **"Kategoriyalar"** `ListTile`
  (icon `category_outlined`) under the **"Moliyaviy sozlamalar"** group, opening
  the category manager.

### 5. Data flow (after change)
```
Expense entry ──uses──> categoriesProvider / categoryRepository (unchanged)
History filters ──uses──> categoriesProvider (unchanged)
Settings ▸ Kategoriyalar ──> CategoriesController ──> categoryRepository
Taqsimlash tab ──> AllocationPlanScreen ──> allocationPlan* (unchanged)
Home safe-limit hero ──> dashboardProvider (no longer reads category budgets)
```
No component reads the category-budget engine after this change.

### 6. Error handling
- `saveCategory` keeps its single-transaction wrapper and `Result<int>` return
  (now covering only rename/icon or create — no partial-limit-write hazard).
- No new failure modes introduced; deletions only remove code paths.

## Testing

**Delete**
- `test/features/budgets/…` budgets_screen tests + golden(s), category-edit limit
  assertions.
- `test/core/budget/…` category_budget_engine test.
- budget_labels test if any.

**Update**
- Home tests: remove `overspendCategories` expectations / any "Limitdan chiqqan"
  assertion.
- Routes/shell test: plan branch now builds `AllocationPlanScreen`; nav label
  "Taqsimlash".
- Any test referencing `BudgetsController` / `budgetsControllerProvider` →
  renamed symbols.

**Add**
- Settings: "Kategoriyalar" row opens the manager; create / rename / archive /
  reorder work; **no limit field is present**.
- (Reuse existing category CRUD coverage against the renamed controller.)

**Full suite:** `flutter test --concurrency=1` green. Some full-screen goldens are
known environmentally flaky here (see toolchain notes) — verify the *changed*
goldens specifically and note any pre-existing failures separately.

## Risks / notes
- **Dormant column:** `monthlyLimitMinor` remaining in the schema is intentional;
  a future cleanup can drop it with a proper migration if desired.
- **Symbol rename churn:** `BudgetsController` → `CategoriesController` touches
  every reference; a mechanical find/replace, but must be complete (analyzer will
  catch stragglers).
- **`budget_repository.dart` fate:** confirm it holds nothing but limit logic
  before deleting; otherwise strip only `setCategoryLimits`.
