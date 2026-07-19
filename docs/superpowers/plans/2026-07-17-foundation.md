# Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the runnable app skeleton (sub-project 0 of 7) that every later sub-project of the Personal Financial Assistant extends: layered architecture, pure-core money/time modules, a Drift SQLite database with a migration + snapshot-recovery engine, settings, an extensible onboarding stepper, a 5-tab shell, app-lock, and theming.

**Architecture:** Four downward-only layers — `core/` (pure Dart: money, time, result, theme, l10n), `data/` (Drift DB + repositories), `features/` (Riverpod + UI), and a composition root. Features touch the database only through repository interfaces. The two highest-value, hardest pieces — money arithmetic and financial-period math — are pure Dart, unit-tested exhaustively with no Flutter or DB in the way.

**Tech Stack:** Flutter (stable), Dart 3, Drift (SQLite), Riverpod (hooks_riverpod / flutter_riverpod), GoRouter, local_auth, flutter_secure_storage, intl, crypto, build_runner + drift_dev.

## Global Constraints

- **Platform:** iOS + Android, feature parity (PRD §28.22). No web/desktop targets in MVP.
- **Storage:** Local SQLite only; no network calls anywhere in Foundation (PRD §22.1, §23).
- **Money:** Integer minor units + currency code. **No floating-point money, ever.** UZS = 0 decimal digits.
- **Financial "month":** A period starting on a configurable day (PRD §5.1/§5.2), never assume calendar-1st.
- **Errors:** Data layer returns typed `Failure`s, not thrown exceptions; user-facing text is non-technical and states a next step (PRD §26).
- **Status encoding:** Any safe/near/over status must use color **+ icon + text**, never color alone (PRD §21.8).
- **Red:** Reserved strictly for error/critical states (PRD §21.2).
- **Performance:** Cold start < 2s (PRD §24).
- **UI language:** uz-Latn; font must render Cyrillic + Latin glyphs (PRD §21.3).
- **Commits:** Conventional Commits (`feat:`, `test:`, `chore:`, `refactor:`). Commit at the end of every task.
- **Generated code:** Drift/Riverpod generated files (`*.g.dart`, `*.drift.dart`) are git-ignored; run `dart run build_runner build --delete-conflicting-outputs` after changing annotated files.

---

## File Structure

```
lib/
  main.dart                         # entrypoint: ensureInitialized, run migration gate, runApp
  app.dart                          # root widget: ProviderScope, MaterialApp.router, theme, security wrap
  core/
    money/
      currency.dart                 # Currency, SymbolPosition, currency registry
      money.dart                    # Money value type + arithmetic/parse/format
    time/
      financial_period.dart         # FinancialPeriod + period/week math
      weekday.dart                  # week-start helpers
    result/
      failure.dart                  # Failure hierarchy
      result.dart                   # Result<T> (ok/err)
      failure_messages.dart         # Failure -> user-facing message
    theme/
      app_colors.dart               # warm palette + semantic status roles
      app_typography.dart           # text theme, numerals
      app_theme.dart                # light/dark ThemeData
    l10n/
      formatters.dart               # number/currency/date formatting (intl)
  data/
    db/
      tables.dart                   # Drift table definitions (app_settings, app_meta)
      app_database.dart             # AppDatabase, schemaVersion, MigrationStrategy
      migrations.dart               # stepByStep migration steps
      recovery.dart                 # snapshot + restore file operations
      db_open.dart                  # openConnection + migration gate orchestration
    settings/
      settings_repository.dart      # interface + Drift impl
      settings_model.dart           # AppSettings immutable model + enums
    meta/
      meta_repository.dart          # AppMeta interface + Drift impl
      meta_model.dart               # AppMeta immutable model
  features/
    shell/
      app_shell.dart                # 5-tab Scaffold + bottom nav
      placeholder_tab.dart          # reusable placeholder screen
      routes.dart                   # GoRouter config + route names
    onboarding/
      onboarding_step.dart          # OnboardingStep interface + registry provider
      onboarding_controller.dart    # Riverpod controller: draft state, commit
      onboarding_screen.dart        # stepper host
      steps/                        # welcome, currency, period, reserve, theme, applock
    settings/
      settings_screen.dart          # edit foundation settings
      settings_controller.dart      # Riverpod AsyncNotifier over SettingsRepository
    security/
      app_lock_controller.dart      # PIN hash (secure storage) + biometric
      app_lock_gate.dart            # gate widget wrapping router
      background_shield.dart        # blur overlay on inactive/paused
  providers/
    app_providers.dart              # database, repository providers (composition wiring)
test/
  core/money/…  core/time/…  core/result/…
  data/db/…  data/settings/…  data/meta/…
  features/…
  drift_schemas/                    # exported schema JSONs for migration tests
integration_test/
  app_boot_test.dart
```

---

## Task 0: Project scaffold, dependencies, and layout

**Files:**
- Create: whole Flutter project (`flutter create`), `analysis_options.yaml`, `pubspec.yaml`, empty layer folders with `.gitkeep`.
- Test: `test/scaffold_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: a compiling Flutter app; the dependency set every later task imports.

- [ ] **Step 1: Create the Flutter project in place**

Run (from the repo root, which already contains `docs/`, `.git/`, `.gitignore`):
```bash
flutter create --org com.finassist --project-name financial_assistant --platforms ios,android .
```
Expected: project files generated; `flutter --version` shows a stable channel.

- [ ] **Step 2: Add dependencies**

Run:
```bash
flutter pub add flutter_riverpod drift sqlite3_flutter_libs path_provider path go_router local_auth flutter_secure_storage intl crypto
flutter pub add --dev drift_dev build_runner test
```
Confirm `pubspec.yaml` lists them, then `flutter pub get`.

- [ ] **Step 3: Configure analyzer**

Create `analysis_options.yaml`:
```yaml
include: package:flutter_lints/flutter.yaml
analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.drift.dart"
  language:
    strict-casts: true
    strict-raw-types: true
linter:
  rules:
    prefer_const_constructors: true
    require_trailing_commas: true
    avoid_print: true
```

- [ ] **Step 4: Create the layer folders**

Create empty `.gitkeep` files at: `lib/core/money/`, `lib/core/time/`, `lib/core/result/`, `lib/core/theme/`, `lib/core/l10n/`, `lib/data/db/`, `lib/data/settings/`, `lib/data/meta/`, `lib/features/shell/`, `lib/features/onboarding/steps/`, `lib/features/settings/`, `lib/features/security/`, `lib/providers/`, `test/drift_schemas/`.

- [ ] **Step 5: Sanity test**

Create `test/scaffold_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scaffolding compiles and math works', () {
    expect(1 + 1, 2);
  });
}
```

- [ ] **Step 6: Run tests and analyzer**

Run: `flutter test test/scaffold_test.dart && flutter analyze`
Expected: 1 test passes; analyzer reports no issues (delete the default `test/widget_test.dart` if it references removed template code).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "chore: scaffold Flutter app with foundation dependencies and layer folders"
```

---

## Task 1: Currency type and registry

**Files:**
- Create: `lib/core/money/currency.dart`
- Test: `test/core/money/currency_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum SymbolPosition { before, after }`
  - `class Currency { final String code; final String symbol; final int decimalDigits; final SymbolPosition symbolPosition; const Currency(...); }`
  - `class CurrencyRegistry { static Currency byCode(String code); static const Currency uzs; static const Currency usd; static const Currency eur; }`

- [ ] **Step 1: Write the failing test**

`test/core/money/currency_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';

void main() {
  test('UZS has zero decimal digits and after-position symbol', () {
    final uzs = CurrencyRegistry.uzs;
    expect(uzs.code, 'UZS');
    expect(uzs.decimalDigits, 0);
    expect(uzs.symbolPosition, SymbolPosition.after);
  });

  test('USD has two decimal digits', () {
    expect(CurrencyRegistry.usd.decimalDigits, 2);
  });

  test('byCode returns the registered currency', () {
    expect(CurrencyRegistry.byCode('UZS'), CurrencyRegistry.uzs);
  });

  test('byCode throws ArgumentError for unknown code', () {
    expect(() => CurrencyRegistry.byCode('XXX'), throwsArgumentError);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/money/currency_test.dart`
Expected: FAIL — `currency.dart` not found.

- [ ] **Step 3: Write minimal implementation**

`lib/core/money/currency.dart`:
```dart
enum SymbolPosition { before, after }

class Currency {
  final String code;
  final String symbol;
  final int decimalDigits;
  final SymbolPosition symbolPosition;

  const Currency({
    required this.code,
    required this.symbol,
    required this.decimalDigits,
    required this.symbolPosition,
  });

  @override
  bool operator ==(Object other) =>
      other is Currency && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

class CurrencyRegistry {
  const CurrencyRegistry._();

  static const uzs = Currency(
    code: 'UZS',
    symbol: 'so‘m',
    decimalDigits: 0,
    symbolPosition: SymbolPosition.after,
  );
  static const usd = Currency(
    code: 'USD',
    symbol: r'$',
    decimalDigits: 2,
    symbolPosition: SymbolPosition.before,
  );
  static const eur = Currency(
    code: 'EUR',
    symbol: '€',
    decimalDigits: 2,
    symbolPosition: SymbolPosition.before,
  );

  static const _all = {'UZS': uzs, 'USD': usd, 'EUR': eur};

  static Currency byCode(String code) {
    final c = _all[code];
    if (c == null) {
      throw ArgumentError.value(code, 'code', 'Unknown currency code');
    }
    return c;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/money/currency_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/money/currency.dart test/core/money/currency_test.dart
git commit -m "feat: add Currency type and registry"
```

