# Foundation — Design Spec

**Sub-project:** 0 of 7 (Foundation)
**Parent product:** Shaxsiy Moliyaviy Assistent (Personal Financial Assistant) — Flutter MVP
**Date:** 2026-07-17
**Status:** Approved for planning

---

## 1. Context

The full MVP (PRD: `docs/Shaxsiy Moliyaviy Assistent - Product Requirements Document.pdf`, 30 sections) is too large for a single spec. It is decomposed into seven sequential sub-projects, each with its own spec → plan → build cycle:

0. **Foundation** *(this spec)* — app shell, SQLite + migration/recovery framework, money/currency types, settings, onboarding.
1. Accounts & transactions — accounts, balances, transfers, expenses, income, categories.
2. Allocation & safe-limit engine — income distribution rules, daily/weekly safe limit.
3. Goals — dynamic goals, contributions, progress forecasting.
4. Mortgage — tracking, extra-payment scenarios, amortization.
5. Reports & month-close — reports and period closing.
6. Export/import & backup — full backup, CSV/JSON, encrypted, restore.

Foundation is load-bearing: everything else sits on the decisions here.

### Product constraints (from PRD)
- Flutter, iOS + Android, feature parity across both (§28.22).
- Local SQLite only; no backend in MVP (§22.1). Fully offline (§23).
- Primary currency UZS; each account may carry its own currency (§6.1); no FX conversion in MVP (§27).
- Data must survive app updates and device migration (§20).
- Performance: cold start < 2s; reports over 10k transactions < 2s; recalculation after every operation (§24).

### Build context
The code is written primarily by Claude Code. The architecture is optimized for AI-navigability and testability: small focused files, and a hard separation of pure calculation logic from data and UI so the math can be unit-tested in isolation.

## 2. Chosen stack

| Concern | Choice | Rationale |
|---|---|---|
| State management | **Riverpod** | Compile-safe, testable, clean provider/UI/logic separation. |
| Database | **Drift** over SQLite | Type-safe queries, first-class stepwise migration API, in-memory test support. |
| Router | **GoRouter** | Declarative, deep-link ready, each sub-project registers its own routes. |
| Money | **Integer minor units + currency code** | No floating point; correct for per-account currencies; future-proof. |
| App-lock | **local_auth** (biometric) + **flutter_secure_storage** (PIN hash) | Keeps secrets out of SQLite. |

## 3. Architecture & layering

Four layers; dependencies point downward only.

```
core/     ← pure Dart, no Flutter (except theme). The testable heart.
  money/  Money, Currency, parsing, formatting
  time/   FinancialPeriod, period & week math
  result/ Failure hierarchy + Result type (non-technical error mapping, §26)
  theme/  palette, typography, semantic status roles
  l10n/   uz-Latn UI, number/currency grouping, Cyrillic+Latin glyph support
data/     ← depends on core. Drift DB, DAOs, repositories
  db/       AppDatabase, tables, migration + recovery engine
  settings/ SettingsRepository
  meta/     AppMetaRepository
features/ ← depends on data+core. UI + Riverpod providers
  shell/       5-tab scaffold + routes
  onboarding/  extensible stepper
  settings/    settings screen
  security/    app-lock gate, background blur
app.dart / main.dart  ← composition root, router, provider scope
```

**Rule:** features touch the database only through repository interfaces, never Drift directly.

## 4. Pure-core modules

### 4.1 Money & Currency (`core/money`) — pure Dart
- `Money { int minorUnits; Currency currency }`. Integer-only, no floats anywhere.
- `Currency { String code; String symbol; int decimalDigits; SymbolPosition position }` with a registry. UZS = 0 decimal digits.
- Operations shipped in Foundation:
  - `add` / `subtract` — same-currency only; a mismatched currency returns a typed `Failure` (never a silent coercion).
  - `negate`, `compareTo`, `isNegative`, `zero(currency)`.
  - `parse(userText, currency)` — tolerant of space/comma grouping separators.
  - `format()` → e.g. `1 234 567 so'm` (space grouping, symbol per currency).
- Percentage/ratio allocation math is **not** in Foundation; it arrives with sub-project 2.
- Persisted as `(minorUnits INTEGER, currencyCode TEXT)` column pairs.

### 4.2 FinancialPeriod (`core/time`) — pure Dart
- The app's "month" is a financial period starting on a **configurable day** (§5.1/§5.2), not the calendar 1st. Underlies the safe-limit engine, every report, and month-close.
- `FinancialPeriod { DateTime start; DateTime endExclusive }`.
- Functions: `periodContaining(date, startDay)`, `next()`, `previous()`, `daysRemaining(asOf)`, `totalDays`.
- Edge handling: start day beyond a month's length clamps (e.g. 31 → Feb 28/29). Configurable week-start feeds weekly-limit math (§11.6).
- Exhaustively unit-tested.

### 4.3 Result & failures (`core/result`)
- Data layer returns typed `Failure`s rather than throwing.
- A presentation helper maps failures to non-technical, next-step-oriented messages (§26). No raw exceptions or jargon reach the user.

## 5. Data & migration layer (`data`)

