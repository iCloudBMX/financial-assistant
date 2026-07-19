# Velora Existing Financial Flows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the approved Velora mockups to every already-built financial flow while fixing correctness seams exposed by the review.

**Architecture:** Compose the shared components from the UI Foundation plan around existing Riverpod controllers and repositories. Correct financial behavior in pure engines/repositories first, then redesign screens without embedding calculations in widgets.

**Tech Stack:** Flutter, Riverpod 3, Drift 2, GoRouter, existing pure Dart engines, widget/golden/integration tests.

## Global Constraints

- Execute after `2026-07-19-velora-ui-foundation.md`.
- Preserve integer money, local-only persistence, full offline behavior, and iOS/Android parity.
- Match approved Home, quick-expense, account carousel, category sheet, allocation, budget, goal, mortgage, onboarding, Settings, and PIN-first lock mockups.
- Every multi-write financial action is atomic and every failure is typed and user-safe.
- Quick expense completes in 3–5 seconds and opens within 300 ms on target hardware.

---

### Task 1: Fix safe-limit and typed-failure seams before UI work

**Files:**
- Modify: `lib/providers/app_providers.dart`
- Modify: `lib/core/limit/safe_limit_engine.dart`
- Modify: `lib/core/result/failure.dart`
- Modify: `lib/core/result/failure_messages.dart`
- Test: `test/providers/safe_limit_providers_test.dart`
- Test: `test/core/result/result_test.dart`

**Interfaces:**
- Produces: one `SafeLimitInputs` source for reserved funds and `userMessageFor(Failure)`.

- [ ] Write a regression test where available balance already excludes goal reservations and verify the reservation is not subtracted twice.

```dart
expect((await container.read(safeLimitProvider.future)).spendable.minorUnits, 700000);
```

- [ ] Run `flutter test test/providers/safe_limit_providers_test.dart` and confirm the new test fails with the current lower value.

- [ ] Choose one ownership rule and encode it: `totalAvailable` is ledger cash, while `goalReserves`, `minReserve`, and `unpaidMandatory` are subtracted exactly once in `dailySafeLimit`. Remove any provider-side pre-subtraction. Add `ValidationFailure`, `PersistenceFailure`, and `CurrencyFailure` message mappings.

- [ ] Run `flutter test test/providers/safe_limit_providers_test.dart test/core/result/result_test.dart` and expect PASS.

- [ ] Commit with `git add lib/providers/app_providers.dart lib/core/limit lib/core/result test/providers/safe_limit_providers_test.dart test/core/result && git commit -m "fix: make safe limit reservations single-source"`.

### Task 2: Redesign Home and quick actions

**Files:**
- Modify: `lib/features/home/dashboard_data.dart`
- Modify: `lib/features/home/home_screen.dart`
- Modify: `lib/features/home/safe_limit_cards.dart`
- Modify: `lib/features/mortgage/mortgage_summary_card.dart`
- Create: `lib/features/home/home_summary_cards.dart`
- Modify: `test/features/home/home_screen_test.dart`
- Create: `test/goldens/home_golden_test.dart`

**Interfaces:**
- Produces: `DashboardData` with balance-by-currency, current-period totals, unallocated income, safe-limit inputs, primary goal, and mortgage summary.

- [ ] Write widget tests asserting the order `balance → today safe limit → quick actions → unallocated alert → weekly/monthly progress → goal → mortgage` and privacy hiding.

```dart
expect(t.getTopLeft(find.byKey(const Key('safe-limit-hero'))).dy,
  lessThan(t.getTopLeft(find.byKey(const Key('weekly-limit-card'))).dy));
```

- [ ] Run `flutter test test/features/home/home_screen_test.dart` and verify the missing keys fail.

- [ ] Recompose `HomeScreen` with `VeloraCard`, `VeloraStatusBadge`, one horizontal quick-action row, constructive alerts, and `VeloraAsyncState`; keep repository reads inside `dashboardProvider`.

- [ ] Run Home widget and golden tests at 320/390 px and 200% scale; expect no overflow and approved hierarchy.