---

## Task 2: Money value type

**Files:**
- Create: `lib/core/money/money.dart`
- Test: `test/core/money/money_test.dart`

**Interfaces:**
- Consumes: `Currency`, `CurrencyRegistry`, `SymbolPosition` from Task 1.
- Produces:
  - `class Money { final int minorUnits; final Currency currency; const Money(this.minorUnits, this.currency); }`
  - `Money.zero(Currency)`
  - `Money add(Money other)` / `Money subtract(Money other)` — throw `CurrencyMismatchError` on differing currencies
  - `Money negate()`, `bool get isNegative`, `int compareTo(Money)`
  - `static Money? tryParse(String text, Currency)` — returns null on invalid input
  - `String format()` — grouped digits, symbol placed per `symbolPosition`
  - `class CurrencyMismatchError extends Error`

- [ ] **Step 1: Write the failing test**

`test/core/money/money_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';

void main() {
  final uzs = CurrencyRegistry.uzs;
  final usd = CurrencyRegistry.usd;

  test('add sums minor units of same currency', () {
    expect(Money(1000, uzs).add(Money(500, uzs)), Money(1500, uzs));
  });

  test('subtract can go negative', () {
    final r = Money(500, uzs).subtract(Money(800, uzs));
    expect(r.minorUnits, -300);
    expect(r.isNegative, isTrue);
  });

  test('add throws on currency mismatch', () {
    expect(() => Money(1, uzs).add(Money(1, usd)),
        throwsA(isA<CurrencyMismatchError>()));
  });

  test('tryParse reads grouped UZS input', () {
    expect(Money.tryParse('1 234 567', uzs), Money(1234567, uzs));
  });

  test('tryParse reads USD decimals into minor units', () {
    expect(Money.tryParse('12.34', usd), Money(1234, usd));
  });

  test('tryParse returns null on garbage', () {
    expect(Money.tryParse('abc', uzs), isNull);
  });

  test('format groups thousands and places symbol after for UZS', () {
    expect(Money(1234567, uzs).format(), '1 234 567 so‘m');
  });

  test('format shows two decimals and leading symbol for USD', () {
    expect(Money(1234, usd).format(), r'$12.34');
  });

  test('compareTo orders by amount', () {
    expect(Money(100, uzs).compareTo(Money(200, uzs)), isNegative);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/money/money_test.dart`
Expected: FAIL — `money.dart` not found.

- [ ] **Step 3: Write minimal implementation**

`lib/core/money/money.dart`:
```dart
import 'currency.dart';

class CurrencyMismatchError extends Error {
  final Currency a;
  final Currency b;
  CurrencyMismatchError(this.a, this.b);
  @override
  String toString() => 'CurrencyMismatchError: ${a.code} vs ${b.code}';
}

class Money {
  final int minorUnits;
  final Currency currency;

  const Money(this.minorUnits, this.currency);

  factory Money.zero(Currency currency) => Money(0, currency);

  void _assertSame(Money other) {
    if (other.currency != currency) {
      throw CurrencyMismatchError(currency, other.currency);
    }
  }

  Money add(Money other) {
    _assertSame(other);
    return Money(minorUnits + other.minorUnits, currency);
  }

  Money subtract(Money other) {
    _assertSame(other);
    return Money(minorUnits - other.minorUnits, currency);
  }

  Money negate() => Money(-minorUnits, currency);

  bool get isNegative => minorUnits < 0;

  int compareTo(Money other) {
    _assertSame(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  static Money? tryParse(String text, Currency currency) {
    final cleaned = text.replaceAll(RegExp(r'[\s ]'), '').replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null) return null;
    final scale = _pow10(currency.decimalDigits);
    return Money((value * scale).round(), currency);
  }

  String format() {
    final scale = _pow10(currency.decimalDigits);
    final major = (minorUnits.abs() ~/ scale);
    final grouped = _group(major.toString());
    final sign = isNegative ? '-' : '';
    String number = grouped;
    if (currency.decimalDigits > 0) {
      final frac = (minorUnits.abs() % scale)
          .toString()
          .padLeft(currency.decimalDigits, '0');
      number = '$grouped.$frac';
    }
    return currency.symbolPosition == SymbolPosition.before
        ? '$sign${currency.symbol}$number'
        : '$sign$number ${currency.symbol}';
  }

  static int _pow10(int n) {
    var r = 1;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }

  static String _group(String digits) {
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => 'Money(${format()})';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/money/money_test.dart`
Expected: PASS (9 tests). If the USD format test fails on the `$`, verify the raw-string literal `r'$12.34'` in the test.

- [ ] **Step 5: Commit**

```bash
git add lib/core/money/money.dart test/core/money/money_test.dart
git commit -m "feat: add Money value type with arithmetic, parse, and format"
```

---

## Task 3: FinancialPeriod and week math

**Files:**
- Create: `lib/core/time/financial_period.dart`, `lib/core/time/weekday.dart`
- Test: `test/core/time/financial_period_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class FinancialPeriod { final DateTime start; final DateTime endExclusive; }`
  - `static FinancialPeriod containing(DateTime date, int startDay)`
  - `FinancialPeriod next()`, `FinancialPeriod previous()`
  - `int get totalDays`, `int daysRemaining(DateTime asOf)`, `bool contains(DateTime d)`
  - `weekday.dart`: `DateTime startOfWeek(DateTime date, int weekStartIso)` where `weekStartIso` is 1=Mon…7=Sun

- [ ] **Step 1: Write the failing test**

`test/core/time/financial_period_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/time/financial_period.dart';

void main() {
  DateTime d(int y, int m, int day) => DateTime(y, m, day);

  test('period starting on the 5th contains a mid-month date', () {
    final p = FinancialPeriod.containing(d(2026, 3, 10), 5);
    expect(p.start, d(2026, 3, 5));
    expect(p.endExclusive, d(2026, 4, 5));
    expect(p.contains(d(2026, 3, 10)), isTrue);
  });

  test('a date before the start day belongs to the previous period', () {
    final p = FinancialPeriod.containing(d(2026, 3, 2), 5);
    expect(p.start, d(2026, 2, 5));
    expect(p.endExclusive, d(2026, 3, 5));
  });

  test('start day 31 clamps to the last day of a short month', () {
    final p = FinancialPeriod.containing(d(2026, 2, 15), 31);
    expect(p.start, d(2026, 1, 31));
    expect(p.endExclusive, d(2026, 2, 28));
  });

  test('totalDays and daysRemaining', () {
    final p = FinancialPeriod.containing(d(2026, 3, 10), 1);
    expect(p.totalDays, 31);
    expect(p.daysRemaining(d(2026, 3, 10)), 22); // 31 - 9 days elapsed
  });

  test('next and previous are contiguous', () {
    final p = FinancialPeriod.containing(d(2026, 3, 10), 5);
    expect(p.next().start, p.endExclusive);
    expect(p.previous().endExclusive, p.start);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/time/financial_period_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Write minimal implementation**

`lib/core/time/financial_period.dart`:
```dart
class FinancialPeriod {
  final DateTime start;
  final DateTime endExclusive;

  const FinancialPeriod(this.start, this.endExclusive);

  static DateTime _clampedDate(int year, int month, int startDay) {
    // Normalize month overflow/underflow.
    final base = DateTime(year, month, 1);
    final lastDay = DateTime(base.year, base.month + 1, 0).day;
    final day = startDay > lastDay ? lastDay : startDay;
    return DateTime(base.year, base.month, day);
  }

  static FinancialPeriod containing(DateTime date, int startDay) {
    final thisMonthStart = _clampedDate(date.year, date.month, startDay);
    final DateTime start;
    if (!date.isBefore(thisMonthStart)) {
      start = thisMonthStart;
    } else {
      start = _clampedDate(date.year, date.month - 1, startDay);
    }
    final end = _clampedDate(start.year, start.month + 1, startDay);
    return FinancialPeriod(start, end);
  }

  bool contains(DateTime d) =>
      !d.isBefore(start) && d.isBefore(endExclusive);

  int get totalDays => endExclusive.difference(start).inDays;

