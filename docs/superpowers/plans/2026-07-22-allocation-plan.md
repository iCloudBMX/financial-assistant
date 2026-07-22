# Taqsimlash rejasi (Allocation Plan) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Foydalanuvchi belgilangan manba kartadan boshqa kartalarga belgilangan-summali o'tkazmalar rejasini tuzadi va bitta tugma bilan (tasdiqdan keyin) qo'lda ishga tushiradi; eski abstrakt-buket taqsimlash tizimi butunlay olib tashlanadi.

**Architecture:** Sof hisob (`computePlanTransfers`) I/O'dan ajratilgan; repository barcha o'tkazmalarni bitta `db.transaction`da mavjud `buildTransfer` engine orqali yozadi (atomik); UI `AllocationPlan`/`PlanApplyResult` qiymatlarini iste'mol qiladi. Yangi kod yangi fayl nomlari bilan quriladi, so'ng eski buket klasteri oxirgi taskda o'chiriladi — daraxt har commitda kompilyatsiya bo'ladi.

**Tech Stack:** Flutter, Riverpod (flutter_riverpod 3.x, `StateProvider` `legacy.dart`dan), Drift (SQLite, hand-written migrations), custom "Velora" design system.

## Global Constraints

- Til: barcha foydalanuvchi matni **o'zbekcha** (lotin). Apostrof: `'` (masalan `Jamg'arma`, `qo'llash`).
- Pul: `Money(minorUnits, currency)`; birlamchi valyuta `CurrencyRegistry.uzs`. `Money`da `multiply`/`divide`/`isZero` YO'Q; faqat `add`/`subtract`/`negate`/`compareTo`/`isNegative`/`minorUnits`.
- Result: `sealed Result<T>` — `Ok(value)`/`Err(failure)`, `.isOk`, `.valueOrNull`, `.when(ok:, err:)`. `Result<void>` uchun `const Ok(null)`. `isErr`/`failureOrNull` YO'Q.
- Failure'lar: `PersistenceFailure`/`ValidationFailure`/`NotFoundFailure`/`CurrencyFailure` — bittadan pozitsion `debugDetail` string. UI matni har doim `userMessageFor(Failure)` orqali.
- Migratsiyalar faqat additive uslubda yozilgan; `_hasColumn(m, 'table_name', 'column')` guard bilan idempotent. Jadval/ustun o'chirish faqat raw `customStatement('DROP TABLE IF EXISTS ...')` orqali.
- Drift jadval nomi = klass nomining snake_case'i (masalan `AccountsTable` → `accounts_table`, `AllocationPlanRulesTable` → `allocation_plan_rules_table`). Ustun `allocationSourceAccountId` → `allocation_source_account_id`.
- Drift kod generatsiyasi: schema o'zgargach `dart run build_runner build --delete-conflicting-outputs` ishga tushiriladi (`app_database.g.dart` commit qilinadi).
- Test buyrug'i: `flutter test --concurrency=1`. Bitta fayl: `flutter test <path>`. Golden yangilash: `flutter test <path> --update-goldens`.
- Velora tokenlar: `VeloraColors.{plum,coral,coralTint,plumTint,apricot,apricotTint,blush,inkberry,success,critical,muted,line,onPlumTrack}`; `VeloraSpacing.{xs=4,sm=8,md=12,lg=16,xl=24}`; `VeloraRadii.{control=16,card=22,sheet=28}`.
- **Deviatsiya (spec §5/§8):** `transactions_table.allocatedMinor` ustuni JISMONAN saqlanadi (hot jadval + `LedgerEntry.allocated` bilan bog'liq). Buket kodi olib tashlangach hech kim unga nol bo'lmagan qiymat yozmaydi — u xavfsiz 0 bo'lib qoladi. Faqat ikki buket JADVALI (`allocation_directions_table`, `income_allocations_table`) o'chiriladi.

---

## File Structure

**Yaratiladi:**
- `lib/core/allocation/allocation_plan.dart` — modellar: `AllocationRule`, `AllocationPlan`, `PlannedTransfer`, `PlanShortfall`, `PlanApplyResult`.
- `lib/core/allocation/allocation_plan_engine.dart` — sof `computePlanTransfers(...)`.
- `lib/data/allocation/allocation_plan_repository.dart` — `AllocationPlanRepository` + Drift impl (`plan`/`saveRules`/`setSource`/`applyPlan`).
- `lib/features/allocation/allocation_plan_controller.dart` — `AllocationPlanController` + provider.
- `lib/features/allocation/allocation_plan_screen.dart` — reja tahrirchisi + "Qo'llash".
- `lib/features/allocation/allocation_rule_sheet.dart` — qator qo'shish/tahrirlash sheet.
- `lib/features/allocation/apply_plan_sheet.dart` — tasdiq (preview) sheet.
- Testlar: `test/core/allocation/allocation_plan_engine_test.dart`, `test/data/allocation/allocation_plan_repository_test.dart`, `test/features/allocation/allocation_plan_screen_test.dart`, `test/goldens/allocation_plan_golden_test.dart`.

**O'zgartiriladi:**
- `lib/data/db/tables.dart` — `AllocationPlanRulesTable` qo'shiladi; `AppSettingsTable.allocationSourceAccountId` qo'shiladi; `AllocationDirectionsTable`+`IncomeAllocationsTable` olib tashlanadi.
- `lib/data/db/app_database.dart` — `schemaVersion` 6→7; `@DriftDatabase` tables ro'yxati.
- `lib/data/db/migrations.dart` — v7 branch; eski buket yaratish/seed olib tashlanadi.
- `lib/data/settings/settings_model.dart` — `allocationSourceAccountId` maydoni + `copyWith`.
- `lib/data/settings/settings_repository.dart` — read/write mapping.
- `lib/providers/app_providers.dart` — yangi provayderlar; eski allocation provayderlari olib tashlanadi.
- `lib/features/income_entry/income_entry_sheet.dart` — `showAllocationChoice` olib tashlanadi.
- `lib/features/budgets/budgets_screen.dart` — navigatsiya `AllocationTemplateScreen`→`AllocationPlanScreen`.
- `test/data/db/migration_recovery_test.dart` — `_FailingUpgradeDb.schemaVersion` 7→8.

**O'chiriladi (oxirgi taskda):**
- `lib/core/allocation/allocation_models.dart`, `allocation_engine.dart`, `allocation_dynamic.dart`
- `lib/core/allocation/allocation_result_labels.dart` (agar mavjud bo'lsa)
- `lib/data/allocation/allocation_repository.dart`
- `lib/features/allocation/allocation_controller.dart`, `allocate_sheet.dart`, `income_allocation_prompt.dart`, `variable_budget_offer.dart`, `allocation_template_screen.dart`
- `lib/data/db/default_allocation.dart`
- Ularning testlari: `test/core/allocation/allocation_engine_test.dart`, `test/features/allocation/allocation_controller_test.dart`, va boshqa `test/**/allocation*` (buket) fayllari.

---

## Task 1: Sof modellar va engine

**Files:**
- Create: `lib/core/allocation/allocation_plan.dart`
- Create: `lib/core/allocation/allocation_plan_engine.dart`
- Test: `test/core/allocation/allocation_plan_engine_test.dart`

**Interfaces:**
- Produces: `AllocationRule({required int destinationAccountId, required Money amount, required int sortOrder})`; `AllocationPlan({required int? sourceAccountId, required List<AllocationRule> rules})`; `PlannedTransfer(int destinationAccountId, Money amount)`; `PlanShortfall({required int destinationAccountId, required Money requested, required Money funded})` with `Money get shortBy`; `PlanApplyResult({required List<PlannedTransfer> transfers, required Money totalMoved, required Money sourceRemaining, required List<PlanShortfall> shortfalls})`; `PlanApplyResult computePlanTransfers({required Money sourceBalance, required List<AllocationRule> rules})`.

- [ ] **Step 1: Write the models file**

Create `lib/core/allocation/allocation_plan.dart`:

```dart
import '../money/money.dart';