- [ ] Commit with `git add lib/features/home lib/features/mortgage/mortgage_summary_card.dart test/features/home test/goldens && git commit -m "feat: redesign Velora home dashboard"`.

### Task 3: Redesign expense, income, recurring income, accounts, and history

**Files:**
- Modify: `lib/features/expense_entry/expense_entry_sheet.dart`
- Modify: `lib/features/expense_entry/expense_entry_controller.dart`
- Modify: `lib/features/income_entry/income_entry_sheet.dart`
- Modify: `lib/features/income_entry/income_entry_controller.dart`
- Modify: `lib/features/recurring/recurring_prompt.dart`
- Modify: `lib/features/accounts/*.dart`
- Modify: `lib/features/transactions/*.dart`
- Test: `test/features/expense_entry/expense_entry_controller_test.dart`
- Create: `test/features/expense_entry/expense_entry_sheet_test.dart`
- Modify: `test/features/accounts/*.dart`
- Modify: `test/features/transactions/*.dart`

**Interfaces:**
- Expense intent: `save(amount, categoryId, accountId, occurredAt, note, planned) -> Result<int>`.
- Income intent: `save(...) -> Result<IncomeSaveResult>` where `IncomeSaveResult` contains ledger id and optional recurring plan id.

- [ ] Write failing tests for formatted autofocus amount, last account card selection, four quick categories, searchable full selector, details collapse, undo, currency mismatch, and recurring-income rollback.

```dart
expect(find.byType(VeloraMoneyField), findsOneWidget);
expect(find.byKey(const Key('quick-category')), findsNWidgets(4));
expect(find.text('Batafsil'), findsOneWidget);
```

- [ ] Run the expense/income/account/transaction test folders and confirm failures describe the old controls.

- [ ] Replace raw `TextField`/`DropdownButton`/unbounded chips with `VeloraMoneyField`, `AccountCardPicker`, `CategoryPicker`, and `VeloraSheetScaffold`. Wrap income + recurring-plan creation in `AppDatabase.transaction`; return typed `Result` instead of null/raw exceptions.

- [ ] Run `flutter test test/features/expense_entry test/features/income_entry test/features/accounts test/features/transactions` and expect PASS, including transfer-not-income/expense and balance-adjustment labels.

- [ ] Commit with `git add lib/features/expense_entry lib/features/income_entry lib/features/recurring lib/features/accounts lib/features/transactions test/features && git commit -m "feat: redesign transaction entry and account flows"`.

### Task 4: Redesign allocation, category, and budget flows

**Files:**
- Modify: `lib/features/allocation/*.dart`
- Modify: `lib/features/budgets/*.dart`
- Create: `lib/features/budgets/category_edit_sheet.dart`
- Modify: `test/features/allocation/*.dart`
- Modify: `test/features/budgets/*.dart`
- Create: `test/goldens/plan_budget_golden_test.dart`

**Interfaces:**
- Produces allocation preview with `income`, `directions`, `allocatedTotal`, `unallocated`, `freeAfter`, and `shortfall`.

- [ ] Add tests for reorderable rule cards, fixed/percentage/goal/remaining rule labels, balanced preview, insufficient-income priority reduction, and safe/near/over budget text+icon.
- [ ] Run `flutter test test/features/allocation test/features/budgets`; expect failures for missing redesigned controls.
- [ ] Recompose screens from shared cards/fields, add searchable category editor, and disable confirm unless `allocatedTotal <= income`. Keep calculations in `core/allocation` and `core/budget`.
- [ ] Run feature and golden tests; expect PASS at narrow width and dark theme.
- [ ] Commit with `git add lib/features/allocation lib/features/budgets test/features/allocation test/features/budgets test/goldens && git commit -m "feat: redesign allocation and budgets"`.

### Task 5: Redesign goals and mortgage, including explicit payment split

**Files:**
- Modify: `lib/features/goals/*.dart`
- Modify: `lib/features/mortgage/*.dart`
- Modify: `lib/data/mortgage/mortgage_repository.dart`
- Modify: `test/features/goals/*.dart`
- Modify: `test/features/mortgage/*.dart`
- Create: `test/goldens/goals_mortgage_golden_test.dart`