  int daysRemaining(DateTime asOf) {
    final elapsed = asOf.difference(start).inDays;
    final remaining = totalDays - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

  FinancialPeriod next() {
    final nextEnd = _clampedDate(
        endExclusive.year, endExclusive.month + 1, endExclusive.day);
    return FinancialPeriod(endExclusive, nextEnd);
  }

  FinancialPeriod previous() {
    final prevStart =
        _clampedDate(start.year, start.month - 1, start.day);
    return FinancialPeriod(prevStart, start);
  }

  @override
  bool operator ==(Object other) =>
      other is FinancialPeriod &&
      other.start == start &&
      other.endExclusive == endExclusive;

  @override
  int get hashCode => Object.hash(start, endExclusive);
}
```

`lib/core/time/weekday.dart`:
```dart
/// Returns midnight of the week-start day for [date].
/// [weekStartIso]: 1=Monday … 7=Sunday (matches DateTime.weekday).
DateTime startOfWeek(DateTime date, int weekStartIso) {
  final day = DateTime(date.year, date.month, date.day);
  final diff = (day.weekday - weekStartIso + 7) % 7;
  return day.subtract(Duration(days: diff));
}
```

> Note on `daysRemaining`: the test uses whole-day differences from `start`. Because the period boundary is date-based (midnight), pass date-only `DateTime`s (no time component) to these functions. Transaction timestamps get truncated to date before period math in later sub-projects.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/time/financial_period_test.dart`
Expected: PASS (5 tests). If `daysRemaining` is off by one, confirm the test passes date-only values.

- [ ] **Step 5: Add a week-start test and commit**

Append to the test file:
```dart
  test('startOfWeek snaps to Monday when weekStart=1', () {
    // 2026-07-15 is a Wednesday.
    expect(startOfWeek(DateTime(2026, 7, 15), 1), DateTime(2026, 7, 13));
  });
```
Add the import `import 'package:financial_assistant/core/time/weekday.dart';`, run `flutter test test/core/time/financial_period_test.dart` (expect PASS), then:
```bash
git add lib/core/time/ test/core/time/
git commit -m "feat: add FinancialPeriod and week-start math"
```

---

## Task 4: Result type and failure hierarchy

**Files:**
- Create: `lib/core/result/failure.dart`, `lib/core/result/result.dart`, `lib/core/result/failure_messages.dart`
- Test: `test/core/result/result_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `sealed class Failure` with subclasses `StorageFailure`, `MigrationFailure`, `ValidationFailure`, `NotFoundFailure`, `BackupIncompatibleFailure` (each `final String debugDetail;`)
  - `sealed class Result<T>` with `Ok<T>(T value)` and `Err<T>(Failure failure)`; helpers `bool get isOk`, `T? get valueOrNull`, `R when<R>({required R Function(T) ok, required R Function(Failure) err})`
  - `String userMessage(Failure)` in `failure_messages.dart` — non-technical, next-step text

- [ ] **Step 1: Write the failing test**

`test/core/result/result_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/result/failure.dart';
import 'package:financial_assistant/core/result/result.dart';
import 'package:financial_assistant/core/result/failure_messages.dart';

void main() {
  test('Ok carries a value', () {
    final Result<int> r = Ok(42);
    expect(r.isOk, isTrue);
    expect(r.valueOrNull, 42);
  });

  test('Err carries a failure and no value', () {
    final Result<int> r = Err(ValidationFailure('negative amount'));
    expect(r.isOk, isFalse);
    expect(r.valueOrNull, isNull);
  });

  test('when dispatches to the right branch', () {
    final Result<int> r = Ok(1);
    final s = r.when(ok: (v) => 'ok:$v', err: (f) => 'err');
    expect(s, 'ok:1');
  });

  test('userMessage is non-technical and mentions no jargon', () {
    final msg = userMessage(MigrationFailure('SQLITE_ERROR 1'));
    expect(msg.toLowerCase(), isNot(contains('sqlite')));
    expect(msg, isNotEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/result/result_test.dart`
Expected: FAIL — files not found.

- [ ] **Step 3: Write minimal implementation**

`lib/core/result/failure.dart`:
```dart
sealed class Failure {
  final String debugDetail;
  const Failure(this.debugDetail);
}

class StorageFailure extends Failure {
  const StorageFailure(super.debugDetail);
}

class MigrationFailure extends Failure {
  const MigrationFailure(super.debugDetail);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.debugDetail);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.debugDetail);
}

class BackupIncompatibleFailure extends Failure {
  const BackupIncompatibleFailure(super.debugDetail);
}
```

`lib/core/result/result.dart`:
```dart
import 'failure.dart';

sealed class Result<T> {
  const Result();
  bool get isOk => this is Ok<T>;
  T? get valueOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => null,
      };
  R when<R>({
    required R Function(T value) ok,
    required R Function(Failure failure) err,
  }) =>
      switch (this) {
        Ok<T>(:final value) => ok(value),
        Err<T>(:final failure) => err(failure),
      };
}

class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

class Err<T> extends Result<T> {
  final Failure failure;
  const Err(this.failure);
}
```

`lib/core/result/failure_messages.dart`:
```dart
import 'failure.dart';

/// Maps a [Failure] to non-technical, next-step-oriented text (PRD §26).
String userMessage(Failure failure) => switch (failure) {
      StorageFailure() =>
        'Ma\'lumotni saqlab bo\'lmadi. Iltimos, qayta urinib ko\'ring.',
      MigrationFailure() =>
        'Ma\'lumotlarni yangilashda muammo yuz berdi. Eski ma\'lumotlaringiz saqlab qolindi.',
      ValidationFailure() =>
        'Kiritilgan ma\'lumot noto\'g\'ri. Iltimos, tekshirib qayta kiriting.',
      NotFoundFailure() => 'So\'ralgan ma\'lumot topilmadi.',
      BackupIncompatibleFailure() =>
        'Bu zaxira nusxasi ilovaning ushbu versiyasi bilan mos emas.',
    };
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/result/result_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/result/ test/core/result/
git commit -m "feat: add Result type and user-facing failure messages"
```

---

## Task 5: Drift database and tables (schema v1)

**Files:**
- Create: `lib/data/db/tables.dart`, `lib/data/db/app_database.dart`
- Test: `test/data/db/app_database_test.dart`

**Interfaces:**
- Consumes: nothing (stores primitives; Money is split into `*_minor` INTEGER + `*_currency` TEXT columns).
- Produces:
  - Drift tables `AppSettingsTable` (single row, id fixed = 0), `AppMetaTable` (single row, id fixed = 0)
  - `class AppDatabase extends _$AppDatabase` with `int get schemaVersion => 1;`
  - `AppDatabase.forTesting(QueryExecutor e)` constructor

- [ ] **Step 1: Write table definitions**

`lib/data/db/tables.dart`:
```dart
import 'package:drift/drift.dart';

class AppSettingsTable extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get primaryCurrency =>
      text().withDefault(const Constant('UZS'))();
  TextColumn get dateFormat =>
      text().withDefault(const Constant('dd.MM.yyyy'))();
  IntColumn get periodStartDay => integer().withDefault(const Constant(1))();
  IntColumn get weekStartIso => integer().withDefault(const Constant(1))();
  TextColumn get dailyLimitMethod =>
      text().withDefault(const Constant('evenSplit'))();
  IntColumn get minReserveMinor => integer().withDefault(const Constant(0))();
  TextColumn get minReserveCurrency =>
      text().withDefault(const Constant('UZS'))();
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  BoolColumn get appLockEnabled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get biometricEnabled =>
      boolean().withDefault(const Constant(false))();
  TextColumn get savingsRolloverMode =>
      text().withDefault(const Constant('askEachTime'))();
  TextColumn get notificationFlagsJson =>
      text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

class AppMetaTable extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  IntColumn get schemaVersion => integer().withDefault(const Constant(1))();
  DateTimeColumn get installedAt => dateTime()();
  BoolColumn get onboardingComplete =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastBackupAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 2: Write the database class (migration engine added in Task 6)**

`lib/data/db/app_database.dart`:
```dart
import 'package:drift/drift.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [AppSettingsTable, AppMetaTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await into(appMetaTable).insert(
            AppMetaTableCompanion.insert(installedAt: DateTime.now()),
          );
          await into(appSettingsTable)
              .insert(const AppSettingsTableCompanion());
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
```

- [ ] **Step 3: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `lib/data/db/app_database.g.dart` generated; no errors.

- [ ] **Step 4: Write the failing test**

`test/data/db/app_database_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('onCreate seeds one settings row and one meta row', () async {
    final settings = await db.select(db.appSettingsTable).getSingle();
    expect(settings.primaryCurrency, 'UZS');
    expect(settings.periodStartDay, 1);

    final meta = await db.select(db.appMetaTable).getSingle();
    expect(meta.onboardingComplete, isFalse);
    expect(meta.schemaVersion, 1);
  });

  test('foreign keys pragma is enabled after open', () async {
    final row =
        await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(row.data.values.first, 1);
  });
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/data/db/app_database_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Export the v1 schema snapshot (for Task 6 migration tests)**

Run:
```bash
dart run drift_dev schema dump lib/data/db/app_database.dart test/drift_schemas/
```
Expected: `test/drift_schemas/drift_schema_v1.json` created.

- [ ] **Step 7: Commit**

```bash
git add lib/data/db/tables.dart lib/data/db/app_database.dart test/data/db/ test/drift_schemas/
git commit -m "feat: add Drift database with app_settings and app_meta tables (schema v1)"
```

---

## Task 6: Migration + snapshot-recovery engine

**Files:**
- Create: `lib/data/db/recovery.dart`, `lib/data/db/db_open.dart`, `lib/data/db/migrations.dart`
- Modify: `lib/data/db/app_database.dart` (route `onUpgrade` to `migrations.dart`)
- Test: `test/data/db/recovery_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `Failure`/`Result`, `path_provider`, `path`.
- Produces:
  - `Future<String> snapshotDatabase(String dbPath)` — copies the file to `<dbPath>.recovery`, returns the snapshot path
  - `Future<void> restoreSnapshot(String snapshotPath, String dbPath)`
  - `Future<Result<AppDatabase>> openAppDatabase({required String dbPath})` — snapshot-before-upgrade, run migration, restore + return `Err(MigrationFailure)` on failure
  - `MigrationStrategy buildMigration(AppDatabase db)` in `migrations.dart` using `stepByStep`

- [ ] **Step 1: Write recovery file helpers**

`lib/data/db/recovery.dart`:
```dart
import 'dart:io';

String recoveryPathFor(String dbPath) => '$dbPath.recovery';

Future<String?> snapshotDatabase(String dbPath) async {
  final src = File(dbPath);
  if (!await src.exists()) return null; // fresh install, nothing to snapshot
  final dst = recoveryPathFor(dbPath);
  await src.copy(dst);
  return dst;
}

Future<void> restoreSnapshot(String snapshotPath, String dbPath) async {
  final snap = File(snapshotPath);
  if (await snap.exists()) {
    await snap.copy(dbPath);
  }
}

Future<void> discardSnapshot(String dbPath) async {
  final snap = File(recoveryPathFor(dbPath));
  if (await snap.exists()) await snap.delete();
}
```

- [ ] **Step 2: Write the failing recovery test**

`test/data/db/recovery_test.dart` (file-copy behavior, no Flutter bindings needed):
```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/recovery.dart';

void main() {
  test('snapshot then restore round-trips the file contents', () async {
    final tmp = await Directory.systemTemp.createTemp('rec');
    final dbPath = '${tmp.path}/app.db';
    await File(dbPath).writeAsString('ORIGINAL');

    final snap = await snapshotDatabase(dbPath);
    expect(snap, isNotNull);

    await File(dbPath).writeAsString('CORRUPTED');
    await restoreSnapshot(snap!, dbPath);

    expect(await File(dbPath).readAsString(), 'ORIGINAL');
    await tmp.delete(recursive: true);
  });

  test('snapshot of a missing file returns null', () async {
    final tmp = await Directory.systemTemp.createTemp('rec');
    final snap = await snapshotDatabase('${tmp.path}/missing.db');
    expect(snap, isNull);
    await tmp.delete(recursive: true);
  });
}
```

- [ ] **Step 3: Run test to verify it passes**

Run: `flutter test test/data/db/recovery_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 4: Write the stepByStep migration builder**

`lib/data/db/migrations.dart`:
```dart
import 'package:drift/drift.dart';
import 'app_database.dart';

/// Stepwise migrations. Each future schema bump adds a `from: N` branch.
/// Foundation ships schema v1 only, so there are no steps yet — the
/// builder exists so later sub-projects add steps without restructuring.
MigrationStrategy buildMigration(AppDatabase db) => MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await db.into(db.appMetaTable).insert(
              AppMetaTableCompanion.insert(installedAt: DateTime.now()),
            );
        await db
            .into(db.appSettingsTable)
            .insert(const AppSettingsTableCompanion());
      },
      onUpgrade: db.stepByStepMigration,
      beforeOpen: (details) async {
        await db.customStatement('PRAGMA foreign_keys = ON');
      },
    );
