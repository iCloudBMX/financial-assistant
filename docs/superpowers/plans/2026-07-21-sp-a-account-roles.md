# SP-A: Account Roles — Implementation Plan

> **For agentic workers — REQUIRED SUB-SKILL:** Before starting, load and follow `superpowers:test-driven-development`. Every task below is written as a strict red → green → commit loop. Do not write implementation code before the failing test exists and has been observed to fail for the right reason.

**Goal:** Add an assignable **budget role** to every account. Introduce the `AccountRole { spending, reserve, credit, savings }` enum, a `role` field on the `Account` domain model, a `role` column on `AccountsTable` (additive migration with a default-mapping rule), repository read/write of the role, and a role selector in both the account create/edit sheet and the onboarding account step. **No behaviour change to the safe-limit** — this slice only makes roles assignable and persisted.

**Architecture:** The app is an offline-first Flutter personal-finance app. Layers, bottom-up:
- `lib/core/ledger/account.dart` — pure domain model (`Account`, `AccountType`). SP-A adds `AccountRole` here.
- `lib/data/db/tables.dart` + `app_database.dart` + `migrations.dart` — drift ORM schema + stepwise migrations. SP-A adds one `TextColumn get role`, bumps `schemaVersion` 5 → 6, and adds a `from < 6` migration branch.
- `lib/data/accounts/account_repository.dart` — maps drift rows ↔ `Account`, exposes CRUD. SP-A reads/writes `role` and adds `setRole`.
- `lib/features/accounts/*` + `lib/features/onboarding/steps/account_step.dart` — Riverpod UI. SP-A adds a choice-chip role selector mirroring the existing account-type selector, plus one-line helper text.
- `lib/features/accounts/account_labels.dart` — single source of truth for Uzbek labels; SP-A adds role labels + helpers + display order here.

**Tech Stack:** Flutter/Dart, drift ORM (SQLite), flutter_riverpod 3.x, drift NativeDatabase for in-memory tests, `flutter_test`.

## Global Constraints

- Flutter/Dart.
- drift ORM for the DB; drift stores `AccountRole` as its `.name` string in a `TextColumn`.
- flutter_riverpod 3.x (note: `StateProvider` needs `import 'package:flutter_riverpod/legacy.dart'`).
- Test command is `flutter test --concurrency=1`.
- Commit messages end with a trailer line `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- Migrations must be additive with a `schemaVersion` bump + a migration test.
- This repo cannot use drift's versioned schema CLI (`drift_dev schema` does not compile here — see the class doc in `migrations.dart`), so migrations use explicit `m.addColumn` / `m.createTable`, and column-adding branches are guarded by `_hasColumn` to survive a collapsed multi-version `onUpgrade` pass.
- `AccountsTable` physical name is `accounts_table`; drift derives snake_case column names (`role`).
- FIXED interface contract (shared across SP-A/SP-B/SP-C — use verbatim): `enum AccountRole { spending, reserve, credit, savings }`; `Account.role` is `final AccountRole role;` (required constructor param); `AccountsTable.role` is `text().withDefault(const Constant('spending'))()`; repo adds `Future<void> setRole(int id, AccountRole role)`; migration default mapping: `type == 'savings'` → `savings`, all other rows → `spending`.

---

## Task 1 — `AccountRole` enum + `Account.role` field + repository mapper

Introduce the enum and the domain field, and teach the row→`Account` mapper to read it. The `AccountsTable` column does not exist yet, so the mapper reads `role` defensively via the same `dynamic` row shape used by the existing mapper — but to keep this task test-driven and green **without** touching the DB, we drive it through a pure `Account` construction test, then wire the mapper in Task 3 once the column exists. This task's scope is strictly the enum + the model field.

**Files:**
- Modify: `lib/core/ledger/account.dart` (lines 4–24 — add enum after line 4, add field + constructor param)
- Test: `test/core/ledger/account_role_test.dart` (Create)

**Interfaces:**
- Produces: `enum AccountRole { spending, reserve, credit, savings }`
- Produces: `Account({ required int id, required String name, required AccountType type, required Money openingBalance, required String icon, required bool archived, required AccountRole role })`

Steps:

- [ ] Write failing test `test/core/ledger/account_role_test.dart`:
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:financial_assistant/core/money/currency.dart';
  import 'package:financial_assistant/core/money/money.dart';
  import 'package:financial_assistant/core/ledger/account.dart';

  void main() {
    const uzs = CurrencyRegistry.uzs;

    test('AccountRole has the four fixed roles in order', () {
      expect(AccountRole.values,
          [AccountRole.spending, AccountRole.reserve, AccountRole.credit, AccountRole.savings]);
      expect(AccountRole.spending.name, 'spending');
      expect(AccountRole.savings.name, 'savings');
    });

    test('Account carries a role', () {
      const a = Account(
        id: 1,
        name: 'Naqd',
        type: AccountType.cash,
        openingBalance: Money(0, uzs),
        icon: 'wallet',
        archived: false,
        role: AccountRole.reserve,
      );
      expect(a.role, AccountRole.reserve);
    });
  }
  ```
