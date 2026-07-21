# Transactions Filters & Click-Style Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add card / type / period filtering to the Transactions screen and rebuild each row into the consistent Click-style anatomy (icon · note+category · amount+time), with two side-by-side income/expense summary cards.

**Architecture:** Filtering is a *view* concern — the `transactionsControllerProvider` still returns all ledger entries; a pure `applyTransactionFilter` function narrows them against a `TransactionFilter` held in a `StateProvider`. Row title/subtitle text is produced by a pure `resolveRowContent` function so it is unit-testable without Flutter. The screen composes a filter-chips row (three bottom sheets), two summary cards, and a per-day list of individual transaction cards.

**Tech Stack:** Flutter, flutter_riverpod, Drift (SQLite), Velora design tokens. No new dependencies.

## Global Constraints

- All user-facing copy is in Uzbek (Latin), matching existing strings.
- Use Velora tokens only: `VeloraColors`, `VeloraSpacing`, `VeloraRadii` from `lib/core/theme/velora_tokens.dart`. No hard-coded colors/paddings except where the existing screen already does (icon-tint alpha values).
- Money is the `Money` value type (`const Money(minorUnits, currency)`); never use raw ints for money in UI. Currency comes from existing entries.
- Offline only; no network. State is session-only (filter is not persisted across restarts).
- Riverpod providers follow existing naming (`somethingProvider`).
- Category id 1 = `Oziq-ovqat` (see `lib/data/db/default_categories.dart`); tests rely on this.
- Adjustments (`LedgerEntryType.adjustment`) always pass the type filter (they are not an offered toggle).
- "O'tkazma" is a single user choice mapping to BOTH `transferOut` and `transferIn`.

---

## File Structure

- Create `lib/core/transactions/transaction_filter.dart` — `TransactionFilter`, `applyTransactionFilter`, `currentMonthFilter`.
- Create `lib/core/transactions/transaction_row_content.dart` — `RowContent`, `resolveRowContent`, `incomeTypeLabel`, `transactionTypeLabel` (moved here from the screen).
- Modify `lib/providers/app_providers.dart` — add `categoriesProvider`.
- Create `lib/features/transactions/transactions_filter_provider.dart` — `transactionFilterProvider` (StateProvider).
- Create `lib/features/transactions/transaction_filter_sheets.dart` — the three bottom sheets + their launchers.
- Modify `lib/features/transactions/transactions_screen.dart` — full redesign.
- Create `test/core/transactions/transaction_filter_test.dart`.
- Create `test/core/transactions/transaction_row_content_test.dart`.
- Modify `test/features/transactions/transactions_screen_test.dart` — update label assertions + filter override.
- Modify `test/goldens/existing_flow_gallery_test.dart` — pin filter to all-time in the transactions `seeded()` helper; regenerate the two seeded baselines.
- Create `test/features/transactions/transactions_filter_widget_test.dart`.

---

## Task 1: `TransactionFilter` model + pure filter function

**Files:**
- Create: `lib/core/transactions/transaction_filter.dart`
- Test: `test/core/transactions/transaction_filter_test.dart`

**Interfaces:**
- Produces:
  - `class TransactionFilter { final DateTimeRange? period; final String? periodLabel; final Set<int> accountIds; final Set<LedgerEntryType> types; }` with `const` ctor (defaults: `period=null, periodLabel=null, accountIds=const {}, types=const {}`), `copyWith(...)`, value `==`/`hashCode`.
  - `List<LedgerEntry> applyTransactionFilter(List<LedgerEntry> entries, TransactionFilter filter)`
  - `TransactionFilter currentMonthFilter(DateTime now)`

- [ ] **Step 1: Write the failing test**

Create `test/core/transactions/transaction_filter_test.dart`:

```dart
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/core/transactions/transaction_filter.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  LedgerEntry entry({
    int id = 1,
    int accountId = 1,
    LedgerEntryType type = LedgerEntryType.expense,
    required DateTime at,
  }) =>
      LedgerEntry(
        id: id,
        accountId: accountId,
        type: type,
        amount: const Money(-1000, uzs),
        occurredAt: at,
        allocated: const Money(0, uzs),
      );

  final e18 = entry(id: 1, at: DateTime(2026, 7, 18, 10));
  final e20 = entry(id: 2, at: DateTime(2026, 7, 20, 23, 59));
  final eAug = entry(id: 3, at: DateTime(2026, 8, 1, 0, 1));

  test('null period keeps every entry', () {
    final out = applyTransactionFilter([e18, e20, eAug], const TransactionFilter());
    expect(out, hasLength(3));
  });

  test('period is inclusive on both whole-day edges', () {
    final f = TransactionFilter(
      period: DateTimeRange(start: DateTime(2026, 7, 18), end: DateTime(2026, 7, 20)),
    );
    final out = applyTransactionFilter([e18, e20, eAug], f);
    expect(out.map((e) => e.id), [1, 2]);
  });

  test('accountIds keeps only matching accounts; empty set keeps all', () {
    final a = entry(id: 1, accountId: 5, at: DateTime(2026, 7, 18));
    final b = entry(id: 2, accountId: 9, at: DateTime(2026, 7, 18));
    expect(applyTransactionFilter([a, b], const TransactionFilter()).length, 2);
    expect(
      applyTransactionFilter([a, b], const TransactionFilter(accountIds: {5}))
          .map((e) => e.id),
      [1],
    );
  });

  test('types filter keeps matching types but always keeps adjustments', () {
    final inc = entry(id: 1, type: LedgerEntryType.income, at: DateTime(2026, 7, 18));
    final exp = entry(id: 2, type: LedgerEntryType.expense, at: DateTime(2026, 7, 18));
    final adj = entry(id: 3, type: LedgerEntryType.adjustment, at: DateTime(2026, 7, 18));
    final out = applyTransactionFilter(
      [inc, exp, adj],
      const TransactionFilter(types: {LedgerEntryType.income}),
    );
    expect(out.map((e) => e.id), [1, 3]);
  });

  test('currentMonthFilter spans the whole month and is labelled Bu oy', () {
    final f = currentMonthFilter(DateTime(2026, 7, 21, 14));
    expect(f.periodLabel, 'Bu oy');
    expect(f.period!.start, DateTime(2026, 7, 1));
    expect(f.period!.end, DateTime(2026, 7, 31));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/transactions/transaction_filter_test.dart`
