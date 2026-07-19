# Mortgage — Design Spec

**Sub-project:** 4 of 7 (Mortgage)
**Parent product:** Shaxsiy Moliyaviy Assistent (Personal Financial Assistant) — Flutter MVP
**Depends on:** SP0 (Foundation) + SP1 (Accounts & transactions) + SP2 (Allocation & safe-limit engine) + SP3 (Goals) — all merged to `master`
**Date:** 2026-07-19
**Status:** Approved for planning

---

## 1. Context

Fifth-built of seven sequential sub-projects. Builds on the Foundation's pure
core (`Money`, `Currency`, `FinancialPeriod`, `Result`), SP1's derived
double-entry ledger + repository/provider pattern + 5-tab shell, SP2's three pure
engines (`core/allocation`, `core/limit`, `core/budget`) with their generic
string-keyed allocation buckets, and SP3's derived-data pattern (a goal's saved
amount is `Σ` of contribution rows, never a stored column).

SP4 delivers the last seam SP2 deliberately left open, plus the mortgage feature:

- **§13** — mortgage management: create, dashboard, record payments (with a
  principal/interest/fees split), extra payments with recalculation, early-payoff
  strategy, and payoff scenarios.
- **§8.1/§8.3** — the `mortgage` (mandatory) and `mortgage:extra` (extra
  principal) allocation buckets. These come free as generic string keys — no
  engine or schema change to `core/allocation`.
- **§11.2 `unpaidMandatory`** — the safe-limit engine's "hali toʻlanmagan
  majburiy toʻlovlar" input, `0` in SP2/SP3, now supplied with a real value.