- [ ] Run it, expect FAIL (compile error: `AccountRole` undefined / `role` not a param):
  `flutter test --concurrency=1 test/core/ledger/account_role_test.dart`
- [ ] Minimal implementation in `lib/core/ledger/account.dart`:
  ```dart
  import '../money/currency.dart';
  import '../money/money.dart';

  enum AccountType { bankCard, cash, savings, other }

  enum AccountRole { spending, reserve, credit, savings }

  class Account {
    final int id;
    final String name;
    final AccountType type;
    final Money openingBalance;
    final String icon;
    final bool archived;
    final AccountRole role;

    const Account({
      required this.id,
      required this.name,
      required this.type,
      required this.openingBalance,
      required this.icon,
      required this.archived,
      required this.role,
    });

    Currency get currency => openingBalance.currency;
  }
  ```
- [ ] Run it, expect PASS: `flutter test --concurrency=1 test/core/ledger/account_role_test.dart`
- [ ] NOTE: making `role` a required param will break every existing `Account(...)` construction and the repository `_map` (which does not yet pass `role`). This is expected and is fixed in Task 3. Do **not** run the full suite yet. Commit just the model + its unit test:
  ```
  git add lib/core/ledger/account.dart test/core/ledger/account_role_test.dart
  git commit -m "$(cat <<'EOF'
  feat(accounts): add AccountRole enum + Account.role field

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Task 2 — `AccountsTable.role` column + schemaVersion 5→6 + migration with default mapping

Add the additive column, bump the schema version, add the `from < 6` migration branch that back-fills existing rows (savings type → savings role; all others keep the `'spending'` column default), and cover it with a real v5→v6 upgrade test that mirrors the existing `schema_v3` column-adding test (raw DDL for the pre-column table so `addColumn` gets genuine coverage).

**Files:**
- Modify: `lib/data/db/tables.dart` (`AccountsTable`, lines 47–59 — add `role` after line 54)
- Modify: `lib/data/db/app_database.dart` (line 25 — `schemaVersion` 5 → 6)
- Modify: `lib/data/db/migrations.dart` (add a `from < 6` branch after the `from < 5` branch, lines 89–95)
- Test: `test/data/db/schema_v6_migration_test.dart` (Create)

**Interfaces:**
- Produces: `AccountsTable.role` → `TextColumn get role => text().withDefault(const Constant('spending'))();`
- Produces: `onUpgrade(from, to)` handles `from < 6`: `addColumn(accountsTable.role)` (guarded) + `UPDATE accounts_table SET role = 'savings' WHERE type = 'savings'`.
- Consumes: existing `_hasColumn(Migrator, table, column)` helper (lines 106–110).

Steps:

- [ ] Write failing migration test `test/data/db/schema_v6_migration_test.dart`. `_V5AppDatabase` builds `accounts_table` with **raw DDL that omits `role`** (so `addColumn` is genuinely exercised), and the rest of the SP0–SP5 tables via `m.createTable`:
  ```dart
  import 'dart:io';
  import 'package:drift/drift.dart';
  import 'package:drift/native.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:financial_assistant/data/db/app_database.dart';

  /// A genuine v5 database: accounts_table built WITHOUT the SP-A `role`
  /// column (raw DDL, so onUpgrade's addColumn path gets real coverage —
  /// m.createTable(accountsTable) would build today's shape which already
  /// carries `role`). All other SP0–SP5 tables are current-shape.
  class _V5AppDatabase extends AppDatabase {
    _V5AppDatabase(super.e);
    @override
    int get schemaVersion => 5;
    @override
    MigrationStrategy get migration => MigrationStrategy(
          onCreate: (m) async {
            // Pre-SP-A accounts_table: no `role`. Column list + defaults
            // mirror $AccountsTableTable in app_database.g.dart exactly,
            // minus role. created_at is stored as INTEGER (unix seconds).
            await m.database.customStatement(
              'CREATE TABLE accounts_table ('
              'id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
              'name TEXT NOT NULL, '
              'type TEXT NOT NULL, '
              'opening_balance_minor INTEGER NOT NULL DEFAULT 0, '
              'currency_code TEXT NOT NULL DEFAULT \'UZS\', '
              'icon TEXT NOT NULL DEFAULT \'wallet\', '
              'archived INTEGER NOT NULL DEFAULT 0 CHECK ("archived" IN (0, 1)), '
              'sort_order INTEGER NOT NULL DEFAULT 0, '
              'created_at INTEGER NOT NULL);',
            );
            await m.createTable(appSettingsTable);
            await m.createTable(appMetaTable);
            await m.createTable(categoriesTable);
            await m.createTable(transactionsTable);
            await m.createTable(recurringIncomePlansTable);
            await m.createTable(allocationDirectionsTable);
            await m.createTable(incomeAllocationsTable);
            await m.createTable(goalsTable);
            await m.createTable(goalContributionsTable);
            await m.createTable(mortgagesTable);
            await m.createTable(mortgagePaymentsTable);
            await into(appSettingsTable)
                .insert(const AppSettingsTableCompanion(id: Value(0)));
            // Seed two accounts via raw insert (no role column exists yet).
            await m.database.customStatement(
              "INSERT INTO accounts_table (name, type, created_at) "
              "VALUES ('Jamg''arma kartasi', 'savings', 0)");
            await m.database.customStatement(
              "INSERT INTO accounts_table (name, type, created_at) "
              "VALUES ('Naqd', 'cash', 0)");
          },
          beforeOpen: (d) async => customStatement('PRAGMA foreign_keys = ON'),
        );
  }

  void main() {
    test('schemaVersion is 6', () {
      final db = AppDatabase(NativeDatabase.memory());
      expect(db.schemaVersion, 6);
      db.close();
    });

    test('fresh v6 open: accounts default to spending role', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.into(db.accountsTable).insert(
            AccountsTableCompanion.insert(name: 'X', type: 'cash'),
          );
      final rows = await db.select(db.accountsTable).get();
      expect(rows.single.role, 'spending');
      await db.close();
    });

    test('real v5 -> v6 onUpgrade adds role + applies default mapping', () async {
      final tmp = await Directory.systemTemp.createTemp('schema_v6_upgrade');
      final dbPath = '${tmp.path}/app.db';

      final v5db = _V5AppDatabase(NativeDatabase(File(dbPath)));
      await v5db.select(v5db.accountsTable).get(); // force onCreate
      expect(v5db.schemaVersion, 5);
      await v5db.close();

      final v6db = AppDatabase(NativeDatabase(File(dbPath)));
      final rows = await v6db.select(v6db.accountsTable).get();
      final byName = {for (final r in rows) r.name: r.role};
      // savings type -> savings role; everything else -> spending.
      expect(byName['Jamg\'arma kartasi'], 'savings');
      expect(byName['Naqd'], 'spending');

      await v6db.close();
      await tmp.delete(recursive: true);
    });
  }
  ```
  Also update the incidental version assertions in the existing schema tests that hard-code `5` (`test/data/db/schema_v3_migration_test.dart` line 74 `expect(db.schemaVersion, 5)` and line 35 `'schemaVersion is 5'` in `schema_v5_migration_test.dart`, and any in `app_database_test.dart`) — grep first: `flutter test` will flag them.
- [ ] Run it, expect FAIL (`db.schemaVersion` is 5; `rows.single.role` getter undefined):
  `flutter test --concurrency=1 test/data/db/schema_v6_migration_test.dart`
- [ ] Add the column in `lib/data/db/tables.dart` `AccountsTable`, immediately after the `icon` line:
  ```dart
  TextColumn get icon => text().withDefault(const Constant('wallet'))();
  TextColumn get role => text().withDefault(const Constant('spending'))(); // AccountRole.name
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  ```
- [ ] Bump `schemaVersion` in `lib/data/db/app_database.dart`:
  ```dart
  @override
  int get schemaVersion => 6;
  ```
- [ ] Add the migration branch in `lib/data/db/migrations.dart`, immediately after the `from < 5` block (before the closing `}` of `onUpgrade`):
  ```dart
  if (from < 6) {
    // v5 -> v6: add the account budget `role` column. Additive with a
    // 'spending' default. Guarded by _hasColumn because a collapsed
    // v1->v6 pass may have built accounts_table with today's full column
    // set already (this codebase can't use drift's versioned schema CLI —
    // see the class doc — so createTable has no historical snapshot).
    if (!await _hasColumn(m, 'accounts_table', 'role')) {
      await m.addColumn(db.accountsTable, db.accountsTable.role);
    }
    // Default mapping: existing savings-type cards become the savings role;
    // every other row keeps the column's 'spending' default.
    await m.database.customStatement(
      "UPDATE accounts_table SET role = 'savings' WHERE type = 'savings'",
    );
  }
  ```
- [ ] Regenerate drift code (the new column needs `app_database.g.dart` updated):
  `dart run build_runner build --delete-conflicting-outputs`
- [ ] Run it, expect PASS: `flutter test --concurrency=1 test/data/db/schema_v6_migration_test.dart`
- [ ] Run the other schema tests to confirm the version-assertion updates: `flutter test --concurrency=1 test/data/db/`
- [ ] Commit:
  ```
  git add lib/data/db/tables.dart lib/data/db/app_database.dart lib/data/db/app_database.g.dart lib/data/db/migrations.dart test/data/db/
  git commit -m "$(cat <<'EOF'
  feat(accounts): add role column + v5->v6 migration with default mapping

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Task 3 — Repository `setRole` + `create` writes role + mapper reads role