Expected: FAIL — `transaction_filter.dart` does not exist / symbols undefined.

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/transactions/transaction_filter.dart`:

```dart
import 'package:flutter/material.dart' show DateTimeRange, immutable;

import '../ledger/ledger_entry.dart';

/// The active history filter. All fields are "widening by default": a null
/// [period], an empty [accountIds], or an empty [types] each mean "no
/// restriction on that axis". [periodLabel] is a display-only caption for the
/// Davr chip (e.g. 'Bu oy', 'O'tgan hafta', or a formatted range).
@immutable
class TransactionFilter {
  final DateTimeRange? period;
  final String? periodLabel;
  final Set<int> accountIds;
  final Set<LedgerEntryType> types;

  const TransactionFilter({
    this.period,
    this.periodLabel,
    this.accountIds = const {},
    this.types = const {},
  });

  TransactionFilter copyWith({
    DateTimeRange? period,
    String? periodLabel,
    Set<int>? accountIds,
    Set<LedgerEntryType>? types,
    bool clearPeriod = false,
  }) =>
      TransactionFilter(
        period: clearPeriod ? null : (period ?? this.period),
        periodLabel: clearPeriod ? null : (periodLabel ?? this.periodLabel),
        accountIds: accountIds ?? this.accountIds,
        types: types ?? this.types,
      );

  @override
  bool operator ==(Object other) =>
      other is TransactionFilter &&
      other.period?.start == period?.start &&
      other.period?.end == period?.end &&
      other.periodLabel == periodLabel &&
      _setEq(other.accountIds, accountIds) &&
      _setEq(other.types, types);

  @override
  int get hashCode => Object.hash(
        period?.start,
        period?.end,
        periodLabel,
        Object.hashAllUnordered(accountIds),
        Object.hashAllUnordered(types),
      );

  static bool _setEq<T>(Set<T> a, Set<T> b) =>
      a.length == b.length && a.containsAll(b);
}

/// Applies [filter] to [entries]. Period bounds are inclusive to whole-day
/// granularity on both ends. Adjustments always survive the type filter.
List<LedgerEntry> applyTransactionFilter(
  List<LedgerEntry> entries,
  TransactionFilter filter,
) {
  final period = filter.period;
  DateTime? start, end;
  if (period != null) {
    start = DateTime(period.start.year, period.start.month, period.start.day);
    end = DateTime(period.end.year, period.end.month, period.end.day);
  }
  return entries.where((e) {
    if (start != null && end != null) {
      final d = DateTime(
          e.occurredAt.year, e.occurredAt.month, e.occurredAt.day);
      if (d.isBefore(start) || d.isAfter(end)) return false;
    }
    if (filter.accountIds.isNotEmpty &&
        !filter.accountIds.contains(e.accountId)) {
      return false;
    }
    if (filter.types.isNotEmpty &&
        e.type != LedgerEntryType.adjustment &&
        !filter.types.contains(e.type)) {
      return false;
    }
    return true;
  }).toList();
}

