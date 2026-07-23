# Backup / Restore Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user export all app data to a single `.fabackup` file and restore it later (PRD §18–19, acceptance criteria #18/#19).

**Architecture:** The backup file is a plain single-file SQLite database produced by `VACUUM INTO`. A path-driven `BackupService` (no plugins, fully testable) does export / validate / commit; a thin `BackupController` supplies temp paths, the share sheet, and the file picker. Import validates and migrates a throwaway copy first, and only overwrites the live DB once that copy proves it opens and migrates cleanly. After a successful restore the app shows a "please reopen" screen (no in-app DB reload).

**Tech Stack:** Flutter, drift (SQLite), flutter_riverpod, `share_plus`, `file_picker`, `sqlite3`.

## Global Constraints

- Dart SDK `^3.12.2`; drift `^2.34.2`; flutter_riverpod `^3.3.2` (StateProvider needs `import 'package:flutter_riverpod/legacy.dart';`).
- Test command: `flutter test --concurrency=1`.
- Money is stored in **minor units** (int); do not touch money here.
- Results use the existing `Result<T>` = `Ok<T>` / `Err<T>` from `lib/core/result/result.dart`.
- Failures reuse existing types from `lib/core/result/failure.dart`: `StorageFailure` (file I/O), `BackupIncompatibleFailure` (version too new), `MigrationFailure` (open/migrate). User-facing text already exists in `failure_messages.dart` — do **not** add new failure types or messages.
- Drift SQL table names are snake_case of the class name: `AccountsTable`→`accounts_table`, `TransactionsTable`→`transactions_table`, `GoalsTable`→`goals_table`, `MortgagesTable`→`mortgages_table`, `AppMetaTable`→`app_meta_table`.
- UI copy is Uzbek (Latin), matching the existing app.
- **Deferred, not in scope:** password-protected backup (§18.4), CSV/JSON report export (§18.3), merge-on-import (§19.3).

---

### Task 1: BackupPreview model + BackupService.exportTo

**Files:**
- Create: `lib/data/backup/backup_preview.dart`
- Create: `lib/data/backup/backup_service.dart`
- Test: `test/data/backup/backup_service_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` (`lib/data/db/app_database.dart`), `DriftMetaRepository` (`lib/data/meta/meta_repository.dart`), `Result`/`Ok`/`Err`, `StorageFailure`.
- Produces:
  - `class BackupPreview { final int schemaVersion; final DateTime backupDate; final Map<String,int> counts; final String validatedTempPath; const BackupPreview({...}); }`
  - `class BackupService { BackupService(this.db, this.dbPath); final AppDatabase db; final String dbPath; Future<Result<void>> exportTo(String destPath); }`

- [ ] **Step 1: Write the failing test**

Create `test/data/backup/backup_service_test.dart`:

```dart
import 'dart:io';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/backup/backup_service.dart';

Future<void> _seedOneAccount(AppDatabase db) => db.into(db.accountsTable).insert(
      AccountsTableCompanion.insert(name: 'Cash', type: 'cash'),
    );

void main() {
  test('exportTo writes an openable backup with the same data + backup timestamp',
      () async {
    final tmp = await Directory.systemTemp.createTemp('bk');
    final dbPath = '${tmp.path}/app.db';
    final db = AppDatabase(NativeDatabase(File(dbPath)));
    await _seedOneAccount(db);
    final service = BackupService(db, dbPath);

    final dest = '${tmp.path}/out.fabackup';
    final r = await service.exportTo(dest);
    expect(r.isOk, isTrue);
    expect(await File(dest).exists(), isTrue);

    final out = AppDatabase(NativeDatabase(File(dest)));
    final n = (await out.customSelect('SELECT count(*) AS n FROM accounts_table')
            .getSingle())
        .read<int>('n');
    expect(n, 1);
    final backupAt = (await out.customSelect(
            'SELECT last_backup_at AS t FROM app_meta_table')
        .getSingle());
    expect(backupAt.data['t'], isNotNull); // timestamp recorded before the snapshot
    await out.close();
    await db.close();
    await tmp.delete(recursive: true);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/data/backup/backup_service_test.dart`