Wire the domain field to the column: read `role` in `_map`, write it in `create` (default `spending`), and add `setRole`. This is the task that makes the whole app compile again (Task 1 made `role` required; `_map` and every `create` call now supply it). Existing repo callers pass no role and get `spending` via the default param.

**Files:**
- Modify: `lib/data/accounts/account_repository.dart` (abstract class lines 8–21; `_map` lines 27–37; `create` lines 39–56; add `setRole` after `setIcon` ~line 68)
- Modify: `lib/features/accounts/accounts_controller.dart` (`createAccount` lines 36–46 — thread optional `role`)
- Test: `test/data/accounts/account_repository_test.dart` (extend existing file)

**Interfaces:**
- Produces: `AccountRepository.setRole(int id, AccountRole role) → Future<void>`
- Produces: `AccountRepository.create({ ..., AccountRole role = AccountRole.spending }) → Future<int>`
- Produces: `Account _map(dynamic r)` reads `AccountRole.values.byName(r.role as String)`.
- Consumes: `AccountsTableCompanion.insert(... role: Value(role.name))`, `AccountsTableCompanion(role: Value(role.name))`.

Steps:

- [ ] Add failing tests to `test/data/accounts/account_repository_test.dart` (append inside `main`). Also add `role: AccountRole.savings` expectations where useful — but the new-default check needs no arg:
  ```dart
  test('create defaults role to spending; round-trips role', () async {
    final id = await repo.create(
        name: 'Naqd',
        type: AccountType.cash,
        openingBalance: const Money(0, uzs),
        icon: 'wallet');
    expect((await repo.byId(id))!.role, AccountRole.spending);

    final id2 = await repo.create(
        name: 'Zaxira',
        type: AccountType.bankCard,
        openingBalance: const Money(0, uzs),
        icon: 'wallet',
        role: AccountRole.reserve);
    expect((await repo.byId(id2))!.role, AccountRole.reserve);
  });

  test('setRole updates the stored role', () async {
    final id = await repo.create(
        name: 'A',
        type: AccountType.cash,
        openingBalance: const Money(0, uzs),
        icon: 'w');
    await repo.setRole(id, AccountRole.credit);
    expect((await repo.byId(id))!.role, AccountRole.credit);
    // list() reads role too
    expect((await repo.list()).single.role, AccountRole.credit);
  });
  ```