/// The default filter: the whole current month, labelled 'Bu oy'.
TransactionFilter currentMonthFilter(DateTime now) {
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 0); // last day of month
  return TransactionFilter(
    period: DateTimeRange(start: start, end: end),
    periodLabel: 'Bu oy',
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/transactions/transaction_filter_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/transactions/transaction_filter.dart test/core/transactions/transaction_filter_test.dart
git commit -m "feat(transactions): pure TransactionFilter model + applyTransactionFilter"
```

---

## Task 2: Row content resolver (title/subtitle) + labels

**Files:**
- Create: `lib/core/transactions/transaction_row_content.dart`
- Test: `test/core/transactions/transaction_row_content_test.dart`

**Interfaces:**
- Consumes: `LedgerEntry`, `LedgerEntryType`, `IncomeType` from `core/ledger/ledger_entry.dart`.
- Produces:
  - `String transactionTypeLabel(LedgerEntryType t)` (moved verbatim from the screen).
  - `String incomeTypeLabel(IncomeType t)`
  - `class RowContent { final String title; final String? subtitle; const RowContent(this.title, this.subtitle); }`
  - `RowContent resolveRowContent(LedgerEntry e, {String? accountName, String? categoryName})`

- [ ] **Step 1: Write the failing test**

Create `test/core/transactions/transaction_row_content_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/core/transactions/transaction_row_content.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  LedgerEntry e({
    LedgerEntryType type = LedgerEntryType.expense,
    String? note,
    IncomeType? incomeType,
  }) =>
      LedgerEntry(
        id: 1,
        accountId: 1,
        type: type,
        amount: const Money(-1000, uzs),
        occurredAt: DateTime(2026, 7, 18),
        allocated: const Money(0, uzs),
        note: note,
        incomeType: incomeType,
      );

  test('expense with a note: title=note, subtitle=category', () {
    final r = resolveRowContent(e(note: 'Coca Cola'),
        accountName: 'Naqd', categoryName: 'Oziq-ovqat');
    expect(r.title, 'Coca Cola');
    expect(r.subtitle, 'Oziq-ovqat');
  });

  test('expense without a note: title=category, subtitle=account', () {
    final r = resolveRowContent(e(note: '  '),
        accountName: 'Naqd', categoryName: 'Oziq-ovqat');
    expect(r.title, 'Oziq-ovqat');
    expect(r.subtitle, 'Naqd');
  });

  test('expense without note or category falls back to Chiqim', () {
    final r = resolveRowContent(e(), accountName: 'Naqd');
    expect(r.title, 'Chiqim');
    expect(r.subtitle, 'Naqd');
  });

  test('income without a note uses the income-type label as title', () {
    final r = resolveRowContent(
      e(type: LedgerEntryType.income, incomeType: IncomeType.salary),
      accountName: 'Karta',
    );
    expect(r.title, 'Maosh');
    expect(r.subtitle, 'Karta');
  });

  test('transfer leg keeps its operation label', () {
    final r = resolveRowContent(e(type: LedgerEntryType.transferOut));
    expect(r.title, "O'tkazma (chiqdi)");
    expect(r.subtitle, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/transactions/transaction_row_content_test.dart`
Expected: FAIL — file/symbols undefined.

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/transactions/transaction_row_content.dart`:

```dart
import '../ledger/ledger_entry.dart';

/// A transaction's type label as it appears in history (Velora design §6.6):
/// transfer legs are never shown as income or expense, and balance
/// adjustments are always visibly labeled.
String transactionTypeLabel(LedgerEntryType t) => switch (t) {
      LedgerEntryType.expense => 'Chiqim',
      LedgerEntryType.income => 'Kirim',
      LedgerEntryType.transferOut => 'O\'tkazma (chiqdi)',
      LedgerEntryType.transferIn => 'O\'tkazma (kirdi)',
      LedgerEntryType.adjustment => 'Balans tuzatish',
    };

/// Uzbek labels for income sub-types, shown as a row's category line.
String incomeTypeLabel(IncomeType t) => switch (t) {
      IncomeType.salary => 'Maosh',
      IncomeType.bonus => 'Bonus',
      IncomeType.freelance => 'Frilans',
      IncomeType.refund => 'Qaytarim',
      IncomeType.other => 'Boshqa',
    };

/// The two text lines of a history row: a primary [title] and an optional
/// [subtitle]. A null subtitle renders as a single-line row.
class RowContent {
  final String title;
  final String? subtitle;
  const RowContent(this.title, this.subtitle);
}

/// Resolves a row's title/subtitle. The user's note ("what it was spent on")
/// leads when present; otherwise the category / income-type / operation label
/// is promoted to the title and the account name drops to the subtitle, so the
/// two lines never repeat the same text.
RowContent resolveRowContent(
  LedgerEntry e, {
  String? accountName,
  String? categoryName,
}) {
  String? clean(String? s) =>
      (s != null && s.trim().isNotEmpty) ? s.trim() : null;
  final note = clean(e.note);
  final acc = clean(accountName);

  switch (e.type) {
    case LedgerEntryType.expense:
      final cat = clean(categoryName) ?? 'Chiqim';
      return note != null ? RowContent(note, cat) : RowContent(cat, acc);
    case LedgerEntryType.income:
      final label =
          e.incomeType != null ? incomeTypeLabel(e.incomeType!) : 'Kirim';
      return note != null ? RowContent(note, label) : RowContent(label, acc);
    case LedgerEntryType.transferOut:
    case LedgerEntryType.transferIn:
    case LedgerEntryType.adjustment:
      final op = transactionTypeLabel(e.type);
      return note != null ? RowContent(note, op) : RowContent(op, acc);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/transactions/transaction_row_content_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/transactions/transaction_row_content.dart test/core/transactions/transaction_row_content_test.dart
git commit -m "feat(transactions): pure row-content resolver + income-type labels"
```

---

## Task 3: Providers — categories map + filter state

**Files:**
- Modify: `lib/providers/app_providers.dart`
- Create: `lib/features/transactions/transactions_filter_provider.dart`
- Test: `test/features/transactions/transactions_filter_widget_test.dart` (create now with a provider-default test; expanded in Task 5)

**Interfaces:**
- Consumes: `categoryRepositoryProvider` (exists in `app_providers.dart`), `Category`, `currentMonthFilter`.
- Produces:
  - `categoriesProvider` — `FutureProvider<List<Category>>`.
  - `transactionFilterProvider` — `StateProvider<TransactionFilter>` defaulting to `currentMonthFilter(DateTime.now())`.

- [ ] **Step 1: Add the categories provider**

In `lib/providers/app_providers.dart`, immediately after the existing
`categoryRepositoryProvider` (around line 64-65), add:

```dart
/// Every category (including archived), used to resolve category names for
/// history rows. Rebuilds when the ledger revision changes so a newly added
/// category appears without a manual refresh.
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  ref.watch(ledgerRevisionProvider);
  return ref.watch(categoryRepositoryProvider).list(includeArchived: true);
});
```

Confirm `Category` is imported — `app_providers.dart` already imports
`../data/categories/category_model.dart` (verified). If not, add it.

- [ ] **Step 2: Create the filter state provider**

Create `lib/features/transactions/transactions_filter_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/transactions/transaction_filter.dart';

/// The active history filter. Session-only (not persisted). Defaults to the
/// current month so history opens on the same scope the old "BU OY" hero used.
final transactionFilterProvider = StateProvider<TransactionFilter>(
  (ref) => currentMonthFilter(DateTime.now()),
);
```

- [ ] **Step 3: Write a provider-default test**

Create `test/features/transactions/transactions_filter_widget_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:financial_assistant/core/transactions/transaction_filter.dart';
import 'package:financial_assistant/features/transactions/transactions_filter_provider.dart';

void main() {
  test('filter defaults to the current month', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final f = c.read(transactionFilterProvider);
    expect(f.periodLabel, 'Bu oy');
    expect(f.period, isNotNull);
  });

  test('overriding the filter to all-time widens it', () {
    final c = ProviderContainer(overrides: [
      transactionFilterProvider.overrideWith((ref) => const TransactionFilter()),
    ]);
    addTearDown(c.dispose);
    expect(c.read(transactionFilterProvider).period, isNull);
  });
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/transactions/transactions_filter_widget_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/providers/app_providers.dart lib/features/transactions/transactions_filter_provider.dart test/features/transactions/transactions_filter_widget_test.dart
git commit -m "feat(transactions): categories provider + session filter state"
```

---

## Task 4: Screen redesign — summary cards + per-transaction cards

**Files:**
- Modify: `lib/features/transactions/transactions_screen.dart` (full rewrite of the body/widgets; keep the async scaffolding)
- Modify: `test/features/transactions/transactions_screen_test.dart`

**Interfaces:**
- Consumes: `transactionsControllerProvider`, `accountsControllerProvider`, `categoriesProvider`, `transactionFilterProvider`, `applyTransactionFilter`, `resolveRowContent`, `transactionTypeLabel`.
- Produces: redesigned `TransactionsScreen`. Widget keys used by tests:
  - `Key('transactions-summary-income')`, `Key('transactions-summary-expense')` on the two summary cards.
  - Each transaction card is a `Dismissible` with key `Key('txn_<id>')` (unchanged).
- Note: this task does NOT add the filter-chips row (Task 5). The screen reads
  the filter provider and applies it, but there is no chip UI yet.

- [ ] **Step 1: Rewrite the screen**

Replace the entire contents of `lib/features/transactions/transactions_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ledger/ledger_entry.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../core/transactions/transaction_filter.dart';
import '../../core/transactions/transaction_row_content.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/velora_async_state.dart';
import '../accounts/accounts_controller.dart';
import 'transactions_controller.dart';
import 'transactions_filter_provider.dart';

IconData _typeIcon(LedgerEntryType t) => switch (t) {
      LedgerEntryType.expense => Icons.arrow_upward,
      LedgerEntryType.income => Icons.arrow_downward,
      LedgerEntryType.transferOut => Icons.call_made,
      LedgerEntryType.transferIn => Icons.call_received,
      LedgerEntryType.adjustment => Icons.tune,
    };

/// The soft tile fill + glyph colour for a row's leading icon. Income leans on
/// the success tint (money in), everything else on the calm plum tint so
/// transfers and adjustments never borrow the income/expense palette.
({Color bg, Color fg}) _iconTones(LedgerEntryType t) => switch (t) {
      LedgerEntryType.income => (
          bg: const Color(0x1F2E9D7C),
          fg: VeloraColors.success,
        ),
      _ => (bg: VeloraColors.plumTint, fg: VeloraColors.plum),
    };

/// The amount colour: income green, expense inkberry, transfers/adjustments
/// neutral so a moved balance never reads as spending or earning (§6.6).
Color _amountColor(LedgerEntryType t) => switch (t) {
      LedgerEntryType.income => VeloraColors.success,
      LedgerEntryType.expense => VeloraColors.inkberry,
      _ => VeloraColors.muted,
    };

/// Signed, currency-formatted amount with an explicit `+` on income.
String _amountText(LedgerEntry e) {
  final formatted = e.amount.format();
  if (e.type == LedgerEntryType.income && !e.amount.isNegative) {
    return '+$formatted';
  }
  return formatted;
}

String _timeLabel(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// The signed income+expense net for a set of entries. Transfers and balance
/// adjustments are excluded so they never distort a day's spend/earn figure.
Money _incomeExpenseNet(Iterable<LedgerEntry> entries) {
  var minor = 0;
  Money? sample;
  for (final e in entries) {
    if (e.type == LedgerEntryType.income ||
        e.type == LedgerEntryType.expense) {
      minor += e.amount.minorUnits;
      sample ??= e.amount;
    }
  }
  final currency = sample?.currency ?? entries.first.amount.currency;
  return Money(minor, currency);
}

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(transactionsControllerProvider);
    final filter = ref.watch(transactionFilterProvider);
    final nameById = <int, String>{
      for (final a in ref.watch(accountsControllerProvider).asData?.value ??
          const <AccountWithBalance>[])
        a.account.id: a.account.name,
    };
    final categoryById = <int, String>{
      for (final c in ref.watch(categoriesProvider).asData?.value ??
          const <dynamic>[])
        c.id as int: c.name as String,
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tranzaksiyalar'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          color: VeloraColors.plum,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => VeloraErrorState(
          message: 'Xatolik yuz berdi',
          onRetry: () => ref.invalidate(transactionsControllerProvider),
        ),
        data: (all) {
          // A totally empty ledger keeps the original first-transaction nudge
          // (no chips, no summary) — there is nothing to filter yet. Only once
          // entries exist do the filter chips + summary cards appear, and an
          // over-narrow filter shows the "widen your filter" message instead.
          if (all.isEmpty) {
            return const VeloraEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Hali tranzaksiya yo\'q',
              message: 'Chiqim yoki kirim qo\'shsangiz, shu yerda ko\'rinadi.',
            );
          }
          final items = applyTransactionFilter(all, filter);
          return _TransactionsBody(
            entries: items,
            nameById: nameById,
            categoryById: categoryById,
          );
        },
      ),
    );
  }
}

/// The scrollable body: two summary cards, then the day-grouped list. When the
/// filter empties the list the summary cards still render (as zero) so the user
/// keeps context while widening the filter.
class _TransactionsBody extends StatelessWidget {
  const _TransactionsBody({
    required this.entries,
    required this.nameById,
    required this.categoryById,
  });

  final List<LedgerEntry> entries;
  final Map<int, String> nameById;
  final Map<int, String> categoryById;

  @override
  Widget build(BuildContext context) {
    final groups = <DateTime, List<LedgerEntry>>{};
    for (final entry in entries) {
      final day = DateTime(
          entry.occurredAt.year, entry.occurredAt.month, entry.occurredAt.day);
      groups.putIfAbsent(day, () => []).add(entry);
    }
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      // Bottom padding clears the global floating "Chiqim" FAB.
      padding: const EdgeInsets.fromLTRB(
        VeloraSpacing.lg,
        VeloraSpacing.sm,
        VeloraSpacing.lg,
        88,
      ),
      children: [
        _SummaryCards(entries: entries),
        const SizedBox(height: VeloraSpacing.lg),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: VeloraSpacing.xl),
            child: VeloraEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Tranzaksiya topilmadi',
              message: 'Tanlangan filtrga mos yozuv yo\'q. Filtrni kengaytiring.',
            ),
          )
        else
          for (final day in days) ...[
            _DayHeader(
              label: _groupLabel(day),
              net: _incomeExpenseNet(groups[day]!),
            ),
            const SizedBox(height: VeloraSpacing.sm),
            for (final entry in groups[day]!) ...[
              _TransactionCard(
                entry: entry,
                accountName: nameById[entry.accountId],
                categoryName: entry.categoryId == null
                    ? null
                    : categoryById[entry.categoryId],
              ),
              const SizedBox(height: VeloraSpacing.sm),
            ],
            const SizedBox(height: VeloraSpacing.md),
          ],
      ],
    );
  }

  String _groupLabel(DateTime day) {
    final today = DateTime.now();
    final isToday = day.year == today.year &&
        day.month == today.month &&
        day.day == today.day;
    if (isToday) return 'Bugun';
    final yesterday = today.subtract(const Duration(days: 1));
    final isYesterday = day.year == yesterday.year &&
        day.month == yesterday.month &&
        day.day == yesterday.day;
    if (isYesterday) return 'Kecha';
    return '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }
}

/// Two equal-width cards: total income (left) and total expense (right) over
/// the filtered set.
class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.entries});

  final List<LedgerEntry> entries;

  @override
  Widget build(BuildContext context) {
    final currency = entries.isNotEmpty
        ? entries.first.amount.currency
        : _incomeExpenseNet(entries).currency;
    var incomeMinor = 0;
    var expenseMinor = 0;
    for (final e in entries) {
      if (e.type == LedgerEntryType.income) incomeMinor += e.amount.minorUnits;
      if (e.type == LedgerEntryType.expense) {
        expenseMinor += e.amount.minorUnits;
      }
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _SummaryCard(
              cardKey: const Key('transactions-summary-income'),
              label: 'Kirim',
              value: '+${Money(incomeMinor, currency).formatNumber()}',
              color: VeloraColors.success,
              icon: Icons.arrow_downward,
            ),
          ),
          const SizedBox(width: VeloraSpacing.md),
          Expanded(
            child: _SummaryCard(
              cardKey: const Key('transactions-summary-expense'),
              label: 'Chiqim',
              value: Money(expenseMinor, currency).formatNumber(),
              color: VeloraColors.inkberry,
              icon: Icons.arrow_upward,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.cardKey,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final Key cardKey;
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: cardKey,
      padding: const EdgeInsets.all(VeloraSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(VeloraRadii.card),
        border: Border.all(color: VeloraColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(VeloraRadii.control),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: VeloraSpacing.sm),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: VeloraColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: VeloraSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A day divider: the human label ("Bugun") + "Sarflangan" on the left, that
/// day's signed income+expense net on the right.
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label, required this.net});

  final String label;
  final Money net;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: VeloraSpacing.xs,
        end: VeloraSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: VeloraColors.inkberry,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Sarflangan',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: VeloraColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: VeloraSpacing.sm),
          Text(
            net.formatNumber(),
            style: theme.textTheme.labelLarge?.copyWith(
                color: VeloraColors.muted, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// One transaction as its own rounded card (Click-style): leading icon, a
/// title/subtitle column, and a right column with the amount over the time.
class _TransactionCard extends ConsumerWidget {
  const _TransactionCard({
    required this.entry,
    this.accountName,
    this.categoryName,
  });

  final LedgerEntry entry;
  final String? accountName;
  final String? categoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tones = _iconTones(entry.type);
    final content = resolveRowContent(
      entry,
      accountName: accountName,
      categoryName: categoryName,
    );

    return Dismissible(
      key: Key('txn_${entry.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(VeloraRadii.card),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: VeloraSpacing.lg),
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tranzaksiyani o\'chirish'),
          content: const Text(
              'Bu tranzaksiyani o\'chirmoqchimisiz? Bu amalni ortga qaytarib bo\'lmaydi.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Bekor qilish'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('O\'chirish'),
            ),
          ],
        ),
      ).then((confirmed) => confirmed ?? false),
      onDismissed: (_) =>
          ref.read(transactionsControllerProvider.notifier).delete(entry.id),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(VeloraRadii.card),
          border: Border.all(color: VeloraColors.line),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: VeloraSpacing.md,
          vertical: VeloraSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tones.bg,
                borderRadius: BorderRadius.circular(VeloraRadii.control),
              ),
              child: Icon(_typeIcon(entry.type), size: 22, color: tones.fg),
            ),
            const SizedBox(width: VeloraSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (content.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      content.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: VeloraColors.muted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: VeloraSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    _amountText(entry),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: _amountColor(entry.type),
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _timeLabel(entry.occurredAt),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: VeloraColors.muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Update the existing screen test for the new anatomy**

In `test/features/transactions/transactions_screen_test.dart`, the seeded
expense (categoryId 1, no note) now renders title `Oziq-ovqat` (not `Chiqim`),
and the default month filter could hide fixed-date seed data. Apply two changes
to BOTH `testWidgets` that pump a `TransactionsScreen`:

1. Add the filter override so seed data is always visible. Change every
   `UncontrolledProviderScope(container: container, ...)` — but these tests build
   the container directly, so instead override at the container level. Replace the
   `ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)])`
   creations with the import + override below.

Add import at the top of the file:

```dart
import 'package:financial_assistant/core/transactions/transaction_filter.dart';
import 'package:financial_assistant/features/transactions/transactions_filter_provider.dart';
```

In `seeded()` change the container construction to:

```dart
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      transactionFilterProvider.overrideWith((ref) => const TransactionFilter()),
    ]);
