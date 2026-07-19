# Velora Mobile Redesign — Design Spec

**Product:** Personal Financial Assistant — Flutter MVP

**Date:** 2026-07-19

**Status:** Approved for implementation planning

**Brand:** Velora
**Depends on:** Foundation, Accounts & Transactions, Allocation & Safe Limit, Goals, and Mortgage specs

---

## 1. Purpose

This specification turns the approved Velora mockups into an implementation-ready interaction and visual design for the complete mobile MVP. It has three goals:

1. bring every current screen into one modern, payment-system-inspired visual language;
2. make frequent financial actions fast, understandable, and safe on a phone;
3. close the UI coverage gaps identified in `docs/prd.txt`, without changing the PRD's business rules.

This is a cross-cutting UI/UX specification. Existing domain specs remain authoritative for ledger, allocation, safe-limit, goal, mortgage, migration, and persistence behavior. Where a missing PRD module has no implementation yet—reports, month-close, backup/import, and notification management—this document defines its user-facing contract, while its implementation plan must include the required data and domain work.

## 2. Baseline review and target coverage

The review snapshot before this redesign found:

| Acceptance state | Count | Criteria |
|---|---:|---|
| Met | 11 | AC 1, 4, 5, 8–14, 16 |
| Partial | 5 | AC 2, 3, 6, 7, 20 |
| Missing | 3 | AC 15, 18, 19 |
| Unverified | 3 | AC 17, 21, 22 |

The existing suite passed `flutter analyze` and all 258 tests. Passing tests do not close product-level gaps: reports, full backup/restore, month-close, notification controls, and dashboard personalization remain absent or incomplete. Performance, offline parity, platform parity, and migration-failure recovery also require device-level verification.

Known correctness risks that implementation must resolve before the redesigned UI is considered complete:

- safe-limit inputs may subtract the same reserved amount twice;
- cross-currency entry and aggregation semantics are not consistently enforced;
- workflows that write multiple financial records are not uniformly atomic;
- repository exceptions can reach presentation code without a typed, user-safe failure mapping.

The redesigned screen inventory covers all 22 acceptance criteria visually. Visual coverage is not implementation completion; the implementation plan must preserve the baseline distinction and add verification for every criterion.

## 3. Approved design direction

The selected direction is **Velora Human**: warm and friendly enough to reduce financial pressure, structured enough to feel like a trusted payment application.

### 3.1 Experience principles

- **One clear decision per screen.** Each screen has one primary CTA; secondary actions use lower emphasis.
- **Numbers first, jargon second.** Amount, consequence, and next action appear before financial terminology.
- **Fast by default, detailed on demand.** Optional fields stay collapsed or behind a detail action.
- **Constructive, never accusatory.** Overspending language explains impact and recovery instead of blame.
- **Safe financial actions.** Destructive and multi-record operations show a preview, consequence, and explicit confirmation.
- **Thumb-reachable.** Frequent controls and CTAs sit in the lower interaction zone.
- **Offline confidence.** Local save state is explicit; loss of internet does not imply loss of data.

### 3.2 Brand tokens

| Role | Token | Value | Use |
|---|---|---|---|
| Primary | Velora Plum | `#5B3A6E` | navigation, selected state, key financial surfaces |
| Action | Coral | `#E96F5C` | the single primary CTA and positive action emphasis |
| Highlight | Apricot Glow | `#FFB46A` | progress accents and soft emphasis |
| Background | Blush Surface | `#FFF8F5` | default light background |
| Text | Inkberry | `#332A3A` | primary text and amounts |
| Success | Calm Success | `#2E9D7C` | completed, balanced, and safe states |

Red is reserved for errors and critical states. Near-limit states use amber/apricot. Every status combines color with text and an icon.

### 3.3 Typography and geometry

- Preferred typography: **Onest** for display amounts and headings, **Noto Sans** for interface text, and **IBM Plex Mono** only for compact technical identifiers. The final Flutter font package must support Uzbek Latin, Cyrillic user content, and tabular numerals.
- Body text respects system text scaling without clipping through 200%.
- Touch targets are at least 48×48 logical pixels.
- Primary cards use 20–24 px radii; compact inputs and controls use 14–18 px radii.
- Motion lasts 180–240 ms, is non-looping, and honors reduced-motion settings.
- Amounts use tabular numerals and space grouping, for example `12 500 000 so‘m`.