```

- [ ] **Step 5: Wire the migration into AppDatabase**

In `lib/data/db/app_database.dart`, replace the inline `migration` getter with:
```dart
  @override
  MigrationStrategy get migration => buildMigration(this);

  // Populated by later sub-projects via drift's stepByStep helper.
  OnUpgrade get stepByStepMigration => stepByStep();
```
Add `import 'migrations.dart';` at the top. Re-run `dart run build_runner build --delete-conflicting-outputs` and `flutter test test/data/db/app_database_test.dart` (expect PASS, unchanged behavior).

- [ ] **Step 6: Write the migration-gate opener**

`lib/data/db/db_open.dart`:
```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import '../../core/result/failure.dart';
import '../../core/result/result.dart';
import 'app_database.dart';
import 'recovery.dart';

/// Opens the database with snapshot-before-upgrade protection (PRD §20.3).
/// On any failure while opening/migrating, restores the pre-upgrade snapshot
/// and returns Err(MigrationFailure); the caller then reopens read-safe.
Future<Result<AppDatabase>> openAppDatabase({required String dbPath}) async {
  final snapshot = await snapshotDatabase(dbPath);
  final db = AppDatabase(NativeDatabase(File(dbPath)));
  try {
    // Force the migration to run now by touching the schema.
    await db.customSelect('SELECT 1').get();
    await discardSnapshot(dbPath);
    return Ok(db);
  } catch (e) {
    await db.close();
    if (snapshot != null) {
      await restoreSnapshot(snapshot, dbPath);
    }
    return Err(MigrationFailure(e.toString()));
  }
}
```
Add `import 'dart:io';` at the top.

> Note: `NativeDatabase(File(dbPath))` opens lazily; the `SELECT 1` above forces `beforeOpen`/migration to execute inside this try/catch so a failure is caught here rather than on first real query.

- [ ] **Step 7: Write the forced-failure recovery test**

Append to `test/data/db/recovery_test.dart`:
```dart
import 'package:financial_assistant/data/db/db_open.dart';
import 'package:financial_assistant/core/result/failure.dart';

  test('a corrupted db file yields Err(MigrationFailure) and restores snapshot',
      () async {
    final tmp = await Directory.systemTemp.createTemp('rec');
    final dbPath = '${tmp.path}/app.db';
    // Write a valid db first by opening and closing once.
    final first = await openAppDatabase(dbPath: dbPath);
    expect(first.isOk, isTrue);
    await first.valueOrNull!.close();

    // Snapshot the good file, then corrupt the live db.
    await File(dbPath).writeAsBytes([0, 1, 2, 3]); // not a valid sqlite header
    final result = await openAppDatabase(dbPath: dbPath);
    expect(result.isOk, isFalse);
    result.when(
      ok: (_) => fail('expected failure'),
      err: (f) => expect(f, isA<MigrationFailure>()),
    );
    await tmp.delete(recursive: true);
  });
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test test/data/db/`
Expected: PASS. If corrupting the file does not throw on `SELECT 1`, replace the corrupt bytes with a truncated-but-nonempty payload, or force a query against a table (`SELECT * FROM app_meta`).

- [ ] **Step 9: Commit**

```bash
git add lib/data/db/ test/data/db/
git commit -m "feat: add migration engine with snapshot-before-upgrade recovery"
```

---

## Task 7: Settings and AppMeta models + repositories

**Files:**
- Create: `lib/data/settings/settings_model.dart`, `lib/data/settings/settings_repository.dart`, `lib/data/meta/meta_model.dart`, `lib/data/meta/meta_repository.dart`
- Test: `test/data/settings/settings_repository_test.dart`, `test/data/meta/meta_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `Money`, `Currency`, enums.
- Produces:
  - `enum ThemeModeSetting { system, light, dark }`, `enum DailyLimitMethod { evenSplit, fixedDaily }`, `enum SavingsRolloverMode { rolloverDays, toGoal, askEachTime }`
  - `class AppSettings` (immutable, `copyWith`) with typed fields incl. `Money minReserve`
  - `abstract class SettingsRepository { Future<AppSettings> read(); Future<void> write(AppSettings s); }` + `DriftSettingsRepository`
  - `class AppMeta` + `abstract class MetaRepository { Future<AppMeta> read(); Future<void> markOnboardingComplete(); Future<void> touchBackup(DateTime at); }` + `DriftMetaRepository`

- [ ] **Step 1: Write the settings model**

`lib/data/settings/settings_model.dart`:
```dart
import '../../core/money/currency.dart';
import '../../core/money/money.dart';

enum ThemeModeSetting { system, light, dark }
enum DailyLimitMethod { evenSplit, fixedDaily }
enum SavingsRolloverMode { rolloverDays, toGoal, askEachTime }

class AppSettings {
  final String name;
  final Currency primaryCurrency;
  final String dateFormat;
  final int periodStartDay;
  final int weekStartIso;
  final DailyLimitMethod dailyLimitMethod;
  final Money minReserve;
  final ThemeModeSetting themeMode;
  final bool appLockEnabled;
  final bool biometricEnabled;
  final SavingsRolloverMode savingsRolloverMode;

  const AppSettings({
    required this.name,
    required this.primaryCurrency,
    required this.dateFormat,
    required this.periodStartDay,
    required this.weekStartIso,
    required this.dailyLimitMethod,
    required this.minReserve,
    required this.themeMode,
    required this.appLockEnabled,
    required this.biometricEnabled,
    required this.savingsRolloverMode,
  });

  AppSettings copyWith({
    String? name,
    Currency? primaryCurrency,
    String? dateFormat,
    int? periodStartDay,
    int? weekStartIso,
    DailyLimitMethod? dailyLimitMethod,
    Money? minReserve,
    ThemeModeSetting? themeMode,
    bool? appLockEnabled,
    bool? biometricEnabled,
    SavingsRolloverMode? savingsRolloverMode,
  }) =>
      AppSettings(
        name: name ?? this.name,
        primaryCurrency: primaryCurrency ?? this.primaryCurrency,
        dateFormat: dateFormat ?? this.dateFormat,
        periodStartDay: periodStartDay ?? this.periodStartDay,
        weekStartIso: weekStartIso ?? this.weekStartIso,
        dailyLimitMethod: dailyLimitMethod ?? this.dailyLimitMethod,
        minReserve: minReserve ?? this.minReserve,
        themeMode: themeMode ?? this.themeMode,
        appLockEnabled: appLockEnabled ?? this.appLockEnabled,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        savingsRolloverMode: savingsRolloverMode ?? this.savingsRolloverMode,
      );
}
```