```

And in the transfer/adjustment test change its container construction to:

```dart
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      transactionFilterProvider.overrideWith((ref) => const TransactionFilter()),
    ]);
```

2. Replace the three `expect(find.text('Chiqim'), ...)` assertions in the two
   swipe tests. The seeded expense now shows `Oziq-ovqat` as its title. Change:

- `expect(find.text('Chiqim'), findsOneWidget);` (after first pump, both tests)
  → `expect(find.text('Oziq-ovqat'), findsOneWidget);`
- In the cancel test, the final `expect(find.text('Chiqim'), findsOneWidget);`
  → `expect(find.text('Oziq-ovqat'), findsOneWidget);`

The transfer/adjustment test's assertions (`O'tkazma (chiqdi)` etc.) are
unchanged — those labels are still the row titles (transfers have no note).

- [ ] **Step 3: Run the screen tests**

Run: `flutter test test/features/transactions/transactions_screen_test.dart`
Expected: PASS (3 tests). If the seeded expense title assertion fails because
categories did not load, ensure `pumpAndSettle()` runs after pumping (it already
does) so `categoriesProvider` resolves.

- [ ] **Step 4: Update + regenerate the transactions goldens**

`test/goldens/existing_flow_gallery_test.dart` has a `Transactions / history`
group. Two changes:

