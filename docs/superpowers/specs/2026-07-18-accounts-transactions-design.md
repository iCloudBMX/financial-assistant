# Accounts & Transactions — Design Spec

**Sub-project:** 1 of 7 (Accounts & transactions)
**Parent product:** Shaxsiy Moliyaviy Assistent (Personal Financial Assistant) — Flutter MVP
**Depends on:** Sub-project 0 (Foundation) — merged to `main`
**Date:** 2026-07-18
**Status:** Approved for planning

---

## 1. Context

This is the second of seven sequential sub-projects (see the Foundation spec,
`2026-07-17-foundation-design.md`). It builds directly on the Foundation's pure
core (`Money`, `Currency`, `FinancialPeriod`, `Result`), Drift database +
migration/recovery engine, repository/provider pattern, and the 5-tab shell with
its reserved "add expense" FAB slot.

SP1 delivers the transactional heart of the app: accounts, the ledger
(expenses, income, transfers, balance adjustments), categories, full
recurring-income plans, and the dashboard cards that this data can compute. It
covers PRD sections **§6** (accounts & balance), **§7** (income), **§9**
(expenses), **§10.1–§10.2** (categories — the 13 defaults and dynamic
management), and the SP1-computable parts of **§14** (dashboard). It honours the
integrity (§25), performance (§24), and error-handling (§26) requirements.

### Product constraints carried from Foundation / PRD
- Flutter, iOS + Android, feature parity (§28.22). Local SQLite only, offline (§22.1/§23).
- Primary currency UZS; **each account may carry its own currency** (§6.1); **no FX conversion in MVP** (§27).
- Data must survive app updates (§20). Performance: recalculation after every operation; reports over 10k transactions < 2s; quick-expense window opens < 300ms (§24).
- Correctness of the math is the product; pure calculation logic is separated from data and UI and unit-tested in isolation (build-approach).

### Scope decisions taken during brainstorming
- **Category budgets (§10.3/§10.4) → deferred to SP2.** SP1 ships categories and
  spent-per-category tracking (the data) only; budget limits and the
  safe/near/over-limit status ship in SP2 alongside the safe-limit engine, so all
  "limit" math lives in one place.
- **Recurring income (§7.3) → full implementation in SP1.** Plans with due-date
  tracking and an in-app "confirm this income" prompt on next open. No OS
  notifications (those are §17, deferred).
- **Subcategories (§10.2 / §9.1) → deferred entirely.** SP1 ships flat categories;
  a `parentId` column and subcategory UI arrive in a later sub-project (which will
  add its own migration then).
- **Dashboard (§14) → real cards SP1 can compute.** Total available balance,
  this-month income, this-month expense, today's spent, and undistributed funds,
  plus quick-add actions. Other cards remain placeholders for SP2–SP5.

## 2. Architecture: derived double-entry ledger

The central decision. Account balances and every derived total are **computed
from the ledger**, never stored as mutable denormalized state.

