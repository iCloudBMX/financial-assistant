# Existing Financial Flows Task 1 Report

## Outcome

- Encoded the safe-limit ownership contract explicitly: `totalAvailable` is
  full ledger cash before reserve deductions, and `dailySafeLimit` subtracts
  `minReserve`, `goalReserves`, and `unpaidMandatory` exactly once.
- Added a provider regression fixture with 1,000,000 UZS ledger cash and a
  300,000 UZS goal earmark; `spendable` is 700,000 UZS.
- Added `PersistenceFailure` and `CurrencyFailure` alongside the existing
  `ValidationFailure`.
- Added `userMessageFor(Failure)` mappings for validation, persistence, and
  currency failures. Messages are fixed, nontechnical, next-step-oriented
  strings and never interpolate `debugDetail`.
- Kept `userMessage(Failure)` as a compatibility delegate so existing
  presentation call sites continue to compile while new work can consume the
  approved `userMessageFor` interface.

## Ownership audit

The approved base already derived `totalAvailable` directly from
`totalsByCurrency(accounts, entries)`. Goal contributions are earmarks stored in
`goal_contributions`; they do not create ledger transactions. The provider also
already passed goal and mortgage reserves separately to `SafeLimitInputs`.
Therefore no provider-side pre-subtraction existed to remove. The implementation
renames the provider local to `ledgerCash`, documents the ownership at the
provider and value-object boundary, and locks it with the exact 700,000 UZS
regression.

Existing engine/provider coverage was retained for date and period behavior:

- `SafeLimitInputs.period` plus `asOf` drive the remaining-day divisor,
  including the last-day floor.
- `safeLimitProvider` passes the current financial period boundaries into
  `unpaidMandatoryMinor`.
- The focused verification includes the mortgage provider test where a payment
  due in the current period reduces the safe limit.

## TDD evidence

### RED

Command:

```text
flutter test --concurrency=1 test/core/result/result_test.dart
```

Exit code: 1. Compilation failed only on the wished-for interface:

```text
Method not found: 'PersistenceFailure'.
Method not found: 'CurrencyFailure'.
Method not found: 'userMessageFor'.
```

This demonstrated the typed-failure interface gap before production changes.

The new safe-limit regression was also run against the approved base behavior
and passed immediately. This is a deliberate characterization/regression test,
not the RED: it proved the audited double-subtraction was a risk rather than a
live defect in the current provider path.

### GREEN and focused verification

Command:

```text
flutter test --concurrency=1 test/core/limit/safe_limit_engine_test.dart test/providers/safe_limit_providers_test.dart test/providers/mortgage_providers_test.dart test/core/result/result_test.dart
```

Result: exit 0, 18/18 tests passed. This covers reserve ownership, engine
date/period inputs, current-period mortgage reservation, and typed user-safe
failure mapping.

### Full verification

```text
flutter test --concurrency=1
flutter analyze
```

- Full suite: exit 0, 340/340 tests passed.
- Analyzer: exit 0, `No issues found!`.
- The full suite emitted one pre-existing Drift warning from
  `settings_repository_test.dart` about multiple database classes using the
  same executor. It did not fail the suite and is unrelated to these changes.

## Deviations and risks

- Plan wording expected the new safe-limit test to fail with a lower value.
  Inspection and execution showed the approved base already follows the chosen
  ledger-cash ownership rule, so manufacturing a provider pre-subtraction and
  then removing it would have changed working code without evidence. The
  meaningful RED instead covered the required missing typed-failure interface.
- System Poppler executables were unavailable while reading the approved PRD.
  The relevant pages (safe-limit section 11 and failure section 26) were
  extracted with the bundled `pypdf` library. No PDF artifact was modified.
- `PersistenceFailure` and `StorageFailure` coexist. `StorageFailure` remains
  for compatibility with existing foundation and recovery paths; new
  repository/persistence flows can use the more explicit type without a broad,
  unrelated migration in this task.

## Review follow-up: failure taxonomy and production reachability

Review found that the first implementation defined new failure types without
enough separation or representative production translation. The follow-up
establishes these contracts:

- `StorageFailure`: filesystem/artifact I/O outside the live database, including
  backup, import, export, snapshot, and restore-file access.
- `MigrationFailure`: database open, schema migration, and recovery failures.
- `PersistenceFailure`: live repository/database read, write, or transaction
  failures where an in-app change was not saved.
- `CurrencyFailure`: a known incompatible-currency conflict translated at a
  `Result` intent or repository boundary. Low-level `Money` arithmetic retains
  `CurrencyMismatchError` as its invariant error.

The storage message now directs the user to choose another artifact location
and check file access. The migration message directs an app restart and backup
recovery. The persistence message remains specific to an unsaved live change
and retry. Tests require all three messages to be distinct and keep diagnostic
details out of presentation text.

Production reachability changes:

- `buildTransfer` returns `CurrencyFailure` when accounts or the amount use
  incompatible currencies; a non-positive amount remains `ValidationFailure`.
- `DriftLedgerRepository.editEntry` returns `CurrencyFailure` for a currency
  change while transfer-leg editing remains `ValidationFailure`.
- The transfer database transaction and edit update translate executor errors
  to `Err(PersistenceFailure(debugDetail))`. Lookup, not-found, and typed
  validation paths remain outside those catches.

### Follow-up RED

```text
flutter test --concurrency=1 test/core/result/result_test.dart test/core/ledger/balance_engine_test.dart test/data/ledger/ledger_repository_test.dart
```

Exit code: 1, with six expected failures:

- storage message lacked file/location recovery guidance;
- transfer construction and both ledger currency paths returned
  `ValidationFailure` instead of `CurrencyFailure`;
- a SQLite trigger aborting the second transfer insert escaped as a raw
  `SqliteException`;
- a SQLite trigger aborting an entry update escaped as a raw
  `SqliteException`.

### Follow-up GREEN and final verification

Focused command:

```text
flutter test --concurrency=1 test/core/result/result_test.dart test/core/ledger/balance_engine_test.dart test/data/ledger/ledger_repository_test.dart test/core/limit/safe_limit_engine_test.dart test/providers/safe_limit_providers_test.dart test/providers/mortgage_providers_test.dart
```

Result: exit 0, 35/35 passed. The transfer failure test also verifies the first
insert rolls back, and the edit failure test verifies the original row remains
unchanged.

Full verification:

```text
flutter test --concurrency=1
flutter analyze
```

- Full suite: exit 0, 343/343 tests passed.
- Analyzer: exit 0, `No issues found!`.
- The same pre-existing multiple-database Drift warning appeared in
  `settings_repository_test.dart`; it remains unrelated and non-failing.