/// One line of the allocation plan: send [amount] to [destinationAccountId].
/// Only fixed amounts are supported (no percentage / remaining). Lines are
/// applied in [sortOrder] priority order.
class AllocationRule {
  final int destinationAccountId;
  final Money amount;
  final int sortOrder;
  const AllocationRule({
    required this.destinationAccountId,
    required this.amount,
    required this.sortOrder,
  });

  AllocationRule copyWith({int? destinationAccountId, Money? amount, int? sortOrder}) =>
      AllocationRule(
        destinationAccountId: destinationAccountId ?? this.destinationAccountId,
        amount: amount ?? this.amount,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}

/// The single reusable plan: a designated source card plus ordered rules.
class AllocationPlan {
  final int? sourceAccountId;
  final List<AllocationRule> rules; // sortOrder order
  const AllocationPlan({required this.sourceAccountId, required this.rules});
}

/// A resolved transfer the plan will execute: [amount] to [destinationAccountId].
class PlannedTransfer {
  final int destinationAccountId;
  final Money amount;
  const PlannedTransfer(this.destinationAccountId, this.amount);
}

/// A rule the source balance could not fully fund.
class PlanShortfall {
  final int destinationAccountId;
  final Money requested;
  final Money funded;
  const PlanShortfall({
    required this.destinationAccountId,
    required this.requested,
    required this.funded,
  });
  Money get shortBy => requested.subtract(funded);
}

/// The outcome of splitting a source balance across the plan's rules.
class PlanApplyResult {
  final List<PlannedTransfer> transfers;
  final Money totalMoved;
  final Money sourceRemaining;
  final List<PlanShortfall> shortfalls;
  const PlanApplyResult({
    required this.transfers,
    required this.totalMoved,
    required this.sourceRemaining,
    required this.shortfalls,
  });

  bool get hasShortfall => shortfalls.isNotEmpty;
}
```

- [ ] **Step 2: Write the failing engine test**

Create `test/core/allocation/allocation_plan_engine_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/allocation/allocation_plan.dart';
import 'package:financial_assistant/core/allocation/allocation_plan_engine.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  Money m(int v) => Money(v, uzs);

  AllocationRule rule(int dest, int amount, int order) =>
      AllocationRule(destinationAccountId: dest, amount: m(amount), sortOrder: order);

  test('funds every rule exactly when the balance covers them', () {
    final r = computePlanTransfers(sourceBalance: m(2000000), rules: [
      rule(2, 500000, 0),
      rule(3, 300000, 1),
    ]);
    expect(r.transfers.length, 2);
    expect(r.transfers[0].destinationAccountId, 2);
    expect(r.transfers[0].amount, m(500000));
    expect(r.transfers[1].amount, m(300000));
    expect(r.totalMoved, m(800000));
    expect(r.sourceRemaining, m(1200000));
    expect(r.shortfalls, isEmpty);
  });

  test('priority fill: partial last funded rule, later rules get zero', () {
    final r = computePlanTransfers(sourceBalance: m(700000), rules: [
      rule(2, 500000, 0),
      rule(3, 300000, 1),
      rule(4, 200000, 2),
    ]);
    // 500k full, 200k left -> rule 3 gets 200k (short 100k), rule 4 gets 0.
    expect(r.transfers.length, 2);
    expect(r.transfers[0].amount, m(500000));
    expect(r.transfers[1].destinationAccountId, 3);
    expect(r.transfers[1].amount, m(200000));
    expect(r.totalMoved, m(700000));
    expect(r.sourceRemaining, m(0));
    expect(r.shortfalls.length, 2);
    expect(r.shortfalls[0].destinationAccountId, 3);
    expect(r.shortfalls[0].shortBy, m(100000));
    expect(r.shortfalls[1].destinationAccountId, 4);
    expect(r.shortfalls[1].funded, m(0));
    expect(r.shortfalls[1].shortBy, m(200000));
  });

  test('empty rules produce no transfers and keep the full balance', () {
    final r = computePlanTransfers(sourceBalance: m(1000000), rules: const []);
    expect(r.transfers, isEmpty);
    expect(r.totalMoved, m(0));
    expect(r.sourceRemaining, m(1000000));
    expect(r.shortfalls, isEmpty);
  });

  test('zero balance funds nothing; all rules are shortfalls', () {
    final r = computePlanTransfers(sourceBalance: m(0), rules: [rule(2, 500000, 0)]);
    expect(r.transfers, isEmpty);
    expect(r.totalMoved, m(0));
    expect(r.sourceRemaining, m(0));
    expect(r.shortfalls.single.shortBy, m(500000));
  });

