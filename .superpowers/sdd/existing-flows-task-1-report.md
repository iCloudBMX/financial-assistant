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