- [ ] Run it, expect FAIL (`setRole` undefined; `create` has no `role` param; `Account.role` unset in `_map`):
  `flutter test --concurrency=1 test/data/accounts/account_repository_test.dart`
- [ ] Implement in `lib/data/accounts/account_repository.dart`. Import already has `account.dart`. Update the abstract signature, `_map`, `create`, and add `setRole`:
  ```dart
  abstract class AccountRepository {
    Future<int> create({
      required String name,
      required AccountType type,
      required Money openingBalance,
      required String icon,
      AccountRole role = AccountRole.spending,
    });
    Future<void> rename(int id, String name);
    Future<void> setIcon(int id, String icon);
    Future<void> setRole(int id, AccountRole role);
    Future<void> setArchived(int id, bool archived);
    Future<void> reorder(List<int> orderedIds);
    Future<List<Account>> list({bool includeArchived = false});
    Future<Account?> byId(int id);
  }
  ```
  ```dart
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
        role: AccountRole.values.byName(r.role as String),
      );

  @override
  Future<int> create({
    required String name,
    required AccountType type,
    required Money openingBalance,
    required String icon,
    AccountRole role = AccountRole.spending,
  }) {
    return db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(
            name: name,
            type: type.name,
            openingBalanceMinor: Value(openingBalance.minorUnits),
            currencyCode: Value(openingBalance.currency.code),
            icon: Value(icon),
            role: Value(role.name),
            createdAt: Value(DateTime.now()),
          ),
        );
  }
  ```
  Add `setRole` after `setIcon`:
  ```dart
  @override
  Future<void> setRole(int id, AccountRole role) async {
    await (db.update(db.accountsTable)..where((t) => t.id.equals(id)))
        .write(AccountsTableCompanion(role: Value(role.name)));
  }
  ```