  test('negative balance funds nothing and stays negative', () {
    final r = computePlanTransfers(sourceBalance: m(-50000), rules: [rule(2, 100000, 0)]);
    expect(r.transfers, isEmpty);
    expect(r.sourceRemaining, m(-50000));
    expect(r.shortfalls.single.funded, m(0));
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/core/allocation/allocation_plan_engine_test.dart`
Expected: FAIL — `computePlanTransfers` / `allocation_plan_engine.dart` not found.

- [ ] **Step 4: Write the engine**

Create `lib/core/allocation/allocation_plan_engine.dart`:

```dart
import '../money/money.dart';
import 'allocation_plan.dart';

/// Split [sourceBalance] across [rules] in priority (sortOrder) order. Each
/// rule takes its fixed amount, capped by what is still available; a rule that
/// cannot be fully funded records a [PlanShortfall] and later rules see the
/// smaller remainder. A zero/negative balance funds nothing. Rules funded at
/// zero produce no [PlannedTransfer] (a transfer of 0 is meaningless) but are
/// still reported as shortfalls.
PlanApplyResult computePlanTransfers({
  required Money sourceBalance,
  required List<AllocationRule> rules,
}) {
  final currency = sourceBalance.currency;
  var remaining = sourceBalance.minorUnits;
  final transfers = <PlannedTransfer>[];
  final shortfalls = <PlanShortfall>[];
  var moved = 0;

  for (final rule in rules) {
    final requested = rule.amount.minorUnits;
    final available = remaining < 0 ? 0 : remaining;
    final funded = requested > available ? available : requested;

    if (funded < requested) {
      shortfalls.add(PlanShortfall(
        destinationAccountId: rule.destinationAccountId,
        requested: Money(requested, currency),
        funded: Money(funded < 0 ? 0 : funded, currency),
      ));
    }
    if (funded > 0) {
      transfers.add(PlannedTransfer(rule.destinationAccountId, Money(funded, currency)));
      remaining -= funded;
      moved += funded;
    }
  }

  return PlanApplyResult(
    transfers: transfers,
    totalMoved: Money(moved, currency),
    sourceRemaining: Money(remaining, currency),
    shortfalls: shortfalls,
  );
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/core/allocation/allocation_plan_engine_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/core/allocation/allocation_plan.dart lib/core/allocation/allocation_plan_engine.dart test/core/allocation/allocation_plan_engine_test.dart
git commit -m "feat(allocation): pure plan model + computePlanTransfers engine"
```

---

## Task 2: DB — yangi jadval va settings ustuni (additive)

**Files:**
- Modify: `lib/data/db/tables.dart` (add `AllocationPlanRulesTable`; add `AppSettingsTable.allocationSourceAccountId`)
- Modify: `lib/data/db/app_database.dart` (schemaVersion 6→7; add table to `@DriftDatabase`)
- Modify: `lib/data/db/migrations.dart` (add v7 branch — additive only for now)
- Modify: `test/data/db/migration_recovery_test.dart` (`schemaVersion` 7→8)
- Regenerate: `lib/data/db/app_database.g.dart`

**Interfaces:**
- Produces: Drift accessors `db.allocationPlanRulesTable`, `AllocationPlanRulesTableCompanion`; `appSettingsTable` row field `allocationSourceAccountId` (`int?`).

- [ ] **Step 1: Add the new table class**

In `lib/data/db/tables.dart`, after the `IncomeAllocationsTable` class (around line 119), add:

```dart
class AllocationPlanRulesTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get destinationAccountId =>
      integer().references(AccountsTable, #id)();
  IntColumn get amountMinor => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
```

- [ ] **Step 2: Add the settings column**

In `lib/data/db/tables.dart`, inside `AppSettingsTable`, after `safetyBufferMinor` (line ~31), add:

```dart
  IntColumn get allocationSourceAccountId => integer().nullable()();
```

- [ ] **Step 3: Register the table and bump the schema version**

In `lib/data/db/app_database.dart`, add `AllocationPlanRulesTable,` to the `@DriftDatabase(tables: [...])` list (after `IncomeAllocationsTable,`), and change:

```dart
  @override
  int get schemaVersion => 7;
```

- [ ] **Step 4: Add the additive v7 migration branch**

In `lib/data/db/migrations.dart`, inside `onUpgrade`, after the `if (from < 6) { ... }` block, add:

```dart
        if (from < 7) {
          await m.createTable(db.allocationPlanRulesTable);
          if (!await _hasColumn(
              m, 'app_settings_table', 'allocation_source_account_id')) {
            await m.addColumn(db.appSettingsTable,
                db.appSettingsTable.allocationSourceAccountId);
          }
        }
```

(The `DROP TABLE` cleanup for the old bucket tables is added in Task 9, together with the code removal.)

- [ ] **Step 5: Keep the recovery test ahead of the real version**

In `test/data/db/migration_recovery_test.dart`, change `_FailingUpgradeDb`:

```dart
  @override
  int get schemaVersion => 8; // stay ahead of the real version (now 7)
```

- [ ] **Step 6: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `app_database.g.dart` regenerates with `allocationPlanRulesTable` accessor + `allocationSourceAccountId` on the settings row. No errors.

- [ ] **Step 7: Run migration + a broad sanity test**

Run: `flutter test test/data/db/migration_recovery_test.dart`
Expected: PASS. Then run: `flutter test test/data/settings/settings_repository_test.dart` — Expected: PASS (schema still opens cleanly).

- [ ] **Step 8: Commit**

```bash
git add lib/data/db/tables.dart lib/data/db/app_database.dart lib/data/db/migrations.dart lib/data/db/app_database.g.dart test/data/db/migration_recovery_test.dart
git commit -m "feat(db): add allocation_plan_rules table + settings source column (v7)"
```

---

## Task 3: Settings model + repository mapping

**Files:**
- Modify: `lib/data/settings/settings_model.dart`
- Modify: `lib/data/settings/settings_repository.dart`
- Test: `test/data/settings/settings_repository_test.dart` (add a round-trip case)

**Interfaces:**
- Consumes: `db.appSettingsTable` row field `allocationSourceAccountId` (Task 2).
- Produces: `AppSettings.allocationSourceAccountId` (`int?`) + `copyWith(allocationSourceAccountId: ...)`.

- [ ] **Step 1: Write the failing round-trip test**

In `test/data/settings/settings_repository_test.dart`, add inside `main`:

```dart
  test('allocationSourceAccountId round-trips (and defaults to null)', () async {
    final base = await repo.read();
    expect(base.allocationSourceAccountId, isNull);
    await repo.write(base.copyWith(allocationSourceAccountId: 7));
    final back = await repo.read();
    expect(back.allocationSourceAccountId, 7);
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/settings/settings_repository_test.dart`
Expected: FAIL — `copyWith` has no `allocationSourceAccountId` param.

- [ ] **Step 3: Add the field to the model**

In `lib/data/settings/settings_model.dart`:
- Add field after `safetyBuffer`: `final int? allocationSourceAccountId;`
- Add to the constructor (optional, defaults null): `this.allocationSourceAccountId,`
- Add to `copyWith` params: `int? allocationSourceAccountId,` and in the body: `allocationSourceAccountId: allocationSourceAccountId ?? this.allocationSourceAccountId,`

- [ ] **Step 4: Map it in the repository**

In `lib/data/settings/settings_repository.dart`:
- In `read()`, add to the `AppSettings(...)` args: `allocationSourceAccountId: row.allocationSourceAccountId,`
- In `write()`, add to the `AppSettingsTableCompanion(...)`: `allocationSourceAccountId: Value(s.allocationSourceAccountId),`

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/data/settings/settings_repository_test.dart`
Expected: PASS (all cases, including the new one).

- [ ] **Step 6: Commit**

```bash
git add lib/data/settings/settings_model.dart lib/data/settings/settings_repository.dart test/data/settings/settings_repository_test.dart
git commit -m "feat(settings): persist allocationSourceAccountId"
```

---

## Task 4: Repository — read plan, save rules, set source, apply (atomic)

**Files:**
- Create: `lib/data/allocation/allocation_plan_repository.dart`
- Test: `test/data/allocation/allocation_plan_repository_test.dart`

**Interfaces:**
- Consumes: `computePlanTransfers` (Task 1) is NOT used here; the repo receives already-resolved `List<PlannedTransfer>`. Uses `buildTransfer` (`lib/core/ledger/balance_engine.dart`) → `TransferDraft(outEntry, inEntry)`; `AccountRepository.byId(int) → Future<Account?>`; Drift accessors from Task 2.
- Produces: `abstract class AllocationPlanRepository` with `Future<AllocationPlan> plan()`, `Future<void> saveRules(List<AllocationRule>)`, `Future<void> setSource(int?)`, `Future<Result<void>> applyPlan(int sourceId, List<PlannedTransfer> transfers)`; `class DriftAllocationPlanRepository(AppDatabase db, AccountRepository accounts)`.

- [ ] **Step 1: Write the failing repository test**

Create `test/data/allocation/allocation_plan_repository_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/allocation/allocation_plan.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/accounts/account_repository.dart';
import 'package:financial_assistant/data/allocation/allocation_plan_repository.dart';
import 'package:financial_assistant/data/db/app_database.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  Money m(int v) => Money(v, uzs);

  late AppDatabase db;
  late AccountRepository accounts;
  late AllocationPlanRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    accounts = DriftAccountRepository(db);
    repo = DriftAllocationPlanRepository(db, accounts);
  });
  tearDown(() => db.close());

  Future<int> makeAccount(String name, {int opening = 0, String role = 'spending'}) {
    return db.into(db.accountsTable).insert(AccountsTableCompanion.insert(
          name: name,
          type: 'bankCard',
          openingBalanceMinor: Value(opening),
          role: Value(role),
        ));
  }

  test('plan() is empty by default (no source, no rules)', () async {
    final p = await repo.plan();
    expect(p.sourceAccountId, isNull);
    expect(p.rules, isEmpty);
  });

  test('setSource + saveRules round-trip in sortOrder', () async {
    final src = await makeAccount('Sarf', opening: 3000000);
    final dst1 = await makeAccount('Kredit', role: 'credit');
    final dst2 = await makeAccount('Jamgarma', role: 'savings');
    await repo.setSource(src);
    await repo.saveRules([
      AllocationRule(destinationAccountId: dst1, amount: m(500000), sortOrder: 0),
      AllocationRule(destinationAccountId: dst2, amount: m(300000), sortOrder: 1),
    ]);
    final p = await repo.plan();
    expect(p.sourceAccountId, src);
    expect(p.rules.map((r) => r.destinationAccountId), [dst1, dst2]);
    expect(p.rules[0].amount, m(500000));
    expect(p.rules[1].amount, m(300000));
  });

  test('applyPlan moves money atomically and records transfers, not spends', () async {
    final src = await makeAccount('Sarf', opening: 2000000);
    final dst1 = await makeAccount('Kredit', role: 'credit');
    final dst2 = await makeAccount('Jamgarma', role: 'savings');
    final result = await repo.applyPlan(src, [
      PlannedTransfer(dst1, m(500000)),
      PlannedTransfer(dst2, m(300000)),
    ]);
    expect(result.isOk, isTrue);

    // Balances after: source 1.2M, dst1 500k, dst2 300k — computed from the
    // raw ledger rows (opening balance + summed signed entries).
    final entries = await db.select(db.transactionsTable).get();
    int balance(int accId, int opening) =>
        opening + entries.where((e) => e.accountId == accId)
            .fold(0, (s, e) => s + e.amountMinor);
    expect(balance(src, 2000000), 1200000);
    expect(balance(dst1, 0), 500000);
    expect(balance(dst2, 0), 300000);
    // Transfers are transferOut/transferIn, never expense/income.
    expect(entries.every((e) => e.type == 'transferOut' || e.type == 'transferIn'), isTrue);
    // Each transfer pair shares a transferId; two transfers -> 4 rows, 2 ids.
    expect(entries.length, 4);
    expect(entries.map((e) => e.transferId).toSet().length, 2);
  });

  test('applyPlan with a missing destination fails and writes nothing', () async {
    final src = await makeAccount('Sarf', opening: 2000000);
    final result = await repo.applyPlan(src, [
      PlannedTransfer(999999, m(500000)), // no such account
    ]);
    expect(result.isOk, isFalse);
    final entries = await db.select(db.transactionsTable).get();
    expect(entries, isEmpty); // atomic: nothing persisted
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/allocation/allocation_plan_repository_test.dart`
Expected: FAIL — `allocation_plan_repository.dart` not found.

- [ ] **Step 3: Write the repository**

Create `lib/data/allocation/allocation_plan_repository.dart`:

```dart
import 'package:drift/drift.dart';
import '../../core/allocation/allocation_plan.dart';
import '../../core/ledger/balance_engine.dart';
import '../../core/ledger/ledger_entry.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/result/failure.dart';
import '../../core/result/result.dart';
import '../accounts/account_repository.dart';
import '../db/app_database.dart';

abstract class AllocationPlanRepository {
  Future<AllocationPlan> plan();
  Future<void> saveRules(List<AllocationRule> rules);
  Future<void> setSource(int? accountId);

  /// Executes [transfers] from [sourceId] as internal card-to-card transfers
  /// in ONE database transaction — all-or-nothing. Each transfer becomes a
  /// transferOut/transferIn pair (never income/expense).
  Future<Result<void>> applyPlan(int sourceId, List<PlannedTransfer> transfers);
}

class DriftAllocationPlanRepository implements AllocationPlanRepository {
  final AppDatabase db;
  final AccountRepository accounts;
  DriftAllocationPlanRepository(this.db, this.accounts);

  @override
  Future<AllocationPlan> plan() async {
    final settingsRow = await db.select(db.appSettingsTable).getSingle();
    final currency = CurrencyRegistry.byCode(settingsRow.primaryCurrency);
    final rows = await (db.select(db.allocationPlanRulesTable)
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
    final rules = [
      for (final r in rows)
        AllocationRule(
          destinationAccountId: r.destinationAccountId,
          amount: Money(r.amountMinor, currency),
          sortOrder: r.sortOrder,
        ),
    ];
    return AllocationPlan(
      sourceAccountId: settingsRow.allocationSourceAccountId,
      rules: rules,
    );
  }

  @override
  Future<void> saveRules(List<AllocationRule> rules) async {
    await db.transaction(() async {
      await db.delete(db.allocationPlanRulesTable).go();
      for (var i = 0; i < rules.length; i++) {
        final r = rules[i];
        await db.into(db.allocationPlanRulesTable).insert(
              AllocationPlanRulesTableCompanion.insert(
                destinationAccountId: r.destinationAccountId,
                amountMinor: r.amount.minorUnits,
                sortOrder: Value(i),
              ),
            );
      }
    });
  }

  @override
  Future<void> setSource(int? accountId) async {
    await (db.update(db.appSettingsTable)..where((t) => t.id.equals(0))).write(
      AppSettingsTableCompanion(allocationSourceAccountId: Value(accountId)),
    );
  }

  @override
  Future<Result<void>> applyPlan(
      int sourceId, List<PlannedTransfer> transfers) async {
    if (transfers.isEmpty) return const Ok(null);
    final from = await accounts.byId(sourceId);
    if (from == null) {
      return const Err(NotFoundFailure('source account not found'));
    }
    // Resolve and validate every draft BEFORE writing, so a bad transfer
    // aborts the whole apply without a partial write.
    final drafts = <TransferDraft>[];
    final base = DateTime.now();
    for (var i = 0; i < transfers.length; i++) {
      final t = transfers[i];
      final to = await accounts.byId(t.destinationAccountId);
      if (to == null) {
        return const Err(NotFoundFailure('destination account not found'));
      }
      final draft = buildTransfer(
        from: from,
        to: to,
        amount: t.amount,
        occurredAt: base,
        transferId: 'transfer-${base.microsecondsSinceEpoch}-$i',
      );
      final unwrapped = draft.valueOrNull;
      if (unwrapped == null) {
        return draft.when(ok: (_) => const Ok(null), err: (f) => Err<void>(f));
      }
      drafts.add(unwrapped);
    }
    try {
      await db.transaction(() async {
        for (final d in drafts) {
          await _insertDraft(d.outEntry);
          await _insertDraft(d.inEntry);
        }
      });
      return const Ok(null);
    } catch (error) {
      return Err(PersistenceFailure(error.toString()));
    }
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
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/allocation/allocation_plan_repository_test.dart`
Expected: PASS (4 tests). If `buildTransfer`/`TransferDraft` import path differs, confirm it is `package:financial_assistant/core/ledger/balance_engine.dart`.

- [ ] **Step 5: Commit**

```bash
git add lib/data/allocation/allocation_plan_repository.dart test/data/allocation/allocation_plan_repository_test.dart
git commit -m "feat(allocation): plan repository with atomic applyPlan transfers"
```

---

## Task 5: Providers + controller

**Files:**
- Create: `lib/features/allocation/allocation_plan_controller.dart`
- Modify: `lib/providers/app_providers.dart` (add new providers; do NOT remove old ones yet)
- Test: `test/providers/allocation_plan_providers_test.dart`

**Interfaces:**
- Consumes: `AllocationPlanRepository` (Task 4); `databaseProvider`, `accountRepositoryProvider`, `ledgerRevisionProvider` (existing).
- Produces: `allocationPlanRepositoryProvider` (`Provider<AllocationPlanRepository>`); `allocationPlanProvider` (`FutureProvider<AllocationPlan>`); `AllocationPlanController` with `Future<Result<void>> apply(int, List<PlannedTransfer>)`, `Future<void> setSource(int?)`, `Future<void> saveRules(List<AllocationRule>)`; `allocationPlanControllerProvider`.

- [ ] **Step 1: Add the repository + plan providers**

In `lib/providers/app_providers.dart`, near the existing `allocationRepositoryProvider` (line ~184), add (keep the old ones for now):

```dart
final allocationPlanRepositoryProvider = Provider<AllocationPlanRepository>(
  (ref) => DriftAllocationPlanRepository(
    ref.watch(databaseProvider),
    ref.watch(accountRepositoryProvider),
  ),
);

final allocationPlanProvider = FutureProvider<AllocationPlan>((ref) {
  ref.watch(ledgerRevisionProvider);
  return ref.watch(allocationPlanRepositoryProvider).plan();
});
```

Add imports at the top of the file:

```dart
import '../core/allocation/allocation_plan.dart';
import '../data/allocation/allocation_plan_repository.dart';
```

- [ ] **Step 2: Write the controller**

Create `lib/features/allocation/allocation_plan_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/allocation/allocation_plan.dart';
import '../../core/result/result.dart';
import '../../providers/app_providers.dart';

/// Thin command surface over [AllocationPlanRepository]. Every mutation bumps
/// [ledgerRevisionProvider] so balances, the daily limit, and the plan view
/// recompute.
class AllocationPlanController {
  final Ref ref;
  AllocationPlanController(this.ref);

  Future<Result<void>> apply(int sourceId, List<PlannedTransfer> transfers) async {
    final r = await ref
        .read(allocationPlanRepositoryProvider)
        .applyPlan(sourceId, transfers);
    if (r.isOk) ref.read(ledgerRevisionProvider.notifier).state++;
    return r;
  }

  Future<void> setSource(int? accountId) async {
    await ref.read(allocationPlanRepositoryProvider).setSource(accountId);
    ref.read(ledgerRevisionProvider.notifier).state++;
  }

  Future<void> saveRules(List<AllocationRule> rules) async {
    await ref.read(allocationPlanRepositoryProvider).saveRules(rules);
    ref.read(ledgerRevisionProvider.notifier).state++;
  }
}

final allocationPlanControllerProvider =
    Provider<AllocationPlanController>((ref) => AllocationPlanController(ref));
```

- [ ] **Step 3: Write the failing provider test**

Create `test/providers/allocation_plan_providers_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/allocation/allocation_plan.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/features/allocation/allocation_plan_controller.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  Money m(int v) => Money(v, uzs);

  test('apply moves money and the daily limit recomputes from Sarf balance',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    final src = await db.into(db.accountsTable).insert(
        AccountsTableCompanion.insert(
            name: 'Sarf', type: 'bankCard',
            openingBalanceMinor: const Value(3000000), role: const Value('spending')));
    final dst = await db.into(db.accountsTable).insert(
        AccountsTableCompanion.insert(
            name: 'Zaxira', type: 'bankCard',
            openingBalanceMinor: const Value(0), role: const Value('reserve')));

    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    final before = await container.read(safeLimitProvider.future);
    expect(before.spendable, m(3000000));

    final controller = container.read(allocationPlanControllerProvider);
    final r = await controller.apply(src, [PlannedTransfer(dst, m(1000000))]);
    expect(r.isOk, isTrue);

    final after = await container.read(safeLimitProvider.future);
    expect(after.spendable, m(2000000)); // 1M moved to the excluded reserve card
    await db.close();
  });
}
```

- [ ] **Step 4: Run to verify it fails, then passes**

Run: `flutter test test/providers/allocation_plan_providers_test.dart`
Expected: initially FAIL if any import is missing; after Steps 1-2 are in place it should PASS. (If it already passes because Steps 1-2 were written first, that is fine — the assertion still proves wiring.)

- [ ] **Step 5: Commit**

```bash
git add lib/features/allocation/allocation_plan_controller.dart lib/providers/app_providers.dart test/providers/allocation_plan_providers_test.dart
git commit -m "feat(allocation): plan providers + controller"
```

---

## Task 6: UI — rule sheet (add/edit a rule)

**Files:**
- Create: `lib/features/allocation/allocation_rule_sheet.dart`
- Test: `test/features/allocation/allocation_plan_screen_test.dart` (create file; add the rule-sheet case here, extended in Task 7)

**Interfaces:**
- Consumes: `AccountCardPicker`, `VeloraMoneyField`, `VeloraSheetScaffold`, `VeloraPrimaryButton`; `accountsControllerProvider`.
- Produces: `Future<({int destinationAccountId, Money amount})?> showAllocationRuleSheet(BuildContext context, WidgetRef ref, {required int sourceAccountId, int? excludeAccountId, ({int destinationAccountId, Money amount})? initial})`.

- [ ] **Step 1: Write the rule sheet**

Create `lib/features/allocation/allocation_rule_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/account_card_picker.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_money_field.dart';
import '../../ui/components/velora_sheet.dart';
import '../accounts/accounts_controller.dart';

/// Add or edit one plan rule: pick a destination card (never the source) and a
/// fixed amount. Returns the (destinationAccountId, amount) pair, or null on
/// cancel.
Future<({int destinationAccountId, Money amount})?> showAllocationRuleSheet(
  BuildContext context,
  WidgetRef ref, {
  required int sourceAccountId,
  ({int destinationAccountId, Money amount})? initial,
}) async {
  final settings = await ref.read(settingsProvider.future);
  if (!context.mounted) return null;
  return showModalBottomSheet<({int destinationAccountId, Money amount})>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _RuleSheetBody(
      currency: settings.primaryCurrency,
      sourceAccountId: sourceAccountId,
      initial: initial,
    ),
  );
}

class _RuleSheetBody extends ConsumerStatefulWidget {
  const _RuleSheetBody({
    required this.currency,
    required this.sourceAccountId,
    required this.initial,
  });
  final Currency currency;
  final int sourceAccountId;
  final ({int destinationAccountId, Money amount})? initial;

  @override
  ConsumerState<_RuleSheetBody> createState() => _RuleSheetBodyState();
}

class _RuleSheetBodyState extends ConsumerState<_RuleSheetBody> {
  late final TextEditingController _amountCtrl;
  Money? _amount;
  int? _destId;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
        text: widget.initial?.amount.formatNumber() ?? '');
    _amount = widget.initial?.amount;
    _destId = widget.initial?.destinationAccountId;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsControllerProvider);
    return VeloraSheetScaffold(
      title: widget.initial == null ? 'Yangi qator' : 'Qatorni tahrirlash',
      body: accountsAsync.when(
        loading: () => const SizedBox(
            height: 200, child: Center(child: CircularProgressIndicator())),
        error: (_, _) => const SizedBox.shrink(),
        data: (list) {
          // Destination cards = everything except the source card.
          final dests = [
            for (final a in list)
              if (a.account.id != widget.sourceAccountId) a.account
          ];
          final balances = {for (final a in list) a.account.id: a.balance};
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Qaysi kartaga',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: VeloraSpacing.sm),
              AccountCardPicker(
                key: const Key('rule-dest-picker'),
                accounts: dests,
                availableBalances: balances,
                selectedId: _destId,
                onSelected: (id) => setState(() => _destId = id),
              ),
              const SizedBox(height: VeloraSpacing.lg),
              VeloraMoneyField(
                controller: _amountCtrl,
                currency: widget.currency,
                label: 'Summa',
                onChanged: (mv) => setState(() => _amount = mv),
              ),
            ],
          );
        },
      ),
      primaryAction: VeloraPrimaryButton(
        label: 'Saqlash',
        onPressed: (_destId == null ||
                _amount == null ||
                _amount!.minorUnits <= 0)
            ? null
            : () => Navigator.of(context)
                .pop((destinationAccountId: _destId!, amount: _amount!)),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze compiles**

Run: `flutter analyze lib/features/allocation/allocation_rule_sheet.dart`
Expected: No errors (deprecation infos acceptable).

- [ ] **Step 3: Commit**

```bash
git add lib/features/allocation/allocation_rule_sheet.dart
git commit -m "feat(allocation): add/edit rule bottom sheet"
```

---

## Task 7: UI — plan screen + apply/confirm sheet

**Files:**
- Create: `lib/features/allocation/apply_plan_sheet.dart`
- Create: `lib/features/allocation/allocation_plan_screen.dart`
- Test: `test/features/allocation/allocation_plan_screen_test.dart`

**Interfaces:**
- Consumes: `allocationPlanProvider`, `accountsControllerProvider`, `allocationPlanControllerProvider`, `computePlanTransfers`, `showAllocationRuleSheet`; `AccountWithBalance(account, balance)`; account label helpers (`accountRoleLabel`, `accountTypeIcon`).
- Produces: `class AllocationPlanScreen extends ConsumerStatefulWidget` (no ctor args); `Future<bool?> showApplyPlanSheet(BuildContext, {required PlanApplyResult result, required Map<int, String> destNames})`.

- [ ] **Step 1: Write the confirm/apply sheet**

Create `lib/features/allocation/apply_plan_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import '../../core/allocation/allocation_plan.dart';
import '../../core/theme/velora_tokens.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_sheet.dart';

/// Confirm sheet shown before transfers run: each destination + amount, what
/// stays on the source, and any shortfall (colour + icon + text, never colour
/// alone). Returns true to execute.
Future<bool?> showApplyPlanSheet(
  BuildContext context, {
  required PlanApplyResult result,
  required Map<int, String> destNames,
  required String sourceName,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ApplyPlanBody(
      result: result,
      destNames: destNames,
      sourceName: sourceName,
    ),
  );
}

class _ApplyPlanBody extends StatelessWidget {
  const _ApplyPlanBody({
    required this.result,
    required this.destNames,
    required this.sourceName,
  });
  final PlanApplyResult result;
  final Map<int, String> destNames;
  final String sourceName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return VeloraSheetScaffold(
      title: 'Rejani qo\'llash',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (result.transfers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: VeloraSpacing.md),
              child: Text('Ko\'chiriladigan mablag\' yo\'q.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: VeloraColors.muted)),
            )
          else
            for (final t in result.transfers)
              Padding(
                padding: const EdgeInsets.only(bottom: VeloraSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(destNames[t.destinationAccountId] ?? 'Karta',
                          style: theme.textTheme.bodyLarge),
                    ),
                    Text('+${t.amount.format()}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                            color: VeloraColors.success,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
          const Divider(height: VeloraSpacing.lg * 2, color: VeloraColors.line),
          Row(
            children: [
              Expanded(
                child: Text('$sourceName\'da qoladi',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: VeloraColors.muted)),
              ),
              Text(result.sourceRemaining.format(),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          if (result.hasShortfall) ...[
            const SizedBox(height: VeloraSpacing.md),
            Container(
              padding: const EdgeInsets.all(VeloraSpacing.md),
              decoration: BoxDecoration(
                color: VeloraColors.critical.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(VeloraRadii.control),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 18, color: VeloraColors.critical),
                  const SizedBox(width: VeloraSpacing.sm),
                  Expanded(
                    child: Text(
                      'Ba\'zi qatorlar to\'liq to\'lanmadi — kartada mablag\' yetarli emas.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: VeloraColors.critical),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      primaryAction: VeloraPrimaryButton(
        label: 'Bajarish',
        onPressed: result.transfers.isEmpty
            ? null
            : () => Navigator.of(context).pop(true),
      ),
    );
  }
}
```

- [ ] **Step 2: Write the plan screen**

Create `lib/features/allocation/allocation_plan_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/allocation/allocation_plan.dart';
import '../../core/allocation/allocation_plan_engine.dart';
import '../../core/money/money.dart';
import '../../core/result/failure_messages.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/account_card_picker.dart';
import '../../ui/components/app_snackbar.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_card.dart';
import '../accounts/account_labels.dart';
import '../accounts/accounts_controller.dart';
import 'allocation_plan_controller.dart';
import 'allocation_rule_sheet.dart';
import 'apply_plan_sheet.dart';

/// The manual allocation plan: designate a source card, list fixed-amount
/// rules to other cards, and apply them all (after a confirm) as internal
/// transfers. Reached from the Budget page header.
class AllocationPlanScreen extends ConsumerWidget {
  const AllocationPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(allocationPlanProvider);
    final accountsAsync = ref.watch(accountsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Taqsimlash rejasi')),
      body: planAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Xatolik yuz berdi')),
        data: (plan) => accountsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text('Xatolik yuz berdi')),
          data: (accounts) =>
              _PlanBody(plan: plan, accounts: accounts),
        ),
      ),
    );
  }
}

class _PlanBody extends ConsumerWidget {
  const _PlanBody({required this.plan, required this.accounts});
  final AllocationPlan plan;
  final List<AccountWithBalance> accounts;

  Money? _sourceBalance() {
    for (final a in accounts) {
      if (a.account.id == plan.sourceAccountId) return a.balance;
    }
    return null;
  }

  Future<void> _apply(BuildContext context, WidgetRef ref) async {
    final sourceId = plan.sourceAccountId;
    final balance = _sourceBalance();
    if (sourceId == null || balance == null) return;
    final result =
        computePlanTransfers(sourceBalance: balance, rules: plan.rules);
    final destNames = {
      for (final a in accounts) a.account.id: a.account.name,
    };
    final sourceName = destNames[sourceId] ?? 'Manba';
    final ok = await showApplyPlanSheet(context,
        result: result, destNames: destNames, sourceName: sourceName);
    if (ok != true || !context.mounted) return;
    final res = await ref
        .read(allocationPlanControllerProvider)
        .apply(sourceId, result.transfers);
    if (!context.mounted) return;
    res.when(
      ok: (_) => ScaffoldMessenger.of(context).showAutoDismissSnackBar(
        SnackBar(content: Text('${result.totalMoved.format()} ko\'chirildi')),
      ),
      err: (f) => ScaffoldMessenger.of(context).showAutoDismissSnackBar(
        SnackBar(content: Text(userMessageFor(f))),
      ),
    );
  }

  Future<void> _addRule(BuildContext context, WidgetRef ref) async {
    final sourceId = plan.sourceAccountId;
    if (sourceId == null) return;
    final picked =
        await showAllocationRuleSheet(context, ref, sourceAccountId: sourceId);
    if (picked == null) return;
    final next = [
      ...plan.rules,
      AllocationRule(
          destinationAccountId: picked.destinationAccountId,
          amount: picked.amount,
          sortOrder: plan.rules.length),
    ];
    await ref.read(allocationPlanControllerProvider).saveRules(next);
  }

  Future<void> _editRule(
      BuildContext context, WidgetRef ref, int index) async {
    final sourceId = plan.sourceAccountId;
    if (sourceId == null) return;
    final r = plan.rules[index];
    final picked = await showAllocationRuleSheet(context, ref,
        sourceAccountId: sourceId,
        initial: (destinationAccountId: r.destinationAccountId, amount: r.amount));
    if (picked == null) return;
    final next = [...plan.rules];
    next[index] = r.copyWith(
        destinationAccountId: picked.destinationAccountId, amount: picked.amount);
    await ref.read(allocationPlanControllerProvider).saveRules(next);
  }

  Future<void> _deleteRule(WidgetRef ref, int index) async {
    final next = [...plan.rules]..removeAt(index);
    await ref.read(allocationPlanControllerProvider).saveRules(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sourceId = plan.sourceAccountId;
    final balances = {for (final a in accounts) a.account.id: a.balance};
    final nameOf = {for (final a in accounts) a.account.id: a.account.name};
    final canApply = sourceId != null && plan.rules.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(VeloraSpacing.lg),
            children: [
              Text('MANBA KARTA',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: VeloraColors.muted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6)),
              const SizedBox(height: VeloraSpacing.sm),
              AccountCardPicker(
                key: const Key('plan-source-picker'),
                accounts: [for (final a in accounts) a.account],
                availableBalances: balances,
                selectedId: sourceId,
                onSelected: (id) => ref
                    .read(allocationPlanControllerProvider)
                    .setSource(id),
              ),
              const SizedBox(height: VeloraSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Text('Qatorlar',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  TextButton.icon(
                    key: const Key('plan-add-rule'),
                    onPressed: sourceId == null
                        ? null
                        : () => _addRule(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Yangi qator'),
                  ),
                ],
              ),
              const SizedBox(height: VeloraSpacing.sm),
              if (sourceId == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: VeloraSpacing.md),
                  child: Text('Avval manba kartani tanlang.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: VeloraColors.muted)),
                )
              else if (plan.rules.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: VeloraSpacing.md),
                  child: Text('Hali qator yo\'q. "Yangi qator" bilan qo\'shing.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: VeloraColors.muted)),
                )
              else
                for (var i = 0; i < plan.rules.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: VeloraSpacing.sm),
                    child: VeloraCard(
                      onTap: () => _editRule(context, ref, i),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              nameOf[plan.rules[i].destinationAccountId] ??
                                  'O\'chirilgan karta',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          Text(plan.rules[i].amount.format(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                  color: VeloraColors.plum,
                                  fontWeight: FontWeight.w800)),
                          IconButton(
                            key: Key('plan-delete-rule-$i'),
                            icon: const Icon(Icons.remove_circle_outline,
                                color: VeloraColors.critical),
                            onPressed: () => _deleteRule(ref, i),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(VeloraSpacing.lg),
            child: Theme(
              data: theme.copyWith(
                colorScheme: theme.colorScheme.copyWith(
                    primary: VeloraColors.coral, onPrimary: Colors.white),
              ),
              child: VeloraPrimaryButton(
                key: const Key('plan-apply'),
                label: 'Rejani qo\'llash',
                onPressed: canApply ? () => _apply(context, ref) : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

> Implementer note: `account_labels.dart` (`accountRoleLabel`, `accountTypeIcon`) is imported for optional future use in the rows; if the analyzer flags it as unused, either use `accountTypeIcon` for a leading icon on each rule card or drop the import. Prefer adding a leading `Icon(accountTypeIcon(account.type, icon: account.icon))` to each rule row for visual parity with other screens.

- [ ] **Step 3: Write the widget test**

Create `test/features/allocation/allocation_plan_screen_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/allocation/allocation_plan.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/features/allocation/allocation_plan_controller.dart';
import 'package:financial_assistant/features/allocation/allocation_plan_screen.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  Future<(AppDatabase, ProviderContainer, int, int)> seed() async {
    final db = AppDatabase(NativeDatabase.memory());
    final src = await db.into(db.accountsTable).insert(
        AccountsTableCompanion.insert(
            name: 'Sarf', type: 'bankCard',
            openingBalanceMinor: const Value(2000000),
            role: const Value('spending')));
    final dst = await db.into(db.accountsTable).insert(
        AccountsTableCompanion.insert(
            name: 'Kredit', type: 'bankCard',
            openingBalanceMinor: const Value(0), role: const Value('credit')));
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(() {
      container.dispose();
      db.close();
    });
    return (db, container, src, dst);
  }

  testWidgets('shows a hint until a source is chosen', (tester) async {
    final (_, container, _, _) = await seed();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AllocationPlanScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Avval manba kartani tanlang.'), findsOneWidget);
    // Add-rule button disabled with no source chosen.
    final addBtn = tester.widget<TextButton>(
        find.byKey(const Key('plan-add-rule')));
    expect(addBtn.onPressed, isNull);
  });

  testWidgets('applying a saved rule moves money off the source card',
      (tester) async {
    final (db, container, src, dst) = await seed();
    // Pre-seed a source + one 1,000,000 rule to the destination card.
    await container.read(allocationPlanControllerProvider).setSource(src);
    await container.read(allocationPlanControllerProvider).saveRules([
      AllocationRule(
          destinationAccountId: dst,
          amount: const Money(1000000, uzs),
          sortOrder: 0),
    ]);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AllocationPlanScreen()),
    ));
    await tester.pumpAndSettle();

    // The rule row renders the destination name + amount.
    expect(find.text('Kredit'), findsWidgets);

    // Apply -> confirm sheet -> Bajarish.
    await tester.tap(find.byKey(const Key('plan-apply')));
    await tester.pumpAndSettle();
    expect(find.text('Bajarish'), findsOneWidget);
    await tester.tap(find.text('Bajarish'));
    await tester.pumpAndSettle();

    // Source dropped by 1,000,000 (2,000,000 opening -> 1,000,000).
    final entries = await db.select(db.transactionsTable).get();
    int balance(int accId, int opening) =>
        opening +
        entries
            .where((e) => e.accountId == accId)
            .fold(0, (s, e) => s + e.amountMinor);
    expect(balance(src, 2000000), 1000000);
    expect(balance(dst, 0), 1000000);
  });
}
```

- [ ] **Step 4: Run the widget test**

Run: `flutter test test/features/allocation/allocation_plan_screen_test.dart`
Expected: PASS (2 tests — the hint/disabled check and the apply-moves-money flow).

- [ ] **Step 5: Commit**

```bash
git add lib/features/allocation/apply_plan_sheet.dart lib/features/allocation/allocation_plan_screen.dart test/features/allocation/allocation_plan_screen_test.dart
git commit -m "feat(allocation): plan screen + apply/confirm sheet"
```

---

## Task 8: Rewire navigation + income entry

**Files:**
- Modify: `lib/features/budgets/budgets_screen.dart` (navigate to `AllocationPlanScreen`)
- Modify: `lib/features/income_entry/income_entry_sheet.dart` (drop `showAllocationChoice`)

**Interfaces:**
- Consumes: `AllocationPlanScreen` (Task 7).

- [ ] **Step 1: Point the Budget header at the new screen**

In `lib/features/budgets/budgets_screen.dart`:
- Replace the import `import '../allocation/allocation_template_screen.dart';` with `import '../allocation/allocation_plan_screen.dart';`
- In `_PlanHeader`'s `onOpenAllocation` navigation (the `MaterialPageRoute` builder), change `const AllocationTemplateScreen()` to `const AllocationPlanScreen()`.

- [ ] **Step 2: Remove the post-income allocation choice**

In `lib/features/income_entry/income_entry_sheet.dart`:
- Remove the import `import '../allocation/income_allocation_prompt.dart';`
- In `showIncomeEntrySheet`, delete the block:

```dart
  if (saved != null && context.mounted) {
    await showAllocationChoice(context, ref,
        incomeId: saved.incomeId, amount: saved.amount);
  }
```

The income sheet now just saves and closes. The `_save` handler already pops the sheet; no further action needed.

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/features/budgets/budgets_screen.dart lib/features/income_entry/income_entry_sheet.dart`
Expected: No errors. (`showIncomeEntrySheet` may now not use `ref` for allocation — keep `ref` if still used for `settingsProvider`/`accountRepositoryProvider`; it is.)

- [ ] **Step 4: Commit**

```bash
git add lib/features/budgets/budgets_screen.dart lib/features/income_entry/income_entry_sheet.dart
git commit -m "refactor(allocation): route Budget header to plan screen; drop post-income choice"
```

---

## Task 9: Remove the old bucket system + drop tables

**Files:**
- Delete: `lib/core/allocation/allocation_models.dart`, `allocation_engine.dart`, `allocation_dynamic.dart`, `allocation_result_labels.dart` (if present)
- Delete: `lib/data/allocation/allocation_repository.dart`
- Delete: `lib/features/allocation/allocation_controller.dart`, `allocate_sheet.dart`, `income_allocation_prompt.dart`, `variable_budget_offer.dart`, `allocation_template_screen.dart`
- Delete: `lib/data/db/default_allocation.dart`
- Delete tests: `test/core/allocation/allocation_engine_test.dart`, `test/features/allocation/allocation_controller_test.dart`, and any other `test/**/*allocation*` file exercising buckets (NOT the new `allocation_plan_*` tests)
- Modify: `lib/providers/app_providers.dart` (remove old providers + imports)
- Modify: `lib/data/db/tables.dart` (remove `AllocationDirectionsTable`, `IncomeAllocationsTable`)
- Modify: `lib/data/db/app_database.dart` (remove them from `@DriftDatabase`)
- Modify: `lib/data/db/migrations.dart` (fix historical branch; add DROP TABLE to v7)
- Regenerate: `lib/data/db/app_database.g.dart`

**Interfaces:**
- Produces: a tree with no references to bucket allocation symbols.

- [ ] **Step 1: Find every reference to the old symbols**

Run: `git grep -n -E "allocationRepositoryProvider|allocationTemplateProvider|allocationControllerProvider|AllocationController|showAllocationChoice|AllocationTemplate|computeAllocation|previewAllocation|editedAllocationPreview|resolveDynamicAmounts|seedDefaultAllocationTemplate|AllocationDirection|bucketLabel|maybeOfferVariableBudgetUpdate|allocation_engine|allocation_models|allocation_dynamic|allocation_result_labels|allocate_sheet|income_allocation_prompt|variable_budget_offer|allocation_template_screen|allocation_repository\.dart|default_allocation" -- lib test`

Expected: matches ONLY in the files listed for deletion/modification in this task. If a match appears elsewhere (e.g. `dashboard_data.dart`, `home_screen.dart`, `recurring_prompt.dart`), open that file and remove the reference before deleting anything.

- [ ] **Step 2: Remove old providers from app_providers.dart**

In `lib/providers/app_providers.dart`, delete `allocationRepositoryProvider` and `allocationTemplateProvider` declarations, and remove now-unused imports (`allocation_repository.dart`, `allocation_models.dart`/`AllocationTemplate`). Keep the new `allocationPlanRepositoryProvider`/`allocationPlanProvider`.

- [ ] **Step 3: Delete the old files**

```bash
git rm lib/core/allocation/allocation_models.dart lib/core/allocation/allocation_engine.dart lib/core/allocation/allocation_dynamic.dart lib/data/allocation/allocation_repository.dart lib/features/allocation/allocation_controller.dart lib/features/allocation/allocate_sheet.dart lib/features/allocation/income_allocation_prompt.dart lib/features/allocation/variable_budget_offer.dart lib/features/allocation/allocation_template_screen.dart lib/data/db/default_allocation.dart
git rm test/core/allocation/allocation_engine_test.dart
```

Then check for and remove any remaining bucket tests: `git grep -l -E "computeAllocation|AllocationController|AllocationTemplate|resolveDynamicAmounts" -- test` and `git rm` each. Also `git rm lib/core/allocation/allocation_result_labels.dart` if `git status`/grep shows it exists and is now unreferenced.

- [ ] **Step 4: Remove the bucket tables from the schema**

In `lib/data/db/tables.dart`, delete the `AllocationDirectionsTable` and `IncomeAllocationsTable` class definitions.

In `lib/data/db/app_database.dart`, remove `AllocationDirectionsTable,` and `IncomeAllocationsTable,` from the `@DriftDatabase(tables: [...])` list.

- [ ] **Step 5: Fix the historical migration branch + add the drop**

In `lib/data/db/migrations.dart`:
- Remove the import `import 'default_allocation.dart';`.
- In `onCreate`, delete the line `await seedDefaultAllocationTemplate(db);`.
- In the `if (from < 3) { ... }` branch, delete these three lines:
  ```dart
  await m.createTable(db.allocationDirectionsTable);
  await m.createTable(db.incomeAllocationsTable);
  await seedDefaultAllocationTemplate(db);
  ```
- In the `if (from < 7) { ... }` branch (added in Task 2), append the drops:
  ```dart
          await m.database
              .customStatement('DROP TABLE IF EXISTS income_allocations_table');
          await m.database
              .customStatement('DROP TABLE IF EXISTS allocation_directions_table');
  ```

- [ ] **Step 6: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `app_database.g.dart` regenerates without the two bucket tables. No errors.

- [ ] **Step 7: Analyze the whole project**

Run: `flutter analyze`
Expected: No errors (pre-existing deprecation infos like `onReorder` are acceptable). Fix any dangling references the analyzer surfaces.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor(allocation): remove abstract-bucket system + drop bucket tables"
```

---

## Task 10: Golden + full verification

**Files:**
- Create: `test/goldens/allocation_plan_golden_test.dart`
- Create: `test/goldens/baselines/` PNGs (generated)

**Interfaces:**
- Consumes: `pumpVelora` (`test/support/velora_test_app.dart`), `phone390`/`phone320` (`test/support/golden_devices.dart`).

- [ ] **Step 1: Write the golden test**

Create `test/goldens/allocation_plan_golden_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/allocation/allocation_plan.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/features/allocation/allocation_plan_screen.dart';
import 'package:financial_assistant/providers/app_providers.dart';

import '../support/golden_devices.dart';
import '../support/velora_test_app.dart';

Future<ProviderContainer> _seeded() async {
  const uzs = CurrencyRegistry.uzs;
  final db = AppDatabase(NativeDatabase.memory());
  final src = await db.into(db.accountsTable).insert(
      AccountsTableCompanion.insert(
          name: 'Asosiy Sarf', type: 'bankCard',
          openingBalanceMinor: const Value(3000000), role: const Value('spending')));
  final dst1 = await db.into(db.accountsTable).insert(
      AccountsTableCompanion.insert(
          name: 'Kredit', type: 'bankCard',
          openingBalanceMinor: const Value(0), role: const Value('credit')));
  final dst2 = await db.into(db.accountsTable).insert(
      AccountsTableCompanion.insert(
          name: "Jamg'arma", type: 'bankCard',
          openingBalanceMinor: const Value(0), role: const Value('savings')));
  final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)]);
  addTearDown(() {
    container.dispose();
    db.close();
  });
  await container.read(allocationPlanControllerProvider).setSource(src);
  await container.read(allocationPlanControllerProvider).saveRules([
    AllocationRule(destinationAccountId: dst1, amount: const Money(500000, uzs), sortOrder: 0),
    AllocationRule(destinationAccountId: dst2, amount: const Money(300000, uzs), sortOrder: 1),
  ]);
  await container.read(allocationPlanProvider.future);
  await container.read(accountsControllerProvider.future);
  return container;
}

void main() {
  testWidgets('allocation plan screen at 390px light', (tester) async {
    final container = await _seeded();
    await pumpVelora(
      tester,
      child: UncontrolledProviderScope(
        container: container,
        child: const AllocationPlanScreen(),
      ),
      size: phone390,
      brightness: Brightness.light,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(AllocationPlanScreen),
      matchesGoldenFile('baselines/allocation-plan-light-390.png'),
    );
  });
}
```

- [ ] **Step 2: Generate the baseline**

Run: `flutter test test/goldens/allocation_plan_golden_test.dart --update-goldens`
Expected: creates `test/goldens/baselines/allocation-plan-light-390.png`. Then run WITHOUT the flag to confirm it matches:
Run: `flutter test test/goldens/allocation_plan_golden_test.dart`
Expected: PASS.

- [ ] **Step 3: Full test suite**

Run: `flutter test --concurrency=1`
Expected: All pass. (Some full-screen goldens may fail environmentally per project notes — if a golden fails, confirm it is a pre-existing environmental failure unrelated to allocation before proceeding.)

- [ ] **Step 4: Manual verification on the emulator**

Run the app (`flutter run -d emulator-5554`), then: Reja tab → header "Taqsimlash rejasi" (tune icon) → pick a source card → add a rule (destination + amount) → "Rejani qo'llash" → confirm sheet → "Bajarish". Verify: snackbar shows the moved total, the source card balance dropped by that total, and Home's "BUGUN QOLDI" daily limit decreased accordingly. Screenshot via `adb -s emulator-5554 exec-out screencap -p > screen.png` and inspect.

- [ ] **Step 5: Commit**

```bash
git add test/goldens/allocation_plan_golden_test.dart test/goldens/baselines/allocation-plan-light-390.png
git commit -m "test(allocation): plan screen golden + baseline"
```

---

## Self-Review Notes (author)

- **Spec coverage:** §2 talab 1 (manual) → Task 7 apply flow; talab 2 (one button) → `plan-apply`; talab 3 (source + rules) → Tasks 2/4/7; talab 4 (fixed only) → `AllocationRule.amount` (no method); talab 5 (priority fill) → Task 1 engine; talab 6 (confirm) → Task 7 `apply_plan_sheet`; talab 7 (real transfers) → Task 4 `buildTransfer`; talab 8 (remove buckets) → Task 9; talab 9 (goals untouched) → no goal files modified.
- **Deviation:** `transactions.allocatedMinor` KEPT physically (documented under Global Constraints) — reduces hot-table migration risk; column stays 0.
- **Type consistency:** `PlannedTransfer(int, Money)` positional everywhere; `AllocationRule(destinationAccountId, amount, sortOrder)` named everywhere; `computePlanTransfers({sourceBalance, rules})` named; `applyPlan(int sourceId, List<PlannedTransfer>)` matches controller `apply`.
- **Sequencing:** new code (new names) precedes deletion (Task 9), so the tree compiles at every commit; DB is additive in Task 2 and the DROP is deferred to Task 9 alongside code removal.