Out of scope for SP4 (deferred to SP5 — Reports & month-close): §13.8 mortgage
report; the month-close-dependent recommendations in §13.7 ("kategoriya
budjetidan tejab qolingan mablagʻni ipotekaga oʻtkazish").

### Product constraints carried from Foundation / SP1 / SP2 / SP3 / PRD
- Flutter, iOS + Android, feature parity. Local SQLite only, offline (§22.1, §23).
- Primary currency UZS; **no FX** in the MVP (§27). A mortgage is single-currency
  (primary) in SP4; a `// TODO(multi-currency)` guard mirrors SP1/SP2/SP3.
- **Correctness of the math is the product** (build-approach memory): all
  amortization / payoff / scenario math lives in a pure `core/mortgage` engine,
  no Flutter/Drift deps, unit-tested in isolation. **Integer minor units only —
  no float ever**, including the interest rate (stored as integer basis points).
- Recalculation after every relevant operation; `unpaidMandatory` recomputes into
  the safe limit after every payment via `ledgerRevisionProvider` (§11.3).

---

## 2. The central design decision: derived balance + a real ledger payment

A mortgage is almost the **mirror image of a goal**. A goal is an *earmark* that
never moves money and whose saved amount is derived. A mortgage payment moves
*real* money out of an account, yet its balance is *also* derived — from the
principal portions of recorded payments.

### 2.1 The balance is derived, not stored

```
currentPrincipal = openingPrincipalMinor − Σ mortgage_payments.principalPortionMinor
```

PRD §13.1 asks the user for **two** principal figures, because the user usually
starts tracking a loan that is already part-way through:

- `initialLoanMinor` — the original loan amount. **Informational only**: it is the
  denominator for the "kreditning bajarilish foizi" (completion %) and future
  reports. It is *never* the derivation baseline.
- `openingPrincipalMinor` — the principal balance **at the moment tracking
  starts**. This is the derivation baseline. The live balance is this minus the
  sum of principal portions of every payment recorded *after* creation.

There is **no** stored `currentPrincipalMinor` column. This mirrors SP3's
derived-saved rule and grounds the number in the user's real recorded payments.

### 2.2 A payment is real money — it hits the SP1 ledger

Unlike a goal contribution, recording a mortgage payment moves real money to the
bank. Recording one is a single atomic operation that writes **both**:

1. a `mortgage_payments` **detail row** — the split into principal / interest /
   commission / insurance / other (§13.3), plus an `isExtra` flag; and
2. a linked SP1 ledger **expense transaction** for the **full payment amount**
   under a seeded **"Mortgage"** system category, so real money leaving the
   account updates account balances and the safe limit.

The `mortgage_payments` row carries `ledgerTransactionId` (FK → `transactions`),
the same linkage pattern SP1 used for transfers (`transferId`) and SP3 used for
income-sourced contributions (`incomeTransactionId`).

**Why the full amount as one expense (not split principal vs interest):** for
account balances and the safe limit to be correct, the whole cash amount must
leave the account. Categorizing only interest+fees as an expense and principal as
a separate non-expense outflow would require a new entry kind in SP1's ledger,
reopening a merged sub-project. The tradeoff — principal repayment shows up in
"shu oygi jami chiqim" (this month's total outflow), slightly overstating true
spending — is acceptable for the MVP; SP5's report can separate principal from
interest using the `mortgage_payments` split, which is preserved in full.

### 2.3 The pure engine only projects forward

`core/mortgage` never sets the authoritative balance. It takes the current
(derived) balance as an **input** and projects forward: payoff date, months
remaining, remaining interest, scenario comparisons, and extra-payment
recalculation. The PRD is explicit (§13.7) that these figures are informational
and do not replace the bank's official calculation.

---

## 3. `core/mortgage` — amortization, payoff & scenario engine (pure Dart)

No Flutter/Drift imports. Integer minor units only. This is the heart of the
sub-project and is unit-tested in isolation.

### 3.1 Integer interest

The annual rate is stored and passed as **integer basis points** (`annualRateBp`;
18.5 % → `1850`, 18 % → `1800`). One month's interest on a balance is:

```
monthlyInterestMinor = round(balanceMinor × annualRateBp / 120000)
```

(`120000 = 12 months × 10000 bp`). Rounding is half-up on the integer division so
the schedule is deterministic and reproducible. No `double` appears anywhere in
the money path.

### 3.2 Types

- `enum PaymentType { annuity, differential, custom }` — all three per §13.1.
  - **annuity** — fixed total payment; interest = `balance × rate`, principal =
    `payment − interest`, balance decreases by principal.
  - **differential** — fixed principal each month (`openingPrincipal ÷ term`);
    interest = `balance × rate`; total payment decreases over time.
  - **custom** — a user-entered schedule; the engine consumes the explicit
    per-period principal/interest figures rather than computing them.
- `enum PayoffStrategy { shortenTerm, lowerPayment, unclear }` (§13.5). `unclear`
  causes the engine to flag its results `isApproximate = true`.
- `class MortgageProjection { DateTime? payoffDate; int monthsRemaining; int
  totalRemainingInterestMinor; int completionBp; bool isApproximate; }`
- `class ScenarioResult { ScenarioKind kind; DateTime? payoffDate; int
  monthsRemaining; int totalInterestMinor; int interestSavedMinor; int
  monthsSaved; int requiredMonthlyMinor; bool isApproximate; }`
- `enum ScenarioKind { mandatoryOnly, fixedExtraMonthly, oneTimeExtra,
  allRemainingIncome }`

### 3.3 Functions

- `MortgageProjection projectPayoff({ required int currentPrincipalMinor,
  required int annualRateBp, required int mandatoryPaymentMinor, required
  PaymentType type, required DateTime asOf, DateTime? endDate })` — forward
  amortization from the current balance to a zero balance. Guards against a
  non-amortizing loan (mandatory payment ≤ first month's interest for an annuity)
  by returning `payoffDate == null` with `monthsRemaining` capped, so the UI can
  warn "at this payment the loan never closes".
- `ScenarioResult computeScenario({ required ScenarioKind kind, required int
  currentPrincipalMinor, required int annualRateBp, required int
  mandatoryPaymentMinor, required PaymentType type, required DateTime asOf, int
  extraMonthlyMinor = 0, int oneTimeExtraMinor = 0, int remainingIncomeMinor = 0
  })` — one scenario. `interestSavedMinor` / `monthsSaved` are measured against
  the `mandatoryOnly` baseline computed with the same inputs.
- `List<ScenarioResult> compareScenarios(...)` — the four scenarios of §13.6 as a
  comparable list (baseline first).
- `MortgageProjection applyExtraPayment({ required int currentPrincipalMinor,
  required int extraMinor, required int annualRateBp, required int
  mandatoryPaymentMinor, required PaymentType type, required PayoffStrategy
  strategy, required DateTime asOf })` — §13.4: reduce the balance by `extraMinor`
  then reproject. `shortenTerm` keeps the mandatory payment and yields fewer
  months; `lowerPayment` keeps the term and yields a smaller payment; `unclear`
  computes `shortenTerm` but sets `isApproximate = true`. Returns enough to show
  §13.4's five outputs (new balance, new payoff date, new remaining interest,
  interest saved, months saved).

---

## 4. Schema v5 — `mortgages` + `mortgage_payments`

Schema version bumps 4 → 5. Both tables are new in v5, so the migration is a
plain `createTable ×2` with no `_hasColumn` guard — identical in shape to SP3's
v3→v4 branch. A collapsed v1→v5 pass builds the tables from their current class
via `onCreate`.

### 4.1 `MortgagesTable`

| column | type | notes |
|---|---|---|
| id | int PK autoInc | |
| name | text | |
| bank | text | |
| initialLoanMinor | int | informational (completion % denominator) |
| openingPrincipalMinor | int | derivation baseline (balance at tracking start) |
| annualRateBp | int | basis points, e.g. 1850 |
| startDate | dateTime | |
| endDate | dateTime nullable | |
| mandatoryPaymentMinor | int | |
| nextPaymentDate | dateTime | |
| paymentType | text | `PaymentType.name` |
| payoffStrategy | text | `PayoffStrategy.name`, default `unclear` |
| currencyCode | text | default `'UZS'` |
| status | text | `MortgageStatus.name`, default `active` |
| sortOrder | int | default 0 |
| createdAt | dateTime | clientDefault now |

### 4.2 `MortgagePaymentsTable`

| column | type | notes |
|---|---|---|
| id | int PK autoInc | |
| mortgageId | int | FK → mortgages.id |
| totalMinor | int | full cash amount that left the account |
| principalPortionMinor | int | reduces the derived balance |
| interestPortionMinor | int | |
| commissionMinor | int | default 0 |
| insuranceMinor | int | default 0 |
| otherMinor | int | default 0 |
| isExtra | bool | default false — true = extra principal payment (§13.4) |
| ledgerTransactionId | int nullable | FK → transactions.id (the linked expense) |
| currencyCode | text | |
| occurredAt | dateTime | |
| note | text nullable | |
| createdAt | dateTime | clientDefault now |

**Invariant:** `principal + interest + commission + insurance + other == total`,
enforced in the controller (a `ValidationFailure`, not a DB constraint).

`enum MortgageStatus { active, closed, archived }` — `closed` when the derived
balance reaches 0 (loan paid off); `archived` hides it from the default list.

### 4.3 Migration test fan-out (do it in the schema task)

Bumping the real version to 5 breaks the tests that hard-code `4`:
- `migration_recovery_test.dart`'s forced-upgrade fake reports `schemaVersion`
  one ahead of the real one → becomes `6`.
- `schema_v2/v3/v4_migration_test.dart` each assert `expect(db.schemaVersion, 4)`
  → become `5`.
- Add `schema_v5_migration_test.dart`: a genuine v4 database (all SP0–SP3 tables,
  no mortgage tables) reopened with the real v5 `AppDatabase` runs `onUpgrade(4,
  5)` and the two mortgage tables become queryable.

---

## 5. Repository, providers & seam wiring

### 5.1 `MortgageRepository` (`lib/data/mortgage/mortgage_repository.dart`)

Interface + `DriftMortgageRepository`:

- `Future<List<Mortgage>> list({bool includeArchived = false})` — ordered by
  `sortOrder`; excludes `archived` unless asked.
- `Future<int> create(MortgageDraft draft)` / `update(int id, MortgageDraft)` /
  `setStatus(int id, MortgageStatus)` / `archive(int id)` / `delete(int id)`
  (hard delete removes the mortgage's payment rows and the mortgage atomically;
  it does **not** delete the linked ledger transactions — those are real
  historical expenses and remain in the ledger).
- `Future<int> recordPayment({ required int mortgageId, required MortgagePaymentSplit split, required int accountId, bool isExtra = false, String? note, DateTime? occurredAt })`
  — in **one DB transaction**: insert the ledger expense (full `total`, "Mortgage"
  category, from `accountId`) via the existing SP1 write path, capture its id,
  then insert the `mortgage_payments` row with `ledgerTransactionId` set. Returns
  the payment id.
- `Future<List<MortgagePayment>> payments(int mortgageId)` — newest `occurredAt`
  first.
- `Future<int> currentPrincipalMinor(int mortgageId)` — `openingPrincipal − Σ
  principalPortion`.
- `Future<MortgageTotals> totals(int mortgageId)` — Σ principal paid, Σ interest
  paid, Σ extra paid (for the dashboard §13.2).
- `Future<int> unpaidMandatoryMinor()` — the safe-limit seam (§5.3).

### 5.2 Providers (`lib/providers/app_providers.dart`)

- `mortgageRepositoryProvider = Provider<MortgageRepository>(...)`.
- `class MortgageWithProjection { Mortgage mortgage; int currentPrincipalMinor;
  MortgageTotals totals; MortgageProjection projection; }`.
- `mortgagesProvider = FutureProvider<List<MortgageWithProjection>>` — watches
  `ledgerRevisionProvider`; for each mortgage computes the derived balance +
  totals + a `projectPayoff` in the primary currency.
- `mortgagePaymentsProvider = FutureProvider.family<List<MortgagePayment>, int>`.
- `mortgageScenariosProvider` — a `FutureProvider.family` (or a controller method)
  returning `compareScenarios(...)` for a given mortgage id + scenario inputs.

### 5.3 Safe-limit seam — `unpaidMandatory`

Replace the hardcoded line in `safeLimitProvider`
(`app_providers.dart:236`, `unpaidMandatory: Money.zero(currency)`) with the real
value from `MortgageRepository.unpaidMandatoryMinor()`:

> `unpaidMandatory` = **Σ over active mortgages** of `mandatoryPaymentMinor`, for
> each mortgage whose `nextPaymentDate` is **on or before the current financial
> period's `endExclusive`** and for which **no non-extra payment has been recorded
> within the current period** (`occurredAt ∈ [period.start, period.endExclusive)`
> on a row with `isExtra == false`). Otherwise that mortgage contributes 0.

This makes the daily safe limit hold back money for a mortgage payment that is due
this period but not yet made, and releases it once the payment is recorded — the
recompute rides `ledgerRevisionProvider`, satisfying §11.3's "majburiy toʻlov
amalga oshirilganda" (recalculate when a mandatory payment is made). `nextPaymentDate`
advancement (rolling to next month after a payment) is handled by the controller
on `recordPayment` for a non-extra payment.

### 5.4 Allocation seam — planning only, **no auto-posting**

The `mortgage` (mandatory) and `mortgage:extra` (extra principal) buckets are
generic `bucketKey` strings and need **no** change to `core/allocation`. They
appear in the allocation template so income can be planned against them and the
§8.3 order is expressible.

Unlike SP3's income→goal bridge — which auto-writes a `goal_contributions` row on
allocation confirm because a goal contribution is an earmark that moves no real
money — **allocation confirm does NOT auto-post a mortgage payment.** A mortgage
payment moves real money at the bank's time; auto-posting a ledger expense on
allocation confirm would pay the bank before the bank actually takes it, and would
double-count against the balance. The mortgage buckets are therefore
**planning-only** in SP4: the safe limit already reserves the mandatory payment
via `unpaidMandatory`, and the user records the real payment through §13.3 when
the bank debits them. (`AllocationController.confirm` keeps its SP3 behaviour for
`goal:{id}` buckets and simply does nothing special for `mortgage*` buckets.)

---

## 6. Controller & guards

`MortgageController` (`lib/features/mortgage/mortgage_controller.dart`), exposed as
`mortgageControllerProvider`:

- `create` / `update` — validate name non-empty, `initialLoan > 0`,
  `openingPrincipal > 0`, `annualRateBp ≥ 0`, `mandatoryPayment > 0`.
- `recordPayment({ ... })` — guards (typed `Result` / `ValidationFailure`):
  every portion `≥ 0`; `total > 0`; **split sums to total**. It does **not** guard
  the source account's balance — SP1's expense entry allows overdrawing (the
  derived ledger permits negative balances), and a mortgage payment must behave
  the same. On success, advances the
  mortgage's `nextPaymentDate` by one month for a non-extra payment, and closes
  the mortgage (`status = closed`) if the derived balance reaches 0. Bumps
  `ledgerRevisionProvider`.
- `recordExtraPayment(...)` — a convenience wrapper: `recordPayment` with
  `isExtra = true` and the full amount as `principalPortion` (an extra payment is
  100 % principal, §13.4); does not advance `nextPaymentDate`.
- `closeMortgage(int id)` / `reopen(...)` for manual status changes.

Every mutation bumps `ledgerRevisionProvider` so balances, the safe limit, and
`mortgagesProvider` all recompute.

---

## 7. Navigation & UI

The 5-tab shell is full (`Bosh`, `Tranzaksiya`, `Taqsimlash`, `Goal`, `Hisobot`);
tab 4 (`Hisobot`) is reserved for SP5. Mortgage is therefore **not** a sixth
bottom-nav tab (five is the practical mobile maximum). Instead:

- **Home (`Bosh`)** gains a **mortgage-summary card** (current balance, next
  payment + date, completion %) that pushes the full mortgage screen — the same
  pushed-screen pattern SP3 used for goal detail.
- `MortgageDashboardScreen` (§13.2) — balance, rate, next mandatory payment +
  date, totals (paid / principal / interest / extra), completion %, projected
  payoff date; a **recommendations** section (§13.7 thin subset — see §8); and
  entry points to record a payment, make an extra payment, and view scenarios.
- `MortgageEditSheet` (§13.1) — create/edit; money fields seeded with
  `Money.formatNumber` (never `.format()` — the SP2 data-loss bug); rate entered
  as a percent and converted to `annualRateBp`; `paymentType` + `payoffStrategy`
  selectors; start/end/next-payment date pickers.
- `MortgagePaymentSheet` (§13.3) — total plus optional principal / interest /
  commission / insurance / other fields; a live "split must equal total" check;
  an account picker for the source account.
- `ExtraPaymentSheet` (§13.4–13.5) — amount + strategy; a live recalc preview
  (new balance, new payoff date, interest saved, months saved) from
  `applyExtraPayment`; `unclear` strategy shows an "approximate" badge.
- `MortgageScenariosScreen` (§13.6) — the four scenarios as a comparison list,
  each showing payoff date, months remaining, total interest, interest saved,
  months saved, required monthly.

UI language uz-Latn; the Foundation font renders Latin + Cyrillic. Red is reserved
for over-limit / "loan never closes at this payment" warnings only (§21.2).

---

## 8. Recommendations (§13.7) — thin subset in SP4

Only the recommendations computable from data already in hand ship in SP4, each
rendered as an informational card with the mandated "advisory, not the bank's
official calc" disclaimer:

- **"joriy surʼatda ipoteka qachon yopilishi"** — from `projectPayoff` (payoff
  date at the current mandatory payment).
- **"oyiga qoʻshimcha toʻlovni oshirish natijasi"** — from a `fixedExtraMonthly`
  scenario (interest saved / months saved for a sample extra).
- **"taqsimlanmagan mablagʻni ipotekaga yoʻnaltirish taklifi"** — when the
  allocation preview shows an `undistributed` remainder, suggest directing it to
  the mortgage.
- **"minimal zaxira yetarli boʻlmasa, qoʻshimcha toʻlovni kamaytirish"** — when
  the safe limit's `freeBalance` would go negative, suggest a smaller extra.

**Deferred to SP5:** "kategoriya budjetidan tejab qolingan mablagʻni ipotekaga
oʻtkazish" (needs month-close / saved-category-budget, SP5) and the full §13.8
report.

---

## 9. Testing strategy

- **`core/mortgage` (pure, the priority):** annuity + differential schedules;
  integer interest rounding; a non-amortizing loan (payment ≤ first interest →
  null payoff); `computeScenario` for all four kinds with interest-saved vs
  baseline; `applyExtraPayment` under all three strategies; boundary cases
  (balance already 0, one month left, past `endDate`).
- **Repository:** derived `currentPrincipalMinor`; `recordPayment` writes a
  `mortgage_payments` row **and** a linked ledger expense of the full total, in
  one transaction, with `ledgerTransactionId` set; `unpaidMandatoryMinor` windows
  (due-this-period-unpaid vs paid-this-period vs due-later); archive/delete
  (delete removes payment rows but leaves ledger transactions).
- **Migration:** `schema_v5_migration_test.dart` (real v4→v5) + the three edited
  version assertions + the recovery fake bumped to 6.
- **Providers/controller:** `unpaidMandatory` reduces the daily safe limit and
  releases after a recorded payment; the split-sum guard rejects a mismatched
  split.
- **Widget:** dashboard renders derived figures; payment sheet blocks a split that
  doesn't sum to total; extra-payment preview updates.
- Run with `flutter test --concurrency=1`.

---

## 10. Global constraints (carried forward)

- **Money:** integer minor units + currency code; **no float ever**, rate as
  integer basis points. Same-currency arithmetic only.
- **Earmark vs real money:** goals earmark (no movement); a mortgage payment is
  real money and posts to the SP1 ledger. Do not conflate the two seams.
- **Derived, not stored:** balance = opening − Σ principal portions; never a
  stored live-balance column.
- **Single source of truth for `unpaidMandatory`:** `MortgageRepository`, from
  the mortgages + payments tables — nothing else.
- **Money field seeding:** `Money.formatNumber()`, never `.format()`.
- **Errors:** typed `Failure` via `Result<T>`; user-facing text is non-technical
  and states a next step (§26).
- **Multi-currency:** MVP single-currency; guard non-primary with
  `// TODO(multi-currency)` (SP5).
- **UI language:** uz-Latn; red for over-limit/error only.
- **Commits:** Conventional Commits; co-author trailer as configured.
- **Generated code:** run `dart run build_runner build --delete-conflicting-outputs`
  after any `@DriftDatabase`/`Table` change, before tests.
- **Test command:** `flutter test --concurrency=1`.

---

## 11. Deferred to later sub-projects

- §13.8 mortgage report (balance-by-month, principal/interest/extra series,
  planned vs actual payoff, interest saved, term shortening) → **SP5**.
- §13.7 "saved category budget → mortgage" recommendation (needs month-close /
  `savingsRolloverMode`) → **SP5**.
- Real multi-currency mortgages → **SP5**.
- Auto-generation / reminders for the mandatory payment due date (SP4 stores
  `nextPaymentDate` and reserves it via `unpaidMandatory`; push reminders are out
  of MVP scope, §22.1 offline).
