# Account-role budgeting — design

**Date:** 2026-07-21
**Status:** Approved (brainstorming). Not yet built.
**Supersedes:** the earlier "Budget page redesign only" idea — that becomes SP-C here.
**Prototype (SP-C, pre-model-A):** https://claude.ai/code/artifact/fecf697d-5f78-4640-b292-29d2452606f5
(still shows the abstract top card that this model removes — to be updated during SP-C design.)

## Why

The app currently derives the daily safe limit from three abstract, manually-entered
numbers on the Budget page: `variableBudget` ("o'zgaruvchan budjet"),
`safetyBuffer` ("xavfsizlik buferi"), and `minReserve` ("minimal yostiq"). The user
found these confusing and — more importantly — **they do not match how the user
actually budgets.** The user works with a **card/envelope model**: income lands on a
main card and is physically split across cards (credit, family/groceries, an
untouchable emergency card). "Reserve" is a real untouchable card, not a number.

So the abstract numbers duplicate, in a confusing way, what the user already expresses
by moving money between cards. We replace them with an **account-role model**.

## The model (A)

Every account (card) carries a **budget role**:

| Role (uz) | Meaning | In the spendable pool? |
|---|---|---|
| 🟢 **Sarf** (spending) | Day-to-day living cards (main, family/groceries) | **Yes** |
| 🛡 **Zaxira** (reserve) | Untouchable, emergency-only cards | No |
| 🔴 **Kredit** (credit) | Cards used for loan/interest payments | No |
| 🎯 **Jamg'arma** (savings) | Money earmarked for goals/savings | No |

**Daily limit formula:**

```
spendablePool = Σ balance(account) for accounts whose role == Sarf
daysLeft      = whole days from today to the end of the current financial period (min 1)
dailyLimit    = spendablePool ÷ daysLeft        (integer floor)
```

`balance(account)` is the existing ledger-derived balance (opening balance + entries),
per `totalsByCurrency`. Reserve / Credit / Savings balances are simply excluded.

### What is removed
- Settings: `variableBudget`, `safetyBuffer`, `minReserve` (retire the fields, their
  editors, and onboarding steps that set them).
- Category `kind` (`mandatory`/`variable`) — removed entirely from model and UI.
- Category weekly limit — dropped from the UI (monthly plan only). (Column may remain
  unused or be dropped; decide in SP-C.)
- Terminology: "Limit" → "Reja" (plan) throughout the budget surface.

### What stays
- Accounts, transactions, categories (name + icon + optional monthly plan), the
  Mortgage module (credit tracking / payoff scenarios), the Goals module.

## Decomposition (build in order)

Each sub-project is independently shippable and testable and gets its own
implementation plan.

### SP-A · Account roles (foundation)
- Add a `role` column to `AccountsTable` (`lib/data/db/tables.dart`) — text, storing an
  `AccountRole` enum name. New enum `AccountRole { spending, reserve, credit, savings }`
  in the account model (`lib/core/ledger/account.dart`) + field on `Account`.
- **DB migration** (bump schema version, see `lib/data/db/migrations.dart`): default
  existing rows — `AccountType.savings` → `AccountRole.savings`; everything else →
  `AccountRole.spending`.
- Repository (`account_repository.dart`): read/write `role`; `setRole(id, role)`.
- Account create/edit UI (`account_edit_sheet.dart`) + onboarding account step: a role
  selector (segmented / choice chips), labelled Sarf / Zaxira / Kredit / Jamg'arma with
  one-line helper text each.
- **No behaviour change yet** — the safe-limit still runs on the old formula. This slice
  only makes roles assignable.
- Tests: migration default mapping; repository round-trip; UI selector.

### SP-B · Daily limit from cards
- Rewrite `lib/core/limit/safe_limit_engine.dart`: `dailySafeLimit` takes the spending
  pool + daysLeft (+ todaySpent for the "today remaining" figure) and drops
  `variableBudget`/`variableSpent`/`manualBuffer`/`minReserve`/`goalReserves`/
  `unpaidMandatory` from the core formula. Keep pure and integer-only.
- Rewire `safeLimitProvider` (`lib/providers/app_providers.dart`): sum balances of
  Sarf-role accounts for the primary currency; compute daysLeft; feed the new engine.
- Home "Bugungi xavfsiz limit" reads the new figure (display should need little change).
- **Open questions to resolve in SP-B design:**
  - Mortgage `unpaidMandatory` and Goals `activeReserveMinor` are currently subtracted
    in the old formula. Under model A these are represented by Credit/Savings account
    balances being excluded. Confirm no double-counting and decide whether the mortgage
    payoff planning still needs `unpaidMandatory` for its own module (likely yes, but
    out of the daily-limit path).
  - What the daily limit shows when there are zero Sarf accounts (empty state).
- Tests: new engine formula (pure); provider wiring with role-filtered accounts.

### SP-C · Budget page redesign
- Replace the abstract top card with a **cards-driven summary**: today's limit +
  spendable pool, sourced from Sarf accounts (read-only here; links to Accounts to
  change roles/balances).
- Category list = single active list: add / **remove (= archive, history preserved)** /
  restore (an "Olib tashlangan" view) / reorder. The data layer already supports this
  (`sortOrder`, `archived`, `reorder()`, `create()`, `list(includeArchived)`), so this is
  mostly UI.
- Redesigned category detail sheet: current-status card + name + icon + **monthly plan
  ("Oylik reja")**. No `kind`, no weekly.
- Remove `kind` from the category model/UI and delete the now-dead abstract-settings
  editors (`setVariableBudget`/`setSafetyBuffer` in `budgets_controller.dart`, the
  `_VariableBudgetCard`, etc.).
- Update the SP-C prototype to model A before implementing.
- Tests: category list add/remove/restore/reorder; detail save; summary math.

## Key code references (verified 2026-07-21)
- `lib/core/ledger/account.dart` — `Account`, `AccountType` (no role yet).
- `lib/data/db/tables.dart` — `AccountsTable` (has `sortOrder`, `archived`; no `role`).
- `lib/data/db/migrations.dart` — migration home.
- `lib/core/limit/safe_limit_engine.dart` — current `dailySafeLimit`.
- `lib/providers/app_providers.dart` — `safeLimitProvider` (~L363), `categoryBudgetsProvider` (~L328).
- `lib/data/settings/settings_model.dart` — `variableBudget`, `safetyBuffer`, `minReserve`.
- `lib/data/categories/category_repository.dart` — already has create/setArchived/reorder/list.
- `lib/features/budgets/*` and `lib/features/accounts/*` — the two feature surfaces touched.