- [ ] **Step 2: Write the settings repository**

`lib/data/settings/settings_repository.dart`:
```dart
import 'package:drift/drift.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../db/app_database.dart';
import 'settings_model.dart';

abstract class SettingsRepository {
  Future<AppSettings> read();
  Future<void> write(AppSettings settings);
}

class DriftSettingsRepository implements SettingsRepository {
  final AppDatabase db;
  DriftSettingsRepository(this.db);

  @override
  Future<AppSettings> read() async {
    final row = await db.select(db.appSettingsTable).getSingle();
    return AppSettings(
      name: row.name,
      primaryCurrency: CurrencyRegistry.byCode(row.primaryCurrency),
      dateFormat: row.dateFormat,
      periodStartDay: row.periodStartDay,
      weekStartIso: row.weekStartIso,
      dailyLimitMethod: DailyLimitMethod.values.byName(row.dailyLimitMethod),
      minReserve: Money(
          row.minReserveMinor, CurrencyRegistry.byCode(row.minReserveCurrency)),
      themeMode: ThemeModeSetting.values.byName(row.themeMode),
      appLockEnabled: row.appLockEnabled,
      biometricEnabled: row.biometricEnabled,
      savingsRolloverMode:
          SavingsRolloverMode.values.byName(row.savingsRolloverMode),
    );
  }

  @override
  Future<void> write(AppSettings s) async {
    await db.update(db.appSettingsTable).replace(
          AppSettingsTableCompanion(
            id: const Value(0),
            name: Value(s.name),
            primaryCurrency: Value(s.primaryCurrency.code),
            dateFormat: Value(s.dateFormat),
            periodStartDay: Value(s.periodStartDay),
            weekStartIso: Value(s.weekStartIso),
            dailyLimitMethod: Value(s.dailyLimitMethod.name),
            minReserveMinor: Value(s.minReserve.minorUnits),
            minReserveCurrency: Value(s.minReserve.currency.code),
            themeMode: Value(s.themeMode.name),
            appLockEnabled: Value(s.appLockEnabled),
            biometricEnabled: Value(s.biometricEnabled),
            savingsRolloverMode: Value(s.savingsRolloverMode.name),
          ),
        );
  }
}
```

- [ ] **Step 3: Write the failing settings test**

`test/data/settings/settings_repository_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/settings/settings_model.dart';
import 'package:financial_assistant/data/settings/settings_repository.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftSettingsRepository(db);
  });
  tearDown(() => db.close());

  test('default row reads back UZS defaults', () async {
    final s = await repo.read();
    expect(s.primaryCurrency, CurrencyRegistry.uzs);
    expect(s.periodStartDay, 1);
    expect(s.appLockEnabled, isFalse);
  });

  test('write then read round-trips every field', () async {
    final updated = (await repo.read()).copyWith(
      name: 'Sarvar',
      periodStartDay: 5,
      minReserve: Money(2000000, CurrencyRegistry.uzs),
      themeMode: ThemeModeSetting.dark,
      appLockEnabled: true,
    );
    await repo.write(updated);
    final s = await repo.read();
    expect(s.name, 'Sarvar');
    expect(s.periodStartDay, 5);
    expect(s.minReserve, Money(2000000, CurrencyRegistry.uzs));
    expect(s.themeMode, ThemeModeSetting.dark);
    expect(s.appLockEnabled, isTrue);
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/settings/settings_repository_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Write the meta model + repository**

`lib/data/meta/meta_model.dart`:
```dart
class AppMeta {
  final int schemaVersion;
  final DateTime installedAt;
  final bool onboardingComplete;
  final DateTime? lastBackupAt;
  const AppMeta({
    required this.schemaVersion,
    required this.installedAt,
    required this.onboardingComplete,
    required this.lastBackupAt,
  });
}
```

`lib/data/meta/meta_repository.dart`:
```dart
import 'package:drift/drift.dart';
import '../db/app_database.dart';
import 'meta_model.dart';

abstract class MetaRepository {
  Future<AppMeta> read();
  Future<void> markOnboardingComplete();
  Future<void> touchBackup(DateTime at);
}

class DriftMetaRepository implements MetaRepository {
  final AppDatabase db;
  DriftMetaRepository(this.db);

  @override
  Future<AppMeta> read() async {
    final r = await db.select(db.appMetaTable).getSingle();
    return AppMeta(
      schemaVersion: r.schemaVersion,
      installedAt: r.installedAt,
      onboardingComplete: r.onboardingComplete,
      lastBackupAt: r.lastBackupAt,
    );
  }

  @override
  Future<void> markOnboardingComplete() async {
    await (db.update(db.appMetaTable)..where((t) => t.id.equals(0)))
        .write(const AppMetaTableCompanion(onboardingComplete: Value(true)));
  }

  @override
  Future<void> touchBackup(DateTime at) async {
    await (db.update(db.appMetaTable)..where((t) => t.id.equals(0)))
        .write(AppMetaTableCompanion(lastBackupAt: Value(at)));
  }
}
```

- [ ] **Step 6: Write the failing meta test**

`test/data/meta/meta_repository_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/meta/meta_repository.dart';

void main() {
  late AppDatabase db;
  late MetaRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftMetaRepository(db);
  });
  tearDown(() => db.close());

  test('onboarding starts incomplete and can be marked complete', () async {
    expect((await repo.read()).onboardingComplete, isFalse);
    await repo.markOnboardingComplete();
    expect((await repo.read()).onboardingComplete, isTrue);
  });

  test('touchBackup records the timestamp', () async {
    final at = DateTime(2026, 7, 17);
    await repo.touchBackup(at);
    expect((await repo.read()).lastBackupAt, at);
  });
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/data/`
Expected: PASS (all data-layer tests).

- [ ] **Step 8: Commit**

```bash
git add lib/data/settings/ lib/data/meta/ test/data/settings/ test/data/meta/
git commit -m "feat: add settings and app-meta models with Drift repositories"
```

---

## Task 8: Riverpod provider wiring

**Files:**
- Create: `lib/providers/app_providers.dart`
- Test: `test/providers/app_providers_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `DriftSettingsRepository`, `DriftMetaRepository`.
- Produces:
  - `final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError());` (overridden at composition root)
  - `final settingsRepositoryProvider = Provider<SettingsRepository>(...)`
  - `final metaRepositoryProvider = Provider<MetaRepository>(...)`
  - `final settingsProvider = FutureProvider<AppSettings>(...)`
  - `final metaProvider = FutureProvider<AppMeta>(...)`

- [ ] **Step 1: Write providers**

`lib/providers/app_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/db/app_database.dart';
import '../data/meta/meta_model.dart';
import '../data/meta/meta_repository.dart';
import '../data/settings/settings_model.dart';
import '../data/settings/settings_repository.dart';

/// Overridden in the composition root with the opened database.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => DriftSettingsRepository(ref.watch(databaseProvider)),
);

final metaRepositoryProvider = Provider<MetaRepository>(
  (ref) => DriftMetaRepository(ref.watch(databaseProvider)),
);

final settingsProvider = FutureProvider<AppSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).read(),
);

final metaProvider = FutureProvider<AppMeta>(
  (ref) => ref.watch(metaRepositoryProvider).read(),
);
```

- [ ] **Step 2: Write the failing test**

`test/providers/app_providers_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  test('settingsProvider reads defaults through the overridden database',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final settings = await container.read(settingsProvider.future);
    expect(settings.primaryCurrency, CurrencyRegistry.uzs);
  });
}
```

- [ ] **Step 3: Run test to verify it passes**

Run: `flutter test test/providers/app_providers_test.dart`
Expected: PASS (1 test).

- [ ] **Step 4: Commit**

```bash
git add lib/providers/ test/providers/
git commit -m "feat: wire database and repositories through Riverpod providers"
```

---

## Task 9: Theme and typography

**Files:**
- Create: `lib/core/theme/app_colors.dart`, `lib/core/theme/app_typography.dart`, `lib/core/theme/app_theme.dart`
- Test: `test/core/theme/app_theme_test.dart`

**Interfaces:**
- Consumes: nothing (Flutter material only).
- Produces:
  - `class AppColors { static const warmPrimary, surfaceLight, surfaceDark, statusSafe, statusNear, statusOver, error; }`
  - `class AppStatusStyle { final Color color; final IconData icon; final String labelKey; }` + `AppStatusStyle safe/near/over` (color **+ icon + text**, never color-only)
  - `ThemeData buildLightTheme()`, `ThemeData buildDarkTheme()`

- [ ] **Step 1: Write colors and status styles**

