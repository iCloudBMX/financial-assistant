# Velora Data, Notifications, and Security Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete full backup/restore, CSV/JSON export, local notifications, dashboard personalization, migration recovery UX, and native-biometric/PIN security required by the PRD and approved mockups.

**Architecture:** Pure backup codecs and validators are independent from platform file/share adapters. Destructive restore operates against a staged database and swaps only after validation. Notification scheduling is behind a mockable service; preferences remain in Settings. Security uses native biometric prompts and secure-storage PIN secrets.

**Tech Stack:** Drift schema v7, `archive ^4.0.9`, `cryptography ^2.9.0`, `file_picker ^11.0.2`, `share_plus ^13.2.1`, `flutter_local_notifications ^22.1.0`, `timezone ^0.11.1`, local_auth, flutter_secure_storage.

## Global Constraints

- Execute after UI Foundation, Existing Flows, and Reports/Month-Close plans.
- All data stays on-device unless the user explicitly exports/shares a file.
- MVP restore is full replacement only; no merge option is shown.
- Failed import leaves current data byte-for-byte unchanged.
- A recovery backup is created before restore and before schema migration.
- PIN is four digits, salted/hashed in secure storage, and never stored in SQLite.
- Biometric UI is always the native operating-system prompt.
- Package/platform requirements must be checked against official pub.dev pages before execution; current Android AGP 9.0.1, Gradle 9.1, Java 17 satisfy the listed package floors.

---

### Task 1: Add platform dependencies and adapters

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/build.gradle.kts`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`
- Create: `lib/platform/file_gateway.dart`
- Create: `lib/platform/share_gateway.dart`
- Create: `test/platform/platform_gateways_test.dart`

**Interfaces:**
- `FileGateway.pickBackup()`, `saveBackup(name, bytes)`.
- `ShareGateway.shareFile(path)`.

- [ ] Add fake-gateway tests proving cancel returns typed cancellation and file/share errors return `PersistenceFailure`.
- [ ] Run `flutter test test/platform/platform_gateways_test.dart`; expect missing interfaces.
- [ ] Add pinned dependencies, Android notification/desugaring permissions, iOS Face ID/notification descriptions, and adapter implementations with no business logic.
- [ ] Run `flutter pub get`, `flutter analyze`, and platform gateway tests; expect successful resolution and PASS.
- [ ] Commit with `git add pubspec.* android ios lib/platform test/platform && git commit -m "feat: add data and notification platform adapters"`.

### Task 2: Define and test the Velora backup container

**Files:**
- Create: `lib/core/backup/backup_manifest.dart`
- Create: `lib/core/backup/backup_codec.dart`
- Create: `lib/core/backup/backup_crypto.dart`
- Create: `test/core/backup/backup_codec_test.dart`

**Interfaces:**
- `BackupCodec.encode(BackupPayload, {String? password}) -> Future<Uint8List>`.
- `BackupCodec.inspect(Uint8List, {String? password}) -> Future<Result<BackupPreview>>`.
- Container: magic `VLRB`, format version 1, manifest JSON, SQLite snapshot, SHA-256 checksums; password mode uses PBKDF2-HMAC-SHA256 with 310,000 iterations, a random 16-byte salt, a 32-byte key, and AES-256-GCM with a random 12-byte nonce.

- [ ] Write round-trip, wrong-password, tamper, corrupted ZIP, unsupported version, and deterministic-manifest tests.
- [ ] Run `flutter test test/core/backup`; expect missing codec failure.
- [ ] Implement the exact container and cryptographic parameters; never log password, key, decrypted database bytes, or financial content.
- [ ] Run core backup tests; expect every invalid input to return a typed failure without throwing.
- [ ] Commit with `git add lib/core/backup test/core/backup && git commit -m "feat: add versioned encrypted backup codec"`.

### Task 3: Implement export, preview, and transactional full restore

**Files:**
- Create: `lib/data/backup/backup_repository.dart`
- Create: `lib/data/backup/report_exporter.dart`
- Modify: `lib/data/meta/meta_repository.dart`
- Create: `test/data/backup/backup_repository_test.dart`
- Create: `test/data/backup/report_exporter_test.dart`