- [ ] Thread an optional `role` through the controller in `lib/features/accounts/accounts_controller.dart` so the UI can set it at create time:
  ```dart
  Future<int> createAccount({
    required String name,
    required AccountType type,
    required Money openingBalance,
    required String icon,
    AccountRole role = AccountRole.spending,
  }) async {
    final id = await ref.read(accountRepositoryProvider).create(
        name: name,
        type: type,
        openingBalance: openingBalance,
        icon: icon,
        role: role);
    await _invalidate();
    return id;
  }
  ```
- [ ] Run it, expect PASS: `flutter test --concurrency=1 test/data/accounts/account_repository_test.dart`
- [ ] Run the full suite to confirm the earlier Task 1 breakage is now resolved (any other `Account(...)` constructions in test fixtures/factories will surface here — fix each by adding `role: AccountRole.spending`): `flutter test --concurrency=1`
- [ ] Commit:
  ```
  git add lib/data/accounts/account_repository.dart lib/features/accounts/accounts_controller.dart test/data/accounts/account_repository_test.dart
  git commit -m "$(cat <<'EOF'
  feat(accounts): repository reads/writes role + setRole + create default

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Task 4 — Role labels + role selector in the account create/edit sheet

Add the Uzbek role labels/helpers and display order to `account_labels.dart` (single source of truth, matching the existing `accountTypeLabel` pattern), then add a choice-chip role selector to `account_edit_sheet.dart` mirroring the existing account-type `Wrap` of `ChoiceChip`s. The selected role is passed to `createAccount(role: ...)`.

**Files:**
- Modify: `lib/features/accounts/account_labels.dart` (add role label/helper/order functions after line 24)
- Modify: `lib/features/accounts/account_edit_sheet.dart` (add `_role` state line 40; role selector in `build` after the type `Wrap` ~line 103; pass `role` in `_save` ~line 59)
- Test: `test/features/accounts/account_role_selector_test.dart` (Create — widget test)

**Interfaces:**
- Produces: `String accountRoleLabel(AccountRole)` → Sarf / Zaxira / Kredit / Jamg'arma.
- Produces: `String accountRoleHelper(AccountRole)` → the one-line helper per role.
- Produces: `const List<AccountRole> accountRolesInDisplayOrder`.
- Consumes: `accountsControllerProvider.notifier.createAccount(role:)`.
- Consumes: `ChoiceChip` with `key: Key('account-role-<name>')` for widget tests.

Steps:

- [ ] Write failing widget test `test/features/accounts/account_role_selector_test.dart`. Keep it label-focused so it does not depend on DB wiring (labels are the SP-A UI contract). Pattern after existing accounts widget tests (a `ProviderScope` + `MaterialApp` pump of the sheet body, or a direct label unit check — prefer the label unit check plus a chip-presence pump):
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:financial_assistant/core/ledger/account.dart';
  import 'package:financial_assistant/features/accounts/account_labels.dart';

  void main() {
    test('role labels match the fixed Uzbek contract', () {
      expect(accountRoleLabel(AccountRole.spending), 'Sarf');
      expect(accountRoleLabel(AccountRole.reserve), 'Zaxira');
      expect(accountRoleLabel(AccountRole.credit), 'Kredit');
      expect(accountRoleLabel(AccountRole.savings), 'Jamg\'arma');
    });

    test('role helpers match the fixed contract', () {
      expect(accountRoleHelper(AccountRole.spending), 'Kundalik xarajatlar uchun');
      expect(accountRoleHelper(AccountRole.reserve), 'Favqulodda holatlar, tegilmaydi');
      expect(accountRoleHelper(AccountRole.credit), "Kredit to'lovlari uchun");
      expect(accountRoleHelper(AccountRole.savings), "Maqsad/jamg'arma uchun");
    });

    test('display order is spending, reserve, credit, savings', () {
      expect(accountRolesInDisplayOrder, const [
        AccountRole.spending,
        AccountRole.reserve,
        AccountRole.credit,
        AccountRole.savings,
      ]);
    });
  }
  ```