1. In its `seeded(tester)` helper, right before `return container;`, pin the
   filter to all-time so the two seeded goldens never drop the "Kecha"
   adjustment on the 1st of a month:

```dart
      container.read(transactionFilterProvider.notifier).state =
          const TransactionFilter();
```

   Add the imports if missing:

```dart
import 'package:financial_assistant/core/transactions/transaction_filter.dart';
import 'package:financial_assistant/features/transactions/transactions_filter_provider.dart';
```

2. The two seeded goldens (`transactions-light-390.png`,
   `transactions-dark-320-scale200.png`) legitimately change (new card layout +
   summary cards). The `empty` golden is UNCHANGED — an empty ledger now hits the
   `all.isEmpty` guard and renders the identical original nudge. `loading` and
   `error` goldens are unchanged.

Run the full suite: `flutter test`
Expected: only the two seeded transactions goldens fail. Regenerate just those:
`flutter test test/goldens/existing_flow_gallery_test.dart --update-goldens`
Then re-run `flutter test` and confirm green. Review the two regenerated PNGs
look like the intended Click-style layout before committing.

- [ ] **Step 5: Commit**

```bash
git add lib/features/transactions/transactions_screen.dart \
  test/features/transactions/transactions_screen_test.dart \
  test/goldens/existing_flow_gallery_test.dart \
  test/goldens/baselines/transactions-light-390.png \
  test/goldens/baselines/transactions-dark-320-scale200.png
git commit -m "feat(transactions): Click-style per-txn cards + income/expense summary cards"
```