- One `transactions` table where **every money movement is one or more entries,
  each belonging to exactly one account** (satisfies §25: "each transaction linked
  to one account").
  - **Expense** → one entry (account −, `categoryId` set).
  - **Income** → one entry (account +, `incomeType` set).
  - **Transfer** → **two** linked entries sharing a `transferId` (out of A, into B).
    Total is preserved by construction (§6.2, §25).
  - **Balance adjustment** → one entry recording the delta, so it appears in
    history (§6.3).
- **Account balance = opening balance + Σ its entries.** There is no
  `currentBalance` column to drift out of sync.
- Because balance is derived, **editing or deleting a past entry needs no reversal
  logic** — recomputation is inherent, which is exactly what §25 demands (edit/
  delete/past-period-edit all recalc correctly).

**Rejected alternatives.** *Stored mutable balance* (O(1) reads) was rejected:
denormalized state drifts, and reversing edits/deletes of past transactions is
the exact class of error a finance app cannot ship, and is hard to test. *Hybrid
(derived + rebuildable cache)* was deferred as premature optimization (YAGNI) —
at 10k rows a SUM is milliseconds; if profiling ever shows a need, a cache slots
in behind the repository interface without changing the model or its tests.

## 3. Pure core: the ledger engine (`core/ledger`)

Pure Dart, no Flutter, no Drift — the testable heart, following the Foundation's
rule that pure math lives in `core/`. Repositories load domain entries; this
engine defines the *meaning* of every derived number, so there is one source of
truth for the math.

### 3.1 Pure value types
- `LedgerEntry { id, accountId, LedgerEntryType type, Money amount, categoryId?, IncomeType?, transferId?, Money allocated, bool? planned, DateTime occurredAt, String? note }`
- `Account { id, name, AccountType type, Money openingBalance, icon, bool archived }`
- Enums: `LedgerEntryType { expense, income, transferOut, transferIn, adjustment }`,
  `AccountType { bankCard, cash, savings, other }`, `IncomeType { salary, bonus, freelance, refund, other }`.

### 3.2 Pure functions (lists + `FinancialPeriod` in, typed results out)
- `accountBalance(account, entries)` → `openingBalance + Σ entries.amount` (asserts same-currency invariant).
- `totalsByCurrency(accounts, entries)` → `Map<Currency, Money>` — the §14.1 "total available balance" card, grouped by currency (no cross-currency sum, since there is no FX).
- `periodIncome(entries, period)` / `periodExpense(entries, period)` → month income/expense within the configurable financial period.
- `spentOn(date, entries, period)` → today's spent.
- `categorySpent(entries, period)` → `Map<categoryId, Money>` (SP1 needs "spent"; SP2 compares it to budgets).
- `undistributed(entries)` → `Σ income.amount − Σ income.allocated` (SP1: `allocated` is 0, so this is total income; SP2 makes it meaningful).
- `applyAdjustment(currentBalance, realBalance)` → the delta `Money` to record as an `adjustment` entry (§6.3).
- `buildTransfer(from, to, amount)` → the linked entry pair (out/in) sharing a `transferId`; returns a `Failure` on currency mismatch.

Every function is exhaustively unit-tested on fixture lists — no DB, no widgets —
exactly like `Money`/`FinancialPeriod` in the Foundation.

**Performance.** For a card set, the repository loads the relevant entries once
(10k rows is a few ms) and the engine computes all cards in memory. SQL
aggregation is deliberately deferred (YAGNI); it can later slot behind the same
repository interface without touching the engine or its tests.

## 4. Data model (schema v2)

SP1 introduces **schema v2** — the first real upgrade over the Foundation's v1
(whose `onUpgrade` shipped as a documented no-op).

### 4.1 `accounts`
| col | type | notes |
|---|---|---|
| id | INTEGER PK | |
| name | TEXT | |
| type | TEXT | `bankCard` / `cash` / `savings` / `other` |
| openingBalanceMinor | INTEGER | balance at account creation |
| currencyCode | TEXT | per-account currency (§6.1) |
| icon | TEXT | icon key |
| archived | BOOL | used accounts archive, never hard-delete |
| sortOrder | INTEGER | user ordering |
| createdAt | DATETIME | |

### 4.2 `categories` (flat — subcategories deferred)
| col | type | notes |
|---|---|---|
| id | INTEGER PK | |
| name | TEXT | |
| icon | TEXT | |
| isDefault | BOOL | the 13 seeded defaults |
| archived | BOOL | used categories archive, never delete (§10.2) |
| sortOrder | INTEGER | |

### 4.3 `transactions` (the ledger — one row = one entry against one account)
| col | type | notes |
|---|---|---|
| id | INTEGER PK | |
| accountId | INTEGER FK→accounts | every entry belongs to exactly one account (§25) |
| type | TEXT | `expense` / `income` / `transferOut` / `transferIn` / `adjustment` |
| amountMinor | INTEGER | signed: expense/transferOut < 0, income/transferIn > 0, adjustment = delta |
| currencyCode | TEXT | denormalized from account (guards against later account-currency edits) |
| categoryId | INTEGER FK→categories, null | set for `expense` |
| incomeType | TEXT null | for `income` |
| transferId | TEXT null | links the two rows of a transfer |
| allocatedMinor | INTEGER default 0 | income only; SP2 fills this — undistributed = income − allocated |
| planned | BOOL null | expense planned-vs-unexpected (§9.1) |
| note | TEXT null | |
| occurredAt | DATETIME | user-facing date/time; defaults to now |
| createdAt | DATETIME | |

Indexes on `accountId`, `occurredAt`, `categoryId`, `transferId`.

### 4.4 `recurring_income_plans`
| col | type | notes |
|---|---|---|
| id | INTEGER PK | |
| accountId | INTEGER FK | |
| amountMinor / currencyCode | INTEGER / TEXT | templated income amount |
| incomeType | TEXT | |
| note | TEXT null | |
| intervalKind | TEXT | `monthly` / `weekly` (MVP) |
| anchorDay | INTEGER | day-of-month or ISO weekday |
| nextDueAt | DATETIME | |
| active | BOOL | |

On app open, plans with `nextDueAt <= now` surface an in-app "confirm this
income" prompt; confirming creates a real `income` entry and rolls `nextDueAt`
forward. No OS notifications (§17, deferred).

### 4.5 Cross-currency rule
Transfers are restricted to **same-currency** accounts in MVP: there is no FX
(§27), and §6.2's "preserve total balance" is only well-defined without
conversion. A cross-currency transfer attempt returns a plain-language
`Failure`. Consistent with the Foundation's deferral of multi-currency
dashboard aggregation to SP5.

## 5. Data layer (`data/`)

Follows the Foundation pattern: repository interface + Drift-backed impl, each in
a small focused file, exposed via Riverpod providers; features never touch Drift
directly. All repositories return `Result<T, Failure>`; no exceptions reach
features, and failures map to non-technical, next-step messages (§26).

- **`AccountRepository`** — create / rename / change icon / archive / reorder /
  list (active & archived); returns `Account` domain objects.
- **`CategoryRepository`** — seed the 13 defaults on upgrade; create / rename /
  icon / archive / reorder; archived-not-deleted enforced (§10.2).
- **`LedgerRepository`** — `addExpense`, `addIncome`, `transfer` (writes the
  linked pair in one Drift transaction), `adjustBalance`, `editEntry`,
  `deleteEntry`, and typed reads (`entriesForAccount`, `entriesInPeriod`,
  `allEntries`). Every multi-row write wrapped in a Drift transaction (§25).
- **`RecurringIncomeRepository`** — plan CRUD, `duePlans(asOf)`, `markConfirmed`.

### 5.1 Migration v1 → v2
Replace the Foundation's no-op `onUpgrade` with a real step that `createTable`s
the four new tables and seeds the 13 default categories. (`createTable` works
without the `drift_dev schema` CLI that the Foundation noted does not compile
here — only `stepByStep()` needed it.) Bump `AppDatabase.schemaVersion` to 2 and
register the new tables in `@DriftDatabase`. The Foundation's
snapshot-before-upgrade recovery runs automatically; **this is where the deferred
§20.3 "data intact after a failed migration" test lands**, alongside a v1→v2
success test.

## 6. Features & UI (`features/`)

Fills the placeholder tabs the Foundation reserved. Screens are thin; logic lives
in Riverpod controllers over the repositories + `core/ledger`.

- **`features/accounts`** — account list (per-account balance), create/edit sheet,
  archive, reorder; transfer sheet; balance-adjust sheet (§6.3).
- **`features/transactions`** — Transactions tab: unified ledger history (filter by
  account/type/period), entry detail, **edit** (§9.5) and **delete**, both
  recalculating via the derived engine (§25).
- **`features/expense_entry`** — 3-step quick-add (amount → category → save, §9.1),
  opening < 300ms from the shell FAB; optional hidden fields (account/date/note/
  planned); auto-selects last-used account + now (§9.1); quick-pick categories =
  recent + most-used + favorites (§9.2); **short-window undo** via snackbar (§9.4).
- **`features/income_entry`** — add income (amount/type/account/date/note/
  recurring). After save, the §7.2 "distribute now / later / apply previous plan"
  choice is a **stub that marks the income undistributed** (real allocation is
  SP2). If "recurring" is set, creates a plan.
- **`features/home`** — real dashboard cards SP1 can compute (total balance by
  currency, month income, month expense, today's spent, undistributed) + quick-add
  actions; other §14 cards stay placeholders.
- **On-open recurring check** — a controller surfaces due recurring-income
  confirmation prompts.

New accounts/categories register **onboarding steps** through the Foundation's
extensible `onboardingStepsProvider` (first account + starting balance —
satisfying acceptance criterion §28.1) without editing Foundation code.

## 7. Testing & acceptance

Matches Foundation conventions; run `flutter test --concurrency=1`.

- **`core/ledger`** — exhaustive pure unit tests: balances, transfers preserve
  total, adjustments, period income/expense, today's spent, undistributed,
  currency-mismatch failures.
- **Repositories** — against `NativeDatabase.memory()` with fixtures: transfer
  atomicity, archive-not-delete, edit/delete recalculation (§25).
- **Migration** — v1→v2 success **and** forced-failure recovery (§20.3).
- **Widget/controller** — quick-expense saves and updates balance; undo; income
  marks undistributed; recurring prompt fires when due.
- **Acceptance touched** — §28.1 (create account + starting balance), §28.2
  (income added in < 10s), §28.5 (undistributed shown on dashboard).

## 8. Scope boundary

| In SP1 | Deferred |
|---|---|
| Accounts (CRUD, archive, transfer, adjust) | Category budgets & safe/near/over status → SP2 |
| Categories (13 defaults, CRUD, archive) | Daily/weekly safe-limit engine → SP2 |
| Ledger (expense/income/transfer/adjustment) + edit/delete | Real income allocation (distribute-now) → SP2 |
| Pure `core/ledger` engine | Subcategories → later (needs migration) |
| Full recurring-income plans + on-open confirm | OS notifications for recurring → §17 later |
| Home cards SP1 can compute | Goals / mortgage / report cards → SP3–SP5 |
| Schema v2 migration + §20.3 recovery test | Cross-currency transfers & multi-currency total → SP5 |

## 9. Open questions (deferred, not blocking)

- **Multi-currency "total available balance."** SP1 groups totals by currency (no
  FX). A single unified figure remains the Foundation's open question, resolved in
  SP5 (Reports).
- **Undo mechanism.** SP1 implements short-window undo as reversing the just-
  created entry via snackbar. If a broader undo/redo history is wanted later, it
  can build on the immutable-ledger model.