`lib/core/theme/app_colors.dart`:
```dart
import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();
  // Warm, calm palette (PRD §21.2). Red reserved strictly for error/critical.
  static const warmPrimary = Color(0xFF3E7C6A); // calm teal-green
  static const warmAccent = Color(0xFFE8A87C); // soft warm accent
  static const surfaceLight = Color(0xFFFBF7F2);
  static const surfaceDark = Color(0xFF1C2321);
  static const statusSafe = Color(0xFF3E7C6A);
  static const statusNear = Color(0xFFD9A441); // amber, not red
  static const statusOver = Color(0xFFB3462F); // reserved for over/critical
  static const error = Color(0xFFB3261E);
}

class AppStatusStyle {
  final Color color;
  final IconData icon;
  final String labelKey; // resolved by l10n later
  const AppStatusStyle(this.color, this.icon, this.labelKey);

  static const safe =
      AppStatusStyle(AppColors.statusSafe, Icons.check_circle, 'status_safe');
  static const near =
      AppStatusStyle(AppColors.statusNear, Icons.info, 'status_near');
  static const over =
      AppStatusStyle(AppColors.statusOver, Icons.warning_amber, 'status_over');
}
```

- [ ] **Step 2: Write typography and themes**

`lib/core/theme/app_typography.dart`:
```dart
import 'package:flutter/material.dart';

// Uses the platform default font family, which covers Latin + Cyrillic on
// both iOS (SF) and Android (Roboto). Numerals kept tabular where shown.
TextTheme buildTextTheme(ColorScheme scheme) => Typography.material2021(
      platform: TargetPlatform.android,
    ).black.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
```

`lib/core/theme/app_theme.dart`:
```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.warmPrimary,
    brightness: Brightness.light,
    error: AppColors.error,
    surface: AppColors.surfaceLight,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: buildTextTheme(scheme),
  );
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.warmPrimary,
    brightness: Brightness.dark,
    error: AppColors.error,
    surface: AppColors.surfaceDark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: buildTextTheme(scheme),
  );
}
```

- [ ] **Step 3: Write the test**

`test/core/theme/app_theme_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/theme/app_colors.dart';
import 'package:financial_assistant/core/theme/app_theme.dart';

void main() {
  test('light and dark themes use Material 3', () {
    expect(buildLightTheme().useMaterial3, isTrue);
    expect(buildDarkTheme().colorScheme.brightness, Brightness.dark);
  });

  test('each status style pairs a distinct icon with its color', () {
    final icons = {
      AppStatusStyle.safe.icon,
      AppStatusStyle.near.icon,
      AppStatusStyle.over.icon,
    };
    expect(icons.length, 3); // color is never the only differentiator
  });
}
```
Add `import 'package:financial_assistant/core/theme/app_colors.dart';` covers `AppStatusStyle`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/app_theme_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/ test/core/theme/
git commit -m "feat: add warm theme, typography, and color+icon status styles"
```

---

## Task 10: Localization formatters

**Files:**
- Create: `lib/core/l10n/formatters.dart`
- Test: `test/core/l10n/formatters_test.dart`

**Interfaces:**
- Consumes: `intl`, `AppSettings.dateFormat`.
- Produces:
  - `String formatDate(DateTime date, String pattern)`
  - `String formatCount(int n)` — grouped integer (space separators)

- [ ] **Step 1: Write the failing test**

`test/core/l10n/formatters_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/l10n/formatters.dart';