## 4. Information architecture

### 4.1 Primary navigation

The app uses five bottom destinations:

1. **Bugun** — balance, safe limit, alerts, and quick actions;
2. **Tarix** — transactions and filtering;
3. **Reja** — allocation, budgets, and upcoming obligations;
4. **Maqsad** — goals and mortgage progress;
5. **Tahlil** — daily, weekly, monthly, category, goal, and mortgage reports.

Settings opens from the profile entry and is never a sixth tab. The global add-expense action remains reachable from every main destination.

### 4.2 Navigation behavior

- Each tab preserves its own scroll and filter state.
- Back closes a sheet or detail route before leaving the current tab.
- Creation flows use full-height sheets for short tasks and full-screen step flows for long financial forms.
- Deep links and notifications land on the related detail screen, never a generic home screen.
- A bottom CTA remains visible when the form content scrolls, while respecting the keyboard and safe areas.

## 5. Shared component contracts

### 5.1 `VeloraMoneyField`

Every money input uses one shared component and formatter.

**Display contract**

- UZS has zero decimal digits and displays as `1 250 000 so‘m`.
- Currency controls decimal precision; no amount is converted through floating point.
- Grouping appears while typing without moving the caret unexpectedly.
- Empty input is distinct from zero. Placeholder zero is visual only until the user types.
- Paste accepts spaces, non-breaking spaces, commas, apostrophes, and the currency label, then normalizes safely.
- Invalid characters are ignored or explained inline; negative values are blocked unless the domain explicitly permits them.
- Currency is visible beside or above the amount. When an account controls the currency, changing the account revalidates the amount.
- Very large values remain readable and never overflow the viewport.

**Input contract**

- The amount field autofocuses on quick expense and income entry.
- The numeric keyboard opens immediately.
- A clear/backspace control is reachable by thumb.
- Screen readers announce the normalized amount and currency, not individual grouping spaces.
- Internal values are integer minor units plus currency code.

**Validation contract**

- Save remains disabled for empty, zero, negative, overflowed, or currency-mismatched values.
- Inline errors explain the correction: for example, “Summani kiriting” or “Bu hisob UZS’da yuritiladi.”
- Insufficient funds and over-allocation are domain errors shown after valid numeric input, with the missing amount and next action.

### 5.2 `AccountCardPicker`

- Accounts appear as horizontally swipeable cards with a visible next-card peek.
- Tapping a card also selects it; swipe is never the only interaction.
- The last-used active account is selected by default for quick expense.
- Each card shows account name, type, currency, and available balance.
- Archived accounts are excluded from creation flows.
- Cross-currency operations require an explicit compatible path; no silent FX conversion is allowed.

### 5.3 `CategoryPicker`

Quick expense uses a hybrid model:

- show four recent/frequent/favorite categories for one-tap selection;
- open **Kategoriya tanlash** for the full list;
- the full selector supports search, parent grouping, and archived-category exclusion;
- selection returns directly to the amount flow without another confirmation step;
- category state is expressed with icon and label, never icon alone.

This avoids an unscalable grid while keeping common expenses within one tap.

### 5.4 Financial cards and status

- Summary cards show one amount, one clear label, and at most one supporting comparison.
- Safe/near/over states use text + icon + color.
- Progress bars include the current and target values in text.
- Sensitive values can be hidden globally; hidden state persists until the user reveals them.
- Skeletons preserve final layout geometry and do not block unrelated local content.

### 5.5 Sheets, dialogs, and feedback

- Bottom sheets handle searchable selection and short edits.
- Dialogs are reserved for destructive confirmation or irreversible consequence.
- Save success uses a short confirmation with **Bekor qilish** when reversal is safe.
- Multi-write actions show a review screen and commit atomically.
- Raw exceptions never appear. Typed failures map to plain-language cause, impact, and recovery action.

## 6. Screen inventory and approved behavior

### 6.1 Onboarding

Onboarding is progressive and skippable. It collects only what is required for the current step:

1. welcome and preferred name;
2. primary currency and financial-period start;
3. first account and opening balance;
4. income, mandatory expenses, variable budget, and minimal reserve;
5. mortgage presence;
6. optional security setup.

A progress indicator shows position, not completion pressure. Skipped values remain editable in Settings. Long numeric forms use `VeloraMoneyField`.

### 6.2 Bugun / Home

The hierarchy is:

1. total available balance with privacy toggle;
2. today's safe-to-spend amount as the dominant decision card;
3. quick actions: expense, income, allocation, goal contribution, mortgage payment;
4. unallocated income alert when non-zero;
5. weekly limit and monthly free-budget progress;
6. primary goal and mortgage summaries;
7. actionable upcoming obligations.

Dashboard personalization allows reorder, hide/show, and primary-goal selection. Essential safe-limit and unallocated-income signals cannot both be hidden.

### 6.3 Quick expense

Target completion is 3–5 seconds:

1. sheet opens with amount focused and last-used account selected;
2. user types a formatted amount;
3. user taps one of four quick categories or opens the searchable selector;
4. user taps **Saqlash** once;
5. local transaction, account balance, budget state, safe limit, and report inputs update atomically;
6. success feedback offers **Bekor qilish** briefly.

Account cards are swipeable horizontally and tappable. Date/time, note, subcategory, and planned/unplanned flags are in **Batafsil** and default to current context.

### 6.4 Income and recurring income

Income uses the same money input, account picker, and optional-detail pattern. After save, the user chooses:

- distribute now;
- distribute later;
- apply the previous allocation template.

Recurring income creates a plan, not an automatic ledger entry. On its date, Velora asks the user to confirm, edit, postpone, or skip that occurrence.

### 6.5 Allocation

The allocation editor supports fixed amount, percentage, goal-based, and remaining-balance rules. Rules can be reordered. Before commit it shows total income, each destination, allocated total, unallocated balance, and free balance after allocation.

If funds are insufficient, critical obligations remain first, lower-priority directions are reduced, and the exact shortfall is shown. Save is disabled while allocations exceed income. The final commit is atomic.

### 6.6 Tarix / Transactions and accounts

- The transaction list groups by date and keeps amount, category, account, and status scannable.
- Filters cover date range, account, category, transaction type, goal, and mortgage where relevant.
- Transaction detail supports edit and delete with derived balances, limits, and reports recalculated.
- Account management covers create, edit, archive, transfer, and balance adjustment.
- Transfers show source and destination cards and never count as income or expense.
- Balance adjustments are visibly labeled in history.

### 6.7 Reja / Categories and budgets

- Budget cards show planned, spent, remaining, percentage, and safe/near/over label.
- Category creation supports name, icon, type, optional parent, monthly limit, weekly limit, and quick-expense visibility.
- Used categories can only be archived.
- The planning view combines allocation rules, category budgets, recurring obligations, and next-period preparation without mixing them into one editable form.

### 6.8 Maqsad / Goals

- Goal cards show saved amount, target, percentage, remaining amount, target date, projected completion, and required monthly contribution.
- Creation is a short form with name, icon, target, dates, priority, type, and optional note.
- Contribution and withdrawal show their effect before commit and produce history entries.
- Goal completion offers close, set a new target, or move excess to another goal.
- The primary goal can be selected for Home.

### 6.9 Mortgage

Mortgage setup uses two steps: loan data, then payment plan. Dashboard shows current principal, next payment, rate, payment history, projected payoff, and scenario entry.

The payment split is deliberately explicit:

- **Auto split** calculates principal and interest from the plan;
- **Manual split** shows two large fields: **Asosiy qarzga** and **Foiz to‘lovi**;
- helper text states that principal reduces debt and interest does not;
- a live equation must balance to the total payment;
- save stays disabled when the split is negative, exceeds the total, or does not balance;
- extra principal previews estimated time and interest saved;
- every estimate is labeled as informational, not a bank statement.

### 6.10 Tahlil / Reports

Reports include daily, weekly, monthly, category, goal, and mortgage views. The default report presents the main comparison first; filters open in a sheet. Charts always have text equivalents and accessible labels.