---

## Task 5: Filter chips row + bottom sheets

**Files:**
- Create: `lib/features/transactions/transaction_filter_sheets.dart`
- Modify: `lib/features/transactions/transactions_screen.dart` (add chips row above the list)
- Modify: `test/features/transactions/transactions_filter_widget_test.dart` (add behaviour tests)

**Interfaces:**
- Consumes: `transactionFilterProvider`, `accountsControllerProvider`,
  `TransactionFilter`, `currentMonthFilter`, `VeloraSheetScaffold`.
- Produces:
  - `showPeriodFilterSheet(BuildContext, WidgetRef)`,
    `showAccountFilterSheet(BuildContext, WidgetRef)`,
    `showTypeFilterSheet(BuildContext, WidgetRef)`.
  - `_FilterChipsRow` widget inside the screen.
  - Chip keys for tests: `Key('filter-chip-period')`, `Key('filter-chip-account')`,
    `Key('filter-chip-type')`.

- [ ] **Step 1: Create the filter sheets**

Create `lib/features/transactions/transaction_filter_sheets.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ledger/ledger_entry.dart';
import '../../core/theme/velora_tokens.dart';
import '../../core/transactions/transaction_filter.dart';
import '../../ui/components/velora_button.dart'; // exports VeloraPrimaryButton
import '../../ui/components/velora_sheet.dart';
import '../accounts/accounts_controller.dart';
import 'transactions_filter_provider.dart';

/// The three "O'tkazma"-grouped operation choices offered to the user.
const _typeChoices = <({String label, Set<LedgerEntryType> types})>[
  (label: 'Kirim', types: {LedgerEntryType.income}),
  (label: 'Chiqim', types: {LedgerEntryType.expense}),
  (
    label: "O'tkazma",
    types: {LedgerEntryType.transferOut, LedgerEntryType.transferIn}
  ),
];

Future<void> showPeriodFilterSheet(BuildContext context, WidgetRef ref) async {
  final current = ref.read(transactionFilterProvider);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _PeriodSheet(initial: current),
  );
}

Future<void> showAccountFilterSheet(BuildContext context, WidgetRef ref) async {
  final accounts = await ref.read(accountsControllerProvider.future);
  if (!context.mounted) return;
  final current = ref.read(transactionFilterProvider);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _AccountSheet(
      accounts: accounts,
      initial: current.accountIds,
    ),
  );
}

Future<void> showTypeFilterSheet(BuildContext context, WidgetRef ref) async {
  final current = ref.read(transactionFilterProvider);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _TypeSheet(initial: current.types),
  );
}

class _PeriodSheet extends ConsumerStatefulWidget {
  const _PeriodSheet({required this.initial});
  final TransactionFilter initial;
  @override
  ConsumerState<_PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends ConsumerState<_PeriodSheet> {
  DateTime? _start;
  DateTime? _end;
  String? _label;

  @override
  void initState() {
    super.initState();
    _start = widget.initial.period?.start;
    _end = widget.initial.period?.end;
    _label = widget.initial.periodLabel;
  }

  void _preset(String label, DateTimeRange range) {
    setState(() {
      _start = range.start;
      _end = range.end;
      _label = label;
    });
  }

  String _fmt(DateTime? d) => d == null
      ? 'KK.OO.YYYY'
      : '${d.day.toString().padLeft(2, '0')}.'
          '${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _pick({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _start : _end) ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
      _label = null; // a manual edit is a custom range
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final presets = <({String label, DateTimeRange range})>[
      (label: 'Bugun', range: DateTimeRange(start: today, end: today)),
      (
        label: 'Kecha',
        range: DateTimeRange(
          start: today.subtract(const Duration(days: 1)),
          end: today.subtract(const Duration(days: 1)),
        )
      ),
      (
        label: "O'tgan hafta",
        range: DateTimeRange(
            start: today.subtract(const Duration(days: 7)), end: today)
      ),
      (
        label: "O'tgan oy",
        range: DateTimeRange(
            start: DateTime(now.year, now.month - 1, 1),
            end: DateTime(now.year, now.month, 0))
      ),
      (label: 'Bu oy', range: currentMonthFilter(now).period!),
    ];

    return VeloraSheetScaffold(
      title: 'Davr',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _DateField(
                    label: 'Sanadan',
                    value: _fmt(_start),
                    onTap: () => _pick(isStart: true)),
              ),
              const SizedBox(width: VeloraSpacing.md),
              Expanded(
                child: _DateField(
                    label: 'Sanagacha',
                    value: _fmt(_end),
                    onTap: () => _pick(isStart: false)),
              ),
            ],
          ),
          const SizedBox(height: VeloraSpacing.lg),
          Wrap(
            spacing: VeloraSpacing.sm,
            runSpacing: VeloraSpacing.sm,
            children: [
              for (final p in presets)
                ChoiceChip(
                  label: Text(p.label),
                  selected: _label == p.label,
                  onSelected: (_) => _preset(p.label, p.range),
                ),
            ],
          ),
        ],
      ),
      primaryAction: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () {
                ref.read(transactionFilterProvider.notifier).update(
                    (f) => f.copyWith(clearPeriod: true));
                Navigator.of(context).pop();
              },
              child: const Text("O'chirish"),
            ),
          ),
          const SizedBox(width: VeloraSpacing.md),
          Expanded(
            child: VeloraPrimaryButton(
              label: "Ko'rsatish",
              onPressed: () {
                if (_start != null && _end != null) {
                  final s = _start!;
                  final e = _end!;
                  final range = s.isAfter(e)
                      ? DateTimeRange(start: e, end: s)
                      : DateTimeRange(start: s, end: e);
                  ref.read(transactionFilterProvider.notifier).update(
                        (f) => f.copyWith(
                          period: range,
                          periodLabel: _label ??
                              '${_fmt(range.start)}–${_fmt(range.end)}',
                        ),
                      );
                }
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField(
      {required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: VeloraColors.muted)),
        const SizedBox(height: VeloraSpacing.xs),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(VeloraRadii.control),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: VeloraSpacing.md, vertical: VeloraSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(VeloraRadii.control),
              border: Border.all(color: VeloraColors.line),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium),
                ),
                const Icon(Icons.calendar_today,
                    size: 18, color: VeloraColors.muted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountSheet extends ConsumerStatefulWidget {
  const _AccountSheet({required this.accounts, required this.initial});
  final List<AccountWithBalance> accounts;
  final Set<int> initial;
  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  late Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initial};
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _selected.isEmpty;
    return VeloraSheetScaffold(
      title: 'Kartalar',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            value: allSelected,
            title: const Text('Barcha kartalar'),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (_) => setState(() => _selected.clear()),
          ),
          for (final a in widget.accounts)
            CheckboxListTile(
              value: _selected.contains(a.account.id),
              title: Text(a.account.name),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (checked) => setState(() {
                if (checked == true) {
                  _selected.add(a.account.id);
                } else {
                  _selected.remove(a.account.id);
                }
              }),
            ),
        ],
      ),
      primaryAction: VeloraPrimaryButton(
        label: "Ko'rsatish",
        onPressed: () {
          ref
              .read(transactionFilterProvider.notifier)
              .update((f) => f.copyWith(accountIds: {..._selected}));
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

class _TypeSheet extends ConsumerStatefulWidget {
  const _TypeSheet({required this.initial});
  final Set<LedgerEntryType> initial;
  @override
  ConsumerState<_TypeSheet> createState() => _TypeSheetState();
}

class _TypeSheetState extends ConsumerState<_TypeSheet> {
  late Set<LedgerEntryType> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initial};
  }

  bool _isOn(Set<LedgerEntryType> group) => group.every(_selected.contains);

  @override
  Widget build(BuildContext context) {
    return VeloraSheetScaffold(
      title: 'Operatsiya turi',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final choice in _typeChoices)
            CheckboxListTile(
              value: _isOn(choice.types),
              title: Text(choice.label),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (checked) => setState(() {
                if (checked == true) {
                  _selected.addAll(choice.types);
                } else {
                  _selected.removeAll(choice.types);
                }
              }),
            ),
        ],
      ),
      primaryAction: VeloraPrimaryButton(
        label: "Ko'rsatish",
        onPressed: () {
          ref
              .read(transactionFilterProvider.notifier)
              .update((f) => f.copyWith(types: {..._selected}));
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
```