**Interfaces:**
- `exportFull(password) -> Future<Result<ExportedBackup>>`.
- `previewImport(bytes, password) -> Future<Result<BackupPreview>>`.
- `restoreFull(bytes, password) -> Future<Result<void>>`.
- `exportTransactions(format: csv|json, filter) -> Future<Result<Uint8List>>`.

- [ ] Write tests that all tables are present, preview counts match, CSV/JSON escape Uzbek text, successful restore replaces all data, and forced validation/swap failure preserves the live DB.
- [ ] Run backup repository tests; expect missing implementation.
- [ ] Snapshot live DB, decode into a staging path, open/migrate/validate staging, close both DBs, atomically swap files, and reopen. On any failure restore the live snapshot and keep `lastBackupAt` unchanged.
- [ ] Run repository, migration-recovery, and exporter tests; expect PASS and zero partial restoration.
- [ ] Commit with `git add lib/data/backup lib/data/meta test/data/backup && git commit -m "feat: add safe export and full restore"`.

### Task 4: Build Velora backup/import/recovery screens

**Files:**
- Create: `lib/features/data_management/data_management_screen.dart`
- Create: `lib/features/data_management/backup_export_sheet.dart`
- Create: `lib/features/data_management/import_preview_screen.dart`
- Create: `lib/features/data_management/migration_recovery_screen.dart`
- Modify: `lib/features/settings/settings_screen.dart`
- Modify: `lib/features/shell/routes.dart`
- Create: `test/features/data_management/data_management_test.dart`
- Create: `test/goldens/data_management_golden_test.dart`

**Interfaces:**
- Settings routes to data management; import preview shows version/date/counts and only “current data replacement”.

- [ ] Write tests for plain/protected export, OS save/share, password retry, validated preview, authentication gate, destructive confirmation, corrupted/version errors, retry, and migration-recovery messaging.
- [ ] Run tests and verify missing screens.
- [ ] Implement approved Velora screens with one primary CTA, current-data safety backup explanation, progress that cannot be dismissed during swap, and typed recovery actions.
- [ ] Run widget/golden and backup rollback tests; expect PASS.
- [ ] Commit with `git add lib/features/data_management lib/features/settings lib/features/shell test/features/data_management test/goldens && git commit -m "feat: add Velora data management flows"`.

### Task 5: Add schema v7 dashboard preferences

**Files:**
- Modify: `lib/data/db/tables.dart`
- Modify: `lib/data/db/app_database.dart`
- Modify: `lib/data/db/migrations.dart`
- Modify: `lib/data/settings/settings_model.dart`
- Modify: `lib/data/settings/settings_repository.dart`
- Create: `test/data/db/schema_v7_migration_test.dart`
- Modify: `test/data/settings/settings_repository_test.dart`

**Interfaces:**
- Adds `dashboardLayoutJson` and `primaryGoalId` to settings; schema version becomes 7.

- [ ] Add v6→v7 migration and settings round-trip tests with default essential cards `safeLimit` and `unallocated` visible.
- [ ] Run DB/settings tests; expect missing columns.
- [ ] Add nullable primary goal FK semantics in repository validation and JSON layout ordering/hide state. Prevent both essential signals from being hidden.
- [ ] Run every migration and settings test; expect v1→v7 compatibility.
- [ ] Commit with `git add lib/data/db lib/data/settings test/data && git commit -m "feat: persist dashboard personalization"`.

### Task 6: Implement dashboard customization UI

**Files:**
- Create: `lib/features/home/dashboard_customize_sheet.dart`
- Modify: `lib/features/home/home_screen.dart`
- Modify: `lib/features/settings/settings_screen.dart`
- Create: `test/features/home/dashboard_customize_test.dart`

**Interfaces:**
- Reorder, hide/show, and primary-goal selection save through `SettingsController`.

- [ ] Write tests for drag reorder, visibility toggles, essential-card guard, primary goal, persistence after restart, and Home order update.
- [ ] Run the tests; expect missing customization sheet.
- [ ] Implement a reorderable list with explicit move semantics for accessibility and a single Save CTA.
- [ ] Run Home/settings tests and goldens; expect PASS.
- [ ] Commit with `git add lib/features/home lib/features/settings test/features/home && git commit -m "feat: add dashboard personalization"`.