Required report content follows PRD §15 and §13.8. The monthly report includes income, expense, mandatory/variable split, goal allocation, mortgage mandatory/extra payment, savings, unallocated balance, and prior-period comparison. Up to 10,000 transactions must render within two seconds on target hardware.

### 6.11 Month-close

Month-close is a guided review:

1. show period totals and a checklist;
2. block close while draft or invalid financial records remain;
3. show leftover allocation choices: mortgage principal, reserve, selected goal, next month, or a split;
4. require allocated total to equal the available leftover;
5. preview the next period with copied budgets and recurring obligations;
6. commit close, allocations, and next-period creation atomically.

Closed-period editing remains possible only through an explicit reopen flow. The UI explains the reporting consequence before reopening.

### 6.12 Settings, data, and security

Settings groups profile, financial preferences, notifications, appearance, privacy/security, and data management.

- Notification types are independently toggleable.
- Backup supports plain or password-protected export, Files/share targets, CSV/JSON report export, last-backup state, and reminder status.
- Import validates format, version, date, and record counts before replacing local data. MVP uses full replacement; merge is not offered.
- A safety backup is created before restore. Import failure leaves current data unchanged and offers a clear retry path.
- Delete-all requires authentication and typed confirmation.
- Background preview hides financial amounts.

### 6.13 App Lock

The approved default is **PIN-first**:

- the persistent fallback screen is a simple four-digit numeric keypad;
- Face ID, Touch ID, or Android biometrics use the operating system's native prompt and may launch automatically;
- a biometric icon on the PIN screen retries the native prompt;
- PIN is never displayed, logged, or stored in SQLite;
- repeated failures use platform-appropriate cooldown and recovery behavior;
- **PIN kodni unutdingizmi?** begins a secure local recovery/reset flow without exposing data.

No custom fake Face ID animation or custom biometric dialog is used.

### 6.14 Global states

Every data screen defines:

- empty state with one meaningful creation action;
- loading skeleton matching final geometry;
- offline state explaining that local work still functions;
- recoverable error with a retry or corrective action;
- success state with undo where safe;
- permission-denied state with a route to system settings when required.

## 7. Presentation architecture

The redesign keeps domain logic out of widgets.

```text
Screen / Sheet
  -> feature controller or notifier
    -> repository interface
      -> Drift transaction / pure domain engine
  <- typed view state and typed failures
```

### 7.1 Boundaries

- `core/theme`: Velora semantic tokens, typography, spacing, motion, and status roles.
- `core/money`: integer money parsing/formatting and `VeloraMoneyField` formatter behavior.
- `ui/components`: shared cards, buttons, sheets, account picker, category picker, amount field, status, empty/error/loading states.
- `features/*/presentation`: route-specific composition and controllers only.
- `data/*`: repositories and atomic persistence.

Widgets do not calculate safe limits, allocation totals, goal projections, or amortization. They render already-derived view models and send user intents back to controllers.

### 7.2 Atomicity

These operations must be database transactions:

- transaction save/edit/delete plus dependent ledger entries;
- transfer and balance adjustment;
- income plus confirmed allocation;
- goal contribution/withdrawal plus account movement;
- mortgage payment plus ledger transaction and principal update inputs;
- month-close plus leftover allocation and next-period creation;
- import replacement and migration recovery.

If any write fails, the whole operation rolls back and the previous view state remains valid.

## 8. Accessibility and localization

- All controls have semantic labels and logical traversal order.
- Icon-only controls expose an accessible name.
- Status never depends on color alone.
- Dynamic type works to 200%; dense financial rows reflow instead of clipping.
- Minimum contrast follows WCAG AA for normal text and controls.
- Motion can be reduced; no information exists only in animation.
- Uzbek Latin is the interface default. User-entered Cyrillic remains fully supported.
- Dates follow the selected format; financial periods use the configured start day.
- Formatted amounts are announced with currency and full value.

## 9. Performance targets

- Cold start under two seconds on the agreed target device class.
- Quick-expense sheet visually ready within 300 ms.
- Save provides immediate local feedback; persistence failure reverses optimistic state safely.
- Home initially renders cached/local summaries without a blank blocking screen.
- Monthly reports with 10,000 transactions open under two seconds.
- Horizontal account cards and scrolling lists maintain smooth interaction on iOS and Android.