### 5.1 Database
A single Drift `AppDatabase`. Foundation declares only the tables it owns:
- **`app_settings`** — single typed row: name, primaryCurrency, dateFormat, periodStartDay, weekStartDay, dailyLimitMethod (enum; calculation lands in SP2), minReserve (minorUnits + code), themeMode, appLockEnabled, biometricEnabled, notification flags bucket, savingsRolloverMode (§11.4).
- **`app_meta`** — schema version, install date, `onboardingComplete`, `lastBackupAt` (feeds §17 backup reminder later).

`PRAGMA foreign_keys = ON` always. Multi-write operations wrapped in transactions (§25). Later sub-projects add their own tables via new migration steps.

### 5.2 Repositories
Pure repository interfaces with Drift-backed implementations. Foundation ships `SettingsRepository` and `AppMetaRepository`. Riverpod exposes them as providers (`AsyncNotifier` for settings).

### 5.3 Migration & recovery engine (§20)
On every app start:
1. Read stored schema version vs. the code's current version.
2. If an upgrade is needed, **snapshot the SQLite file** to a recovery location first (§20.3), then run Drift's stepwise `onUpgrade`.
3. Drift wraps each migration step in a transaction; a failing step rolls back. If the whole migration still fails (corruption, non-transactional DDL): **restore the snapshot, open on the old schema, and show a plain-language message** — the app opens with data intact, never blank (§20.3).
4. Migrations run without user intervention (§20.2); old rows are transformed in the upgrade steps.
5. Backup-file schema versions (SP6 import) are checked against a compatibility floor — Foundation reserves the version field and the check hook; import logic itself is SP6 (§20.4).

## 6. Feature shell (`features`)

### 6.1 App shell (`features/shell`)
`MaterialApp.router` + GoRouter. Bottom navigation with the five sections from §21.4 — **Home, Transactions, Allocation, Goals, Reports** — each a placeholder screen filled in by later sub-projects. Settings opens from a profile/menu entry, not a sixth tab. The shell reserves a thumb-reachable action slot (§21.5) for sub-project 1's "add expense" FAB.

### 6.2 Onboarding (`features/onboarding`) — extensible stepper
An `OnboardingStep` interface plus a provider assembling an ordered step list. Foundation contributes only its own steps:
1. Welcome + name → 2. Currency → 3. Financial-period start day + week start → 4. Minimal reserve → 5. Theme → 6. App-lock (optional).

Every step is skippable (§5.1) and editable later in Settings. Later sub-projects register their own steps (first account, mortgage y/n, monthly obligations, variable budget) without touching Foundation code. On finish → write settings, set `onboardingComplete`. First launch routes to onboarding; thereafter to the shell.

### 6.3 Settings (`features/settings`)
Screen exposing the Foundation-owned settings (§5.2): name, currency, date format, period start day, week start day, daily-limit method, minimal reserve, notifications toggles (bucket), theme, biometric/app-lock. The "export data" entry is a stub → SP6.

### 6.4 Security (`features/security`)
- **App-lock gate** wrapping the router: PIN or biometric (`local_auth`) on cold start and on resume past a timeout. PIN stored **hashed in `flutter_secure_storage`**, never in SQLite.
- **Hide-in-background (§22.3):** on `AppLifecycleState.inactive/paused`, show a branded blur overlay so no amounts appear in the app switcher.

### 6.5 Theming & localization (`core/theme`, `core/l10n`)
- Warm, calm palette (§21.2); **red reserved strictly for errors/critical**. Status (safe / near-limit / over-limit) always encoded as color **+ icon + text**, never color alone (§10.4, §21.8).
- Light/dark modes (§5.2). Typography with clear numerals and full Cyrillic+Latin glyph coverage (§21.3); respects system font scaling (§21.8).
- UI language: **uz-Latn** (matching the PRD), with the font also covering Cyrillic for user-entered text.

## 7. Scope boundary

| In Foundation | Stubbed / deferred |
|---|---|
| Layered scaffold, GoRouter, provider scope | Accounts, transactions, categories, budgets → SP1 |
| `Money`, `Currency`, `FinancialPeriod` (+ tests) | Safe-limit & allocation math → SP2 |
| Drift DB, migration + recovery engine | Goals → SP3, Mortgage → SP4 |
| `app_settings` + `app_meta` tables & repos | Reports & month-close → SP5 |
| Settings screen, extensible onboarding | Export/import/backup → SP6 (fields reserved) |
| 5-tab shell (placeholder tabs) | Notifications → later (flags reserved) |
| App-lock + hide-in-background | Multi-currency dashboard aggregation → open question, SP5 |
| Warm theme, l10n scaffold, error mapping | |

## 8. Testing & acceptance

- Pure core (`Money`, `FinancialPeriod`) exhaustively unit-tested.
- Repositories tested against `NativeDatabase.memory()` (in-memory Drift).
- Migration verified with Drift schema snapshots; a v1→v2 migration test **and** a forced-failure recovery test both green.
- App cold-starts < 2s (§24); launches to onboarding on first run, to the shell thereafter; settings persist across restarts; app-lock and background blur verified.

## 9. Open questions (deferred, not blocking)

- **Multi-currency dashboard aggregation** — with per-account currencies and no FX (§27), how is "total available balance" (§14.1) shown when accounts differ in currency? Resolve in SP5 (Reports). Foundation's `Money` type already supports the data faithfully.
- **uz-Cyrl UI** — Foundation ships uz-Latn UI; a Cyrillic UI locale can be added later if wanted (font already covers the glyphs).