### Task 7: Implement local notification policy and settings

**Files:**
- Create: `lib/core/notifications/notification_rule.dart`
- Create: `lib/platform/local_notification_service.dart`
- Create: `lib/features/settings/notification_settings_screen.dart`
- Modify: `lib/features/settings/settings_controller.dart`
- Modify: `lib/main.dart`
- Create: `test/core/notifications/notification_rule_test.dart`
- Create: `test/features/settings/notification_settings_test.dart`

**Interfaces:**
- Notification types: mortgage due, mandatory payment, budget 80%, budget exhausted, daily-limit exceeded, unallocated income, goal due, month-close, stale backup.
- `NotificationService.sync(NotificationPlan)` is mockable and idempotent.

- [ ] Write pure scheduling tests, permission-denied tests, independent-toggle persistence, stable notification IDs, and deep-link payload tests.
- [ ] Run tests; expect missing policy/service.
- [ ] Implement rules, initialize `timezone` data, request permission only from user action, and schedule/cancel through `flutter_local_notifications`. Route payloads to the related GoRouter destination.
- [ ] Run notification/settings tests and Android/iOS debug builds; expect PASS.
- [ ] Commit with `git add lib/core/notifications lib/platform lib/features/settings lib/main.dart test && git commit -m "feat: add local notification controls"`.

### Task 8: Harden PIN, native biometrics, privacy, and delete-all

**Files:**
- Modify: `lib/features/security/app_lock_controller.dart`
- Modify: `lib/features/security/app_lock_gate.dart`
- Modify: `lib/features/security/background_shield.dart`
- Create: `lib/features/security/security_settings_screen.dart`
- Create: `test/features/security/security_flow_test.dart`
- Modify: `test/app_boot_lock_test.dart`

**Interfaces:**
- Four-digit PIN auto-submit; native biometric auto-attempt once; cooldown after five failures; authenticated delete-all; forgotten-PIN recovery requires successful native biometric authentication or full local-data reset.

- [ ] Add tests for PIN length, salted hash, five-failure cooldown, biometric cancel/lockout/fallback, app-resume relock, hidden app-switcher preview, forgotten-PIN biometric reset, forgotten-PIN destructive fallback, and delete-all requiring reauthentication + typed phrase.
- [ ] Run security tests; expect failures for keypad/cooldown/delete-all behavior.
- [ ] Implement controller-owned failure counters using secure storage, native `local_auth`, privacy shield before lifecycle pause rendering, biometric-authorized PIN replacement, and an explicit full-data reset fallback when biometrics cannot prove ownership. The atomic wipe preserves only install bootstrap state.
- [ ] Run security widget tests and real-device biometric checklist on iOS/Android.
- [ ] Commit with `git add lib/features/security test/features/security test/app_boot_lock_test.dart && git commit -m "feat: harden Velora local security"`.

### Task 9: Final 22-AC verification and visual fidelity gate

**Files:**
- Create: `integration_test/mvp_acceptance_test.dart`
- Create: `docs/qa/velora-mvp-acceptance.md`
- Modify: all Velora golden suites only when reviewed visual changes are intentional.

**Interfaces:**
- Produces evidence for AC 1–22 and every approved mock/state.

- [ ] Implement an integration matrix covering account, timed income/expense, allocation, safe-limit recalculation, budgets, goals, mortgage, reports, offline, backup/restore, migration failure, and iOS/Android parity.
- [ ] Run `dart format --set-exit-if-changed lib test integration_test`, `flutter analyze`, and `flutter test`; expect no formatting changes, 0 issues, all tests pass.
- [ ] Run Android and iOS integration suites, inspect every approved screen golden, and record device/OS/duration/result in the QA document.
- [ ] Verify `git diff --check` and confirm no raw exception text, hidden-overflow errors, merge-import option, custom biometric dialog, or unapproved mock drift.
- [ ] Commit with `git add integration_test docs/qa test/goldens && git commit -m "test: verify Velora MVP acceptance"`.
