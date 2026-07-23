# Full backup / restore — design spec

**PRD:** §18 (export), §19 (import/restore), §20.4 (cross-version import), §26 (error handling).
**Acceptance criteria:** #18 (export all data to a backup file), #19 (full restore from backup).
**Date:** 2026-07-23

## Scope

**In:** full-database backup export and delete-and-restore import, with pre-import
validation and destructive-restore confirmation.

**Deferred (out of this spec):**
- Password-protected backup (§18.4) — optional in PRD, not an acceptance criterion.
  Needs an AES dependency (`crypto` only hashes). Flag in code:
  `// ponytail: plain snapshot; add AES + encrypt dep when §18.4 is required.`
- CSV/JSON transaction/report export (§18.3) — a separate readable-export feature,
  not the full backup. The PRD (line 852) explicitly allows the full backup to use
  its own format.
- Merge-on-import (§19.3) — PRD defers merge to a future version; MVP is
  delete-and-restore only.

## Format decision: SQLite file snapshot (not JSON dump)

The backup file is a **plain single-file SQLite database** produced by
`VACUUM INTO`, given the extension `.fabackup`. Rationale:

1. **Cross-version import (§20.4) is free.** Opening an older backup runs the
   existing, tested Drift migrations to upgrade it. A JSON dump would force a
   second migration code path (old-JSON → new-schema) maintained forever.
2. **Completeness (§18.1) is inherent.** All 11 tables — including
   `RecurringIncomePlansTable`, which §18.1's own prose list omits — are captured
   with no serializer to forget a table and no FK insert-ordering on restore.
3. **Correctness surface ≈ none.** SQLite copies itself; no DateTime/bool/nullable
   serialization to get wrong.

`VACUUM INTO` (not `File.copy`) is used because the backup is taken while the app
holds the DB open; `VACUUM INTO` writes a transactionally-consistent, compacted
single-file snapshot. (`recovery.dart`'s plain copy is correct only at its
shutdown-time call site.)

## Components

```
lib/data/backup/backup_service.dart   — file I/O + validation (no UI, no Riverpod)
lib/data/backup/backup_preview.dart   — BackupPreview value object
lib/features/backup/backup_controller.dart — Riverpod; releases DB handle, orchestrates
lib/features/backup/restore_confirm_sheet.dart — §19.2 pre-import sheet
Settings ▸ Ma'lumotlar — two tiles replace the disabled placeholder (settings_screen.dart:471)
```

### BackupService interface

```dart
Future<Result<String>>        exportBackup();              // → temp .fabackup path
Future<Result<BackupPreview>> validateBackup(String pickedPath);
Future<Result<void>>          commitRestore(BackupPreview preview);
```

### BackupPreview

```dart
class BackupPreview {
  final int schemaVersion;
  final DateTime? backupDate;      // from app_meta.lastBackupAt
  final Map<String,int> counts;    // per-table row counts for the sheet
  final String validatedTempPath;  // the already-migrated copy, ready to swap in
}
```

## Export flow (§18.1–18.2)

1. Settings ▸ **"Zaxira nusxa yaratish"**.
2. `VACUUM INTO <tempDir>/financial-assistant-<yyyy-MM-dd>.fabackup`.
3. Set `app_meta.lastBackupAt = now` (drives the tile subtitle).
4. UI hands the path to `share_plus` → OS share sheet (save to device / Files /
   other app). No auto cloud sync (§18.2).

Failure → `StorageFailure` (message already in `failure_messages.dart`).

## Import flow (§19) — original data untouched until a migrated copy proves good

1. Settings ▸ **"Zaxiradan tiklash"** → `file_picker` picks a file.
2. **`validateBackup`** operates on a throwaway copy:
   - copy picked file → `<tempDir>/validate.db`.
   - open it via the existing `openAppDatabase(validate.db)`:
     - schema-touch `SELECT` fails on garbage/corrupt → `StorageFailure` (§26).
     - **migrations run on the copy** → older backup upgraded in place (§20.4).
     - `schemaVersion > AppDatabase.schemaVersion` → `BackupIncompatibleFailure`
       (§20.4; "newer app version" case).
   - read `lastBackupAt` + `count(*)` per table → `BackupPreview`; close the copy.
3. **`restore_confirm_sheet`** shows date, counts, "⚠ mavjud barcha ma'lumot
   almashtiriladi", `[Bekor]` `[Tiklash]` (§19.2).
4. On confirm, **`commitRestore`**:
   - release the app DB handle (close via the controller).
   - snapshot current DB → `<dbPath>.importbak` (original data safety).
   - copy the already-migrated `validate.db` over `dbPath`.
   - success → delete `.importbak`.
   - file-I/O failure → restore `.importbak` over `dbPath`, then `StorageFailure`
     (§19.4: existing data intact, retry offered).
5. Navigate to a blocking **"Tiklash tugadi — ilovani qayta oching"** screen so no
   provider queries the closed DB. (Chosen over in-app reload: zero stale-state
   risk, negligible code. iOS cannot self-restart, so this is a "please reopen"
   screen, not a programmatic restart.)

## Error handling (§26)

All failures reuse existing typed `Failure`s and their non-technical Uzbek
`userMessageFor` text — no new types needed:
- corrupt / unreadable / I/O → `StorageFailure`
- incompatible (newer-version) backup → `BackupIncompatibleFailure`
- migration failure during validation → `MigrationFailure`

Every failure path leaves current data unchanged and allows retry (§19.4).

## Testing

- **Round-trip:** seed DB → `exportBackup` → wipe → `validateBackup` +
  `commitRestore` → assert per-table row counts and account balances match.
- **Version gate:** `validateBackup` rejects a doctored file whose
  `schemaVersion` exceeds `AppDatabase.schemaVersion` → `BackupIncompatibleFailure`.
- **Corruption:** garbage bytes → `StorageFailure`; original DB untouched.
- **Follow-up (flagged):** an older-schema fixture asserting §20.4
  migration-on-restore end-to-end; heavier to fabricate, tracked as a targeted
  test rather than a blocker.

## Dependencies

- `share_plus` — export share sheet (§18.2).
- `file_picker` — pick a backup to import.

## Entry points

`settings_screen.dart` — replace the single disabled tile (line 471, "keyingi
bosqichda") under the **"Ma'lumotlar"** section with:
- **"Zaxira nusxa yaratish"** — subtitle: last backup date (`lastBackupAt`) or none.
- **"Zaxiradan tiklash"**.