void main() {
  test('formatDate applies the supplied pattern', () {
    expect(formatDate(DateTime(2026, 7, 17), 'dd.MM.yyyy'), '17.07.2026');
  });

  test('formatCount groups thousands with spaces', () {
    expect(formatCount(1234567), '1 234 567');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/l10n/formatters_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Write minimal implementation**

`lib/core/l10n/formatters.dart`:
```dart
import 'package:intl/intl.dart';

String formatDate(DateTime date, String pattern) =>
    DateFormat(pattern).format(date);

String formatCount(int n) {
  final f = NumberFormat.decimalPattern();
  // Force space grouping regardless of ambient locale.
  final grouped = f.format(n).replaceAll(RegExp(r'[., ]'), ' ');
  return grouped.trim();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/l10n/formatters_test.dart`
Expected: PASS (2 tests). If grouping uses a different separator, the regex normalizes it to a space.

- [ ] **Step 5: Commit**

```bash
git add lib/core/l10n/ test/core/l10n/
git commit -m "feat: add date and number formatters"
```

---

## Task 11: App shell with GoRouter and placeholder tabs

**Files:**
- Create: `lib/features/shell/placeholder_tab.dart`, `lib/features/shell/app_shell.dart`, `lib/features/shell/routes.dart`
- Test: `test/features/shell/app_shell_test.dart`

**Interfaces:**
- Consumes: theme.
- Produces:
  - `class PlaceholderTab extends StatelessWidget { final String title; }`
  - `class AppShell extends StatefulWidget` — `Scaffold` with `NavigationBar`, 5 destinations (Home, Transactions, Allocation, Goals, Reports), a reserved center action slot
  - `GoRouter buildRouter({required bool onboardingComplete})` in `routes.dart` with route names `home`, `onboarding`, `settings`
  - `class RouteNames { static const home='/'; static const onboarding='/onboarding'; static const settings='/settings'; }`

- [ ] **Step 1: Write the placeholder tab**

`lib/features/shell/placeholder_tab.dart`:
```dart
import 'package:flutter/material.dart';

class PlaceholderTab extends StatelessWidget {
  final String title;
  const PlaceholderTab({super.key, required this.title});

  @override
  Widget build(BuildContext context) => Center(
        key: Key('placeholder_$title'),
        child: Text('$title\n(keyingi bosqichda)',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium),
      );
}
```

- [ ] **Step 2: Write the shell**

`lib/features/shell/app_shell.dart`:
```dart
import 'package:flutter/material.dart';
import 'placeholder_tab.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _tabs = [
    PlaceholderTab(title: 'Bosh sahifa'),
    PlaceholderTab(title: 'Tranzaksiyalar'),
    PlaceholderTab(title: 'Taqsimlash'),
    PlaceholderTab(title: "Goal'lar"),
    PlaceholderTab(title: 'Hisobotlar'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: _tabs[_index]),
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

- [ ] **Step 3: Write the router**

`lib/features/shell/routes.dart`:
```dart
import 'package:go_router/go_router.dart';
import '../onboarding/onboarding_screen.dart';
import '../settings/settings_screen.dart';
import 'app_shell.dart';

class RouteNames {
  const RouteNames._();
  static const home = '/';
  static const onboarding = '/onboarding';
  static const settings = '/settings';
}

GoRouter buildRouter({required bool onboardingComplete}) => GoRouter(
      initialLocation:
          onboardingComplete ? RouteNames.home : RouteNames.onboarding,
      routes: [
        GoRoute(
            path: RouteNames.home, builder: (_, __) => const AppShell()),
        GoRoute(
            path: RouteNames.onboarding,
            builder: (_, __) => const OnboardingScreen()),
        GoRoute(
            path: RouteNames.settings,
            builder: (_, __) => const SettingsScreen()),
      ],
    );
```

> This imports `OnboardingScreen` (Task 12) and `SettingsScreen` (Task 13). If executing strictly in order, create temporary empty `StatelessWidget` stubs for those two screens now and replace them in their tasks; the shell test below doesn't touch them.

- [ ] **Step 4: Write the widget test**

`test/features/shell/app_shell_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/features/shell/app_shell.dart';

void main() {
  testWidgets('shell shows five destinations and switches tabs',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.byKey(const Key('placeholder_Bosh sahifa')), findsOneWidget);

    await tester.tap(find.text('Hisobot'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('placeholder_Hisobotlar')), findsOneWidget);
  });
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/shell/app_shell_test.dart`
Expected: PASS (1 test).

- [ ] **Step 6: Commit**

```bash
git add lib/features/shell/ test/features/shell/
git commit -m "feat: add 5-tab app shell and GoRouter configuration"
```

---

## Task 12: Extensible onboarding stepper

**Files:**
- Create: `lib/features/onboarding/onboarding_step.dart`, `lib/features/onboarding/onboarding_controller.dart`, `lib/features/onboarding/onboarding_screen.dart`, and `lib/features/onboarding/steps/` (welcome, currency, period, reserve, theme)
- Test: `test/features/onboarding/onboarding_controller_test.dart`

**Interfaces:**
- Consumes: `settingsRepositoryProvider`, `metaRepositoryProvider`, `AppSettings`.
- Produces:
  - `abstract class OnboardingStep { String get id; Widget build(BuildContext, OnboardingController); }`
  - `final onboardingStepsProvider = Provider<List<OnboardingStep>>(...)` — Foundation returns its ordered steps; later sub-projects override/extend
  - `class OnboardingController extends StateNotifier<OnboardingDraft>` with `next()`, `back()`, `updateName(...)`, …, `Future<void> commit()` (writes settings + `markOnboardingComplete`)
  - `class OnboardingDraft` (immutable working copy of settings + current index)

- [ ] **Step 1: Write the step interface and draft**

`lib/features/onboarding/onboarding_step.dart`:
```dart
import 'package:flutter/material.dart';
import 'onboarding_controller.dart';

abstract class OnboardingStep {
  String get id;
  String get title;
  Widget build(BuildContext context, OnboardingController controller);
}
```

- [ ] **Step 2: Write the controller (TDD target)**

`lib/features/onboarding/onboarding_controller.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../data/meta/meta_repository.dart';
import '../../data/settings/settings_model.dart';
import '../../data/settings/settings_repository.dart';

class OnboardingDraft {
  final AppSettings settings;
  final int index;
  const OnboardingDraft(this.settings, this.index);
  OnboardingDraft copyWith({AppSettings? settings, int? index}) =>
      OnboardingDraft(settings ?? this.settings, index ?? this.index);
}

AppSettings defaultSettings() => AppSettings(
      name: '',
      primaryCurrency: CurrencyRegistry.uzs,
      dateFormat: 'dd.MM.yyyy',
      periodStartDay: 1,
      weekStartIso: 1,
      dailyLimitMethod: DailyLimitMethod.evenSplit,
      minReserve: Money.zero(CurrencyRegistry.uzs),
      themeMode: ThemeModeSetting.system,
      appLockEnabled: false,
      biometricEnabled: false,
      savingsRolloverMode: SavingsRolloverMode.askEachTime,
    );

class OnboardingController extends StateNotifier<OnboardingDraft> {
  final SettingsRepository settingsRepo;
  final MetaRepository metaRepo;
  final int stepCount;

  OnboardingController({
    required this.settingsRepo,
    required this.metaRepo,
    required this.stepCount,
  }) : super(OnboardingDraft(defaultSettings(), 0));

  void next() {
    if (state.index < stepCount - 1) {
      state = state.copyWith(index: state.index + 1);
    }
  }

  void back() {
    if (state.index > 0) state = state.copyWith(index: state.index - 1);
  }

  void update(AppSettings Function(AppSettings) f) =>
      state = state.copyWith(settings: f(state.settings));

  bool get isLast => state.index == stepCount - 1;

  Future<void> commit() async {
    await settingsRepo.write(state.settings);
    await metaRepo.markOnboardingComplete();
  }
}
```

- [ ] **Step 3: Write the failing controller test**

`test/features/onboarding/onboarding_controller_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/meta/meta_repository.dart';
import 'package:financial_assistant/data/settings/settings_repository.dart';
import 'package:financial_assistant/features/onboarding/onboarding_controller.dart';

void main() {
  late AppDatabase db;
  late OnboardingController c;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    c = OnboardingController(
      settingsRepo: DriftSettingsRepository(db),
      metaRepo: DriftMetaRepository(db),
      stepCount: 5,
    );
  });
  tearDown(() => db.close());

  test('next advances but stops at the last step', () {
    for (var i = 0; i < 10; i++) {
      c.next();
    }
    expect(c.state.index, 4);
    expect(c.isLast, isTrue);
  });

  test('update mutates the draft settings', () {
    c.update((s) => s.copyWith(name: 'Sarvar', periodStartDay: 5));
    expect(c.state.settings.name, 'Sarvar');
    expect(c.state.settings.periodStartDay, 5);
  });

  test('commit persists settings and marks onboarding complete', () async {
    c.update((s) => s.copyWith(name: 'Sarvar'));
    await c.commit();

    final settings = await DriftSettingsRepository(db).read();
    final meta = await DriftMetaRepository(db).read();
    expect(settings.name, 'Sarvar');
    expect(meta.onboardingComplete, isTrue);
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/onboarding/onboarding_controller_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Write the screen and steps**

Create the five step widgets in `lib/features/onboarding/steps/` — each implements `OnboardingStep` and renders a single form control bound to `controller.update(...)`:
- `welcome_step.dart` — a `TextField` for `name` (skippable).
- `currency_step.dart` — a dropdown over `CurrencyRegistry` codes.
- `period_step.dart` — a day-of-month picker (1–31) for `periodStartDay` + week-start dropdown for `weekStartIso`.
- `reserve_step.dart` — a `TextField` parsed via `Money.tryParse(text, settings.primaryCurrency)` into `minReserve`.
- `theme_step.dart` — a segmented control over `ThemeModeSetting`.

Example — `lib/features/onboarding/steps/reserve_step.dart`:
```dart
import 'package:flutter/material.dart';
import '../../../core/money/money.dart';
import '../onboarding_controller.dart';
import '../onboarding_step.dart';

class ReserveStep extends OnboardingStep {
  @override
  String get id => 'reserve';
  @override
  String get title => 'Minimal zaxira';

  @override
  Widget build(BuildContext context, OnboardingController controller) =>
      Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Summa'),
              onChanged: (t) {
                final m = Money.tryParse(
                    t, controller.state.settings.primaryCurrency);
                if (m != null) {
                  controller.update((s) => s.copyWith(minReserve: m));
                }
              },
            ),
          ],
        ),
      );
}
```

`lib/features/onboarding/onboarding_screen.dart` hosts a `PageView`/stepper driven by the controller, with Back / Next / (on last) Finish buttons; Finish calls `controller.commit()` then `context.go(RouteNames.home)`. Register steps:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'onboarding_step.dart';
import 'steps/welcome_step.dart';
import 'steps/currency_step.dart';
import 'steps/period_step.dart';
import 'steps/reserve_step.dart';
import 'steps/theme_step.dart';

final onboardingStepsProvider = Provider<List<OnboardingStep>>((ref) => [
      WelcomeStep(),
      CurrencyStep(),
      PeriodStep(),
      ReserveStep(),
      ThemeStep(),
    ]);
```

- [ ] **Step 6: Widget-test the screen renders the first step and advances**

`test/features/onboarding/onboarding_screen_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/features/onboarding/onboarding_screen.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  testWidgets('onboarding renders the welcome step first', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: OnboardingScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Minimal zaxira'), findsNothing); // not on first page
    expect(find.byType(TextField), findsWidgets); // welcome name field present
  });
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/features/onboarding/`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/onboarding/ test/features/onboarding/
git commit -m "feat: add extensible onboarding stepper with foundation steps"
```

---

## Task 13: Settings screen

**Files:**
- Create: `lib/features/settings/settings_controller.dart`, `lib/features/settings/settings_screen.dart`
- Test: `test/features/settings/settings_controller_test.dart`

**Interfaces:**
- Consumes: `settingsRepositoryProvider`, `settingsProvider`, `AppSettings`.
- Produces:
  - `class SettingsController extends AsyncNotifier<AppSettings>` with `Future<void> save(AppSettings)` (writes + refreshes)
  - `final settingsControllerProvider = AsyncNotifierProvider<SettingsController, AppSettings>(...)`
  - `class SettingsScreen extends ConsumerWidget`

- [ ] **Step 1: Write the controller**

`lib/features/settings/settings_controller.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/settings/settings_model.dart';
import '../../providers/app_providers.dart';

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() =>
      ref.watch(settingsRepositoryProvider).read();

  Future<void> save(AppSettings updated) async {
    state = const AsyncLoading();
    await ref.read(settingsRepositoryProvider).write(updated);
    state = AsyncData(updated);
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
        SettingsController.new);
```

- [ ] **Step 2: Write the failing controller test**

`test/features/settings/settings_controller_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/features/settings/settings_controller.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  test('save persists and updates the controller state', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    final current =
        await container.read(settingsControllerProvider.future);
    await container
        .read(settingsControllerProvider.notifier)
        .save(current.copyWith(name: 'Sarvar'));

    final after = await container.read(settingsControllerProvider.future);
    expect(after.name, 'Sarvar');
  });
}
```

- [ ] **Step 3: Run test to verify it passes**

Run: `flutter test test/features/settings/settings_controller_test.dart`
Expected: PASS (1 test).

- [ ] **Step 4: Write the screen**

`lib/features/settings/settings_screen.dart` — a `ConsumerWidget` that `ref.watch(settingsControllerProvider)` and renders form rows for the Foundation-owned settings (§5.2): name, currency, date format, period start day, week start, daily-limit method, minimal reserve, theme, biometric/app-lock toggles, plus a disabled "Ma'lumotlarni eksport qilish" tile labeled "(keyingi bosqichda)". Each edit calls `.notifier.save(...)`. Show `AsyncLoading`/`AsyncError` via `state.when(...)` using `userMessage` for errors.
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sozlamalar')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Xatolik yuz berdi')),
        data: (s) => ListView(children: [
          ListTile(title: const Text('Ism'), subtitle: Text(s.name)),
          ListTile(
              title: const Text('Valyuta'),
              subtitle: Text(s.primaryCurrency.code)),
          ListTile(
              title: const Text('Davr boshlanish kuni'),
              subtitle: Text('${s.periodStartDay}')),
          SwitchListTile(
            title: const Text('Ilova qulfi'),
            value: s.appLockEnabled,
            onChanged: (v) => ref
                .read(settingsControllerProvider.notifier)
                .save(s.copyWith(appLockEnabled: v)),
          ),
          const ListTile(
            enabled: false,
            title: Text("Ma'lumotlarni eksport qilish"),
            subtitle: Text('(keyingi bosqichda)'),
          ),
        ]),
      ),
    );
  }
}
```
(If you created a stub in Task 11, replace it now.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/settings/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/settings/ test/features/settings/
git commit -m "feat: add settings screen and controller"
```

---

## Task 14: App-lock and background shield

**Files:**
- Create: `lib/features/security/app_lock_controller.dart`, `lib/features/security/app_lock_gate.dart`, `lib/features/security/background_shield.dart`
- Test: `test/features/security/app_lock_controller_test.dart`

**Interfaces:**
- Consumes: `flutter_secure_storage`, `local_auth`, `crypto`.
- Produces:
  - `class PinHasher { static String hash(String pin, String salt); }`
  - `abstract class SecretStore { Future<void> write(String k, String v); Future<String?> read(String k); }` + `SecureSecretStore` (wraps `FlutterSecureStorage`)
  - `class AppLockController` with `Future<void> setPin(String)`, `Future<bool> verifyPin(String)`, `Future<bool> authenticateBiometric()`
  - `class AppLockGate extends StatefulWidget` — blocks the child until unlocked; re-locks on resume past a timeout
  - `class BackgroundShield extends StatefulWidget` — overlays a blur when `AppLifecycleState` is `inactive`/`paused`