**Interfaces:**
- Payment UI state: `MortgageSplitMode.auto|manual`, `total`, `principal`, `interest`, `difference`, `canSave`.

- [ ] Add tests that Auto mode derives the split, Manual mode explains both portions, `principal + interest == total`, interest never reduces principal, and unbalanced save is disabled.

```dart
expect(find.text('Asosiy qarzga'), findsOneWidget);
expect(find.text('Foiz to‘lovi'), findsOneWidget);
expect(t.widget<FilledButton>(find.byKey(const Key('payment-save'))).onPressed, isNull);
```

- [ ] Run goal/mortgage tests and confirm the new hierarchy fails.
- [ ] Recompose goal cards/edit/contribution/completion and mortgage setup/dashboard/scenarios. Use `VeloraMoneyField` for every amount and keep repository payment+ledger writes inside one transaction.
- [ ] Run goal/mortgage tests and goldens; expect payoff estimates labeled “Taxminiy” and no amount overflow.
- [ ] Commit with `git add lib/features/goals lib/features/mortgage lib/data/mortgage test/features/goals test/features/mortgage test/goldens && git commit -m "feat: redesign goals and mortgage flows"`.

### Task 6: Redesign onboarding, Settings, and PIN-first App Lock

**Files:**
- Modify: `lib/features/onboarding/onboarding_screen.dart`
- Create: `lib/features/onboarding/steps/account_step.dart`
- Create: `lib/features/onboarding/steps/financial_baseline_step.dart`
- Modify: `lib/features/settings/settings_screen.dart`
- Modify: `lib/features/security/app_lock_gate.dart`
- Modify: `lib/features/security/app_lock_controller.dart`
- Modify: `test/features/onboarding/*.dart`
- Modify: `test/features/settings/*.dart`
- Create: `test/features/security/app_lock_gate_test.dart`
- Create: `test/goldens/onboarding_settings_lock_golden_test.dart`

**Interfaces:**
- App lock remains `AppLockGate(controller, enabled, biometricEnabled, lockTimeout)`.
- PIN keypad submits automatically after four digits; biometric prompt launches once on lock entry and the icon retries it.

- [ ] Write tests for skippable onboarding steps, account/opening balance creation, grouped Settings sections, four-digit keypad, automatic native biometric call, retry icon, wrong-PIN reset, and background privacy shield.
- [ ] Run onboarding/settings/security tests and verify failure against old form-based lock.
- [ ] Implement the approved progressive onboarding and PIN keypad. Call `authenticateBiometric()` from `addPostFrameCallback` once when biometric is enabled; never render a custom biometric dialog.
- [ ] Run feature tests, goldens, `flutter analyze`, and full `flutter test`; expect 0 issues and all tests passing.
- [ ] Commit with `git add lib/features/onboarding lib/features/settings lib/features/security test/features/onboarding test/features/settings test/features/security test/goldens && git commit -m "feat: redesign onboarding settings and app lock"`.

### Task 7: Existing-flow visual fidelity checkpoint

**Files:**
- Create: `test/goldens/existing_flow_gallery_test.dart`
- Create: `integration_test/quick_expense_flow_test.dart`

**Interfaces:**
- Produces visual baselines for every mock screen in this plan and timing evidence for AC 2–3.

- [ ] Add one golden state per approved screen plus 320 px, dark theme, loading, empty, error, and 200% scale variants.
- [ ] Add an integration stopwatch around opening and completing quick expense; assert the sheet is ready under 300 ms in profile-device runs and record user-flow completion under five seconds in the QA checklist.
- [ ] Run `flutter test --update-goldens test/goldens/existing_flow_gallery_test.dart`, inspect images, then rerun without `--update-goldens`.
- [ ] Run `flutter analyze && flutter test`; expect no issues and all suites passing.
- [ ] Commit with `git add integration_test test/goldens && git commit -m "test: lock existing-flow visual fidelity"`.