CONFIRMED APIs (verified against source): the button component is
`VeloraPrimaryButton({required String label, required VoidCallback? onPressed, bool loading})`
exported from `lib/ui/components/velora_button.dart` — there is no
`VeloraButton` class and no secondary variant, so the "O'chirish" action uses a
plain `TextButton` (as the codebase does elsewhere). `VeloraSheetScaffold` takes
`title`, `body`, `primaryAction`. `LedgerRepository.addIncome` params:
`accountId`, `amount`, `incomeType`, `occurredAt`, `note?`. `addExpense` params:
`accountId`, `amount`, `categoryId?`, `occurredAt`, `note?`, `planned?`.

- [ ] **Step 2: Add the chips row to the screen**

In `lib/features/transactions/transactions_screen.dart`:

1. Add import near the other feature imports:

```dart
import 'transaction_filter_sheets.dart';
```

2. Wrap the non-empty return in a `Column` with a fixed chips row above the
scrolling list. Leave the `all.isEmpty` guard (from Task 4) untouched. Replace
only these lines:

```dart
          final items = applyTransactionFilter(all, filter);
          return _TransactionsBody(
            entries: items,
            nameById: nameById,
            categoryById: categoryById,
          );
```

with:

```dart
          final items = applyTransactionFilter(all, filter);
          return Column(
            children: [
              _FilterChipsRow(filter: filter),
              Expanded(
                child: _TransactionsBody(
                  entries: items,
                  nameById: nameById,
                  categoryById: categoryById,
                ),
              ),
            ],
          );
```

3. Add the `_FilterChipsRow` widget at the end of the file:

