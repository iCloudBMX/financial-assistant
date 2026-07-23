# SP5 — Reports & Month-close — Design

Date: 2026-07-23
Status: Approved (brainstorm), pending implementation plan
PRD sections: §15 (Reports), §16 (Oylik davrni yopish), §13.8 (Ipoteka hisoboti), §15.5 (Goal hisoboti)

## Purpose

SP1–SP4 record and plan money in the present. SP5 adds the app's **retrospective**
(reports) and its **period-boundary ceremony** (month-close + leftover distribution).
It is the last unbuilt core sub-project; its safe-limit inputs (`goalReserves`,
`unpaidMandatory`) are already real, so nothing blocks it.

## Guiding decisions (from brainstorm)

1. **Month-close is a SOFT ceremony**, not a hard boundary. Closing a month shows a
   summary, runs the leftover-distribution prompt, and advances to the next period.
   Nothing is frozen; **reports always recompute live from the ledger**; there is no
   period lock and no snapshot storage. Reopening is a non-event.
2. **Reports are monthly-first.** Build Monthly (§15.3, full) + Category (§15.4) +
   Goal (§15.5) + Mortgage (§13.8) as thin read-only views over existing engines.
   **Skip** dedicated Daily/Weekly report screens (§15.1/§15.2) — Home + the safe-limit
   line already show that live. §15.6 filtering is deferred.
3. **Leftover distribution reuses existing sheets.** The close summary shows the
   leftover amount and a destination chooser; each destination opens the EXISTING
   sheet (goal-contribute / mortgage-extra / allocation-transfer) pre-filled, and the
   remaining leftover decrements after each apply. "Split across targets" = apply
   several in sequence. No new posting logic, no atomic multi-target splitter.

## What is already free (do NOT build)

- **§16.3 "create next period"** — `FinancialPeriod.next()` is derived from the clock +
  anchor day (`lib/core/time/financial_period.dart`). There is no stored period entity.
- **§16.3 "carry recurring / continue goals"** — `recurring_income_plans` and goals
  already persist and auto-recur. Nothing to carry forward.
- **§16.2 posting mechanisms** — goal contribution (`GoalController.contribute`),
  mortgage extra payment (`MortgageController`), and allocation-plan transfers all
  exist. Distribution is a chooser that deep-links them.
- **Report math** — `summary_engine.dart` already exposes `periodIncome`,
  `periodExpense`, `totalsByCurrency`, `spentOn` over any `FinancialPeriod`. The goal
  engine (`computeGoalProgress`) and mortgage engine (`projectPayoff`/`compareScenarios`)
  already produce the §15.5 / §13.8 figures.

## Genuinely-new pieces

### 1. Reports section
A new Reports entry (tab or Settings-level section — plan decides placement to match
existing nav). Four thin read-only views:

- **Monthly report (§15.3)** — total income, total expense, mandatory vs variable
  expense, goal allocations, mortgage mandatory + extra payment, saved amount,
  undistributed remainder, **and prev-month comparison** via `period.previous()`.
- **Category report (§15.4)** — actual expense · share of total · trend vs prior
  periods. (See Conflict A — planned/remaining/deviation columns dropped.)
- **Goal report (§15.5)** — re-surfaces `computeGoalProgress`: progress, added this
  month, total saved, remaining to target, forecast, contribution history.
- **Mortgage report (§13.8)** — re-surfaces the mortgage engine: balance by month,
  principal vs interest payments, extra payments, actual vs planned payoff, estimated
  interest saved, term reduction.

### 2. Month-close flow
- **§16.1 summary** — computed live: total income, total expense, spending-envelope
  saved-or-over, added to goals, mortgage-balance change, undistributed (= leftover).
- **§16.2 leftover-distribution chooser** — shows leftover, offers destinations
  (→ goal / → mortgage extra / → reserve fund / carry over). Each opens the existing
  pre-filled sheet; remaining leftover decrements after each applied action. "Carry
  over" is a no-op (money stays in spending accounts).
- Ends with an optional "Set up this month's allocation?" link into the existing
  allocation plan (see Conflict B).

### 3. Persisted close marker
- **`lastClosedPeriodStart`** — a single field on the existing settings singleton.
  No new table. Powers: (a) "this period is already closed" state to avoid
  re-prompting, (b) an **in-app "time to close" CTA** shown when an elapsed period is
  unclosed. OS notifications (§17) are out of scope.

## Data model

- **"Leftover" / "undistributed"** = Σ balances of `spending`-role accounts at close
  (envelope model: budgeted-to-spend money not spent). This single number is §16.1's
  "saved" figure AND §16.2's distributable amount — self-consistent.
- **Schema change: the settings field only.** Soft ceremony ⇒ no snapshot tables, no
  period-lock columns, no edit-guards on SP1 mutators.

## Resolved scope conflicts

**Conflict A — §15.4/§16.1 "budget deviation."** Category budgets (monthly limits)
were deliberately removed. Those fields have no source. **Resolution:** reinterpret
against the envelope model — Category report shows actual spend / share / trend (no
planned/remaining/deviation); §16.1 "saved vs over" = spending-envelope leftover
(positive) or overspend (negative). No removed feature is resurrected.

**Conflict B — §16.3 "copy previous budgets."** No category budgets exist to copy; the
allocation plan is manual/on-demand. **Resolution:** §16.3 is a no-op beyond the
automatic period advance; the close screen optionally links into the existing
allocation plan for the new period. Nothing auto-copied.

## Testing

- Pure engine additions get unit tests: spending-envelope leftover calculation;
  prev-period comparison deltas for the monthly report.
- Distribution-chooser logic gets one widget/logic test: remaining decrements
  correctly and cannot be over-distributed below zero.
- Reuse existing sheet/engine tests for the deep-linked destinations.
- Golden gallery entries for the new report + close screens.

## Deferred (with "add when")

- Snapshot tables / period locks — add when trends get slow or the books must be
  frozen against back-dated edits.
- Daily/Weekly standalone report screens (§15.1/§15.2) — add when users ask; Home
  covers it live today.
- §15.6 report filtering (date range / account / category / type / goal / mortgage) —
  add after the base report views land.
- Atomic multi-target splitter — add if sequential apply proves too tedious.
- OS notifications including "time to close" (§17) — separate sub-project.

## Rough task shape (for writing-plans)

~6–8 TDD tasks: (1) spending-envelope leftover engine + tests; (2) monthly-report
view-model/provider + prev-month comparison; (3) category/goal/mortgage thin report
views; (4) close-summary screen; (5) leftover-distribution chooser; (6) settings
`lastClosedPeriodStart` field + migration + unclosed-period CTA; (7) golden gallery.
