# Home dashboard simplification — design

**Date:** 2026-07-20
**Status:** Proposed (awaiting review)
**Scope:** Home screen only. Narrow, surgical change.

## Problem

Home shows ~20 numbers on one screen and repeats the same figure under
different labels. Concretely, the user's "free/spendable" amount (e.g.
`33 800 so'm`) appears **three times**:

1. `MiniBalanceRow` → "Erkin"
2. `DistributionCard` ("Pul taqsimoti") → "Erkin xarajat"
3. `WeeklySafeLimitCard` → "Oylik erkin byudjet: Qoldiq"

Separately, the safe-limit hero shows a confusing raw negative when the day is
over budget: `Bugun qoldi: −14 384 so'm`.

The user asked to simplify **only two things** and remove one card, leaving
everything else on Home exactly where it is.

## Non-goals

- Do **not** touch: the header, quick-actions row, unallocated-income alert,
  primary-goal card, mortgage card, or the transfer button.
- Do **not** add a "limit details" / reports screen or link Home to any report.
  The weekly/monthly figures are simply removed from Home.
- Do **not** change the safe-limit calculation engine
  (`lib/core/limit/safe_limit_engine.dart`). Its pure `weeklySafeLimit` /
  `WeeklySafeLimit` and `dailySafeLimit` stay intact and tested — a future
  Reports feature (SP5) can reuse them. Only the *presentation* changes.

## The three changes

### 1. "Bugun qoldi" hero (`SafeLimitCard`)

**File:** `lib/features/home/safe_limit_cards.dart`

The hero's big number becomes **what is actually left to spend today**, floored
at zero, so an over-budget day reads as `0 so'm` plus a plain-language note
instead of a naked negative.

| | Before | After |
|---|---|---|
| Label | `BUGUN BEMALOL` | `BUGUN QOLDI` |
| Big number | `perDay` (2 816) | `max(0, todayRemaining)` — `0` when over |
| Supporting line (on track) | `Bugun qoldi: 2 816 · 12 kun qoldi` | `Kunlik limit 2 816 so'm · 12 kun qoldi` |
| Supporting line (over) | `Bugun qoldi: −14 384 · 12 kun qoldi` | `Bugungi limitdan 14 384 so'm oshdingiz · 12 kun qoldi` |

- The daily allowance (`perDay`) is not lost — it moves to the supporting line.
- Progress bar behavior is unchanged: `fraction = (todayRemaining / perDay)`
  clamped to `[0,1]`; over-budget clamps to an empty track; hidden when
  `perDay <= 0`.
- The over-limit "Limitdan chiqqan: …" offenders line (`overspendCategories`)
  is unchanged.
- Status tone (`_statusFor` → safe / near / over icon) is unchanged.

No new inputs: the widget already receives `SafeLimit` (which carries `perDay`,
`todayRemaining`, `daysLeft`, `isOver`). This is a pure render change.

### 2. Merge the two balance cards into one "Balans" card

**File:** `lib/features/home/home_hero.dart`

Replace `MiniBalanceRow` **and** `DistributionCard` with a single `BalanceCard`.

Layout:

- Title: `Balans`
- Big number: **Jami** (total balance), with the existing privacy mask
  (`hidden` → `••••••`). Preserve `Key('balance-card')` on the card and
  `Key('balance-amount')` on the big number for test/semantics continuity.
- A single stacked bar split into exactly **two** segments that sum to the
  total:
  - **Erkin** (`free`) — coral
  - **Rezerv** (`reserved`) — plum/muted
- A legend row per segment: colored dot · label · amount (masked when hidden).

**Why only two segments (important correctness point):** `reserved` is defined
as `total − free`. Goal earmarks and mortgage-mandatory amounts are *already
inside* `reserved` (the safe-limit engine subtracts them to compute `free`).
Adding separate "Maqsad" / "Ipoteka" segments alongside Erkin+Rezerv would
double-count and the bar would exceed the total. So the honest part-whole split
of the balance is **Erkin / Rezerv only**. Goals and mortgage keep their own
dedicated cards further down Home, so no information is lost.

Null/empty states (unchanged intent): when the safe limit has not resolved,
`free`/`reserved` are null → legend shows an em dash and the bar renders as a
single neutral segment, mirroring today's em-dash behavior.

`BalanceCard` inputs: `total`, `free` (`Money?`), `reserved` (`Money?`),
`hidden`. These are already computed in `_HomeBody`.

### 3. Remove the weekly/monthly card

**Files:** `lib/features/home/home_screen.dart`,
`lib/features/home/safe_limit_cards.dart`,
`lib/features/home/dashboard_data.dart`, `lib/providers/app_providers.dart`

- Remove the `WeeklySafeLimitCard(...)` block from `_HomeBody`
  (`home_screen.dart:185-186`).
- Delete the now-unused `WeeklySafeLimitCard` widget from `safe_limit_cards.dart`.
- Remove the now-unused Home plumbing that fed it:
  - `weeklySafeLimitProvider` (`app_providers.dart:425-456`).
  - `DashboardData.weeklyLimit` field + its `buildDashboard` parameter +
    the `weeklyLimit: …` line in `dashboardProvider` (`app_providers.dart:95,106`).
- Keep the pure engine (`weeklySafeLimit`, `WeeklySafeLimit`) and its tests.

## Consequential cleanup

Merging away `DistributionCard` leaves two Home-only helpers unused:

- `DistributionSegment` construction in `_HomeBody` and the `goalsSavedTotal`
  wiring that fed the distribution's goals segment. Remove the dead
  `DistributionCard`/`DistributionSegment` usage from Home. `DistributionCard`
  and `DistributionSegment` classes may be deleted if nothing else references
  them (verify at implementation time); `_goalsSavedTotal` and
  `DashboardData.goalsSavedTotal` become removable if no other consumer remains.

Keep this cleanup limited to what is genuinely dead after the merge — do not
refactor unrelated code.

## Resulting Home (top → bottom)

1. Header (unchanged)
2. **Bugun qoldi** hero — changed (change 1)
3. Quick-actions row (unchanged)
4. Unallocated-income alert (unchanged, conditional)
5. **Balans** card — new merged card (change 2)
6. Primary-goal card (unchanged)
7. Mortgage card (unchanged)
8. Transfer button (unchanged)

Numbers on screen drop from ~20 to ~7; every figure appears once.

## Testing

- **`safe_limit_cards_test.dart`** — update hero assertions to the new label,
  big number (`todayRemaining`, `0` when over), and the two supporting-line
  copies; remove `WeeklySafeLimitCard` tests.
- **`home_screen_test.dart`** — assert the merged `BalanceCard` (total + Erkin +
  Rezerv, privacy mask) and the absence of the weekly card and the old
  `distribution-card` / three-mini row.
- **`safe_limit_providers_test.dart`** — drop `weeklySafeLimitProvider`
  coverage; keep daily.
- **Golden tests** (`velora_*_golden_test.dart`, home goldens) — regenerate for
  the new Home layout.
- Engine tests (`safe_limit_engine_test.dart`) — unchanged (engine untouched).

## Risks

- **Golden churn** is expected and intended (layout changed). Regenerate and
  eyeball the new goldens.
- **Test key continuity:** keep `Key('balance-card')` / `Key('balance-amount')`
  on the new `BalanceCard` to avoid breaking unrelated selectors.
- **Dead-code scope creep:** the "consequential cleanup" must stay bounded to
  what the merge orphaned; confirm each deletion has no other referent before
  removing.