```dart
/// The three history filters as tappable chips. A chip is filled and shows its
/// selection when that axis is narrowed; otherwise it shows the bare axis name.
class _FilterChipsRow extends ConsumerWidget {
  const _FilterChipsRow({required this.filter});

  final TransactionFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountLabel = filter.accountIds.isEmpty
        ? 'Kartalar'
        : 'Kartalar · ${filter.accountIds.length} ta';
    final typeLabel = _typeChipLabel(filter.types);
    final periodLabel =
        filter.period == null ? 'Davr' : 'Davr · ${filter.periodLabel ?? ''}';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
          VeloraSpacing.lg, VeloraSpacing.sm, VeloraSpacing.lg, VeloraSpacing.sm),
      child: Row(
        children: [
          _FilterChip(
            chipKey: const Key('filter-chip-account'),
            label: accountLabel,
            active: filter.accountIds.isNotEmpty,
            onTap: () => showAccountFilterSheet(context, ref),
          ),
          const SizedBox(width: VeloraSpacing.sm),
          _FilterChip(
            chipKey: const Key('filter-chip-type'),
            label: typeLabel,
            active: filter.types.isNotEmpty,
            onTap: () => showTypeFilterSheet(context, ref),
          ),
          const SizedBox(width: VeloraSpacing.sm),
          _FilterChip(
            chipKey: const Key('filter-chip-period'),
            label: periodLabel,
            active: filter.period != null,
            onTap: () => showPeriodFilterSheet(context, ref),
          ),
        ],
      ),
    );
  }

  String _typeChipLabel(Set<LedgerEntryType> types) {
    if (types.isEmpty) return 'Operatsiya turi';
    final parts = <String>[
      if (types.contains(LedgerEntryType.income)) 'Kirim',
      if (types.contains(LedgerEntryType.expense)) 'Chiqim',
      if (types.contains(LedgerEntryType.transferOut) ||
          types.contains(LedgerEntryType.transferIn))
        "O'tkazma",
    ];
    return 'Turi · ${parts.join(', ')}';
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.chipKey,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final Key chipKey;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: chipKey,
      color: active ? VeloraColors.plum : theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(VeloraRadii.control),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VeloraRadii.control),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: VeloraSpacing.md, vertical: VeloraSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(VeloraRadii.control),
            border: Border.all(
                color: active ? VeloraColors.plum : VeloraColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: active ? Colors.white : VeloraColors.inkberry,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: VeloraSpacing.xs),
              Icon(Icons.keyboard_arrow_down,
                  size: 18,
                  color: active ? Colors.white : VeloraColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Add behaviour tests**

Append to `test/features/transactions/transactions_filter_widget_test.dart`
(add the widget-test imports at the top of the file):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/transactions/transactions_screen.dart';
```

Add these `testWidgets` inside `main()`:

```dart
  const uzs = CurrencyRegistry.uzs;

  testWidgets('type filter narrows the list and updates the summary',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      // start all-time so both seeded rows are visible regardless of run date
      transactionFilterProvider.overrideWith((ref) => const TransactionFilter()),
    ]);
    addTearDown(container.dispose);
    final accId = await container.read(accountRepositoryProvider).create(
        name: 'Naqd',
        type: AccountType.cash,
        openingBalance: const Money(1000000, uzs),
        icon: 'w');
    await container.read(ledgerRepositoryProvider).addExpense(
        accountId: accId,
        amount: const Money(250000, uzs),
        categoryId: 1,
        occurredAt: DateTime(2026, 7, 18));
    await container.read(ledgerRepositoryProvider).addIncome(
        accountId: accId,
        amount: const Money(500000, uzs),
        incomeType: IncomeType.salary,
        occurredAt: DateTime(2026, 7, 18));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TransactionsScreen()),
    ));
    await tester.pumpAndSettle();

    // Both rows visible initially.
    expect(find.text('Oziq-ovqat'), findsOneWidget);
    expect(find.text('Maosh'), findsOneWidget);

    // Apply an expense-only filter directly through the provider.
    container.read(transactionFilterProvider.notifier).state =
        const TransactionFilter(types: {LedgerEntryType.expense});
    await tester.pumpAndSettle();

    expect(find.text('Oziq-ovqat'), findsOneWidget);
    expect(find.text('Maosh'), findsNothing);
  });

  testWidgets('tapping the Davr chip opens the period sheet', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      transactionFilterProvider.overrideWith((ref) => const TransactionFilter()),
    ]);
    addTearDown(container.dispose);
    await container.read(accountRepositoryProvider).create(
        name: 'Naqd',
        type: AccountType.cash,
        openingBalance: const Money(1000000, uzs),
        icon: 'w');

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TransactionsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('filter-chip-period')));
    await tester.pumpAndSettle();

    // The Davr sheet shows its date-field labels and preset chips.
    expect(find.text('Sanadan'), findsOneWidget);
    expect(find.text("O'tgan hafta"), findsWidgets);
  });
```

NOTE: `addIncome` params are confirmed (`accountId`, `amount`, `incomeType`,
`occurredAt`, `note?`) — the test above matches the real API.

- [ ] **Step 4: Run the filter tests**

Run: `flutter test test/features/transactions/transactions_filter_widget_test.dart`
Expected: PASS (4 tests total).

- [ ] **Step 5: Run analyzer + full suite**

Run: `flutter analyze` then `flutter test`
Expected: no analyzer errors; all tests PASS. Regenerate goldens if a
transactions golden exists and its layout legitimately changed
(`flutter test --update-goldens`, review the diff).

- [ ] **Step 6: Commit**

```bash
git add lib/features/transactions/transaction_filter_sheets.dart lib/features/transactions/transactions_screen.dart test/features/transactions/transactions_filter_widget_test.dart
git commit -m "feat(transactions): filter chips row + card/type/period sheets"
```

---

## Self-Review Notes (for the executor)

- **Spec coverage:** period/card/type filters (Tasks 1,3,5); Click-style row
  anatomy note→title, category→subtitle, amount+time right (Tasks 2,4); two
  summary cards (Task 4); no search (omitted by design); pure testable filter +
  content functions (Tasks 1,2).
- **APIs confirmed against source:** `VeloraPrimaryButton` (not `VeloraButton`),
  `addIncome`/`addExpense` signatures, `VeloraSheetScaffold` params. The one
  remaining unknown is whether a golden test covers this screen — check for a
  transactions golden and regenerate it if the layout legitimately changed.
- **Determinism:** every widget test that renders fixed-date seed data overrides
  `transactionFilterProvider` to `const TransactionFilter()` (all-time) so the
  current-month default never hides seeds on a future run date.
```