Expected: FAIL — `backup_service.dart` / `BackupService` does not exist.

- [ ] **Step 3: Write BackupPreview**

Create `lib/data/backup/backup_preview.dart`:

```dart
/// Read-only summary of a validated backup, shown on the pre-import sheet
/// (PRD §19.2). `validatedTempPath` points at an already-migrated copy of the
/// backup, ready to be swapped in by [BackupService.commit].
class BackupPreview {
  final int schemaVersion;
  final DateTime backupDate;
  final Map<String, int> counts; // Uzbek label -> row count
  final String validatedTempPath;
  const BackupPreview({
    required this.schemaVersion,
    required this.backupDate,
    required this.counts,
    required this.validatedTempPath,
  });
}
```

- [ ] **Step 4: Write BackupService.exportTo**

Create `lib/data/backup/backup_service.dart`:

```dart
import 'dart:io';
import '../../core/result/failure.dart';
import '../../core/result/result.dart';
import '../db/app_database.dart';
import '../meta/meta_repository.dart';

/// File-level backup operations (PRD §18–19). Path-driven and plugin-free so it
/// is fully unit-testable; the controller supplies temp/share/picker paths.
class BackupService {
  final AppDatabase db;
  final String dbPath;
  BackupService(this.db, this.dbPath);

  /// Writes a transactionally-consistent single-file SQLite snapshot to
  /// [destPath] (PRD §18.1). Records the backup time first so the snapshot
  /// carries its own creation timestamp.
  Future<Result<void>> exportTo(String destPath) async {
    try {
      await DriftMetaRepository(db).touchBackup(DateTime.now());
      final dest = File(destPath);
      if (await dest.exists()) await dest.delete(); // VACUUM INTO fails if it exists
      // ponytail: escape single quotes; temp paths have none, but be safe.
      final escaped = destPath.replaceAll("'", "''");
      await db.customStatement("VACUUM INTO '$escaped'");
      return const Ok(null);
    } catch (e) {
      return Err(StorageFailure(e.toString()));
    }
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test --concurrency=1 test/data/backup/backup_service_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/data/backup/ test/data/backup/backup_service_test.dart
git commit -m "feat(backup): BackupService.exportTo via VACUUM INTO + BackupPreview"
```

---

### Task 2: BackupService.validate

**Files:**
- Modify: `lib/data/backup/backup_service.dart`
- Modify: `pubspec.yaml` (add `sqlite3`)
- Test: `test/data/backup/backup_service_test.dart`

**Interfaces:**
- Consumes: `openAppDatabase` (`lib/data/db/db_open.dart`), `DriftMetaRepository`, `sqlite3` (`package:sqlite3/sqlite3.dart`), `path` (`package:path/path.dart`), `BackupIncompatibleFailure`, `MigrationFailure`, `StorageFailure`.
- Produces: `Future<Result<BackupPreview>> BackupService.validate(String pickedPath, String workDir)`.

- [ ] **Step 1: Add the sqlite3 dependency**

In `pubspec.yaml`, under `dependencies:` (alongside `drift`), add:

```yaml
  sqlite3: ^2.4.0
```

Run: `flutter pub get`
Expected: resolves (sqlite3 is already a transitive drift dependency).

- [ ] **Step 2: Write the failing tests**

Append to `test/data/backup/backup_service_test.dart` (inside `main()`), and add these imports at the top: `import 'package:sqlite3/sqlite3.dart';` and `import 'package:financial_assistant/core/result/failure.dart';`:

```dart
  test('validate returns a preview with counts + backup date for a good backup',
      () async {
    final tmp = await Directory.systemTemp.createTemp('bk');
    final dbPath = '${tmp.path}/app.db';
    final db = AppDatabase(NativeDatabase(File(dbPath)));
    await _seedOneAccount(db);
    final service = BackupService(db, dbPath);
    final backup = '${tmp.path}/out.fabackup';
    await service.exportTo(backup);

    final r = await service.validate(backup, '${tmp.path}/work');
    expect(r.isOk, isTrue);
    final preview = r.valueOrNull!;
    expect(preview.counts['Hisoblar'], 1);
    expect(await File(preview.validatedTempPath).exists(), isTrue);
    await db.close();
    await tmp.delete(recursive: true);
  });

  test('validate rejects a backup whose schema is newer than this app', () async {
    final tmp = await Directory.systemTemp.createTemp('bk');
    final dbPath = '${tmp.path}/app.db';
    final db = AppDatabase(NativeDatabase(File(dbPath)));
    final service = BackupService(db, dbPath);
    final backup = '${tmp.path}/out.fabackup';
    await service.exportTo(backup);
    final raw = sqlite3.open(backup);
    raw.userVersion = 999; // pretend it came from a much newer app version
    raw.dispose();

    final r = await service.validate(backup, '${tmp.path}/work');
    expect(r.isOk, isFalse);
    r.when(ok: (_) => fail('expected failure'),
        err: (f) => expect(f, isA<BackupIncompatibleFailure>()));
    await db.close();
    await tmp.delete(recursive: true);
  });

  test('validate rejects a non-database (corrupt) file', () async {
    final tmp = await Directory.systemTemp.createTemp('bk');
    final db = AppDatabase(NativeDatabase(File('${tmp.path}/app.db')));
    final service = BackupService(db, '${tmp.path}/app.db');
    final junk = '${tmp.path}/junk.fabackup';
    await File(junk).writeAsBytes(List<int>.filled(64, 0xAB));

    final r = await service.validate(junk, '${tmp.path}/work');
    expect(r.isOk, isFalse); // StorageFailure or BackupIncompatibleFailure — never Ok
    await db.close();
    await tmp.delete(recursive: true);
  });
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test --concurrency=1 test/data/backup/backup_service_test.dart`
Expected: FAIL — `validate` is not defined.

- [ ] **Step 4: Implement validate**

Add these imports to `lib/data/backup/backup_service.dart`:

```dart
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import '../db/db_open.dart';
```

Add the method to `BackupService`:

```dart
  /// Copies [pickedPath] into [workDir], checks it is a readable SQLite file no
  /// newer than this app (PRD §20.4), migrates the copy to the current schema,
  /// and returns its counts + backup date (PRD §19.2). The original DB is never
  /// touched. The returned [BackupPreview.validatedTempPath] is the migrated copy.
  Future<Result<BackupPreview>> validate(String pickedPath, String workDir) async {
    final copyPath = p.join(workDir, 'validate.db');
    try {
      await Directory(workDir).create(recursive: true);
      await File(pickedPath).copy(copyPath);
    } catch (e) {
      return Err(StorageFailure(e.toString()));
    }

    // Version gate BEFORE migration: read user_version without touching schema.
    int backupVersion;
    try {
      final raw = sqlite3.open(copyPath);
      backupVersion = raw.userVersion;
      raw.dispose();
    } catch (e) {
      return Err(StorageFailure(e.toString())); // not a readable sqlite db
    }
    if (backupVersion < 1 || backupVersion > db.schemaVersion) {
      return Err(BackupIncompatibleFailure(
          'backup schema $backupVersion vs app ${db.schemaVersion}'));
    }

    // Open + migrate the copy (upgrades older backups; rollback-on-failure).
    final opened = await openAppDatabase(dbPath: copyPath);
    if (opened is Err<AppDatabase>) return Err(opened.failure);
    final copyDb = opened.valueOrNull!;
    try {
      final meta = await DriftMetaRepository(copyDb).read();
      final counts = await _counts(copyDb);
      return Ok(BackupPreview(
        schemaVersion: backupVersion,
        backupDate: meta.lastBackupAt ?? meta.installedAt,
        counts: counts,
        validatedTempPath: copyPath,
      ));
    } catch (e) {
      return Err(StorageFailure(e.toString()));
    } finally {
      await copyDb.close();
    }
  }

  Future<Map<String, int>> _counts(AppDatabase d) async {
    Future<int> c(String table) async =>
        (await d.customSelect('SELECT count(*) AS n FROM $table').getSingle())
            .read<int>('n');
    return {
      'Hisoblar': await c('accounts_table'),
      'Tranzaksiyalar': await c('transactions_table'),
      'Goal': await c('goals_table'),
      'Ipoteka': await c('mortgages_table'),
    };
  }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test --concurrency=1 test/data/backup/backup_service_test.dart`
