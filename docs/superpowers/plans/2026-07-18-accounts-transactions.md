# Accounts & Transactions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build sub-project 1 of 7 — accounts, the derived double-entry ledger (expenses, income, transfers, balance adjustments), categories, full recurring-income plans, and the dashboard cards this data can compute.

**Architecture:** A pure-Dart `core/ledger` engine defines the meaning of every derived number (balances, month totals, today's spent, undistributed) and is exhaustively unit-tested with no Drift or Flutter. Account balance is **derived** (opening balance + Σ ledger entries) — there is no stored, mutable balance column, so editing or deleting any past entry recalculates correctly by construction (PRD §25). A new schema v2 migration adds four tables; features reach them only through repository interfaces exposed as Riverpod providers, exactly as the Foundation established.

**Tech Stack:** Flutter (stable), Dart 3, Drift (SQLite), Riverpod (flutter_riverpod), GoRouter, intl, build_runner + drift_dev. Same stack as the Foundation — no new dependencies.

## Global Constraints

- **Platform:** iOS + Android, feature parity (PRD §28.22). No web/desktop targets.
- **Storage:** Local SQLite only; no network calls anywhere (PRD §22.1, §23).
- **Money:** Integer minor units + currency code. **No floating-point money, ever.** UZS = 0 decimal digits. Same-currency arithmetic only; `Money.add`/`subtract` throw `CurrencyMismatchError` on mismatch.
- **Ledger sign convention:** `expense` and `transferOut` store a **negative** `amountMinor`; `income` and `transferIn` store **positive**; `adjustment` stores the **signed delta** (real − current).
- **Every entry belongs to exactly one account** (PRD §25). A transfer is **two** linked entries sharing a `transferId`.
- **Financial "month":** Use `FinancialPeriod`, never the calendar 1st. The period start day comes from `AppSettings.periodStartDay`.
- **No FX in MVP** (PRD §27): transfers are same-currency only; a mismatch returns a typed `Failure`, never a silent coercion. Dashboard totals are grouped by currency, never summed across currencies.
- **Errors:** Data/domain layers return typed `Failure`s via `Result<T>`, not thrown exceptions; user-facing text is non-technical and states a next step (PRD §26).
- **Status encoding:** any safe/near/over status uses color **+ icon + text**, never color alone (PRD §21.8). (Category budget status itself is deferred to SP2.)
- **Red:** reserved strictly for error/critical (PRD §21.2).
- **Archive, never delete:** used accounts and categories are archived, not hard-deleted (PRD §6, §10.2).
- **Performance:** quick-expense entry sheet opens < 300ms; recalculation after every operation; correct over 10k entries (PRD §24).
- **UI language:** uz-Latn; the Foundation font already renders Cyrillic + Latin.
- **Commits:** Conventional Commits (`feat:`, `test:`, `fix:`, `chore:`, `refactor:`). Commit at the end of every task.
- **Generated code:** Drift `*.g.dart` files are git-ignored; run `dart run build_runner build --delete-conflicting-outputs` after changing any `@DriftDatabase`/`Table` code, before running tests.
- **Test command:** `flutter test --concurrency=1` (default concurrency drops suites on the Windows dev box).

---

## File Structure

```
lib/
  core/ledger/
    account.dart            # Account value type + AccountType enum
    ledger_entry.dart       # LedgerEntry value type + LedgerEntryType, IncomeType enums
    balance_engine.dart     # accountBalance, adjustmentDelta, buildTransfer (+ TransferDraft)
    summary_engine.dart     # totalsByCurrency, periodIncome/Expense, spentOn, categorySpent, undistributed
  data/
    db/
      tables.dart           # +AccountsTable, CategoriesTable, TransactionsTable, RecurringIncomePlansTable
      app_database.dart     # register new tables, schemaVersion -> 2
      migrations.dart       # v1->v2 onUpgrade: createTable + seed default categories
      db_open.dart          # add injectable `open` factory seam (for the §20.3 failure test)
      default_categories.dart # the 13 PRD §10.1 default category seeds
    accounts/
      account_repository.dart      # interface + Drift impl (row<->Account mapping)
    categories/
      category_model.dart          # Category domain type
      category_repository.dart     # interface + Drift impl
    ledger/
      ledger_repository.dart       # interface + Drift impl (write ops + typed reads, row<->LedgerEntry)
    recurring/
      recurring_model.dart         # RecurringIncomePlan domain type + IntervalKind enum
      recurring_repository.dart    # interface + Drift impl
  features/
    accounts/
      accounts_controller.dart     # list + balances (repo + engine)
      accounts_screen.dart         # account list
      account_edit_sheet.dart      # create/edit/archive
      transfer_sheet.dart          # between-accounts transfer
      balance_adjust_sheet.dart    # §6.3 adjustment
    expense_entry/
      expense_entry_controller.dart# quick-add state, last-used account, quick-pick categories, undo
      expense_entry_sheet.dart     # 3-step amount -> category -> save
    income_entry/
      income_entry_controller.dart # add income, recurring plan, mark undistributed
      income_entry_sheet.dart
    transactions/
      transactions_controller.dart # history + filters + edit/delete
      transactions_screen.dart     # Transactions tab
    home/
      dashboard_data.dart          # DashboardData + pure buildDashboard(...)
      home_screen.dart             # Home tab cards + quick actions
    recurring/
      recurring_prompt.dart        # on-open "confirm this income" prompt
  providers/
    app_providers.dart      # +repository providers, +ledger query providers
  features/recurring/
    recurring_prompt.dart   # on-open "confirm this income" prompt + controller
```

> **Implementation note (§28.1 / first account):** the spec envisioned a
> first-account *onboarding step*. The Foundation's `OnboardingStep` contract only
> mutates the settings draft (`OnboardingController.update`) and has no repository
> access or post-commit hook, so a repository-backed account cannot be created from
> a step without changing Foundation. Instead, §28.1 ("user creates an account and
> enters a starting balance") is satisfied by the **Accounts screen** (Task 11),
> reachable from the Home app bar (Task 18); its create sheet takes name, type, and
> opening balance. This is the only intentional deviation from the spec.

---

## Task 1: Ledger value types (pure `core/ledger`)

**Files:**
- Create: `lib/core/ledger/account.dart`
- Create: `lib/core/ledger/ledger_entry.dart`
- Test: `test/core/ledger/ledger_types_test.dart`

**Interfaces:**
- Consumes: `Money` (`lib/core/money/money.dart`), `Currency` (`lib/core/money/currency.dart`).
- Produces:
  - `enum AccountType { bankCard, cash, savings, other }`
  - `class Account { int id; String name; AccountType type; Money openingBalance; String icon; bool archived; Currency get currency; }`
  - `enum LedgerEntryType { expense, income, transferOut, transferIn, adjustment }`
  - `enum IncomeType { salary, bonus, freelance, refund, other }`
  - `class LedgerEntry { int id; int accountId; LedgerEntryType type; Money amount; int? categoryId; IncomeType? incomeType; String? transferId; Money allocated; bool? planned; DateTime occurredAt; String? note; }`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/ledger/ledger_types_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  test('Account exposes its currency from the opening balance', () {
    const acc = Account(
      id: 1,
      name: 'Naqd',
      type: AccountType.cash,
      openingBalance: Money(500000, uzs),
      icon: 'wallet',
      archived: false,
    );
    expect(acc.currency, uzs);
    expect(acc.type, AccountType.cash);
  });

  test('LedgerEntry holds a signed amount and optional classification', () {
    final e = LedgerEntry(
      id: 10,
      accountId: 1,
      type: LedgerEntryType.expense,
      amount: const Money(-12000, uzs),
      categoryId: 3,
      allocated: const Money(0, uzs),
      occurredAt: DateTime(2026, 7, 18),
    );
    expect(e.amount.isNegative, isTrue);
    expect(e.categoryId, 3);
    expect(e.incomeType, isNull);
    expect(e.transferId, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/core/ledger/ledger_types_test.dart`
Expected: FAIL — `Account`/`LedgerEntry` not defined (URI doesn't exist).

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/ledger/account.dart
import '../money/currency.dart';
import '../money/money.dart';

enum AccountType { bankCard, cash, savings, other }

class Account {
  final int id;
  final String name;
  final AccountType type;
  final Money openingBalance;
  final String icon;
  final bool archived;

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.openingBalance,
    required this.icon,
    required this.archived,
  });

  Currency get currency => openingBalance.currency;
}
```

```dart
// lib/core/ledger/ledger_entry.dart
import '../money/money.dart';

enum LedgerEntryType { expense, income, transferOut, transferIn, adjustment }

enum IncomeType { salary, bonus, freelance, refund, other }

class LedgerEntry {
  final int id;
  final int accountId;
  final LedgerEntryType type;
  final Money amount; // signed; see Global Constraints sign convention
  final int? categoryId; // set for expense
  final IncomeType? incomeType; // set for income
  final String? transferId; // links the two rows of a transfer
  final Money allocated; // income only; zero otherwise
  final bool? planned; // expense planned-vs-unexpected
  final DateTime occurredAt;
  final String? note;

  const LedgerEntry({
    required this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.occurredAt,
    required this.allocated,
    this.categoryId,
    this.incomeType,
    this.transferId,
    this.planned,
    this.note,
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --concurrency=1 test/core/ledger/ledger_types_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/ledger/account.dart lib/core/ledger/ledger_entry.dart test/core/ledger/ledger_types_test.dart
git commit -m "feat: add pure ledger value types (Account, LedgerEntry)"
```

---

## Task 2: Balance engine (pure `core/ledger`)

**Files:**
- Create: `lib/core/ledger/balance_engine.dart`
- Test: `test/core/ledger/balance_engine_test.dart`

**Interfaces:**
- Consumes: `Account`, `LedgerEntry`, `Money`, `Currency`, `Result`/`Failure` (`lib/core/result/`).
- Produces:
  - `Money accountBalance(Account account, Iterable<LedgerEntry> entries)` — opening balance + Σ entries whose `accountId` matches. Ignores entries for other accounts.
  - `Money adjustmentDelta(Money currentBalance, Money realBalance)` — returns `realBalance - currentBalance` (the signed amount to store as an `adjustment` entry).
  - `class TransferDraft { LedgerEntry outEntry; LedgerEntry inEntry; }`
  - `Result<TransferDraft> buildTransfer({required Account from, required Account to, required Money amount, required DateTime occurredAt, required String transferId, String? note})` — validates same currency and positive amount; produces the negative `transferOut` on `from` and positive `transferIn` on `to`, both id 0 (unpersisted), sharing `transferId`. Returns `Err(ValidationFailure)` on currency mismatch or non-positive amount.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/ledger/balance_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/result/failure.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/core/ledger/balance_engine.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  const usd = CurrencyRegistry.usd;

  Account acc(int id, {Currency c = uzs, int opening = 0}) => Account(
        id: id,
        name: 'A$id',
        type: AccountType.cash,
        openingBalance: Money(opening, c),
        icon: 'wallet',
        archived: false,
      );

  LedgerEntry entry(int accountId, LedgerEntryType type, int minor) => LedgerEntry(
        id: 0,
        accountId: accountId,
        type: type,
        amount: Money(minor, uzs),
        allocated: const Money(0, uzs),
        occurredAt: DateTime(2026, 7, 18),
      );

  test('balance is opening plus only this account\'s entries', () {
    final entries = [
      entry(1, LedgerEntryType.income, 1000000),
      entry(1, LedgerEntryType.expense, -250000),
      entry(2, LedgerEntryType.expense, -999999), // other account, ignored
    ];
    expect(accountBalance(acc(1, opening: 500000), entries),
        const Money(1250000, uzs));
  });

  test('adjustmentDelta is real minus current', () {
    expect(adjustmentDelta(const Money(300000, uzs), const Money(275000, uzs)),
        const Money(-25000, uzs));
  });

  test('buildTransfer produces a linked negative/positive pair', () {
    final r = buildTransfer(
      from: acc(1, opening: 1000000),
      to: acc(2),
      amount: const Money(300000, uzs),
      occurredAt: DateTime(2026, 7, 18),
      transferId: 'tr-1',
    );
    expect(r.isOk, isTrue);
    final d = r.valueOrNull!;
    expect(d.outEntry.accountId, 1);
    expect(d.outEntry.type, LedgerEntryType.transferOut);
    expect(d.outEntry.amount, const Money(-300000, uzs));
    expect(d.inEntry.accountId, 2);
    expect(d.inEntry.type, LedgerEntryType.transferIn);
    expect(d.inEntry.amount, const Money(300000, uzs));
    expect(d.outEntry.transferId, 'tr-1');
    expect(d.inEntry.transferId, 'tr-1');
  });

  test('buildTransfer rejects a cross-currency transfer', () {
    final r = buildTransfer(
      from: acc(1, c: uzs, opening: 1000000),
      to: acc(2, c: usd),
      amount: const Money(300000, uzs),
      occurredAt: DateTime(2026, 7, 18),
      transferId: 'tr-2',
    );
    expect(r.isOk, isFalse);
    r.when(ok: (_) => fail('expected failure'), err: (f) => expect(f, isA<ValidationFailure>()));
  });

  test('buildTransfer rejects a non-positive amount', () {
    final r = buildTransfer(
      from: acc(1, opening: 1000000),
      to: acc(2),
      amount: const Money(0, uzs),
      occurredAt: DateTime(2026, 7, 18),
      transferId: 'tr-3',
    );
    expect(r.isOk, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/core/ledger/balance_engine_test.dart`
Expected: FAIL — `accountBalance`/`buildTransfer` not defined.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/ledger/balance_engine.dart
import '../money/money.dart';
import '../result/failure.dart';
import '../result/result.dart';
import 'account.dart';
import 'ledger_entry.dart';

Money accountBalance(Account account, Iterable<LedgerEntry> entries) {
  var total = account.openingBalance;
  for (final e in entries) {
    if (e.accountId != account.id) continue;
    total = total.add(e.amount); // same-currency; throws on mismatch
  }
  return total;
}

Money adjustmentDelta(Money currentBalance, Money realBalance) =>
    realBalance.subtract(currentBalance);

class TransferDraft {
  final LedgerEntry outEntry;
  final LedgerEntry inEntry;
  const TransferDraft(this.outEntry, this.inEntry);
}

Result<TransferDraft> buildTransfer({
  required Account from,
  required Account to,
  required Money amount,
  required DateTime occurredAt,
  required String transferId,
  String? note,
}) {
  if (from.currency != to.currency || amount.currency != from.currency) {
    return const Err(ValidationFailure('transfer currencies must match'));
  }
  if (amount.minorUnits <= 0) {
    return const Err(ValidationFailure('transfer amount must be positive'));
  }
  final out = LedgerEntry(
    id: 0,
    accountId: from.id,
    type: LedgerEntryType.transferOut,
    amount: amount.negate(),
    allocated: Money.zero(from.currency),
    occurredAt: occurredAt,
    transferId: transferId,
    note: note,
  );
  final inbound = LedgerEntry(
    id: 0,
    accountId: to.id,
    type: LedgerEntryType.transferIn,
    amount: amount,
    allocated: Money.zero(to.currency),
    occurredAt: occurredAt,
    transferId: transferId,
    note: note,
  );
  return Ok(TransferDraft(out, inbound));
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --concurrency=1 test/core/ledger/balance_engine_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/ledger/balance_engine.dart test/core/ledger/balance_engine_test.dart
git commit -m "feat: add pure balance engine (accountBalance, adjustmentDelta, buildTransfer)"
```

---

## Task 3: Summary engine (pure `core/ledger`)

**Files:**
- Create: `lib/core/ledger/summary_engine.dart`
- Test: `test/core/ledger/summary_engine_test.dart`

**Interfaces:**
- Consumes: `Account`, `LedgerEntry`, `accountBalance`, `Money`, `Currency`, `FinancialPeriod` (`lib/core/time/financial_period.dart`).
- Produces (all single-currency: entries whose `amount.currency != currency` are skipped, since there is no FX):
  - `Map<Currency, Money> totalsByCurrency(Iterable<Account> accounts, Iterable<LedgerEntry> entries)` — each account's balance, summed per currency.
  - `Money periodIncome(Iterable<LedgerEntry> entries, FinancialPeriod period, Currency currency)` — Σ positive `income` amounts in period.
  - `Money periodExpense(...)` — Σ **magnitude** of `expense` amounts in period (returned positive).
  - `Money spentOn(DateTime day, Iterable<LedgerEntry> entries, Currency currency)` — expense magnitude on that calendar day.
  - `Map<int, Money> categorySpent(Iterable<LedgerEntry> entries, FinancialPeriod period, Currency currency)` — expense magnitude per `categoryId` in period.
  - `Money undistributed(Iterable<LedgerEntry> entries, Currency currency)` — Σ (`income.amount` − `income.allocated`).

- [ ] **Step 1: Write the failing test**

```dart
// test/core/ledger/summary_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/time/financial_period.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/core/ledger/summary_engine.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  const usd = CurrencyRegistry.usd;
  final period = FinancialPeriod.containing(DateTime(2026, 7, 18), 1); // Jul 1..Aug 1

  LedgerEntry e(int accountId, LedgerEntryType type, int minor, DateTime when,
          {int? categoryId, int allocated = 0, Currency c = uzs}) =>
      LedgerEntry(
        id: 0,
        accountId: accountId,
        type: type,
        amount: Money(minor, c),
        allocated: Money(allocated, c),
        occurredAt: when,
        categoryId: categoryId,
        incomeType: type == LedgerEntryType.income ? IncomeType.salary : null,
      );

  final entries = [
    e(1, LedgerEntryType.income, 5000000, DateTime(2026, 7, 5)),
    e(1, LedgerEntryType.expense, -200000, DateTime(2026, 7, 18), categoryId: 1),
    e(1, LedgerEntryType.expense, -50000, DateTime(2026, 7, 18), categoryId: 2),
    e(1, LedgerEntryType.expense, -70000, DateTime(2026, 7, 10), categoryId: 1),
    e(1, LedgerEntryType.expense, -999, DateTime(2026, 6, 30), categoryId: 1), // prev period
    e(1, LedgerEntryType.income, -0, DateTime(2026, 7, 5), c: usd), // other currency, skipped
  ];

  test('periodIncome sums income in the period, matching currency only', () {
    expect(periodIncome(entries, period, uzs), const Money(5000000, uzs));
  });

  test('periodExpense returns positive magnitude in the period', () {
    expect(periodExpense(entries, period, uzs), const Money(320000, uzs));
  });

  test('spentOn sums a single day', () {
    expect(spentOn(DateTime(2026, 7, 18), entries, uzs), const Money(250000, uzs));
  });

  test('categorySpent groups by category within the period', () {
    final m = categorySpent(entries, period, uzs);
    expect(m[1], const Money(270000, uzs));
    expect(m[2], const Money(50000, uzs));
  });

  test('undistributed is income minus allocated', () {
    final es = [
      e(1, LedgerEntryType.income, 5000000, DateTime(2026, 7, 5), allocated: 2000000),
    ];
    expect(undistributed(es, uzs), const Money(3000000, uzs));
  });

  test('totalsByCurrency sums balances per currency', () {
    const a1 = Account(id: 1, name: 'A', type: AccountType.cash,
        openingBalance: Money(1000000, uzs), icon: 'w', archived: false);
    const a2 = Account(id: 2, name: 'B', type: AccountType.bankCard,
        openingBalance: Money(200, usd), icon: 'c', archived: false);
    final es = [
      e(1, LedgerEntryType.expense, -300000, DateTime(2026, 7, 18)),
      e(2, LedgerEntryType.income, 50, DateTime(2026, 7, 18), c: usd),
    ];
    final totals = totalsByCurrency([a1, a2], es);
    expect(totals[uzs], const Money(700000, uzs));
    expect(totals[usd], const Money(250, usd));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/core/ledger/summary_engine_test.dart`
Expected: FAIL — functions not defined.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/ledger/summary_engine.dart
import '../money/currency.dart';
import '../money/money.dart';
import '../time/financial_period.dart';
import 'account.dart';
import 'balance_engine.dart';
import 'ledger_entry.dart';

Map<Currency, Money> totalsByCurrency(
    Iterable<Account> accounts, Iterable<LedgerEntry> entries) {
  final totals = <Currency, Money>{};
  for (final a in accounts) {
    final bal = accountBalance(a, entries);
    final running = totals[a.currency];
    totals[a.currency] = running == null ? bal : running.add(bal);
  }
  return totals;
}

Money periodIncome(
    Iterable<LedgerEntry> entries, FinancialPeriod period, Currency currency) {
  var sum = 0;
  for (final e in entries) {
    if (e.type != LedgerEntryType.income) continue;
    if (e.amount.currency != currency) continue;
    if (!period.contains(e.occurredAt)) continue;
    sum += e.amount.minorUnits;
  }
  return Money(sum, currency);
}

Money periodExpense(
    Iterable<LedgerEntry> entries, FinancialPeriod period, Currency currency) {
  var sum = 0;
  for (final e in entries) {
    if (e.type != LedgerEntryType.expense) continue;
    if (e.amount.currency != currency) continue;
    if (!period.contains(e.occurredAt)) continue;
    sum += -e.amount.minorUnits; // magnitude
  }
  return Money(sum, currency);
}

Money spentOn(
    DateTime day, Iterable<LedgerEntry> entries, Currency currency) {
  var sum = 0;
  for (final e in entries) {
    if (e.type != LedgerEntryType.expense) continue;
    if (e.amount.currency != currency) continue;
    final d = e.occurredAt;
    if (d.year == day.year && d.month == day.month && d.day == day.day) {
      sum += -e.amount.minorUnits;
    }
  }
  return Money(sum, currency);
}

Map<int, Money> categorySpent(
    Iterable<LedgerEntry> entries, FinancialPeriod period, Currency currency) {
  final out = <int, Money>{};
  for (final e in entries) {
    if (e.type != LedgerEntryType.expense) continue;
    if (e.amount.currency != currency) continue;
    if (e.categoryId == null) continue;
    if (!period.contains(e.occurredAt)) continue;
    final running = out[e.categoryId!];
    final add = Money(-e.amount.minorUnits, currency);
    out[e.categoryId!] = running == null ? add : running.add(add);
  }
  return out;
}

Money undistributed(Iterable<LedgerEntry> entries, Currency currency) {
  var sum = 0;
  for (final e in entries) {
    if (e.type != LedgerEntryType.income) continue;
    if (e.amount.currency != currency) continue;
    sum += e.amount.minorUnits - e.allocated.minorUnits;
  }
  return Money(sum, currency);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --concurrency=1 test/core/ledger/summary_engine_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/ledger/summary_engine.dart test/core/ledger/summary_engine_test.dart
git commit -m "feat: add pure summary engine (totals, period income/expense, spent, undistributed)"
```

---

## Task 4: Schema v2 — tables + migration + default categories

**Files:**
- Create: `lib/data/db/default_categories.dart`
- Modify: `lib/data/db/tables.dart` (append four tables)
- Modify: `lib/data/db/app_database.dart` (register tables, `schemaVersion` -> 2)
- Modify: `lib/data/db/migrations.dart` (real v1->v2 `onUpgrade`)
- Test: `test/data/db/schema_v2_migration_test.dart`

**Interfaces:**
- Produces (Drift-generated): tables `accountsTable`, `categoriesTable`, `transactionsTable`, `recurringIncomePlansTable` with companions `AccountsTableCompanion`, `CategoriesTableCompanion`, `TransactionsTableCompanion`, `RecurringIncomePlansTableCompanion`.
- Produces: `const List<({String name, String icon})> kDefaultCategories` (13 entries, PRD §10.1) in `default_categories.dart`.
- Consumes: the Foundation's `AppDatabase`, `buildMigration`, `openAppDatabase`.

**Note on DateTime storage:** the Foundation stores `DateTimeColumn` as Unix epoch **seconds** (drift default — no `storeDateTimeAsText`). Keep that; new `DateTimeColumn`s inherit it automatically.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/db/schema_v2_migration_test.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/db/default_categories.dart';

void main() {
  test('schemaVersion is 2', () {
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 2);
    db.close();
  });

  test('fresh open seeds the 13 default categories and creates all tables',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    final cats = await db.select(db.categoriesTable).get();
    expect(cats.length, kDefaultCategories.length);
    expect(cats.length, 13);
    expect(cats.every((c) => c.isDefault), isTrue);

    // All four new tables are queryable (no exception thrown).
    expect(await db.select(db.accountsTable).get(), isEmpty);
    expect(await db.select(db.transactionsTable).get(), isEmpty);
    expect(await db.select(db.recurringIncomePlansTable).get(), isEmpty);
    await db.close();
  });

  test('an account row inserts and reads back', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final id = await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(
            name: 'Naqd',
            type: 'cash',
            openingBalanceMinor: const Value(500000),
            currencyCode: const Value('UZS'),
            icon: const Value('wallet'),
          ),
        );
    final row = await (db.select(db.accountsTable)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    expect(row.name, 'Naqd');
    expect(row.openingBalanceMinor, 500000);
    await db.close();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/data/db/schema_v2_migration_test.dart`
Expected: FAIL — `categoriesTable`/`accountsTable` getters and `kDefaultCategories` do not exist / `schemaVersion` is 1.

- [ ] **Step 3: Write the implementation**

Create the default-category seeds:

```dart
// lib/data/db/default_categories.dart
/// The MVP standard categories (PRD §10.1), seeded on first install / upgrade.
const List<({String name, String icon})> kDefaultCategories = [
  (name: 'Oziq-ovqat', icon: 'restaurant'),
  (name: 'Transport', icon: 'directions_car'),
  (name: 'Uy', icon: 'home'),
  (name: 'Kommunal to\'lovlar', icon: 'bolt'),
  (name: 'Sog\'liq', icon: 'favorite'),
  (name: 'Ta\'lim', icon: 'school'),
  (name: 'Kiyim', icon: 'checkroom'),
  (name: 'Ko\'ngilochar', icon: 'movie'),
  (name: 'Restoran va yetkazib berish', icon: 'fastfood'),
  (name: 'Obunalar', icon: 'subscriptions'),
  (name: 'Sovg\'alar', icon: 'card_giftcard'),
  (name: 'Sayohat', icon: 'flight'),
  (name: 'Boshqa', icon: 'category'),
];
```

Append the four tables to `lib/data/db/tables.dart` (keep the existing `AppSettingsTable`/`AppMetaTable`):

```dart
class AccountsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // AccountType.name
  IntColumn get openingBalanceMinor => integer().withDefault(const Constant(0))();
  TextColumn get currencyCode => text().withDefault(const Constant('UZS'))();
  TextColumn get icon => text().withDefault(const Constant('wallet'))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
}

class CategoriesTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(const Constant('category'))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class TransactionsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId =>
      integer().references(AccountsTable, #id)();
  TextColumn get type => text()(); // LedgerEntryType.name
  IntColumn get amountMinor => integer()(); // signed
  TextColumn get currencyCode => text()();
  IntColumn get categoryId =>
      integer().nullable().references(CategoriesTable, #id)();
  TextColumn get incomeType => text().nullable()(); // IncomeType.name
  TextColumn get transferId => text().nullable()();
  IntColumn get allocatedMinor => integer().withDefault(const Constant(0))();
  BoolColumn get planned => boolean().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
}

class RecurringIncomePlansTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(AccountsTable, #id)();
  IntColumn get amountMinor => integer()();
  TextColumn get currencyCode => text()();
  TextColumn get incomeType => text()();
  TextColumn get note => text().nullable()();
  TextColumn get intervalKind => text()(); // IntervalKind.name
  IntColumn get anchorDay => integer()();
  DateTimeColumn get nextDueAt => dateTime()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}
```

Register the tables and bump the version in `lib/data/db/app_database.dart`:

```dart
@DriftDatabase(tables: [
  AppSettingsTable,
  AppMetaTable,
  AccountsTable,
  CategoriesTable,
  TransactionsTable,
  RecurringIncomePlansTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => buildMigration(this);
}
```

Replace `onCreate`/`onUpgrade` in `lib/data/db/migrations.dart` so both fresh installs and upgrades seed the categories and create the v2 tables:

```dart
import 'package:drift/drift.dart';
import 'app_database.dart';
import 'default_categories.dart';

MigrationStrategy buildMigration(AppDatabase db) => MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await db.into(db.appMetaTable).insert(
              AppMetaTableCompanion.insert(
                id: const Value(0),
                installedAt: DateTime.now(),
              ),
            );
        await db
            .into(db.appSettingsTable)
            .insert(const AppSettingsTableCompanion(id: Value(0)));
        await _seedDefaultCategories(db);
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // v1 -> v2: add the accounts/ledger/categories/recurring tables.
          // `createTable` works without the drift schema CLI (only
          // `stepByStep` needs it), so we create each new table explicitly.
          await m.createTable(db.accountsTable);
          await m.createTable(db.categoriesTable);
          await m.createTable(db.transactionsTable);
          await m.createTable(db.recurringIncomePlansTable);
          await _seedDefaultCategories(db);
        }
      },
      beforeOpen: (details) async {
        await db.customStatement('PRAGMA foreign_keys = ON');
      },
    );

Future<void> _seedDefaultCategories(AppDatabase db) async {
  for (var i = 0; i < kDefaultCategories.length; i++) {
    final c = kDefaultCategories[i];
    await db.into(db.categoriesTable).insert(
          CategoriesTableCompanion.insert(
            name: c.name,
            icon: Value(c.icon),
            isDefault: const Value(true),
            sortOrder: Value(i),
          ),
        );
  }
}
```

- [ ] **Step 4: Regenerate Drift code, then run the test**

Run: `dart run build_runner build --delete-conflicting-outputs`
Then: `flutter test --concurrency=1 test/data/db/schema_v2_migration_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/db/tables.dart lib/data/db/app_database.dart lib/data/db/migrations.dart lib/data/db/default_categories.dart test/data/db/schema_v2_migration_test.dart
git commit -m "feat: add schema v2 (accounts, categories, transactions, recurring) + migration"
```

---

## Task 5: §20.3 — data intact after a FAILED migration

The Foundation deferred this test until the first schema-v2 sub-project. It lands here. We add a small injectable seam to `openAppDatabase` so a test can force a migration to throw, then assert the pre-upgrade snapshot is restored and the user's data survives.

**Files:**
- Modify: `lib/data/db/db_open.dart` (add an `open` factory parameter, default = real)
- Test: `test/data/db/migration_recovery_test.dart`

**Interfaces:**
- Produces: `Future<Result<AppDatabase>> openAppDatabase({required String dbPath, AppDatabase Function(QueryExecutor executor) open})` — `open` defaults to `AppDatabase.new`.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/db/migration_recovery_test.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/db/db_open.dart';
import 'package:financial_assistant/data/settings/settings_repository.dart';
import 'package:financial_assistant/data/settings/settings_model.dart';
import 'package:financial_assistant/core/money/currency.dart';

/// A database that pretends to be one version newer and always fails to
/// upgrade — used to exercise the recovery path against a real on-disk file.
class _FailingUpgradeDb extends AppDatabase {
  _FailingUpgradeDb(super.e);
  @override
  int get schemaVersion => 3;
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async => throw Exception('boom'),
        beforeOpen: (d) async =>
            customStatement('PRAGMA foreign_keys = ON'),
      );
}

void main() {
  test('a failed migration restores the snapshot; the user\'s data survives',
      () async {
    final tmp = await Directory.systemTemp.createTemp('mig');
    final dbPath = '${tmp.path}/app.db';

    // 1. Create a real v2 db and store some user data.
    final first = await openAppDatabase(dbPath: dbPath);
    expect(first.isOk, isTrue);
    final db1 = first.valueOrNull!;
    await DriftSettingsRepository(db1).write(
      AppSettings(
        name: 'Ali',
        primaryCurrency: CurrencyRegistry.uzs,
        dateFormat: 'dd.MM.yyyy',
        periodStartDay: 1,
        weekStartIso: 1,
        dailyLimitMethod: DailyLimitMethod.evenSplit,
        minReserve: const Money(0, CurrencyRegistry.uzs),
        themeMode: ThemeModeSetting.system,
        appLockEnabled: false,
        biometricEnabled: false,
        savingsRolloverMode: SavingsRolloverMode.askEachTime,
      ),
    );
    await db1.close();

    // 2. Reopen with a factory whose 2->3 migration throws.
    final failed =
        await openAppDatabase(dbPath: dbPath, open: _FailingUpgradeDb.new);
    expect(failed.isOk, isFalse);

    // 3. Reopen normally: the restored snapshot means data is intact.
    final recovered = await openAppDatabase(dbPath: dbPath);
    expect(recovered.isOk, isTrue);
    final db3 = recovered.valueOrNull!;
    final settings = await DriftSettingsRepository(db3).read();
    expect(settings.name, 'Ali');
    await db3.close();

    await tmp.delete(recursive: true);
  });
}
```

Note: the test imports `Money` via `settings_model.dart`'s re-exported types; if `Money` is not in scope, add `import 'package:financial_assistant/core/money/money.dart';`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/data/db/migration_recovery_test.dart`
Expected: FAIL — `openAppDatabase` has no `open` parameter.

- [ ] **Step 3: Add the injectable seam**

```dart
// lib/data/db/db_open.dart — modify the signature and the construction line
Future<Result<AppDatabase>> openAppDatabase({
  required String dbPath,
  AppDatabase Function(QueryExecutor executor) open = AppDatabase.new,
}) async {
  String? snapshot;
  AppDatabase? db;
  try {
    snapshot = await snapshotDatabase(dbPath);
    db = open(NativeDatabase(File(dbPath)));
    await db.customSelect('SELECT * FROM app_meta_table').get();
    await discardSnapshot(dbPath);
    return Ok(db);
  } catch (e) {
    // ... unchanged catch body ...
  }
}
```

Keep the rest of the file (imports, catch body) exactly as-is. Add `import 'package:drift/drift.dart';` if `QueryExecutor` is not already imported (the file currently imports `package:drift/native.dart`; `QueryExecutor` comes from `package:drift/drift.dart`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --concurrency=1 test/data/db/migration_recovery_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/data/db/db_open.dart test/data/db/migration_recovery_test.dart
git commit -m "test: verify data survives a failed migration (PRD §20.3) via injectable open"
```

---

## Task 6: AccountRepository

**Files:**
- Create: `lib/data/accounts/account_repository.dart`
- Test: `test/data/accounts/account_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `AccountsTableCompanion`, `Account`/`AccountType` (core), `Money`, `CurrencyRegistry`.
- Produces:
  - `abstract class AccountRepository`:
    - `Future<int> create({required String name, required AccountType type, required Money openingBalance, required String icon})`
    - `Future<void> rename(int id, String name)`
    - `Future<void> setIcon(int id, String icon)`
    - `Future<void> setArchived(int id, bool archived)`
    - `Future<void> reorder(List<int> orderedIds)`
    - `Future<List<Account>> list({bool includeArchived = false})`
    - `Future<Account?> byId(int id)`
  - `class DriftAccountRepository implements AccountRepository`.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/accounts/account_repository_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/accounts/account_repository.dart';

void main() {
  late AppDatabase db;
  late AccountRepository repo;
  const uzs = CurrencyRegistry.uzs;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftAccountRepository(db);
  });
  tearDown(() => db.close());

  test('create then read back a domain Account', () async {
    final id = await repo.create(
        name: 'Naqd',
        type: AccountType.cash,
        openingBalance: const Money(500000, uzs),
        icon: 'wallet');
    final a = await repo.byId(id);
    expect(a, isNotNull);
    expect(a!.name, 'Naqd');
    expect(a.type, AccountType.cash);
    expect(a.openingBalance, const Money(500000, uzs));
    expect(a.currency, uzs);
    expect(a.archived, isFalse);
  });

  test('list hides archived unless asked', () async {
    final a = await repo.create(
        name: 'A', type: AccountType.cash, openingBalance: const Money(0, uzs), icon: 'w');
    await repo.create(
        name: 'B', type: AccountType.bankCard, openingBalance: const Money(0, uzs), icon: 'c');
    await repo.setArchived(a, true);
    expect((await repo.list()).length, 1);
    expect((await repo.list(includeArchived: true)).length, 2);
  });

  test('reorder assigns sortOrder in the given order', () async {
    final a = await repo.create(name: 'A', type: AccountType.cash, openingBalance: const Money(0, uzs), icon: 'w');
    final b = await repo.create(name: 'B', type: AccountType.cash, openingBalance: const Money(0, uzs), icon: 'w');
    await repo.reorder([b, a]);
    final names = (await repo.list()).map((e) => e.name).toList();
    expect(names, ['B', 'A']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/data/accounts/account_repository_test.dart`
Expected: FAIL — `AccountRepository` not defined.

- [ ] **Step 3: Write the implementation**

```dart
// lib/data/accounts/account_repository.dart
import 'package:drift/drift.dart';
import '../../core/ledger/account.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../db/app_database.dart';

abstract class AccountRepository {
  Future<int> create({
    required String name,
    required AccountType type,
    required Money openingBalance,
    required String icon,
  });
  Future<void> rename(int id, String name);
  Future<void> setIcon(int id, String icon);
  Future<void> setArchived(int id, bool archived);
  Future<void> reorder(List<int> orderedIds);
  Future<List<Account>> list({bool includeArchived = false});
  Future<Account?> byId(int id);
}

class DriftAccountRepository implements AccountRepository {
  final AppDatabase db;
  DriftAccountRepository(this.db);

  Account _map(dynamic r) => Account(
        id: r.id as int,
        name: r.name as String,
        type: AccountType.values.byName(r.type as String),
        openingBalance: Money(
          r.openingBalanceMinor as int,
          CurrencyRegistry.byCode(r.currencyCode as String),
        ),
        icon: r.icon as String,
        archived: r.archived as bool,
      );

  @override
  Future<int> create({
    required String name,
    required AccountType type,
    required Money openingBalance,
    required String icon,
  }) {
    return db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(
            name: name,
            type: type.name,
            openingBalanceMinor: Value(openingBalance.minorUnits),
            currencyCode: Value(openingBalance.currency.code),
            icon: Value(icon),
            createdAt: DateTime.now(),
          ),
        );
  }

  @override
  Future<void> rename(int id, String name) async {
    await (db.update(db.accountsTable)..where((t) => t.id.equals(id)))
        .write(AccountsTableCompanion(name: Value(name)));
  }

  @override
  Future<void> setIcon(int id, String icon) async {
    await (db.update(db.accountsTable)..where((t) => t.id.equals(id)))
        .write(AccountsTableCompanion(icon: Value(icon)));
  }

  @override
  Future<void> setArchived(int id, bool archived) async {
    await (db.update(db.accountsTable)..where((t) => t.id.equals(id)))
        .write(AccountsTableCompanion(archived: Value(archived)));
  }

  @override
  Future<void> reorder(List<int> orderedIds) async {
    await db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (db.update(db.accountsTable)
              ..where((t) => t.id.equals(orderedIds[i])))
            .write(AccountsTableCompanion(sortOrder: Value(i)));
      }
    });
  }

  @override
  Future<List<Account>> list({bool includeArchived = false}) async {
    final q = db.select(db.accountsTable)
      ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
    if (!includeArchived) q.where((t) => t.archived.equals(false));
    final rows = await q.get();
    return rows.map(_map).toList();
  }

  @override
  Future<Account?> byId(int id) async {
    final row = await (db.select(db.accountsTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _map(row);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --concurrency=1 test/data/accounts/account_repository_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/accounts/account_repository.dart test/data/accounts/account_repository_test.dart
git commit -m "feat: add AccountRepository (create, archive, reorder, list)"
```

---

## Task 7: CategoryRepository

**Files:**
- Create: `lib/data/categories/category_model.dart`
- Create: `lib/data/categories/category_repository.dart`
- Test: `test/data/categories/category_repository_test.dart`

**Interfaces:**
- Produces:
  - `class Category { int id; String name; String icon; bool isDefault; bool archived; }`
  - `abstract class CategoryRepository`:
    - `Future<int> create({required String name, required String icon})`
    - `Future<void> rename(int id, String name)`
    - `Future<void> setIcon(int id, String icon)`
    - `Future<void> setArchived(int id, bool archived)`
    - `Future<void> reorder(List<int> orderedIds)`
    - `Future<List<Category>> list({bool includeArchived = false})`
  - `class DriftCategoryRepository implements CategoryRepository`.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/categories/category_repository_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/categories/category_repository.dart';

void main() {
  late AppDatabase db;
  late CategoryRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftCategoryRepository(db);
  });
  tearDown(() => db.close());

  test('the 13 defaults are present and flagged isDefault', () async {
    final cats = await repo.list();
    expect(cats.length, 13);
    expect(cats.where((c) => c.isDefault).length, 13);
  });

  test('create, rename, and archive a custom category', () async {
    final id = await repo.create(name: 'Xayriya', icon: 'volunteer_activism');
    await repo.rename(id, 'Ehson');
    await repo.setArchived(id, true);
    final all = await repo.list(includeArchived: true);
    final mine = all.firstWhere((c) => c.id == id);
    expect(mine.name, 'Ehson');
    expect(mine.archived, isTrue);
    expect(mine.isDefault, isFalse);
    // archived categories are hidden from the default list (PRD §10.2)
    expect((await repo.list()).any((c) => c.id == id), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/data/categories/category_repository_test.dart`
Expected: FAIL — `CategoryRepository` not defined.

- [ ] **Step 3: Write the implementation**

```dart
// lib/data/categories/category_model.dart
class Category {
  final int id;
  final String name;
  final String icon;
  final bool isDefault;
  final bool archived;
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.isDefault,
    required this.archived,
  });
}
```

```dart
// lib/data/categories/category_repository.dart
import 'package:drift/drift.dart';
import '../db/app_database.dart';
import 'category_model.dart';

abstract class CategoryRepository {
  Future<int> create({required String name, required String icon});
  Future<void> rename(int id, String name);
  Future<void> setIcon(int id, String icon);
  Future<void> setArchived(int id, bool archived);
  Future<void> reorder(List<int> orderedIds);
  Future<List<Category>> list({bool includeArchived = false});
}

class DriftCategoryRepository implements CategoryRepository {
  final AppDatabase db;
  DriftCategoryRepository(this.db);

  Category _map(dynamic r) => Category(
        id: r.id as int,
        name: r.name as String,
        icon: r.icon as String,
        isDefault: r.isDefault as bool,
        archived: r.archived as bool,
      );

  @override
  Future<int> create({required String name, required String icon}) {
    return db.into(db.categoriesTable).insert(
          CategoriesTableCompanion.insert(name: name, icon: Value(icon)),
        );
  }

  @override
  Future<void> rename(int id, String name) async {
    await (db.update(db.categoriesTable)..where((t) => t.id.equals(id)))
        .write(CategoriesTableCompanion(name: Value(name)));
  }

  @override
  Future<void> setIcon(int id, String icon) async {
    await (db.update(db.categoriesTable)..where((t) => t.id.equals(id)))
        .write(CategoriesTableCompanion(icon: Value(icon)));
  }

  @override
  Future<void> setArchived(int id, bool archived) async {
    await (db.update(db.categoriesTable)..where((t) => t.id.equals(id)))
        .write(CategoriesTableCompanion(archived: Value(archived)));
  }

  @override
  Future<void> reorder(List<int> orderedIds) async {
    await db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (db.update(db.categoriesTable)
              ..where((t) => t.id.equals(orderedIds[i])))
            .write(CategoriesTableCompanion(sortOrder: Value(i)));
      }
    });
  }

  @override
  Future<List<Category>> list({bool includeArchived = false}) async {
    final q = db.select(db.categoriesTable)
      ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
    if (!includeArchived) q.where((t) => t.archived.equals(false));
    final rows = await q.get();
    return rows.map(_map).toList();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --concurrency=1 test/data/categories/category_repository_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/categories/category_model.dart lib/data/categories/category_repository.dart test/data/categories/category_repository_test.dart
git commit -m "feat: add CategoryRepository (defaults, CRUD, archive-not-delete)"
```

---

## Task 8: LedgerRepository (the core write/read surface)

**Files:**
- Create: `lib/data/ledger/ledger_repository.dart`
- Test: `test/data/ledger/ledger_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `TransactionsTableCompanion`, `AccountRepository`, `LedgerEntry`/`LedgerEntryType`/`IncomeType`, `buildTransfer`, `accountBalance`, `adjustmentDelta`, `Money`, `Result`/`Failure`.
- Produces:
  - `abstract class LedgerRepository`:
    - `Future<int> addExpense({required int accountId, required Money amount /* positive magnitude */, int? categoryId, required DateTime occurredAt, String? note, bool? planned})`
    - `Future<int> addIncome({required int accountId, required Money amount, required IncomeType incomeType, required DateTime occurredAt, String? note})`
    - `Future<Result<void>> transfer({required int fromId, required int toId, required Money amount, required DateTime occurredAt, String? note})`
    - `Future<void> adjustBalance({required int accountId, required Money realBalance, required DateTime occurredAt, String? note})`
    - `Future<Result<void>> editEntry({required int id, Money? amount, int? categoryId, DateTime? occurredAt, String? note})`
    - `Future<void> deleteEntry(int id)`  // deletes both legs of a transfer
    - `Future<List<LedgerEntry>> entriesForAccount(int accountId)`
    - `Future<List<LedgerEntry>> entriesInPeriod(DateTime start, DateTime endExclusive)`
    - `Future<List<LedgerEntry>> allEntries()`
  - `class DriftLedgerRepository implements LedgerRepository` — constructor `DriftLedgerRepository(this.db, this.accounts)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/ledger/ledger_repository_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/core/ledger/balance_engine.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/accounts/account_repository.dart';
import 'package:financial_assistant/data/ledger/ledger_repository.dart';

void main() {
  late AppDatabase db;
  late AccountRepository accounts;
  late LedgerRepository ledger;
  const uzs = CurrencyRegistry.uzs;
  final when = DateTime(2026, 7, 18, 9);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    accounts = DriftAccountRepository(db);
    ledger = DriftLedgerRepository(db, accounts);
  });
  tearDown(() => db.close());

  Future<int> newAccount({int opening = 0}) => accounts.create(
      name: 'A', type: AccountType.cash,
      openingBalance: Money(opening, uzs), icon: 'w');

  Future<Money> balanceOf(int id) async =>
      accountBalance((await accounts.byId(id))!, await ledger.entriesForAccount(id));

  test('expense is stored negative and lowers the balance', () async {
    final a = await newAccount(opening: 1000000);
    await ledger.addExpense(accountId: a, amount: const Money(250000, uzs), categoryId: 1, occurredAt: when);
    expect(await balanceOf(a), const Money(750000, uzs));
    final es = await ledger.entriesForAccount(a);
    expect(es.single.amount, const Money(-250000, uzs));
    expect(es.single.type, LedgerEntryType.expense);
  });

  test('income is stored positive with allocated 0', () async {
    final a = await newAccount();
    await ledger.addIncome(accountId: a, amount: const Money(5000000, uzs), incomeType: IncomeType.salary, occurredAt: when);
    final e = (await ledger.entriesForAccount(a)).single;
    expect(e.amount, const Money(5000000, uzs));
    expect(e.allocated, const Money(0, uzs));
    expect(e.incomeType, IncomeType.salary);
  });

  test('transfer writes a linked pair and preserves the total', () async {
    final a = await newAccount(opening: 1000000);
    final b = await newAccount();
    final r = await ledger.transfer(fromId: a, toId: b, amount: const Money(300000, uzs), occurredAt: when);
    expect(r.isOk, isTrue);
    expect(await balanceOf(a), const Money(700000, uzs));
    expect(await balanceOf(b), const Money(300000, uzs));
    final legs = await ledger.allEntries();
    expect(legs.length, 2);
    expect(legs[0].transferId, isNotNull);
    expect(legs[0].transferId, legs[1].transferId);
  });

  test('cross-currency transfer is rejected and writes nothing', () async {
    final a = await newAccount(opening: 1000000); // UZS
    final b = await accounts.create(name: 'USD', type: AccountType.bankCard, openingBalance: const Money(0, CurrencyRegistry.usd), icon: 'c');
    final r = await ledger.transfer(fromId: a, toId: b, amount: const Money(300000, uzs), occurredAt: when);
    expect(r.isOk, isFalse);
    expect(await ledger.allEntries(), isEmpty);
  });

  test('adjustBalance records the delta so the balance equals the real value', () async {
    final a = await newAccount(opening: 1000000);
    await ledger.adjustBalance(accountId: a, realBalance: const Money(950000, uzs), occurredAt: when);
    expect(await balanceOf(a), const Money(950000, uzs));
    final e = (await ledger.entriesForAccount(a)).single;
    expect(e.type, LedgerEntryType.adjustment);
    expect(e.amount, const Money(-50000, uzs));
  });

  test('deleting a transfer leg removes both legs', () async {
    final a = await newAccount(opening: 1000000);
    final b = await newAccount();
    await ledger.transfer(fromId: a, toId: b, amount: const Money(300000, uzs), occurredAt: when);
    final legs = await ledger.allEntries();
    await ledger.deleteEntry(legs.first.id);
    expect(await ledger.allEntries(), isEmpty);
  });

  test('editing an expense recomputes the balance', () async {
    final a = await newAccount(opening: 1000000);
    final id = await ledger.addExpense(accountId: a, amount: const Money(250000, uzs), categoryId: 1, occurredAt: when);
    final r = await ledger.editEntry(id: id, amount: const Money(100000, uzs));
    expect(r.isOk, isTrue);
    expect(await balanceOf(a), const Money(900000, uzs));
  });

  test('editing a transfer leg is rejected', () async {
    final a = await newAccount(opening: 1000000);
    final b = await newAccount();
    await ledger.transfer(fromId: a, toId: b, amount: const Money(300000, uzs), occurredAt: when);
    final leg = (await ledger.allEntries()).first;
    final r = await ledger.editEntry(id: leg.id, amount: const Money(1, uzs));
    expect(r.isOk, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/data/ledger/ledger_repository_test.dart`
Expected: FAIL — `LedgerRepository` not defined.

- [ ] **Step 3: Write the implementation**

```dart
// lib/data/ledger/ledger_repository.dart
import 'package:drift/drift.dart';
import '../../core/ledger/account.dart';
import '../../core/ledger/balance_engine.dart';
import '../../core/ledger/ledger_entry.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/result/failure.dart';
import '../../core/result/result.dart';
import '../accounts/account_repository.dart';
import '../db/app_database.dart';

abstract class LedgerRepository {
  Future<int> addExpense({
    required int accountId,
    required Money amount,
    int? categoryId,
    required DateTime occurredAt,
    String? note,
    bool? planned,
  });
  Future<int> addIncome({
    required int accountId,
    required Money amount,
    required IncomeType incomeType,
    required DateTime occurredAt,
    String? note,
  });
  Future<Result<void>> transfer({
    required int fromId,
    required int toId,
    required Money amount,
    required DateTime occurredAt,
    String? note,
  });
  Future<void> adjustBalance({
    required int accountId,
    required Money realBalance,
    required DateTime occurredAt,
    String? note,
  });
  Future<Result<void>> editEntry({
    required int id,
    Money? amount,
    int? categoryId,
    DateTime? occurredAt,
    String? note,
  });
  Future<void> deleteEntry(int id);
  Future<List<LedgerEntry>> entriesForAccount(int accountId);
  Future<List<LedgerEntry>> entriesInPeriod(DateTime start, DateTime endExclusive);
  Future<List<LedgerEntry>> allEntries();
}

class DriftLedgerRepository implements LedgerRepository {
  final AppDatabase db;
  final AccountRepository accounts;
  DriftLedgerRepository(this.db, this.accounts);

  LedgerEntry _map(dynamic r) {
    final currency = CurrencyRegistry.byCode(r.currencyCode as String);
    return LedgerEntry(
      id: r.id as int,
      accountId: r.accountId as int,
      type: LedgerEntryType.values.byName(r.type as String),
      amount: Money(r.amountMinor as int, currency),
      categoryId: r.categoryId as int?,
      incomeType: (r.incomeType as String?) == null
          ? null
          : IncomeType.values.byName(r.incomeType as String),
      transferId: r.transferId as String?,
      allocated: Money(r.allocatedMinor as int, currency),
      planned: r.planned as bool?,
      occurredAt: r.occurredAt as DateTime,
      note: r.note as String?,
    );
  }

  @override
  Future<int> addExpense({
    required int accountId,
    required Money amount,
    int? categoryId,
    required DateTime occurredAt,
    String? note,
    bool? planned,
  }) {
    return db.into(db.transactionsTable).insert(
          TransactionsTableCompanion.insert(
            accountId: accountId,
            type: LedgerEntryType.expense.name,
            amountMinor: -amount.minorUnits,
            currencyCode: amount.currency.code,
            categoryId: Value(categoryId),
            planned: Value(planned),
            note: Value(note),
            occurredAt: occurredAt,
            createdAt: DateTime.now(),
          ),
        );
  }

  @override
  Future<int> addIncome({
    required int accountId,
    required Money amount,
    required IncomeType incomeType,
    required DateTime occurredAt,
    String? note,
  }) {
    return db.into(db.transactionsTable).insert(
          TransactionsTableCompanion.insert(
            accountId: accountId,
            type: LedgerEntryType.income.name,
            amountMinor: amount.minorUnits,
            currencyCode: amount.currency.code,
            incomeType: Value(incomeType.name),
            note: Value(note),
            occurredAt: occurredAt,
            createdAt: DateTime.now(),
          ),
        );
  }

  @override
  Future<Result<void>> transfer({
    required int fromId,
    required int toId,
    required Money amount,
    required DateTime occurredAt,
    String? note,
  }) async {
    final from = await accounts.byId(fromId);
    final to = await accounts.byId(toId);
    if (from == null || to == null) {
      return const Err(NotFoundFailure('account not found'));
    }
    final transferId = 'transfer-${DateTime.now().microsecondsSinceEpoch}';
    final draft = buildTransfer(
      from: from,
      to: to,
      amount: amount,
      occurredAt: occurredAt,
      transferId: transferId,
      note: note,
    );
    return draft.when(
      err: (f) async => Err<void>(f),
      ok: (d) async {
        await db.transaction(() async {
          await _insertDraft(d.outEntry);
          await _insertDraft(d.inEntry);
        });
        return const Ok(null);
      },
    );
  }

  Future<void> _insertDraft(LedgerEntry e) {
    return db.into(db.transactionsTable).insert(
          TransactionsTableCompanion.insert(
            accountId: e.accountId,
            type: e.type.name,
            amountMinor: e.amount.minorUnits,
            currencyCode: e.amount.currency.code,
            transferId: Value(e.transferId),
            note: Value(e.note),
            occurredAt: e.occurredAt,
            createdAt: DateTime.now(),
          ),
        );
  }

  @override
  Future<void> adjustBalance({
    required int accountId,
    required Money realBalance,
    required DateTime occurredAt,
    String? note,
  }) async {
    final account = await accounts.byId(accountId);
    if (account == null) return;
    final current = accountBalance(account, await entriesForAccount(accountId));
    final delta = adjustmentDelta(current, realBalance);
    await db.into(db.transactionsTable).insert(
          TransactionsTableCompanion.insert(
            accountId: accountId,
            type: LedgerEntryType.adjustment.name,
            amountMinor: delta.minorUnits,
            currencyCode: delta.currency.code,
            note: Value(note),
            occurredAt: occurredAt,
            createdAt: DateTime.now(),
          ),
        );
  }

  @override
  Future<Result<void>> editEntry({
    required int id,
    Money? amount,
    int? categoryId,
    DateTime? occurredAt,
    String? note,
  }) async {
    final row = await (db.select(db.transactionsTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return const Err(NotFoundFailure('entry not found'));
    final entry = _map(row);
    if (entry.type == LedgerEntryType.transferOut ||
        entry.type == LedgerEntryType.transferIn) {
      return const Err(
          ValidationFailure('edit a transfer by deleting and re-creating it'));
    }
    int? newMinor;
    if (amount != null) {
      newMinor = entry.type == LedgerEntryType.expense
          ? -amount.minorUnits
          : amount.minorUnits;
    }
    await (db.update(db.transactionsTable)..where((t) => t.id.equals(id)))
        .write(TransactionsTableCompanion(
      amountMinor: newMinor == null ? const Value.absent() : Value(newMinor),
      categoryId: categoryId == null ? const Value.absent() : Value(categoryId),
      occurredAt:
          occurredAt == null ? const Value.absent() : Value(occurredAt),
      note: note == null ? const Value.absent() : Value(note),
    ));
    return const Ok(null);
  }

  @override
  Future<void> deleteEntry(int id) async {
    final row = await (db.select(db.transactionsTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    final transferId = row.transferId as String?;
    if (transferId != null) {
      await (db.delete(db.transactionsTable)
            ..where((t) => t.transferId.equals(transferId)))
          .go();
    } else {
      await (db.delete(db.transactionsTable)..where((t) => t.id.equals(id)))
          .go();
    }
  }

  @override
  Future<List<LedgerEntry>> entriesForAccount(int accountId) async {
    final rows = await (db.select(db.transactionsTable)
          ..where((t) => t.accountId.equals(accountId)))
        .get();
    return rows.map(_map).toList();
  }

  @override
  Future<List<LedgerEntry>> entriesInPeriod(
      DateTime start, DateTime endExclusive) async {
    final rows = await (db.select(db.transactionsTable)
          ..where((t) =>
              t.occurredAt.isBiggerOrEqualValue(start) &
              t.occurredAt.isSmallerThanValue(endExclusive)))
        .get();
    return rows.map(_map).toList();
  }

  @override
  Future<List<LedgerEntry>> allEntries() async {
    final rows = await (db.select(db.transactionsTable)
          ..orderBy([(t) => OrderingTerm(expression: t.id)]))
        .get();
    return rows.map(_map).toList();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --concurrency=1 test/data/ledger/ledger_repository_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/ledger/ledger_repository.dart test/data/ledger/ledger_repository_test.dart
git commit -m "feat: add LedgerRepository (expense, income, transfer, adjust, edit, delete)"
```

---

## Task 9: RecurringIncomeRepository (full recurring, §7.3)

**Files:**
- Create: `lib/data/recurring/recurring_model.dart`
- Create: `lib/data/recurring/recurring_repository.dart`
- Test: `test/data/recurring/recurring_repository_test.dart`

**Interfaces:**
- Produces:
  - `enum IntervalKind { monthly, weekly }`
  - `class RecurringIncomePlan { int id; int accountId; Money amount; IncomeType incomeType; String? note; IntervalKind intervalKind; int anchorDay; DateTime nextDueAt; bool active; }`
  - `DateTime nextRecurringDate(DateTime after, IntervalKind kind, int anchorDay)` — pure: the next occurrence strictly after `after`.
  - `abstract class RecurringIncomeRepository`:
    - `Future<int> create({required int accountId, required Money amount, required IncomeType incomeType, String? note, required IntervalKind intervalKind, required int anchorDay, required DateTime nextDueAt})`
    - `Future<List<RecurringIncomePlan>> listActive()`
    - `Future<List<RecurringIncomePlan>> duePlans(DateTime asOf)`
    - `Future<void> markConfirmed(int id)`  // advances nextDueAt to the next occurrence
    - `Future<void> deactivate(int id)`
  - `class DriftRecurringIncomeRepository implements RecurringIncomeRepository`.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/recurring/recurring_repository_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/recurring/recurring_model.dart';
import 'package:financial_assistant/data/recurring/recurring_repository.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  group('nextRecurringDate', () {
    test('monthly rolls to the anchor day of the next month', () {
      expect(nextRecurringDate(DateTime(2026, 7, 5), IntervalKind.monthly, 5),
          DateTime(2026, 8, 5));
    });
    test('monthly clamps a too-large anchor day to month end', () {
      expect(nextRecurringDate(DateTime(2026, 1, 31), IntervalKind.monthly, 31),
          DateTime(2026, 2, 28));
    });
    test('weekly advances seven days', () {
      expect(nextRecurringDate(DateTime(2026, 7, 5), IntervalKind.weekly, 7),
          DateTime(2026, 7, 12));
    });
  });

  group('repository', () {
    late AppDatabase db;
    late RecurringIncomeRepository repo;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = DriftRecurringIncomeRepository(db);
    });
    tearDown(() => db.close());

    test('due plans are those with nextDueAt at or before now', () async {
      await repo.create(accountId: 1, amount: const Money(5000000, uzs), incomeType: IncomeType.salary, intervalKind: IntervalKind.monthly, anchorDay: 5, nextDueAt: DateTime(2026, 7, 5));
      await repo.create(accountId: 1, amount: const Money(1000000, uzs), incomeType: IncomeType.bonus, intervalKind: IntervalKind.monthly, anchorDay: 20, nextDueAt: DateTime(2026, 8, 20));
      final due = await repo.duePlans(DateTime(2026, 7, 10));
      expect(due.length, 1);
      expect(due.single.amount, const Money(5000000, uzs));
    });

    test('markConfirmed advances nextDueAt to the next occurrence', () async {
      final id = await repo.create(accountId: 1, amount: const Money(5000000, uzs), incomeType: IncomeType.salary, intervalKind: IntervalKind.monthly, anchorDay: 5, nextDueAt: DateTime(2026, 7, 5));
      await repo.markConfirmed(id);
      final due = await repo.duePlans(DateTime(2026, 7, 10));
      expect(due, isEmpty); // now due Aug 5
      final active = await repo.listActive();
      expect(active.single.nextDueAt, DateTime(2026, 8, 5));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/data/recurring/recurring_repository_test.dart`
Expected: FAIL — symbols not defined.

- [ ] **Step 3: Write the implementation**

```dart
// lib/data/recurring/recurring_model.dart
import '../../core/ledger/ledger_entry.dart';
import '../../core/money/money.dart';

enum IntervalKind { monthly, weekly }

class RecurringIncomePlan {
  final int id;
  final int accountId;
  final Money amount;
  final IncomeType incomeType;
  final String? note;
  final IntervalKind intervalKind;
  final int anchorDay;
  final DateTime nextDueAt;
  final bool active;
  const RecurringIncomePlan({
    required this.id,
    required this.accountId,
    required this.amount,
    required this.incomeType,
    required this.note,
    required this.intervalKind,
    required this.anchorDay,
    required this.nextDueAt,
    required this.active,
  });
}

/// The next occurrence strictly after [after]. Monthly clamps the anchor day
/// to the target month's length (e.g. 31 -> Feb 28/29); weekly adds 7 days.
DateTime nextRecurringDate(DateTime after, IntervalKind kind, int anchorDay) {
  switch (kind) {
    case IntervalKind.weekly:
      return after.add(const Duration(days: 7));
    case IntervalKind.monthly:
      final base = DateTime(after.year, after.month + 1, 1);
      final lastDay = DateTime(base.year, base.month + 1, 0).day;
      final day = anchorDay > lastDay ? lastDay : anchorDay;
      return DateTime(base.year, base.month, day);
  }
}
```

```dart
// lib/data/recurring/recurring_repository.dart
import 'package:drift/drift.dart';
import '../../core/ledger/ledger_entry.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../db/app_database.dart';
import 'recurring_model.dart';

abstract class RecurringIncomeRepository {
  Future<int> create({
    required int accountId,
    required Money amount,
    required IncomeType incomeType,
    String? note,
    required IntervalKind intervalKind,
    required int anchorDay,
    required DateTime nextDueAt,
  });
  Future<List<RecurringIncomePlan>> listActive();
  Future<List<RecurringIncomePlan>> duePlans(DateTime asOf);
  Future<void> markConfirmed(int id);
  Future<void> deactivate(int id);
}

class DriftRecurringIncomeRepository implements RecurringIncomeRepository {
  final AppDatabase db;
  DriftRecurringIncomeRepository(this.db);

  RecurringIncomePlan _map(dynamic r) => RecurringIncomePlan(
        id: r.id as int,
        accountId: r.accountId as int,
        amount: Money(r.amountMinor as int,
            CurrencyRegistry.byCode(r.currencyCode as String)),
        incomeType: IncomeType.values.byName(r.incomeType as String),
        note: r.note as String?,
        intervalKind: IntervalKind.values.byName(r.intervalKind as String),
        anchorDay: r.anchorDay as int,
        nextDueAt: r.nextDueAt as DateTime,
        active: r.active as bool,
      );

  @override
  Future<int> create({
    required int accountId,
    required Money amount,
    required IncomeType incomeType,
    String? note,
    required IntervalKind intervalKind,
    required int anchorDay,
    required DateTime nextDueAt,
  }) {
    return db.into(db.recurringIncomePlansTable).insert(
          RecurringIncomePlansTableCompanion.insert(
            accountId: accountId,
            amountMinor: amount.minorUnits,
            currencyCode: amount.currency.code,
            incomeType: incomeType.name,
            note: Value(note),
            intervalKind: intervalKind.name,
            anchorDay: anchorDay,
            nextDueAt: nextDueAt,
          ),
        );
  }

  @override
  Future<List<RecurringIncomePlan>> listActive() async {
    final rows = await (db.select(db.recurringIncomePlansTable)
          ..where((t) => t.active.equals(true)))
        .get();
    return rows.map(_map).toList();
  }

  @override
  Future<List<RecurringIncomePlan>> duePlans(DateTime asOf) async {
    final rows = await (db.select(db.recurringIncomePlansTable)
          ..where((t) =>
              t.active.equals(true) &
              t.nextDueAt.isSmallerOrEqualValue(asOf)))
        .get();
    return rows.map(_map).toList();
  }

  @override
  Future<void> markConfirmed(int id) async {
    final row = await (db.select(db.recurringIncomePlansTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    final plan = _map(row);
    final next = nextRecurringDate(
        plan.nextDueAt, plan.intervalKind, plan.anchorDay);
    await (db.update(db.recurringIncomePlansTable)
          ..where((t) => t.id.equals(id)))
        .write(RecurringIncomePlansTableCompanion(nextDueAt: Value(next)));
  }

  @override
  Future<void> deactivate(int id) async {
    await (db.update(db.recurringIncomePlansTable)
          ..where((t) => t.id.equals(id)))
        .write(const RecurringIncomePlansTableCompanion(active: Value(false)));
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --concurrency=1 test/data/recurring/recurring_repository_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/recurring/recurring_model.dart lib/data/recurring/recurring_repository.dart test/data/recurring/recurring_repository_test.dart
git commit -m "feat: add RecurringIncomeRepository + pure nextRecurringDate helper"
```

---

## Task 10: Providers + pure dashboard builder

**Files:**
- Create: `lib/features/home/dashboard_data.dart`
- Modify: `lib/providers/app_providers.dart` (append repository + dashboard providers)
- Test: `test/features/home/dashboard_data_test.dart`
- Test: `test/providers/ledger_providers_test.dart`

**Interfaces:**
- Produces:
  - `class DashboardData { Map<Currency, Money> totals; Money monthIncome; Money monthExpense; Money todaySpent; Money undistributedFunds; Currency primaryCurrency; }`
  - `DashboardData buildDashboard({required Iterable<Account> accounts, required Iterable<LedgerEntry> entries, required Currency primaryCurrency, required int periodStartDay, required DateTime now})`
  - Providers: `accountRepositoryProvider`, `categoryRepositoryProvider`, `ledgerRepositoryProvider`, `recurringIncomeRepositoryProvider`, `dashboardProvider` (`FutureProvider<DashboardData>`).
- Consumes: the summary engine (Task 3), the four repositories, `settingsProvider`, `databaseProvider`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/home/dashboard_data_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/features/home/dashboard_data.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  test('buildDashboard aggregates balance, month totals, today, undistributed', () {
    final now = DateTime(2026, 7, 18, 12);
    const acc = Account(id: 1, name: 'A', type: AccountType.cash,
        openingBalance: Money(1000000, uzs), icon: 'w', archived: false);
    final entries = [
      LedgerEntry(id: 1, accountId: 1, type: LedgerEntryType.income,
          amount: const Money(5000000, uzs), allocated: const Money(0, uzs),
          occurredAt: DateTime(2026, 7, 3), incomeType: IncomeType.salary),
      LedgerEntry(id: 2, accountId: 1, type: LedgerEntryType.expense,
          amount: const Money(-200000, uzs), allocated: const Money(0, uzs),
          occurredAt: now, categoryId: 1),
    ];
    final d = buildDashboard(
        accounts: [acc], entries: entries, primaryCurrency: uzs,
        periodStartDay: 1, now: now);
    expect(d.totals[uzs], const Money(5800000, uzs)); // 1,000,000 + 5,000,000 - 200,000
    expect(d.monthIncome, const Money(5000000, uzs));
    expect(d.monthExpense, const Money(200000, uzs));
    expect(d.todaySpent, const Money(200000, uzs));
    expect(d.undistributedFunds, const Money(5000000, uzs));
    expect(d.primaryCurrency, uzs);
  });
}
```

```dart
// test/providers/ledger_providers_test.dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  test('dashboardProvider reflects a saved expense', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    final accounts = container.read(accountRepositoryProvider);
    final ledger = container.read(ledgerRepositoryProvider);
    final id = await accounts.create(
        name: 'Naqd', type: AccountType.cash,
        openingBalance: const Money(1000000, CurrencyRegistry.uzs), icon: 'w');
    await ledger.addExpense(
        accountId: id, amount: const Money(250000, CurrencyRegistry.uzs),
        categoryId: 1, occurredAt: DateTime.now());

    final data = await container.read(dashboardProvider.future);
    expect(data.totals[CurrencyRegistry.uzs], const Money(750000, CurrencyRegistry.uzs));
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test --concurrency=1 test/features/home/dashboard_data_test.dart test/providers/ledger_providers_test.dart`
Expected: FAIL — `buildDashboard` and the new providers are undefined.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/home/dashboard_data.dart
import '../../core/ledger/account.dart';
import '../../core/ledger/ledger_entry.dart';
import '../../core/ledger/summary_engine.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/time/financial_period.dart';

class DashboardData {
  final Map<Currency, Money> totals;
  final Money monthIncome;
  final Money monthExpense;
  final Money todaySpent;
  final Money undistributedFunds;
  final Currency primaryCurrency;
  const DashboardData({
    required this.totals,
    required this.monthIncome,
    required this.monthExpense,
    required this.todaySpent,
    required this.undistributedFunds,
    required this.primaryCurrency,
  });
}

DashboardData buildDashboard({
  required Iterable<Account> accounts,
  required Iterable<LedgerEntry> entries,
  required Currency primaryCurrency,
  required int periodStartDay,
  required DateTime now,
}) {
  final period = FinancialPeriod.containing(now, periodStartDay);
  return DashboardData(
    totals: totalsByCurrency(accounts, entries),
    monthIncome: periodIncome(entries, period, primaryCurrency),
    monthExpense: periodExpense(entries, period, primaryCurrency),
    todaySpent: spentOn(now, entries, primaryCurrency),
    undistributedFunds: undistributed(entries, primaryCurrency),
    primaryCurrency: primaryCurrency,
  );
}
```

Append to `lib/providers/app_providers.dart` (keep existing providers and imports; add these imports and providers):

```dart
// add imports
import '../data/accounts/account_repository.dart';
import '../data/categories/category_repository.dart';
import '../data/ledger/ledger_repository.dart';
import '../data/recurring/recurring_repository.dart';
import '../features/home/dashboard_data.dart';

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => DriftAccountRepository(ref.watch(databaseProvider)),
);

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => DriftCategoryRepository(ref.watch(databaseProvider)),
);

final ledgerRepositoryProvider = Provider<LedgerRepository>(
  (ref) => DriftLedgerRepository(
    ref.watch(databaseProvider),
    ref.watch(accountRepositoryProvider),
  ),
);

final recurringIncomeRepositoryProvider = Provider<RecurringIncomeRepository>(
  (ref) => DriftRecurringIncomeRepository(ref.watch(databaseProvider)),
);

/// Bumped by every ledger/account mutation. Read-side providers watch it so
/// they recompute after any change — without mutating controllers having to
/// name each other (which would create forward references across tasks).
final ledgerRevisionProvider = StateProvider<int>((ref) => 0);

final dashboardProvider = FutureProvider<DashboardData>((ref) async {
  ref.watch(ledgerRevisionProvider);
  final settings = await ref.watch(settingsProvider.future);
  final accounts =
      await ref.watch(accountRepositoryProvider).list(includeArchived: false);
  final entries = await ref.watch(ledgerRepositoryProvider).allEntries();
  return buildDashboard(
    accounts: accounts,
    entries: entries,
    primaryCurrency: settings.primaryCurrency,
    periodStartDay: settings.periodStartDay,
    now: DateTime.now(),
  );
});
```

**Convention for all mutating controllers (Tasks 11–17):** after a write, call
`ref.read(ledgerRevisionProvider.notifier).state++;` then `await future;` if the
controller needs its own rebuilt state. Read-side controllers `ref.watch(ledgerRevisionProvider)`
in their `build()`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test --concurrency=1 test/features/home/dashboard_data_test.dart test/providers/ledger_providers_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/dashboard_data.dart lib/providers/app_providers.dart test/features/home/dashboard_data_test.dart test/providers/ledger_providers_test.dart
git commit -m "feat: wire repository + dashboard providers over the ledger engine"
```

---

## Task 11: Accounts feature (controller + screen + edit sheet)

**Files:**
- Create: `lib/features/accounts/accounts_controller.dart`
- Create: `lib/features/accounts/accounts_screen.dart`
- Create: `lib/features/accounts/account_edit_sheet.dart`
- Test: `test/features/accounts/accounts_controller_test.dart`
- Test: `test/features/accounts/accounts_screen_test.dart`

**Interfaces:**
- Produces:
  - `class AccountWithBalance { Account account; Money balance; }`
  - `class AccountsController extends AsyncNotifier<List<AccountWithBalance>>` with `createAccount(...)`, `rename(int, String)`, `archive(int)`.
  - `final accountsControllerProvider = AsyncNotifierProvider<AccountsController, List<AccountWithBalance>>(AccountsController.new)`
  - `class AccountsScreen extends ConsumerWidget`
  - `Future<void> showAccountEditSheet(BuildContext, WidgetRef)`
- Consumes: `accountRepositoryProvider`, `ledgerRepositoryProvider`, `dashboardProvider`, `accountBalance`, `settingsProvider` (for the default currency).

- [ ] **Step 1: Write the failing controller test**

```dart
// test/features/accounts/accounts_controller_test.dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/accounts/accounts_controller.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  ProviderContainer makeContainer(AppDatabase db) {
    final c = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    addTearDown(db.close);
    return c;
  }

  test('createAccount shows up with its opening balance', () async {
    final c = makeContainer(AppDatabase(NativeDatabase.memory()));
    await c.read(accountsControllerProvider.notifier).createAccount(
        name: 'Naqd', type: AccountType.cash,
        openingBalance: const Money(500000, uzs), icon: 'wallet');
    final list = await c.read(accountsControllerProvider.future);
    expect(list.single.account.name, 'Naqd');
    expect(list.single.balance, const Money(500000, uzs));
  });

  test('archived accounts drop out of the list', () async {
    final c = makeContainer(AppDatabase(NativeDatabase.memory()));
    final ctrl = c.read(accountsControllerProvider.notifier);
    await ctrl.createAccount(name: 'A', type: AccountType.cash, openingBalance: const Money(0, uzs), icon: 'w');
    var list = await c.read(accountsControllerProvider.future);
    await ctrl.archive(list.single.account.id);
    list = await c.read(accountsControllerProvider.future);
    expect(list, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/features/accounts/accounts_controller_test.dart`
Expected: FAIL — `accountsControllerProvider` not defined.

- [ ] **Step 3: Write controller + screen + sheet**

```dart
// lib/features/accounts/accounts_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ledger/account.dart';
import '../../core/ledger/balance_engine.dart';
import '../../core/money/money.dart';
import '../../providers/app_providers.dart';

class AccountWithBalance {
  final Account account;
  final Money balance;
  const AccountWithBalance(this.account, this.balance);
}

class AccountsController extends AsyncNotifier<List<AccountWithBalance>> {
  @override
  Future<List<AccountWithBalance>> build() async {
    ref.watch(ledgerRevisionProvider);
    final accounts =
        await ref.watch(accountRepositoryProvider).list();
    final entries = await ref.watch(ledgerRepositoryProvider).allEntries();
    return [
      for (final a in accounts) AccountWithBalance(a, accountBalance(a, entries)),
    ];
  }

  Future<void> _invalidate() async {
    ref.read(ledgerRevisionProvider.notifier).state++;
    await future;
  }

  Future<void> createAccount({
    required String name,
    required AccountType type,
    required Money openingBalance,
    required String icon,
  }) async {
    await ref.read(accountRepositoryProvider).create(
        name: name, type: type, openingBalance: openingBalance, icon: icon);
    await _invalidate();
  }

  Future<void> rename(int id, String name) async {
    await ref.read(accountRepositoryProvider).rename(id, name);
    await _invalidate();
  }

  Future<void> archive(int id) async {
    await ref.read(accountRepositoryProvider).setArchived(id, true);
    await _invalidate();
  }
}

final accountsControllerProvider =
    AsyncNotifierProvider<AccountsController, List<AccountWithBalance>>(
        AccountsController.new);
```

```dart
// lib/features/accounts/accounts_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'accounts_controller.dart';
import 'account_edit_sheet.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(accountsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Hisoblar')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAccountEditSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Xatolik: $e')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('Hali hisob yo\'q'))
            : ListView(
                children: [
                  for (final it in items)
                    ListTile(
                      key: Key('account_${it.account.id}'),
                      leading: const Icon(Icons.account_balance_wallet_outlined),
                      title: Text(it.account.name),
                      trailing: Text(it.balance.format()),
                      onLongPress: () =>
                          ref.read(accountsControllerProvider.notifier)
                              .archive(it.account.id),
                    ),
                ],
              ),
      ),
    );
  }
}
```

```dart
// lib/features/accounts/account_edit_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ledger/account.dart';
import '../../core/money/money.dart';
import '../../providers/app_providers.dart';
import 'accounts_controller.dart';

Future<void> showAccountEditSheet(BuildContext context, WidgetRef ref) async {
  final settings = await ref.read(settingsProvider.future);
  final currency = settings.primaryCurrency;
  final nameCtrl = TextEditingController();
  final balanceCtrl = TextEditingController();
  var type = AccountType.cash;
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16, right: 16, top: 16),
      child: StatefulBuilder(
        builder: (ctx, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nomi')),
            TextField(
                controller: balanceCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Boshlang\'ich balans')),
            DropdownButton<AccountType>(
              value: type,
              isExpanded: true,
              onChanged: (v) => setState(() => type = v ?? type),
              items: const [
                DropdownMenuItem(value: AccountType.cash, child: Text('Naqd pul')),
                DropdownMenuItem(value: AccountType.bankCard, child: Text('Bank kartasi')),
                DropdownMenuItem(value: AccountType.savings, child: Text('Jamg\'arma')),
                DropdownMenuItem(value: AccountType.other, child: Text('Boshqa')),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final opening = Money.tryParse(balanceCtrl.text, currency) ??
                    Money.zero(currency);
                await ref.read(accountsControllerProvider.notifier).createAccount(
                    name: nameCtrl.text.trim().isEmpty ? 'Hisob' : nameCtrl.text.trim(),
                    type: type,
                    openingBalance: opening,
                    icon: 'wallet');
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Saqlash'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}
```

- [ ] **Step 4: Write the screen smoke test**

```dart
// test/features/accounts/accounts_screen_test.dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/accounts/accounts_controller.dart';
import 'package:financial_assistant/features/accounts/accounts_screen.dart';

void main() {
  testWidgets('renders an account with its formatted balance', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    await container.read(accountsControllerProvider.notifier).createAccount(
        name: 'Naqd', type: AccountType.cash,
        openingBalance: const Money(500000, CurrencyRegistry.uzs), icon: 'wallet');

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AccountsScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Naqd'), findsOneWidget);
    expect(find.textContaining('500'), findsWidgets);
  });
}
```

- [ ] **Step 5: Run tests and commit**

Run: `flutter test --concurrency=1 test/features/accounts/`
Expected: PASS.

```bash
git add lib/features/accounts/ test/features/accounts/
git commit -m "feat: add accounts screen with derived balances and create sheet"
```

---

## Task 12: Transfer & balance-adjust sheets

**Files:**
- Create: `lib/features/accounts/transfer_sheet.dart`
- Create: `lib/features/accounts/balance_adjust_sheet.dart`
- Modify: `lib/features/accounts/accounts_controller.dart` (add `transfer`, `adjust` methods)
- Test: `test/features/accounts/accounts_actions_test.dart`

**Interfaces:**
- Produces (added to `AccountsController`):
  - `Future<Result<void>> transfer({required int fromId, required int toId, required Money amount})`
  - `Future<void> adjust({required int accountId, required Money realBalance})`
  - `Future<void> showTransferSheet(BuildContext, WidgetRef)`, `Future<void> showBalanceAdjustSheet(BuildContext, WidgetRef, int accountId)`
- Consumes: `ledgerRepositoryProvider`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/accounts/accounts_actions_test.dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/accounts/accounts_controller.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  ProviderContainer makeContainer() {
    final db = AppDatabase(NativeDatabase.memory());
    final c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    addTearDown(db.close);
    return c;
  }

  Future<int> add(ProviderContainer c, String name, int opening) => c
      .read(accountsControllerProvider.notifier)
      .createAccount(name: name, type: AccountType.cash, openingBalance: Money(opening, uzs), icon: 'w')
      .then((_) async {
    final list = await c.read(accountsControllerProvider.future);
    return list.firstWhere((e) => e.account.name == name).account.id;
  });

  test('transfer moves balance between accounts', () async {
    final c = makeContainer();
    final a = await add(c, 'A', 1000000);
    final b = await add(c, 'B', 0);
    final r = await c.read(accountsControllerProvider.notifier)
        .transfer(fromId: a, toId: b, amount: const Money(300000, uzs));
    expect(r.isOk, isTrue);
    final list = await c.read(accountsControllerProvider.future);
    Money bal(String n) => list.firstWhere((e) => e.account.name == n).balance;
    expect(bal('A'), const Money(700000, uzs));
    expect(bal('B'), const Money(300000, uzs));
  });

  test('adjust makes the balance equal the real value', () async {
    final c = makeContainer();
    final a = await add(c, 'A', 1000000);
    await c.read(accountsControllerProvider.notifier)
        .adjust(accountId: a, realBalance: const Money(950000, uzs));
    final list = await c.read(accountsControllerProvider.future);
    expect(list.single.balance, const Money(950000, uzs));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/features/accounts/accounts_actions_test.dart`
Expected: FAIL — `transfer`/`adjust` not defined on the controller.

- [ ] **Step 3: Add controller methods and the sheets**

Append to `AccountsController` (before the closing brace):

```dart
  Future<Result<void>> transfer({
    required int fromId,
    required int toId,
    required Money amount,
  }) async {
    final r = await ref.read(ledgerRepositoryProvider).transfer(
        fromId: fromId, toId: toId, amount: amount, occurredAt: DateTime.now());
    if (r.isOk) await _invalidate();
    return r;
  }

  Future<void> adjust({
    required int accountId,
    required Money realBalance,
  }) async {
    await ref.read(ledgerRepositoryProvider).adjustBalance(
        accountId: accountId, realBalance: realBalance, occurredAt: DateTime.now());
    await _invalidate();
  }
```

Add the import at the top of `accounts_controller.dart`:

```dart
import '../../core/result/result.dart';
```

Create the two sheets:

```dart
// lib/features/accounts/transfer_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/money.dart';
import '../../core/result/failure_messages.dart';
import '../../providers/app_providers.dart';
import 'accounts_controller.dart';

Future<void> showTransferSheet(BuildContext context, WidgetRef ref) async {
  final settings = await ref.read(settingsProvider.future);
  final currency = settings.primaryCurrency;
  final accounts = await ref.read(accountsControllerProvider.future);
  if (accounts.length < 2) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('O\'tkazma uchun kamida 2 ta hisob kerak')));
    }
    return;
  }
  final amountCtrl = TextEditingController();
  var fromId = accounts[0].account.id;
  var toId = accounts[1].account.id;
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: StatefulBuilder(
        builder: (ctx, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<int>(
              value: fromId, isExpanded: true,
              onChanged: (v) => setState(() => fromId = v ?? fromId),
              items: [for (final a in accounts) DropdownMenuItem(value: a.account.id, child: Text('Dan: ${a.account.name}'))],
            ),
            DropdownButton<int>(
              value: toId, isExpanded: true,
              onChanged: (v) => setState(() => toId = v ?? toId),
              items: [for (final a in accounts) DropdownMenuItem(value: a.account.id, child: Text('Ga: ${a.account.name}'))],
            ),
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Summa')),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final amount = Money.tryParse(amountCtrl.text, currency);
                if (amount == null) return;
                final r = await ref.read(accountsControllerProvider.notifier)
                    .transfer(fromId: fromId, toId: toId, amount: amount);
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                r.when(ok: (_) {}, err: (f) => ScaffoldMessenger.of(ctx)
                    .showSnackBar(SnackBar(content: Text(userMessage(f)))));
              },
              child: const Text('O\'tkazish'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}
```

```dart
// lib/features/accounts/balance_adjust_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/money.dart';
import '../../providers/app_providers.dart';
import 'accounts_controller.dart';

Future<void> showBalanceAdjustSheet(
    BuildContext context, WidgetRef ref, int accountId) async {
  final settings = await ref.read(settingsProvider.future);
  final currency = settings.primaryCurrency;
  final realCtrl = TextEditingController();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Haqiqiy balansni kiriting'),
          TextField(controller: realCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Balans')),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              final real = Money.tryParse(realCtrl.text, currency);
              if (real == null) return;
              await ref.read(accountsControllerProvider.notifier)
                  .adjust(accountId: accountId, realBalance: real);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Tuzatish'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --concurrency=1 test/features/accounts/accounts_actions_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/accounts/ test/features/accounts/accounts_actions_test.dart
git commit -m "feat: add transfer and balance-adjust flows"
```

---

## Task 13: Expense quick-entry (controller + sheet + undo)

**Files:**
- Create: `lib/features/expense_entry/expense_entry_controller.dart`
- Create: `lib/features/expense_entry/expense_entry_sheet.dart`
- Test: `test/features/expense_entry/expense_entry_controller_test.dart`

**Interfaces:**
- Produces:
  - `List<int> quickPickCategoryIds(List<LedgerEntry> expenses, {int limit = 6})` — recent-first distinct category ids, back-filled by most-used, capped at `limit` (PRD §9.2).
  - `class ExpenseEntryState { int? defaultAccountId; List<int> quickPickCategoryIds; int? lastSavedEntryId; }`
  - `class ExpenseEntryController extends AsyncNotifier<ExpenseEntryState>` with `save({required Money amount, required int categoryId, int? accountId, DateTime? occurredAt, String? note, bool? planned})` and `undo()`.
  - `final expenseEntryControllerProvider = AsyncNotifierProvider<ExpenseEntryController, ExpenseEntryState>(ExpenseEntryController.new)`
  - `Future<void> showExpenseEntrySheet(BuildContext, WidgetRef)`
- Consumes: `ledgerRepositoryProvider`, `accountRepositoryProvider`, `categoryRepositoryProvider`, `ledgerRevisionProvider`, `settingsProvider`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/expense_entry/expense_entry_controller_test.dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/expense_entry/expense_entry_controller.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  LedgerEntry exp(int cat) => LedgerEntry(
      id: cat, accountId: 1, type: LedgerEntryType.expense,
      amount: const Money(-1, uzs), allocated: const Money(0, uzs),
      occurredAt: DateTime(2026, 7, cat), categoryId: cat);

  test('quickPickCategoryIds is recent-first, distinct, capped', () {
    final ids = quickPickCategoryIds([exp(1), exp(2), exp(2), exp(3)], limit: 2);
    expect(ids.length, 2);
    expect(ids.first, anyOf(3, 2)); // most recent / most used surface first
  });

  test('save records an expense against the default account and supports undo',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);

    final accId = await c.read(accountRepositoryProvider).create(
        name: 'Naqd', type: AccountType.cash,
        openingBalance: const Money(1000000, uzs), icon: 'w');
    // default account resolves to the only account
    var st = await c.read(expenseEntryControllerProvider.future);
    expect(st.defaultAccountId, accId);

    await c.read(expenseEntryControllerProvider.notifier)
        .save(amount: const Money(250000, uzs), categoryId: 1);
    final data = await c.read(dashboardProvider.future);
    expect(data.totals[uzs], const Money(750000, uzs));

    await c.read(expenseEntryControllerProvider.notifier).undo();
    final after = await c.read(dashboardProvider.future);
    expect(after.totals[uzs], const Money(1000000, uzs));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/features/expense_entry/expense_entry_controller_test.dart`
Expected: FAIL — symbols undefined.

- [ ] **Step 3: Write controller + sheet**

```dart
// lib/features/expense_entry/expense_entry_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ledger/ledger_entry.dart';
import '../../core/money/money.dart';
import '../../providers/app_providers.dart';

/// Recent-first distinct category ids, back-filled by most-used, capped.
List<int> quickPickCategoryIds(List<LedgerEntry> expenses, {int limit = 6}) {
  final recent = <int>[];
  final counts = <int, int>{};
  for (final e in expenses.reversed) {
    final id = e.categoryId;
    if (id == null) continue;
    counts[id] = (counts[id] ?? 0) + 1;
    if (!recent.contains(id)) recent.add(id);
  }
  final byUse = counts.keys.toList()
    ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  final ordered = <int>[...recent];
  for (final id in byUse) {
    if (!ordered.contains(id)) ordered.add(id);
  }
  return ordered.take(limit).toList();
}

class ExpenseEntryState {
  final int? defaultAccountId;
  final List<int> quickPickCategoryIds;
  final int? lastSavedEntryId;
  const ExpenseEntryState({
    this.defaultAccountId,
    this.quickPickCategoryIds = const [],
    this.lastSavedEntryId,
  });
  ExpenseEntryState copyWith({int? defaultAccountId, List<int>? quickPickCategoryIds, int? lastSavedEntryId}) =>
      ExpenseEntryState(
        defaultAccountId: defaultAccountId ?? this.defaultAccountId,
        quickPickCategoryIds: quickPickCategoryIds ?? this.quickPickCategoryIds,
        lastSavedEntryId: lastSavedEntryId ?? this.lastSavedEntryId,
      );
}

class ExpenseEntryController extends AsyncNotifier<ExpenseEntryState> {
  @override
  Future<ExpenseEntryState> build() async {
    ref.watch(ledgerRevisionProvider);
    final entries = await ref.watch(ledgerRepositoryProvider).allEntries();
    final accounts = await ref.watch(accountRepositoryProvider).list();
    final expenses =
        entries.where((e) => e.type == LedgerEntryType.expense).toList();
    // last-used account = the account of the most recent entry (PRD §9.1)
    int? lastAccount;
    if (entries.isNotEmpty) {
      entries.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
      lastAccount = entries.last.accountId;
    }
    return ExpenseEntryState(
      defaultAccountId: lastAccount ?? (accounts.isEmpty ? null : accounts.first.id),
      quickPickCategoryIds: quickPickCategoryIds(expenses),
    );
  }

  Future<void> save({
    required Money amount,
    required int categoryId,
    int? accountId,
    DateTime? occurredAt,
    String? note,
    bool? planned,
  }) async {
    final accId = accountId ?? state.valueOrNull?.defaultAccountId;
    if (accId == null) return;
    final id = await ref.read(ledgerRepositoryProvider).addExpense(
        accountId: accId, amount: amount, categoryId: categoryId,
        occurredAt: occurredAt ?? DateTime.now(), note: note, planned: planned);
    ref.read(ledgerRevisionProvider.notifier).state++;
    await future; // rebuild default/quick-pick
    state = AsyncData(
        (state.valueOrNull ?? const ExpenseEntryState()).copyWith(lastSavedEntryId: id));
  }

  Future<void> undo() async {
    final id = state.valueOrNull?.lastSavedEntryId;
    if (id == null) return;
    await ref.read(ledgerRepositoryProvider).deleteEntry(id);
    ref.read(ledgerRevisionProvider.notifier).state++;
    await future;
  }
}

final expenseEntryControllerProvider =
    AsyncNotifierProvider<ExpenseEntryController, ExpenseEntryState>(
        ExpenseEntryController.new);
```

```dart
// lib/features/expense_entry/expense_entry_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/money.dart';
import '../../data/categories/category_model.dart';
import '../../providers/app_providers.dart';
import 'expense_entry_controller.dart';

/// 3-step quick expense: amount -> category -> save (PRD §9.1). Optional
/// fields (account/date/note) stay hidden behind defaults for speed.
Future<void> showExpenseEntrySheet(BuildContext context, WidgetRef ref) async {
  final settings = await ref.read(settingsProvider.future);
  final currency = settings.primaryCurrency;
  final categories = await ref.read(categoryRepositoryProvider).list();
  if (categories.isEmpty) return;
  final amountCtrl = TextEditingController();
  int? categoryId = categories.first.id;
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: StatefulBuilder(
        builder: (ctx, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Summa'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final Category cat in categories)
                  ChoiceChip(
                    label: Text(cat.name),
                    selected: categoryId == cat.id,
                    onSelected: (_) => setState(() => categoryId = cat.id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final amount = Money.tryParse(amountCtrl.text, currency);
                if (amount == null || categoryId == null) return;
                await ref.read(expenseEntryControllerProvider.notifier)
                    .save(amount: amount, categoryId: categoryId!);
                if (!ctx.mounted) return;
                final messenger = ScaffoldMessenger.of(ctx);
                Navigator.of(ctx).pop();
                messenger.showSnackBar(SnackBar(
                  content: const Text('Chiqim saqlandi'),
                  action: SnackBarAction(
                    label: 'Bekor qilish',
                    onPressed: () =>
                        ref.read(expenseEntryControllerProvider.notifier).undo(),
                  ),
                ));
              },
              child: const Text('Saqlash'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --concurrency=1 test/features/expense_entry/expense_entry_controller_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/expense_entry/ test/features/expense_entry/
git commit -m "feat: add 3-step expense quick-entry with quick-pick categories and undo"
```

---

## Task 14: Income entry + recurring plan (§7.1–§7.3)

**Files:**
- Create: `lib/features/income_entry/income_entry_controller.dart`
- Create: `lib/features/income_entry/income_entry_sheet.dart`
- Test: `test/features/income_entry/income_entry_controller_test.dart`

**Interfaces:**
- Produces:
  - `class IncomeEntryController extends AsyncNotifier<void>` with `save({required int accountId, required Money amount, required IncomeType incomeType, DateTime? occurredAt, String? note, bool recurring = false, IntervalKind intervalKind = IntervalKind.monthly, int? anchorDay})`.
  - `final incomeEntryControllerProvider = AsyncNotifierProvider<IncomeEntryController, void>(IncomeEntryController.new)`
  - `Future<void> showIncomeEntrySheet(BuildContext, WidgetRef)`
- Consumes: `ledgerRepositoryProvider`, `recurringIncomeRepositoryProvider`, `ledgerRevisionProvider`.
- Note: the §7.2 "distribute now / later / apply previous plan" choice is out of scope; income is simply recorded **undistributed** (`allocatedMinor` stays 0). SP2 adds allocation.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/income_entry/income_entry_controller_test.dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/recurring/recurring_model.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/income_entry/income_entry_controller.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  test('income is recorded undistributed and shows on the dashboard', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    final accId = await c.read(accountRepositoryProvider).create(
        name: 'Naqd', type: AccountType.cash, openingBalance: const Money(0, uzs), icon: 'w');

    await c.read(incomeEntryControllerProvider.notifier).save(
        accountId: accId, amount: const Money(5000000, uzs), incomeType: IncomeType.salary);

    final data = await c.read(dashboardProvider.future);
    expect(data.monthIncome, const Money(5000000, uzs));
    expect(data.undistributedFunds, const Money(5000000, uzs));
  });

  test('a recurring income also creates an active plan', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    final accId = await c.read(accountRepositoryProvider).create(
        name: 'Naqd', type: AccountType.cash, openingBalance: const Money(0, uzs), icon: 'w');

    await c.read(incomeEntryControllerProvider.notifier).save(
        accountId: accId, amount: const Money(5000000, uzs), incomeType: IncomeType.salary,
        occurredAt: DateTime(2026, 7, 5), recurring: true,
        intervalKind: IntervalKind.monthly, anchorDay: 5);

    final plans = await c.read(recurringIncomeRepositoryProvider).listActive();
    expect(plans.length, 1);
    expect(plans.single.anchorDay, 5);
    expect(plans.single.nextDueAt, DateTime(2026, 8, 5)); // next occurrence
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/features/income_entry/income_entry_controller_test.dart`
Expected: FAIL — symbols undefined.

- [ ] **Step 3: Write controller + sheet**

```dart
// lib/features/income_entry/income_entry_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ledger/ledger_entry.dart';
import '../../core/money/money.dart';
import '../../data/recurring/recurring_model.dart';
import '../../providers/app_providers.dart';

class IncomeEntryController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> save({
    required int accountId,
    required Money amount,
    required IncomeType incomeType,
    DateTime? occurredAt,
    String? note,
    bool recurring = false,
    IntervalKind intervalKind = IntervalKind.monthly,
    int? anchorDay,
  }) async {
    final when = occurredAt ?? DateTime.now();
    await ref.read(ledgerRepositoryProvider).addIncome(
        accountId: accountId, amount: amount, incomeType: incomeType,
        occurredAt: when, note: note);
    if (recurring) {
      final day = anchorDay ??
          (intervalKind == IntervalKind.monthly ? when.day : when.weekday);
      await ref.read(recurringIncomeRepositoryProvider).create(
            accountId: accountId,
            amount: amount,
            incomeType: incomeType,
            note: note,
            intervalKind: intervalKind,
            anchorDay: day,
            nextDueAt: nextRecurringDate(when, intervalKind, day),
          );
    }
    ref.read(ledgerRevisionProvider.notifier).state++;
  }
}

final incomeEntryControllerProvider =
    AsyncNotifierProvider<IncomeEntryController, void>(IncomeEntryController.new);
```

```dart
// lib/features/income_entry/income_entry_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ledger/ledger_entry.dart';
import '../../core/money/money.dart';
import '../../providers/app_providers.dart';
import 'income_entry_controller.dart';

Future<void> showIncomeEntrySheet(BuildContext context, WidgetRef ref) async {
  final settings = await ref.read(settingsProvider.future);
  final currency = settings.primaryCurrency;
  final accounts = await ref.read(accountRepositoryProvider).list();
  if (accounts.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avval hisob yarating')));
    }
    return;
  }
  final amountCtrl = TextEditingController();
  var accountId = accounts.first.id;
  var incomeType = IncomeType.salary;
  var recurring = false;
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: StatefulBuilder(
        builder: (ctx, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: amountCtrl, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Summa')),
            DropdownButton<IncomeType>(
              value: incomeType, isExpanded: true,
              onChanged: (v) => setState(() => incomeType = v ?? incomeType),
              items: const [
                DropdownMenuItem(value: IncomeType.salary, child: Text('Oylik maosh')),
                DropdownMenuItem(value: IncomeType.bonus, child: Text('Bonus')),
                DropdownMenuItem(value: IncomeType.freelance, child: Text('Freelance')),
                DropdownMenuItem(value: IncomeType.refund, child: Text('Qaytarilgan pul')),
                DropdownMenuItem(value: IncomeType.other, child: Text('Boshqa')),
              ],
            ),
            DropdownButton<int>(
              value: accountId, isExpanded: true,
              onChanged: (v) => setState(() => accountId = v ?? accountId),
              items: [for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name))],
            ),
            SwitchListTile(
              value: recurring,
              onChanged: (v) => setState(() => recurring = v),
              title: const Text('Takroriy kirim'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = Money.tryParse(amountCtrl.text, currency);
                if (amount == null) return;
                await ref.read(incomeEntryControllerProvider.notifier).save(
                    accountId: accountId, amount: amount, incomeType: incomeType,
                    recurring: recurring);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Saqlash'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --concurrency=1 test/features/income_entry/income_entry_controller_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/income_entry/ test/features/income_entry/
git commit -m "feat: add income entry with recurring-plan creation (undistributed)"
```

---

## Task 15: Transactions tab (history + edit + delete)

**Files:**
- Create: `lib/features/transactions/transactions_controller.dart`
- Create: `lib/features/transactions/transactions_screen.dart`
- Test: `test/features/transactions/transactions_controller_test.dart`

**Interfaces:**
- Produces:
  - `class TransactionsController extends AsyncNotifier<List<LedgerEntry>>` (newest first) with `delete(int id)` and `Future<Result<void>> editAmount(int id, Money amount)`.
  - `final transactionsControllerProvider = AsyncNotifierProvider<TransactionsController, List<LedgerEntry>>(TransactionsController.new)`
  - `class TransactionsScreen extends ConsumerWidget`
- Consumes: `ledgerRepositoryProvider`, `ledgerRevisionProvider`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/transactions/transactions_controller_test.dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/transactions/transactions_controller.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  Future<ProviderContainer> seeded() async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    final accId = await c.read(accountRepositoryProvider).create(
        name: 'Naqd', type: AccountType.cash, openingBalance: const Money(1000000, uzs), icon: 'w');
    await c.read(ledgerRepositoryProvider).addExpense(
        accountId: accId, amount: const Money(250000, uzs), categoryId: 1, occurredAt: DateTime(2026, 7, 18));
    return c;
  }

  test('history lists the entry; delete removes it', () async {
    final c = await seeded();
    var list = await c.read(transactionsControllerProvider.future);
    expect(list.length, 1);
    await c.read(transactionsControllerProvider.notifier).delete(list.single.id);
    list = await c.read(transactionsControllerProvider.future);
    expect(list, isEmpty);
  });

  test('editAmount changes the stored magnitude', () async {
    final c = await seeded();
    final list = await c.read(transactionsControllerProvider.future);
    final r = await c.read(transactionsControllerProvider.notifier)
        .editAmount(list.single.id, const Money(100000, uzs));
    expect(r.isOk, isTrue);
    final data = await c.read(dashboardProvider.future);
    expect(data.totals[uzs], const Money(900000, uzs)); // 1,000,000 - 100,000
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/features/transactions/transactions_controller_test.dart`
Expected: FAIL — symbols undefined.

- [ ] **Step 3: Write controller + screen**

```dart
// lib/features/transactions/transactions_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ledger/ledger_entry.dart';
import '../../core/money/money.dart';
import '../../core/result/result.dart';
import '../../providers/app_providers.dart';

class TransactionsController extends AsyncNotifier<List<LedgerEntry>> {
  @override
  Future<List<LedgerEntry>> build() async {
    ref.watch(ledgerRevisionProvider);
    final entries = await ref.watch(ledgerRepositoryProvider).allEntries();
    entries.sort((a, b) => b.occurredAt.compareTo(a.occurredAt)); // newest first
    return entries;
  }

  Future<void> delete(int id) async {
    await ref.read(ledgerRepositoryProvider).deleteEntry(id);
    ref.read(ledgerRevisionProvider.notifier).state++;
    await future;
  }

  Future<Result<void>> editAmount(int id, Money amount) async {
    final r = await ref.read(ledgerRepositoryProvider).editEntry(id: id, amount: amount);
    if (r.isOk) {
      ref.read(ledgerRevisionProvider.notifier).state++;
      await future;
    }
    return r;
  }
}

final transactionsControllerProvider =
    AsyncNotifierProvider<TransactionsController, List<LedgerEntry>>(
        TransactionsController.new);
```

```dart
// lib/features/transactions/transactions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ledger/ledger_entry.dart';
import 'transactions_controller.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  String _label(LedgerEntryType t) => switch (t) {
        LedgerEntryType.expense => 'Chiqim',
        LedgerEntryType.income => 'Kirim',
        LedgerEntryType.transferOut => 'O\'tkazma (chiqdi)',
        LedgerEntryType.transferIn => 'O\'tkazma (kirdi)',
        LedgerEntryType.adjustment => 'Balans tuzatish',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(transactionsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tranzaksiyalar')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Xatolik: $e')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('Hali tranzaksiya yo\'q'))
            : ListView(
                children: [
                  for (final e in items)
                    Dismissible(
                      key: Key('txn_${e.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                          color: Theme.of(context).colorScheme.errorContainer),
                      onDismissed: (_) => ref
                          .read(transactionsControllerProvider.notifier)
                          .delete(e.id),
                      child: ListTile(
                        title: Text(_label(e.type)),
                        subtitle: Text(e.note ?? ''),
                        trailing: Text(e.amount.format()),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --concurrency=1 test/features/transactions/transactions_controller_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/transactions/ test/features/transactions/
git commit -m "feat: add transactions history with swipe-delete and amount edit"
```

---

## Task 16: Home dashboard screen

**Files:**
- Create: `lib/features/home/home_screen.dart`
- Test: `test/features/home/home_screen_test.dart`

**Interfaces:**
- Produces: `class HomeScreen extends ConsumerWidget` — renders the `DashboardData` cards (total balance per currency, month income, month expense, today's spent, undistributed) and a quick-action row (add expense / add income / transfer) wired to the sheets from Tasks 12–14.
- Consumes: `dashboardProvider`, `showExpenseEntrySheet`, `showIncomeEntrySheet`, `showTransferSheet`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/home/home_screen_test.dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/home/home_screen.dart';

void main() {
  testWidgets('shows the total balance card', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    await container.read(accountRepositoryProvider).create(
        name: 'Naqd', type: AccountType.cash,
        openingBalance: const Money(1000000, CurrencyRegistry.uzs), icon: 'w');

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Jami'), findsWidgets);
    expect(find.textContaining('1 000 000'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/features/home/home_screen_test.dart`
Expected: FAIL — `HomeScreen` not defined.

- [ ] **Step 3: Write the screen**

```dart
// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/money.dart';
import '../../providers/app_providers.dart';
import '../accounts/transfer_sheet.dart';
import '../expense_entry/expense_entry_sheet.dart';
import '../income_entry/income_entry_sheet.dart';
import 'dashboard_data.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Bosh sahifa')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Xatolik: $e')),
        data: (d) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _totalCard(context, d),
            _row('Shu oygi kirim', d.monthIncome.format()),
            _row('Shu oygi chiqim', d.monthExpense.format()),
            _row('Bugun sarflangan', d.todaySpent.format()),
            _row('Taqsimlanmagan mablag\'', d.undistributedFunds.format()),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => showExpenseEntrySheet(context, ref),
                  icon: const Icon(Icons.remove),
                  label: const Text('Chiqim'),
                ),
                FilledButton.icon(
                  onPressed: () => showIncomeEntrySheet(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Kirim'),
                ),
                OutlinedButton.icon(
                  onPressed: () => showTransferSheet(context, ref),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('O\'tkazma'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalCard(BuildContext context, DashboardData d) {
    final lines = d.totals.entries
        .map((e) => '${Money(e.value.minorUnits, e.key).format()}')
        .join('\n');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Jami mavjud balans'),
            const SizedBox(height: 8),
            Text(lines.isEmpty ? '—' : lines,
                style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label), Text(value)],
        ),
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --concurrency=1 test/features/home/home_screen_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/home_screen.dart test/features/home/home_screen_test.dart
git commit -m "feat: add Home dashboard with computed cards and quick actions"
```

---

## Task 17: On-open recurring-income confirmation (§7.3)

**Files:**
- Create: `lib/features/recurring/recurring_prompt.dart`
- Test: `test/features/recurring/recurring_prompt_test.dart`

**Interfaces:**
- Produces:
  - `class RecurringPromptController extends AsyncNotifier<List<RecurringIncomePlan>>` (due plans as of now) with `confirm(RecurringIncomePlan)` (records the income + advances the plan) and `later(RecurringIncomePlan)` (advances without recording).
  - `final recurringPromptControllerProvider = AsyncNotifierProvider<RecurringPromptController, List<RecurringIncomePlan>>(RecurringPromptController.new)`
  - `class RecurringPromptBanner extends ConsumerWidget` — renders one card per due plan with "Tasdiqlash" / "Keyinroq".
- Consumes: `recurringIncomeRepositoryProvider`, `ledgerRepositoryProvider`, `ledgerRevisionProvider`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/recurring/recurring_prompt_test.dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/recurring/recurring_model.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/recurring/recurring_prompt.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  test('confirm records income and clears the plan from due', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    final accId = await c.read(accountRepositoryProvider).create(
        name: 'Naqd', type: AccountType.cash, openingBalance: const Money(0, uzs), icon: 'w');
    await c.read(recurringIncomeRepositoryProvider).create(
        accountId: accId, amount: const Money(5000000, uzs), incomeType: IncomeType.salary,
        intervalKind: IntervalKind.monthly, anchorDay: 5, nextDueAt: DateTime(2026, 7, 5));

    final due = await c.read(recurringPromptControllerProvider.future);
    expect(due.length, 1);

    await c.read(recurringPromptControllerProvider.notifier).confirm(due.single);

    final data = await c.read(dashboardProvider.future);
    expect(data.monthIncome.minorUnits, greaterThan(0));
    final stillDue = await c.read(recurringIncomeRepositoryProvider).duePlans(DateTime(2026, 7, 6));
    expect(stillDue, isEmpty); // advanced past the current date
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/features/recurring/recurring_prompt_test.dart`
Expected: FAIL — symbols undefined.

- [ ] **Step 3: Write the controller + banner**

```dart
// lib/features/recurring/recurring_prompt.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/recurring/recurring_model.dart';
import '../../providers/app_providers.dart';

class RecurringPromptController
    extends AsyncNotifier<List<RecurringIncomePlan>> {
  @override
  Future<List<RecurringIncomePlan>> build() async {
    ref.watch(ledgerRevisionProvider);
    return ref.watch(recurringIncomeRepositoryProvider).duePlans(DateTime.now());
  }

  Future<void> confirm(RecurringIncomePlan plan) async {
    await ref.read(ledgerRepositoryProvider).addIncome(
          accountId: plan.accountId,
          amount: plan.amount,
          incomeType: plan.incomeType,
          occurredAt: DateTime.now(),
          note: plan.note,
        );
    await ref.read(recurringIncomeRepositoryProvider).markConfirmed(plan.id);
    ref.read(ledgerRevisionProvider.notifier).state++;
    await future;
  }

  Future<void> later(RecurringIncomePlan plan) async {
    await ref.read(recurringIncomeRepositoryProvider).markConfirmed(plan.id);
    ref.invalidateSelf();
    await future;
  }
}

final recurringPromptControllerProvider =
    AsyncNotifierProvider<RecurringPromptController, List<RecurringIncomePlan>>(
        RecurringPromptController.new);

class RecurringPromptBanner extends ConsumerWidget {
  const RecurringPromptBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(recurringPromptControllerProvider).valueOrNull ?? [];
    if (due.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final plan in due)
          Card(
            key: Key('recurring_${plan.id}'),
            child: ListTile(
              title: const Text('Takroriy kirimni tasdiqlang'),
              subtitle: Text(plan.amount.format()),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => ref
                        .read(recurringPromptControllerProvider.notifier)
                        .later(plan),
                    child: const Text('Keyinroq'),
                  ),
                  FilledButton(
                    onPressed: () => ref
                        .read(recurringPromptControllerProvider.notifier)
                        .confirm(plan),
                    child: const Text('Tasdiqlash'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --concurrency=1 test/features/recurring/recurring_prompt_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/recurring/ test/features/recurring/
git commit -m "feat: add on-open recurring-income confirmation prompt"
```

---

## Task 18: Wire the shell + accounts route + full verification

**Files:**
- Modify: `lib/features/shell/app_shell.dart` (Home + Transactions tabs, add-expense FAB)
- Modify: `lib/features/home/home_screen.dart` (app-bar action to Accounts; show the recurring banner)
- Modify: `lib/features/shell/routes.dart` (add `/accounts` route)
- Test: `test/features/shell/app_shell_test.dart` (extend — Home + Transactions render)

**Interfaces:**
- Consumes everything above. No new public symbols beyond `RouteNames.accounts`.

- [ ] **Step 1: Update the shell**

Replace `lib/features/shell/app_shell.dart` (the first two placeholder tabs become the real screens; add the reserved add-expense FAB from PRD §21.5):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../expense_entry/expense_entry_sheet.dart';
import '../home/home_screen.dart';
import '../transactions/transactions_screen.dart';
import 'placeholder_tab.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  static const _tabs = [
    HomeScreen(),
    TransactionsScreen(),
    PlaceholderTab(title: 'Taqsimlash'),
    PlaceholderTab(title: "Goal'lar"),
    PlaceholderTab(title: 'Hisobotlar'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: _tabs[_index]),
        floatingActionButton: FloatingActionButton(
          onPressed: () => showExpenseEntrySheet(context, ref),
          child: const Icon(Icons.add),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Bosh'),
            NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined), label: 'Tranzaksiya'),
            NavigationDestination(
                icon: Icon(Icons.pie_chart_outline), label: 'Taqsimlash'),
            NavigationDestination(icon: Icon(Icons.flag_outlined), label: 'Goal'),
            NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined), label: 'Hisobot'),
          ],
        ),
      );
}
```

- [ ] **Step 2: Add the accounts route and Home app-bar action + banner**

Add to `RouteNames` and `buildRouter` in `lib/features/shell/routes.dart`:

```dart
// in RouteNames:
static const accounts = '/accounts';

// in buildRouter routes: (add this GoRoute, keep the others)
GoRoute(
  path: RouteNames.accounts,
  builder: (_, _) => const AccountsScreen(),
),
```

Add the import `import '../accounts/accounts_screen.dart';` to `routes.dart`.

In `lib/features/home/home_screen.dart`, add the accounts action to the `AppBar` and render the recurring banner at the top of the list. Change the `AppBar` line and the first list child:

```dart
// add imports
import 'package:go_router/go_router.dart';
import '../shell/routes.dart';
import '../recurring/recurring_prompt.dart';

// AppBar becomes:
appBar: AppBar(
  title: const Text('Bosh sahifa'),
  actions: [
    IconButton(
      icon: const Icon(Icons.account_balance_wallet_outlined),
      onPressed: () => context.push(RouteNames.accounts),
    ),
  ],
),

// and make the FIRST child of the ListView the banner:
children: [
  const RecurringPromptBanner(),
  _totalCard(context, d),
  // ... rest unchanged
```

- [ ] **Step 3: Extend the shell test**

Replace `test/features/shell/app_shell_test.dart` with a version that pumps the shell with an in-memory DB and asserts Home + Transactions render (keep any existing assertions that still hold):

```dart
// test/features/shell/app_shell_test.dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/shell/app_shell.dart';

void main() {
  testWidgets('shell shows Home then switches to Transactions', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AppShell()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Bosh sahifa'), findsOneWidget); // Home app bar

    await tester.tap(find.text('Tranzaksiya'));
    await tester.pumpAndSettle();
    expect(find.text('Tranzaksiyalar'), findsOneWidget); // Transactions app bar
  });
}
```

- [ ] **Step 4: Regenerate, run the FULL suite, and analyze**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test --concurrency=1`
Expected: ALL suites pass (Foundation's 58 + the new SP1 tests).
Run: `flutter analyze`
Expected: no errors (warnings pre-existing in the Foundation are acceptable, but fix anything introduced by SP1).

- [ ] **Step 5: Commit**

```bash
git add lib/features/shell/ lib/features/home/home_screen.dart test/features/shell/app_shell_test.dart
git commit -m "feat: wire Home and Transactions tabs, add-expense FAB, and accounts route"
```

---

## Final verification checklist

Run once at the end (do not commit generated files):

- [ ] `dart run build_runner build --delete-conflicting-outputs` succeeds.
- [ ] `flutter test --concurrency=1` — all green.
- [ ] `flutter analyze` — no new errors.
- [ ] Manual smoke (optional, via `/run`): create an account with an opening balance, add an expense, confirm the Home total drops and the Transactions list shows it, undo, add income (recurring), confirm the recurring banner appears and confirming records income.