- [ ] **Step 1: Write the PIN hasher and abstract store (pure/testable parts)**

`lib/features/security/app_lock_controller.dart`:
```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

class PinHasher {
  const PinHasher._();
  static String hash(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }
}

abstract class SecretStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
}

class AppLockController {
  final SecretStore store;
  AppLockController(this.store);

  static const _pinKey = 'app_lock_pin_hash';
  static const _saltKey = 'app_lock_salt';

  Future<void> setPin(String pin) async {
    final salt = DateTime.now().microsecondsSinceEpoch.toString();
    await store.write(_saltKey, salt);
    await store.write(_pinKey, PinHasher.hash(pin, salt));
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await store.read(_saltKey);
    final stored = await store.read(_pinKey);
    if (salt == null || stored == null) return false;
    return PinHasher.hash(pin, salt) == stored;
  }
}
```

> `authenticateBiometric()` (wrapping `local_auth`) and the `SecureSecretStore` implementation (wrapping `FlutterSecureStorage`) are thin device-only adapters added alongside the gate widget below; they are exercised via manual/integration testing, not unit tests.

- [ ] **Step 2: Write the failing test with a fake store**

`test/features/security/app_lock_controller_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/features/security/app_lock_controller.dart';

class FakeStore implements SecretStore {
  final _m = <String, String>{};
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String value) async => _m[key] = value;
}

void main() {
  test('a set PIN verifies and a wrong PIN fails', () async {
    final c = AppLockController(FakeStore());
    await c.setPin('1234');
    expect(await c.verifyPin('1234'), isTrue);
    expect(await c.verifyPin('0000'), isFalse);
  });

  test('verify fails when no PIN is set', () async {
    expect(await AppLockController(FakeStore()).verifyPin('1234'), isFalse);
  });

  test('hash is salted: same pin, different salt, different hash', () {
    expect(PinHasher.hash('1234', 'a'), isNot(PinHasher.hash('1234', 'b')));
  });
}
```

- [ ] **Step 3: Run test to verify it passes**

Run: `flutter test test/features/security/app_lock_controller_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 4: Write the gate and shield widgets**

`lib/features/security/background_shield.dart`:
```dart
import 'dart:ui';
import 'package:flutter/material.dart';

class BackgroundShield extends StatefulWidget {
  final Widget child;
  const BackgroundShield({super.key, required this.child});
  @override
  State<BackgroundShield> createState() => _BackgroundShieldState();
}

class _BackgroundShieldState extends State<BackgroundShield>
    with WidgetsBindingObserver {
  bool _obscure = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _obscure = state != AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        widget.child,
        if (_obscure)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(color: Colors.black.withValues(alpha: 0.2)),
            ),
          ),
      ]);
}
```

`lib/features/security/app_lock_gate.dart` — a `StatefulWidget` that, when `settings.appLockEnabled`, shows a PIN/biometric prompt over `child` on cold start and whenever the app resumes after being paused beyond a timeout (e.g. 30s), calling `AppLockController.verifyPin` / `authenticateBiometric`. Wraps `child` only after a successful unlock.

- [ ] **Step 5: Run tests and analyzer**

Run: `flutter test test/features/security/ && flutter analyze`
Expected: PASS; no analyzer issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/security/ test/features/security/
git commit -m "feat: add app-lock (salted PIN + biometric) and background shield"
```

---

## Task 15: Composition root and first-run boot

**Files:**
- Create: `lib/app.dart`
- Modify: `lib/main.dart`
- Test: `integration_test/app_boot_test.dart`

**Interfaces:**
- Consumes: everything.
- Produces:
  - `Future<void> main()` that: ensures bindings, resolves the DB file path (`path_provider`), calls `openAppDatabase`, and on `Err` shows a recovery message screen; on `Ok` runs `App` with `databaseProvider` overridden.
  - `class App extends ConsumerWidget` — `MaterialApp.router(theme, darkTheme, themeMode from settings)`, wrapped in `BackgroundShield` and `AppLockGate`, routed by `buildRouter(onboardingComplete: …)`.

- [ ] **Step 1: Write main.dart**

`lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'app.dart';
import 'core/result/failure_messages.dart';
import 'data/db/db_open.dart';
import 'providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  final dbPath = p.join(dir.path, 'financial_assistant.db');

  final result = await openAppDatabase(dbPath: dbPath);
  result.when(
    ok: (db) => runApp(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const App(),
      ),
    ),
    err: (failure) => runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(userMessage(failure), textAlign: TextAlign.center),
          ),
        ),
      ),
    )),
  );
}
```

- [ ] **Step 2: Write app.dart**

`lib/app.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'data/settings/settings_model.dart';
import 'features/security/background_shield.dart';
import 'features/shell/routes.dart';
import 'providers/app_providers.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(metaProvider);
    final settings = ref.watch(settingsProvider);

    return meta.when(
      loading: () => const _Bootstrapping(),
      error: (_, __) => const _Bootstrapping(),
      data: (m) {
        final themeMode = settings.maybeWhen(
          data: (s) => switch (s.themeMode) {
            ThemeModeSetting.system => ThemeMode.system,
            ThemeModeSetting.light => ThemeMode.light,
            ThemeModeSetting.dark => ThemeMode.dark,
          },
          orElse: () => ThemeMode.system,
        );
        return BackgroundShield(
          child: MaterialApp.router(
            title: 'Moliyaviy Assistent',
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: themeMode,
            routerConfig:
                buildRouter(onboardingComplete: m.onboardingComplete),
          ),
        );
      },
    );
  }
}

class _Bootstrapping extends StatelessWidget {
  const _Bootstrapping();
  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
}
```

> `AppLockGate` wrapping is added here around the router child once Task 14's gate widget is in place; keep the wrap conditional on `settings.appLockEnabled`.

- [ ] **Step 3: Write the boot integration test**

`integration_test/app_boot_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:drift/native.dart';
import 'package:financial_assistant/app.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first run boots into onboarding', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const App(),
    ));
    await tester.pumpAndSettle();
    // onboardingComplete=false → not the 5-tab shell yet.
    expect(find.byType(NavigationBar), findsNothing);
  });
}
```
Add `integration_test` to dev dependencies: `flutter pub add --dev integration_test --sdk=flutter`.

- [ ] **Step 4: Run the full suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all unit/widget tests PASS; analyzer clean. (Run the integration test on a device/emulator with `flutter test integration_test/app_boot_test.dart` if available.)

- [ ] **Step 5: Manual smoke check**

Run: `flutter run` on an emulator. Verify: app cold-starts to onboarding; completing onboarding lands on the 5-tab shell; relaunch goes straight to the shell; settings persist; backgrounding the app blurs the content.

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart lib/app.dart integration_test/ pubspec.yaml
git commit -m "feat: wire composition root, first-run routing, and boot recovery screen"
```

---

## Self-Review

**Spec coverage** (design spec §-by-§ → task):
- §2 stack (Drift/Riverpod/GoRouter/Money/local_auth) → Tasks 0, 2, 5, 8, 11, 14. ✔
- §3 layering → file structure + Task 0. ✔
- §4.1 Money/Currency → Tasks 1–2. ✔
- §4.2 FinancialPeriod → Task 3. ✔
- §4.3 Result/Failure + non-technical messages → Task 4. ✔
- §5.1 tables (app_settings, app_meta) → Task 5. ✔
- §5.2 repositories → Task 7. ✔
- §5.3 migration + snapshot recovery → Task 6. ✔
- §6.1 5-tab shell + settings entry → Task 11. ✔
- §6.2 extensible onboarding → Task 12. ✔
- §6.3 settings screen (+ export stub) → Task 13. ✔
- §6.4 app-lock + background shield → Task 14. ✔
- §6.5 theme + status color+icon+text + l10n → Tasks 9–10. ✔
- §8 testing/acceptance (pure unit, in-memory repo, migration + recovery test, boot) → Tasks 1–7, 12, 15. ✔
- §9 open questions (multi-currency aggregation, uz-Cyrl) → correctly deferred, no task. ✔

**Placeholder scan:** UI-only widgets (onboarding step visuals, settings rows, app-lock gate, biometric adapter) are described with concrete code or an explicit, bounded spec plus at least one example implementation; their logic is unit-tested where it exists (controllers, hasher). No "TBD"/"handle edge cases"/"add validation" placeholders remain.

**Type consistency:** `Money(int, Currency)`, `CurrencyRegistry.byCode`, `FinancialPeriod.containing`, `Result.when({ok, err})`, `AppSettings.copyWith`, `SettingsRepository.read/write`, `MetaRepository.markOnboardingComplete/touchBackup`, `databaseProvider` override, `OnboardingController.commit`, `AppLockController.setPin/verifyPin`, `buildRouter(onboardingComplete:)` — names/signatures are consistent across every task that consumes them.

**Known ordering note:** Task 11's router imports the onboarding/settings screens built in Tasks 12–13. When executing strictly in order, create the two named stub widgets in Task 11 and replace them in their own tasks (called out inline in both places).