Expected: PASS (all Task 1 + Task 2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/data/backup/backup_service.dart pubspec.yaml pubspec.lock test/data/backup/backup_service_test.dart
git commit -m "feat(backup): validate backups (version gate + migrate copy + counts)"
```

---

### Task 3: BackupService.commit

**Files:**
- Modify: `lib/data/backup/backup_service.dart`
- Test: `test/data/backup/backup_service_test.dart`

**Interfaces:**
- Consumes: `BackupPreview`, `AppDatabase.close()`, `File` I/O.
- Produces: `Future<Result<void>> BackupService.commit(BackupPreview preview)`.

- [ ] **Step 1: Write the failing test**

Append to `test/data/backup/backup_service_test.dart` (inside `main()`):

```dart
  test('commit replaces the live DB with the backup, then it reopens with the data',
      () async {
    final tmp = await Directory.systemTemp.createTemp('bk');
    // Source DB with 1 account -> a backup file.
    final srcPath = '${tmp.path}/src.db';
    final src = AppDatabase(NativeDatabase(File(srcPath)));
    await _seedOneAccount(src);
    final backup = '${tmp.path}/out.fabackup';
    await BackupService(src, srcPath).exportTo(backup);
    await src.close();

    // Target DB is empty; restore the backup over it.
    final targetPath = '${tmp.path}/target.db';
    final target = AppDatabase(NativeDatabase(File(targetPath)));
    final service = BackupService(target, targetPath);
    final preview = (await service.validate(backup, '${tmp.path}/work')).valueOrNull!;

    final r = await service.commit(preview);
    expect(r.isOk, isTrue);
    expect(await File('$targetPath.importbak').exists(), isFalse); // snapshot cleaned up

    final reopened = AppDatabase(NativeDatabase(File(targetPath)));
    final n = (await reopened.customSelect('SELECT count(*) AS n FROM accounts_table')
            .getSingle())
        .read<int>('n');
    expect(n, 1);
    await reopened.close();
    await tmp.delete(recursive: true);
  });

  test('commit leaves the original data intact when the swap fails', () async {
    final tmp = await Directory.systemTemp.createTemp('bk');
    final targetPath = '${tmp.path}/target.db';
    final target = AppDatabase(NativeDatabase(File(targetPath)));
    await _seedOneAccount(target); // 1 account we must not lose
    final service = BackupService(target, targetPath);

    // A preview whose validatedTempPath does not exist forces the copy to fail.
    final preview = BackupPreview(
      schemaVersion: target.schemaVersion,
      backupDate: DateTime(2026, 1, 1),
      counts: const {},
      validatedTempPath: '${tmp.path}/does-not-exist.db',
    );
    final r = await service.commit(preview);
    expect(r.isOk, isFalse);

    final reopened = AppDatabase(NativeDatabase(File(targetPath)));
    final n = (await reopened.customSelect('SELECT count(*) AS n FROM accounts_table')
            .getSingle())
        .read<int>('n');
    expect(n, 1); // original restored from the .importbak snapshot
    await reopened.close();
    await tmp.delete(recursive: true);
  });
```

Add `import 'package:financial_assistant/data/backup/backup_preview.dart';` to the test file's imports.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test --concurrency=1 test/data/backup/backup_service_test.dart`
Expected: FAIL — `commit` is not defined.

- [ ] **Step 3: Implement commit**

Add the method to `BackupService`:

```dart
  /// Replaces the live DB file with the validated backup (PRD §19.3). Closes the
  /// live handle, snapshots the current DB, swaps in the migrated copy, and on
  /// any file failure restores the snapshot so existing data is untouched
  /// (PRD §19.4). The caller must not use [db] after this and should route the
  /// user to a "reopen the app" screen.
  Future<Result<void>> commit(BackupPreview preview) async {
    final snapshot = '$dbPath.importbak';
    try {
      await db.close();
      await File(dbPath).copy(snapshot); // snapshot original (now closed = consistent)
    } catch (e) {
      return Err(StorageFailure(e.toString()));
    }
    try {
      await File(preview.validatedTempPath).copy(dbPath); // swap in migrated backup
      await File(snapshot).delete();
      return const Ok(null);
    } catch (e) {
      try {
        await File(snapshot).copy(dbPath); // rollback: restore original
      } catch (_) {
        // best-effort; original snapshot remains on disk for manual recovery
      }
      return Err(StorageFailure(e.toString()));
    }
  }
```

Add `import 'backup_preview.dart';` to `backup_service.dart` if not already present (BackupPreview is referenced).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test --concurrency=1 test/data/backup/backup_service_test.dart`
Expected: PASS (all service tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/backup/backup_service.dart test/data/backup/backup_service_test.dart
git commit -m "feat(backup): commit restore with snapshot rollback safety"
```

---

### Task 4: Riverpod wiring + BackupController + dependencies

**Files:**
- Modify: `pubspec.yaml` (add `share_plus`, `file_picker`)
- Modify: `lib/providers/app_providers.dart` (add `dbPathProvider`, `backupServiceProvider`, `backupControllerProvider`)
- Modify: `lib/main.dart` (override `dbPathProvider`)
- Create: `lib/features/backup/backup_controller.dart`
- Test: `test/providers/backup_providers_test.dart`

**Interfaces:**
- Consumes: `BackupService`, `databaseProvider`, `getTemporaryDirectory` (`package:path_provider`), `Share`/`XFile` (`package:share_plus`), `FilePicker` (`package:file_picker`).
- Produces:
  - `final dbPathProvider = Provider<String>(...)`
  - `final backupServiceProvider = Provider<BackupService>(...)`
  - `final backupControllerProvider = Provider<BackupController>(...)`
  - `class BackupController { Future<Result<void>> exportAndShare(); Future<Result<BackupPreview?>> pickAndValidate(); Future<Result<void>> confirm(BackupPreview preview); }` — `pickAndValidate` returns `Ok(null)` when the user cancels the picker.

- [ ] **Step 1: Add dependencies**

In `pubspec.yaml` under `dependencies:` add:

```yaml
  share_plus: ^12.0.0
  file_picker: ^10.3.4
```

Run: `flutter pub get`
Expected: resolves.

- [ ] **Step 2: Write the failing test**

Create `test/providers/backup_providers_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/backup/backup_service.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  test('backupServiceProvider builds a service from db + dbPath overrides', () {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      dbPathProvider.overrideWithValue('/tmp/app.db'),
    ]);
    addTearDown(container.dispose);

    final service = container.read(backupServiceProvider);
    expect(service, isA<BackupService>());
    expect(service.dbPath, '/tmp/app.db');
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/providers/backup_providers_test.dart`
Expected: FAIL — `dbPathProvider` / `backupServiceProvider` undefined.

- [ ] **Step 4: Add the providers**

In `lib/providers/app_providers.dart`, add these imports:

```dart
import '../data/backup/backup_service.dart';
import '../features/backup/backup_controller.dart';
```

And after `databaseProvider` add:

```dart
/// Absolute path to the live DB file. Overridden in the composition root.
final dbPathProvider = Provider<String>(
  (ref) => throw UnimplementedError('dbPathProvider must be overridden'),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(databaseProvider), ref.watch(dbPathProvider)),
);

final backupControllerProvider = Provider<BackupController>(
  (ref) => BackupController(ref.watch(backupServiceProvider)),
);
```

- [ ] **Step 5: Create the controller**

Create `lib/features/backup/backup_controller.dart`:

```dart
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/result/failure.dart';
import '../../core/result/result.dart';
import '../../data/backup/backup_preview.dart';
import '../../data/backup/backup_service.dart';

/// Thin glue between [BackupService] and the platform (temp dir, share sheet,
/// file picker). Not unit-tested — it wraps plugins; the logic lives in the
/// service, which is fully covered.
class BackupController {
  final BackupService service;
  BackupController(this.service);

  /// Exports a backup and opens the OS share sheet (PRD §18.2).
  Future<Result<void>> exportAndShare() async {
    final tmp = await getTemporaryDirectory();
    final dest = p.join(tmp.path, 'financial-assistant-${_stamp(DateTime.now())}.fabackup');
    final r = await service.exportTo(dest);
    if (r is Err<void>) return r;
    // share_plus v12 API: SharePlus.instance.share(ShareParams(...)).
    await SharePlus.instance.share(ShareParams(files: [XFile(dest)]));
    return const Ok(null);
  }

  /// Picks a file and validates it. `Ok(null)` means the user cancelled.
  Future<Result<BackupPreview?>> pickAndValidate() async {
    final picked = await FilePicker.platform.pickFiles();
    final path = picked?.files.single.path;
    if (path == null) return const Ok(null);
    final tmp = await getTemporaryDirectory();
    final r = await service.validate(path, p.join(tmp.path, 'restore'));
    return r.when(ok: (preview) => Ok(preview), err: (f) => Err(f));
  }

  Future<Result<void>> confirm(BackupPreview preview) => service.commit(preview);

  String _stamp(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)}';
  String _two(int n) => n.toString().padLeft(2, '0');
}
```

- [ ] **Step 6: Override dbPathProvider in main**

In `lib/main.dart`, change the overrides list so it also provides the path:

```dart
    ok: (db) => runApp(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          dbPathProvider.overrideWithValue(dbPath),
        ],
        child: const App(),
      ),
    ),
```

- [ ] **Step 7: Run test + analyzer**

Run: `flutter test --concurrency=1 test/providers/backup_providers_test.dart`
Expected: PASS.
Run: `flutter analyze lib/features/backup lib/providers/app_providers.dart lib/main.dart`
Expected: No issues.

- [ ] **Step 8: Commit**

```bash
git add lib/features/backup/ lib/providers/app_providers.dart lib/main.dart pubspec.yaml pubspec.lock test/providers/backup_providers_test.dart
git commit -m "feat(backup): riverpod wiring + BackupController (export/pick/commit glue)"
```

---

### Task 5: Restore confirmation sheet

**Files:**
- Create: `lib/features/backup/restore_confirm_sheet.dart`
- Test: `test/features/backup/restore_confirm_sheet_test.dart`

**Interfaces:**
- Consumes: `BackupPreview`, existing `showVeloraSheet` (`lib/ui/components/velora_sheet.dart`) and `VeloraButton` (`lib/ui/components/velora_button.dart`) — follow their signatures as used elsewhere (e.g. `lib/features/allocation/allocation_rule_sheet.dart`).
- Produces: `Future<bool> showRestoreConfirmSheet(BuildContext context, BackupPreview preview)` — resolves `true` if the user confirms restore, `false`/`null`→ treated as cancel.

- [ ] **Step 1: Write the failing widget test**

Create `test/features/backup/restore_confirm_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/backup/backup_preview.dart';
import 'package:financial_assistant/features/backup/restore_confirm_sheet.dart';

void main() {
  testWidgets('shows counts and returns true on confirm', (tester) async {
    final preview = BackupPreview(
      schemaVersion: 8,
      backupDate: DateTime(2026, 7, 20),
      counts: const {'Hisoblar': 4, 'Tranzaksiyalar': 312},
      validatedTempPath: '/tmp/validate.db',
    );
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async =>
                result = await showRestoreConfirmSheet(context, preview),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('312'), findsWidgets); // a count is shown
    await tester.tap(find.text('Tiklash'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/features/backup/restore_confirm_sheet_test.dart`
Expected: FAIL — `restore_confirm_sheet.dart` does not exist.

- [ ] **Step 3: Implement the sheet**

Create `lib/features/backup/restore_confirm_sheet.dart`. First open `lib/features/allocation/allocation_rule_sheet.dart` to copy the exact `showVeloraSheet`/`VeloraButton` usage pattern, then:

```dart
import 'package:flutter/material.dart';
import '../../data/backup/backup_preview.dart';
import '../../ui/components/velora_sheet.dart';
import '../../ui/components/velora_button.dart';

/// Pre-import confirmation (PRD §19.2): shows backup date + data counts and
/// warns that all current data will be replaced. Returns true on confirm.
Future<bool> showRestoreConfirmSheet(
    BuildContext context, BackupPreview preview) async {
  final result = await showVeloraSheet<bool>(
    context: context,
    title: 'Zaxiradan tiklash',
    builder: (context) {
      final theme = Theme.of(context);
      final d = preview.backupDate;
      final date =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Sana: $date', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          for (final e in preview.counts.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key, style: theme.textTheme.bodyMedium),
                  Text('${e.value}', style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text(
            "⚠ Mavjud barcha ma'lumot almashtiriladi.",
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: VeloraButton(
                  label: 'Bekor',
                  variant: VeloraButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: VeloraButton(
                  label: 'Tiklash',
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
  return result ?? false;
}
```

Note: adjust `showVeloraSheet` parameter names, `VeloraButton` prop names, and `VeloraButtonVariant` to match the real signatures you find in the components — do not invent props.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --concurrency=1 test/features/backup/restore_confirm_sheet_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/backup/restore_confirm_sheet.dart test/features/backup/restore_confirm_sheet_test.dart
git commit -m "feat(backup): pre-import confirmation sheet (§19.2)"
```

---

### Task 6: Settings entry points + restore-complete screen

**Files:**
- Create: `lib/features/backup/restore_complete_screen.dart`
- Modify: `lib/features/settings/settings_screen.dart` (replace the disabled tile group around line 470–480)
- Test: `test/features/settings/settings_screen_test.dart` (extend)

**Interfaces:**
- Consumes: `backupControllerProvider`, `metaProvider` (for last-backup subtitle), `showRestoreConfirmSheet`, `showAppSnackbar` (`lib/ui/components/app_snackbar.dart`), `userMessageFor` (`lib/core/result/failure_messages.dart`).
- Produces: user-visible Export and Restore actions; a full-screen `RestoreCompleteScreen`.

- [ ] **Step 1: Create the restore-complete screen**

Create `lib/features/backup/restore_complete_screen.dart`:

```dart
import 'package:flutter/material.dart';

/// Terminal screen after a successful restore. We do not reload the DB in place;
/// the user reopens the app so all providers rebuild against the restored file.
class RestoreCompleteScreen extends StatelessWidget {
  const RestoreCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Tiklash tugadi', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                "Ma'lumotlar tiklandi. O'zgarishlar kuchga kirishi uchun ilovani qayta oching.",
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Wire the settings tiles**

In `lib/features/settings/settings_screen.dart`, open the section around line 470 and replace the single disabled `_SettingsGroup` (the "keyingi bosqichda" placeholder) with two enabled tiles. The surrounding widget is a `ConsumerWidget`/`Consumer` (it already reads settings via `ref`); use `ref` to read `backupControllerProvider`. Replace:

```dart
              const _SectionHeader("Ma'lumotlar"),
              const _SettingsGroup(
                children: [
                  ListTile(
                    enabled: false,
                    leading: _RowIcon(Icons.download_outlined),
                    title: Text("Ma'lumotlarni eksport qilish"),
                    subtitle: Text('(keyingi bosqichda)'),
                  ),
                ],
              ),
```

with:

```dart
              const _SectionHeader("Ma'lumotlar"),
              _SettingsGroup(
                children: [
                  ListTile(
                    leading: const _RowIcon(Icons.download_outlined),
                    title: const Text("Zaxira nusxa yaratish"),
                    onTap: () => _exportBackup(context, ref),
                  ),
                  ListTile(
                    leading: const _RowIcon(Icons.restore_outlined),
                    title: const Text("Zaxiradan tiklash"),
                    onTap: () => _restoreBackup(context, ref),
                  ),
                ],
              ),
```

Then add these handler methods to the same widget class (and add imports for `backupControllerProvider` via `../../providers/app_providers.dart`, `showRestoreConfirmSheet` from `../backup/restore_confirm_sheet.dart`, `RestoreCompleteScreen` from `../backup/restore_complete_screen.dart`, `userMessageFor` from `../../core/result/failure_messages.dart`, `showAppSnackbar` from `../../ui/components/app_snackbar.dart`, and `Result`/`Err` types):

```dart
  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final r = await ref.read(backupControllerProvider).exportAndShare();
    if (!context.mounted) return;
    r.when(
      ok: (_) {},
      err: (f) => showAppSnackbar(context, userMessageFor(f)),
    );
  }

  Future<void> _restoreBackup(BuildContext context, WidgetRef ref) async {
    final picked = await ref.read(backupControllerProvider).pickAndValidate();
    if (!context.mounted) return;
    final preview = picked.valueOrNull;
    if (picked is Err) {
      showAppSnackbar(context, userMessageFor((picked as Err).failure));
      return;
    }
    if (preview == null) return; // cancelled
    final confirmed = await showRestoreConfirmSheet(context, preview);
    if (!confirmed || !context.mounted) return;
    final done = await ref.read(backupControllerProvider).confirm(preview);
    if (!context.mounted) return;
    done.when(
      ok: (_) => Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RestoreCompleteScreen()),
        (route) => false,
      ),
      err: (f) => showAppSnackbar(context, userMessageFor(f)),
    );
  }
```

Note: match `showAppSnackbar`'s real signature (check `lib/ui/components/app_snackbar.dart`) — adjust the call if it differs.

- [ ] **Step 3: Verify existing settings tests still pass + analyze**

Run: `flutter test --concurrency=1 test/features/settings/settings_screen_test.dart`
Expected: PASS (update the test only if it asserted on the old disabled tile text).
Run: `flutter analyze lib/features/backup lib/features/settings/settings_screen.dart`
Expected: No issues.

- [ ] **Step 4: Full test sweep**

Run: `flutter test --concurrency=1`
Expected: PASS except the known-environmental golden failures noted in project memory. If any golden for the settings screen changed because the tile group changed, re-baseline it per the repo's golden-update process and note it.

- [ ] **Step 5: Manual verification (device/emulator)**

Since export/import use platform plugins, verify by hand:
1. Settings ▸ Ma'lumotlar ▸ **Zaxira nusxa yaratish** → share sheet appears; save the `.fabackup`.
2. Add a transaction, then **Zaxiradan tiklash** → pick the file → sheet shows date + counts → **Tiklash** → "Tiklash tugadi" screen → reopen app → the added transaction is gone (restored to backup state).

- [ ] **Step 6: Commit**

```bash
git add lib/features/backup/restore_complete_screen.dart lib/features/settings/settings_screen.dart test/features/settings/settings_screen_test.dart
git commit -m "feat(backup): settings export/restore entry points + restore-complete screen"
```

---

## Follow-up (flagged, not in this plan)

- End-to-end §20.4 test: build an older-schema fixture DB and assert `validate` migrates it on restore. Heavier to fabricate (needs a hand-authored old-schema file); track as a targeted test.
- Password-protected backup (§18.4) and CSV/JSON report export (§18.3) — separate future features.