## 10. Acceptance traceability after implementation

| AC | Target evidence |
|---:|---|
| 1 | Account creation with opening balance widget/integration test |
| 2 | Timed income-entry usability run under 10 seconds |
| 3 | Timed quick-expense run in 3–5 seconds and sheet-open benchmark |
| 4 | Multi-destination allocation integration test |
| 5 | Home unallocated-income view-state test |
| 6 | Safe-limit pure-engine and provider tests |
| 7 | Expense commit triggers one correct recalculation; regression test for double subtraction |
| 8 | Monthly category-budget create/edit test |
| 9 | Dynamic goal creation test |
| 10 | Goal contribution, withdrawal, and progress projection tests |
| 11 | Mortgage setup flow test |
| 12 | Mortgage payment history test |
| 13 | Projected payoff date engine and UI tests |
| 14 | Extra-payment scenario comparison tests |
| 15 | Daily, weekly, and monthly report tests including 10k performance case |
| 16 | Drift persistence/restart integration test |
| 17 | Full core-flow offline device test |
| 18 | Full backup export and contents test |
| 19 | Full replacement restore, corrupted file, and rollback tests |
| 20 | Version-up migration tests with existing data fixtures |
| 21 | Forced migration failure restores recovery backup with zero data loss |
| 22 | Shared iOS/Android smoke suite for every primary flow |

## 11. Testing strategy

### 11.1 Unit tests

- money parsing, formatting, paste normalization, overflow, and currency precision;
- safe-limit regression for reserved-money double subtraction;
- allocation balance and priority reduction;
- goal and mortgage consequence calculations;
- typed failure-to-message mapping.

### 11.2 Widget and golden tests

- all shared components in light/dark, 320 px width, and 200% text scale;
- quick expense, category selector, mortgage split, PIN lock, reports, month-close, import preview, and global states;
- status semantics verified without relying on color;
- keyboard and safe-area behavior on amount forms.

### 11.3 Integration and device tests

- 3–5 second quick-expense path;
- atomic rollback for every multi-write workflow;
- offline usage across the required PRD flows;
- backup/restore and migration recovery with real files;
- background privacy overlay;
- native biometric success, cancel, lockout, and PIN fallback on iOS and Android;
- performance targets from §9.

## 12. Implementation sequencing

The design is implemented in dependency order to avoid visual work hiding correctness gaps:

1. Velora tokens, typography, shared scaffold, semantic statuses, and `VeloraMoneyField`;
2. navigation shell, Home, quick expense, income, account picker, and category picker;
3. transactions, accounts, allocation, categories, budgets, goals, and mortgage redesign;
4. reports and month-close domain/data/UI work;
5. backup/import, notification controls, dashboard personalization, and security redesign;
6. cross-platform accessibility, performance, migration-recovery, and acceptance verification.

Each phase must keep tests green and may ship independently. A phase is not complete when only its visuals are present; its domain behavior, failure states, accessibility, and evidence in §10 are part of completion.

## 13. Scope boundaries

This redesign does not add bank integrations, SMS transaction detection, cloud sync, multi-user or family budgets, a web version, automatic FX rates, investment management, tax reporting, or AI financial advice. Those remain outside MVP per PRD §27.

The design also does not silently merge backup data, fabricate bank-accurate mortgage results, or convert currencies without an explicit rate source. Estimates and unsupported cross-currency totals are labeled clearly.

## 14. Definition of done

Velora redesign is complete only when:

- all screens in §6 use the shared design system and interaction contracts;
- all 22 acceptance criteria have passing evidence from §10;
- the correctness risks in §2 are resolved with regression tests;
- there are no raw technical errors in user-facing UI;
- all primary flows work offline and on both iOS and Android;
- accessibility and performance targets pass on representative devices;
- backup, restore, migration recovery, and background privacy protect existing data;
- the final implementation matches the approved mock decisions, including swipeable account cards, hybrid category selection, explicit mortgage split, and PIN-first native-biometric App Lock.