- [ ] Run it, expect FAIL (`accountRoleLabel` undefined):
  `flutter test --concurrency=1 test/features/accounts/account_role_selector_test.dart`
- [ ] Add to `lib/features/accounts/account_labels.dart` (after `accountTypesInDisplayOrder`):
  ```dart
  /// Single source of truth for the Uzbek account-role labels shown in the
  /// role selector (create/edit sheet + onboarding). Roles drive the budget
  /// spendable pool (SP-B); the labels here are the user-facing names.
  String accountRoleLabel(AccountRole role) => switch (role) {
        AccountRole.spending => 'Sarf',
        AccountRole.reserve => 'Zaxira',
        AccountRole.credit => 'Kredit',
        AccountRole.savings => 'Jamg\'arma',
      };

  /// One-line helper text under each role, explaining what the role means.
  String accountRoleHelper(AccountRole role) => switch (role) {
        AccountRole.spending => 'Kundalik xarajatlar uchun',
        AccountRole.reserve => 'Favqulodda holatlar, tegilmaydi',
        AccountRole.credit => 'Kredit to\'lovlari uchun',
        AccountRole.savings => 'Maqsad/jamg\'arma uchun',
      };

  /// The order roles are offered in the selector.
  const List<AccountRole> accountRolesInDisplayOrder = [
    AccountRole.spending,
    AccountRole.reserve,
    AccountRole.credit,
    AccountRole.savings,
  ];
  ```
