# Transactions filters & Click-style layout — design

Date: 2026-07-21
Screen: `lib/features/transactions/transactions_screen.dart`

## Goal

Rework the Transactions screen so that:

1. Users can filter history by **card (account)**, **operation type**, and
   **period** (daily / weekly / monthly / custom date range).
2. Every transaction row uses one consistent anatomy, modelled on the Click
   "Hisobotlar" screen (reference screenshots provided by the user).

No text search — the user explicitly dropped it.

## Screen structure (top → bottom)

1. **AppBar** — `Tranzaksiyalar` (unchanged).
2. **Filter chip row** (horizontal): `Karta ▾` · `Operatsiya turi ▾` · `Davr ▾`.
   - Each chip opens a bottom sheet.
   - When a filter is active (i.e. not its default), the chip is filled and its
     label shows the selection, e.g. `Davr · O'tgan hafta`, `Karta · 2 ta`,
     `Turi · Chiqim`. At default the chip shows the bare name (`Davr`, `Karta`,
     `Operatsiya turi`) in the outline style.
3. **Two side-by-side summary cards**, equal width:
   - `Kirim` — income total over the filtered set, green (`VeloraColors.success`),
     prefixed `+`.
   - `Chiqim` — expense total over the filtered set, inkberry
     (`VeloraColors.inkberry`).
   - These replace the current plum `_MonthSummaryHero`.
4. **Grouped-by-day list**: for each day (newest first) a day header
   (`Sarflangan` label + the day's income+expense net on the right) followed by
   **one rounded card per transaction** (individual cards with spacing, per the
   Click reference — not the current single hairline-divided day card).

If, after filtering, no entries remain, show `VeloraEmptyState` under the filter
chips (the chips and summary cards stay visible so the user can widen the
filter). Summary cards then show zero totals.

## Row anatomy (per reference)

`[ leading icon ] [ title / subtitle column ] [ amount / time column ]`

- **Leading icon**: same rounded-square tile + glyph as today
  (`_typeIcon` / `_iconTones`).
- **Title** (primary line): the entry `note` ("what it was spent on"). If `note`
  is empty, fall back to the category / income-type / operation label
  (see fallback chain below).
- **Subtitle** (secondary line): the **category name** for expenses, the
  **income-type label** for income, and the operation label
  (`O'tkazma (chiqdi)` etc.) for transfers/adjustments. If the title already
  used the category/type (because note was empty), the subtitle shows the
  account name instead, so the two lines never repeat the same text.
- **Right column**: **amount** on top (colored via `_amountColor`, signed via
  `_amountText`) and **time** (`HH:mm`) below it in muted text.

### Title / subtitle fallback chain

For each entry, resolve `(title, subtitle)`:

- Expense:
  - note present → `(note, categoryName ?? 'Chiqim')`
  - note empty → `(categoryName ?? 'Chiqim', accountName ?? '')`
- Income:
  - note present → `(note, incomeTypeLabel)`
  - note empty → `(incomeTypeLabel, accountName ?? '')`
- Transfer / adjustment:
  - note present → `(note, operationLabel)`
  - note empty → `(operationLabel, accountName ?? '')`

`operationLabel` = existing `transactionTypeLabel`. `incomeTypeLabel` is a new
small mapping of `IncomeType` → Uzbek label (`Maosh`, `Bonus`, `Frilans`,
`Qaytarim`, `Boshqa`). Empty subtitle lines are simply omitted (single-line
row), so a row never shows a dangling separator.

## Filters

New value object `TransactionFilter`:

```
class TransactionFilter {
  final DateTimeRange? period;      // null = all time
  final Set<int> accountIds;        // empty = all cards
  final Set<LedgerEntryType> types; // empty = all types
}
```

`types` is expressed to the user as three grouped choices —
`Kirim` (`income`), `Chiqim` (`expense`), `O'tkazma`
(`transferIn` + `transferOut`) — and adjustments always pass through (they are
not offered as a toggle). Selecting `O'tkazma` includes both transfer legs.

Default filter: **period = current month** (matches today's "BU OY" semantics),
all cards, all types.

### Pure filter function (testable)

A standalone pure function in a new core file
`lib/core/transactions/transaction_filter.dart`:

```
List<LedgerEntry> applyTransactionFilter(
  List<LedgerEntry> entries,
  TransactionFilter filter,
);
```

Rules:
- period: keep entries whose `occurredAt` is within `[start, endInclusive]`
  (whole-day inclusive on both ends); null period keeps all.
- accountIds: keep entries whose `accountId` is in the set; empty set keeps all.
- types: keep entries whose `type` is in the set (with `O'tkazma` mapping to both
  transfer legs); empty set keeps all; adjustments always kept.

This function has no Flutter/Riverpod dependency and is unit-tested directly.

### State wiring

- A `StateProvider<TransactionFilter>` (or `NotifierProvider`) holds the current
  filter. Default value = current-month filter, computed once.
- The screen watches `transactionsControllerProvider` (all entries) and the
  filter provider, then calls `applyTransactionFilter` to get the visible list.
  The controller itself is unchanged — filtering is a view concern so the raw
  ledger stays cached and other screens are unaffected.
- Income/expense summary totals are computed from the filtered list.

## Filter bottom sheets

- **Davr**: `Sanadan` / `Sanagacha` date pickers + quick chips
  (`Bugun`, `Kecha`, `O'tgan hafta`, `O'tgan oy`) + `O'chirish` / `Ko'rsatish`
  actions. Picking a quick chip fills both date fields. `O'chirish` clears the
  period (all time); `Ko'rsatish` applies. `Bu oy` is the initial state.
- **Karta**: `Barcha kartalar` toggle + one checkbox row per account (name +
  icon). Multi-select. All-checked ≡ empty set (all).
- **Operatsiya turi**: checkboxes `Kirim` / `Chiqim` / `O'tkazma`. Multi-select.
  All-checked ≡ empty set (all).

Each sheet edits a local draft and commits to the filter provider on
`Ko'rsatish` / apply, so cancelling leaves the filter untouched.

## Widget breakdown

- `TransactionsScreen` — scaffold, watches entries + filter, applies filter.
- `_FilterChipsRow` — the three chips; opens sheets.
- `_PeriodFilterSheet`, `_AccountFilterSheet`, `_TypeFilterSheet` — bottom sheets.
- `_SummaryCards` — the two side-by-side income/expense cards.
- `_DayHeader` — kept, relabelled `Sarflangan` (income+expense net unchanged).
- `_TransactionCard` — single-transaction rounded card with the new anatomy
  (replaces `_DayCard` + `_TransactionRow`; keeps `Dismissible` swipe-to-delete).

## Preserved behaviour

- Swipe-to-delete (`Dismissible` + confirm dialog) stays on each row card.
- Amount coloring / signing, transfer & adjustment neutrality (§6.6) unchanged.
- Loading / error / empty async states unchanged in spirit.

## Testing

- Unit: `applyTransactionFilter` — period bounds (inclusive edges, null),
  account subset, type grouping (O'tkazma → both legs), adjustments always kept,
  combined filters.
- Unit: title/subtitle resolver — each fallback branch.
- Widget: filter chip label reflects active selection; applying a period filter
  narrows the visible rows and updates the two summary totals; empty-after-filter
  shows the empty state with chips still present.
- Golden refresh for the redesigned screen if the repo keeps goldens for it.

## Out of scope

- Text search.
- Persisting the filter across app restarts (session-only state).
- Category management / merchant enrichment.