- [ ] Run it, expect PASS: `flutter test --concurrency=1 test/features/accounts/account_role_selector_test.dart`
- [ ] Add the selector to `lib/features/accounts/account_edit_sheet.dart`. Add state field beside `_type`:
  ```dart
  AccountType _type = AccountType.cash;
  AccountRole _role = AccountRole.spending;
  ```
  In `build`, after the account-type `Wrap` (after line 103, before the closing `],` of the Column's children), add the role selector with helper text for the selected role:
  ```dart
  const SizedBox(height: VeloraSpacing.lg),
  const Text('Byudjet roli'),
  const SizedBox(height: VeloraSpacing.sm),
  Wrap(
    spacing: VeloraSpacing.sm,
    runSpacing: VeloraSpacing.sm,
    children: [
      for (final role in accountRolesInDisplayOrder)
        ChoiceChip(
          key: Key('account-role-${role.name}'),
          label: Text(accountRoleLabel(role)),
          selected: _role == role,
          showCheckmark: false,
          onSelected: (_) => setState(() => _role = role),
        ),
    ],
  ),
  const SizedBox(height: VeloraSpacing.sm),
  Text(
    accountRoleHelper(_role),
    style: Theme.of(context).textTheme.bodySmall,
  ),
  ```
  In `_save`, pass the role:
  ```dart
  await ref.read(accountsControllerProvider.notifier).createAccount(
      name: _nameCtrl.text.trim().isEmpty ? 'Hisob' : _nameCtrl.text.trim(),
      type: _type,
      openingBalance: _opening ?? Money.zero(widget.currency),
      icon: 'wallet',
      role: _role);
  ```
- [ ] Run the accounts feature tests to confirm nothing regressed: `flutter test --concurrency=1 test/features/accounts/`
- [ ] Commit:
  ```
  git add lib/features/accounts/account_labels.dart lib/features/accounts/account_edit_sheet.dart test/features/accounts/account_role_selector_test.dart
  git commit -m "$(cat <<'EOF'
  feat(accounts): role selector + Uzbek role labels in edit sheet

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Task 5 — Role selector in the onboarding account step

Mirror the same selector in `account_step.dart`, disabled once the account is created (matching how the existing type chips disable via `_created`), and pass `role` to `createAccount`. Reuse the labels/order from Task 4 — no new label source.

**Files:**
- Modify: `lib/features/onboarding/steps/account_step.dart` (state field ~line 57; `_createAccount` role arg ~line 79; selector after the type `Wrap` ~line 136)
- Test: `test/features/onboarding/account_step_role_test.dart` (Create — widget test)

**Interfaces:**
- Consumes: `accountRolesInDisplayOrder`, `accountRoleLabel`, `accountRoleHelper` (from Task 4).
- Consumes: `accountsControllerProvider.notifier.createAccount(role:)`.
- Produces: `ChoiceChip` with `key: Key('onboarding-account-role-<name>')`.

Steps:

- [ ] Write a failing widget test `test/features/onboarding/account_step_role_test.dart` that pumps the onboarding account step and asserts the four role chips render. Mirror the setup of the existing onboarding account-step test (find it via `flutter test test/features/onboarding/` or grep `onboarding-account-type`); reuse its `ProviderScope`/controller harness. Minimal shape:
  ```dart
  // ... reuse the existing onboarding test harness that builds an
  // OnboardingController + pumps AccountStep.build(...) inside ProviderScope.
  testWidgets('account step shows the four role chips', (tester) async {
    // pump the step (see sibling onboarding account-step test for setup)
    for (final r in ['spending', 'reserve', 'credit', 'savings']) {
      expect(find.byKey(Key('onboarding-account-role-$r')), findsOneWidget);
    }
    expect(find.text('Sarf'), findsOneWidget);
  });
  ```
  If no sibling onboarding harness exists, keep this test at the label level (assert `accountRoleLabel`/order) so it does not block on widget-harness plumbing, and rely on Task 4's coverage for the selector widget itself.
- [ ] Run it, expect FAIL (chip keys not present):
  `flutter test --concurrency=1 test/features/onboarding/account_step_role_test.dart`
- [ ] Add state field in `_AccountStepBodyState` beside `_type`:
  ```dart
  AccountType _type = AccountType.cash;
  AccountRole _role = AccountRole.spending;
  ```
- [ ] Pass the role in `_createAccount`:
  ```dart
  final id =
      await ref.read(accountsControllerProvider.notifier).createAccount(
            name: _nameCtrl.text.trim().isEmpty ? 'Hisob' : _nameCtrl.text.trim(),
            type: _type,
            openingBalance: _opening ?? Money.zero(currency),
            icon: 'wallet',
            role: _role,
          );
  ```
- [ ] Add the selector after the account-type `Wrap` in `build` (after line 136, before the `const SizedBox(height: VeloraSpacing.lg)` that precedes the created badge). Import `account_labels.dart` is already present (line 9):
  ```dart
  const SizedBox(height: VeloraSpacing.lg),
  const Text('Byudjet roli'),
  const SizedBox(height: VeloraSpacing.sm),
  Wrap(
    spacing: VeloraSpacing.sm,
    runSpacing: VeloraSpacing.sm,
    children: [
      for (final role in accountRolesInDisplayOrder)
        ChoiceChip(
          key: Key('onboarding-account-role-${role.name}'),
          label: Text(accountRoleLabel(role)),
          selected: _role == role,
          showCheckmark: false,
          onSelected:
              _created ? null : (_) => setState(() => _role = role),
        ),
    ],
  ),
  const SizedBox(height: VeloraSpacing.sm),
  Text(
    accountRoleHelper(_role),
    style: Theme.of(context).textTheme.bodySmall,
  ),
  ```
- [ ] Run it, expect PASS: `flutter test --concurrency=1 test/features/onboarding/account_step_role_test.dart`
- [ ] Run the full suite one final time — everything green: `flutter test --concurrency=1`
- [ ] Commit:
  ```
  git add lib/features/onboarding/steps/account_step.dart test/features/onboarding/account_step_role_test.dart
  git commit -m "$(cat <<'EOF'
  feat(onboarding): role selector in the account step

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Done criteria

- `AccountRole { spending, reserve, credit, savings }` exists; `Account.role` is a required field.
- `accounts_table.role` column exists (default `'spending'`); `schemaVersion == 6`; v5→v6 migration back-fills `savings`-type rows to the `savings` role and leaves the rest at `spending`, covered by `schema_v6_migration_test.dart`.
- Repository round-trips role, `create` defaults to `spending`, `setRole` works.
- Both the account create/edit sheet and the onboarding account step show a four-chip role selector with the fixed Uzbek labels + one-line helper.
- No safe-limit behaviour change (out of scope — that is SP-B).
- `flutter test --concurrency=1` is fully green.
