# Home Dashboard Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplify Home to ~7 numbers by reframing the safe-limit hero, merging the two balance cards into one, and removing the weekly/monthly safe-limit card.

**Architecture:** Pure presentation change over the existing `DashboardData` pipeline. The safe-limit *engine* is untouched; only Home widgets and the now-orphaned Home provider plumbing change. Three Home widgets change (`SafeLimitCard`, a new `BalanceCard` replacing `MiniBalanceRow` + `DistributionCard`), one card is deleted (`WeeklySafeLimitCard`).

**Tech Stack:** Flutter, Riverpod, Drift (SQLite), `flutter_test` widget + golden tests.

## Global Constraints

- UI copy is Uzbek Latin, warm and non-accusatory (§3.1) — no naked negative amounts shown to the user.
- Money rendering: `Money.format()` = number **with** the `so'm` suffix; `Money.formatNumber()` = number only. Match the existing widget's choice per field.
- Preserve widget `Key`s used by tests: `Key('balance-card')`, `Key('balance-amount')`, `Key('safe-limit-hero')`.
- Colors/spacing come from `VeloraColors` / `VeloraSpacing` / `VeloraRadii` in `lib/core/theme/velora_tokens.dart` — never hardcode hex.
- Do NOT modify `lib/core/limit/safe_limit_engine.dart` or `test/core/limit/safe_limit_engine_test.dart`.
- Run tests with `flutter test`. Regenerate goldens with `flutter test --update-goldens`.

---

### Task 1: Reframe the "Bugun qoldi" hero (`SafeLimitCard`)

**Files:**
- Modify: `lib/features/home/safe_limit_cards.dart` (`SafeLimitCard.build`, lines ~24-115)
- Test: `test/features/home/safe_limit_cards_test.dart`

**Interfaces:**
- Consumes: existing `SafeLimit` value object — `perDay: Money`, `todayRemaining: Money`, `todaySpent: Money`, `daysLeft: int`, `isOver: bool` (`todayRemaining.minorUnits < 0`), `spendable: Money`. No signature change to `SafeLimitCard({required SafeLimit limit, List<String> overspendCategories})`.
- Produces: same widget, new rendered text. Label `BUGUN QOLDI`; big number = remaining today floored at 0; supporting line reframed.

- [ ] **Step 1: Update the failing test for the new label + big number**

In `test/features/home/safe_limit_cards_test.dart`, in the first test (`daily safe-limit card shows the per-day figure`), change the label assertion and add the remaining-today expectation. Replace:

```dart
    expect(find.textContaining('BUGUN BEMALOL'), findsOneWidget);
    // Exact match (not textContaining) so this pins to the dedicated headline
    // Text: with no expenses, "Bugun qoldi: ..." also contains the same figure.
    expect(find.text(limit.perDay.format()), findsOneWidget);
```

with:

```dart
    expect(find.textContaining('BUGUN QOLDI'), findsOneWidget);
    // With no expenses today, remaining == perDay, so the hero's big number
    // still equals the per-day figure. Exact match pins it to the headline Text.
    expect(find.text(limit.todayRemaining.format()), findsOneWidget);
    // The daily allowance now lives in the supporting line.
    expect(find.textContaining('Kunlik limit'), findsOneWidget);
```

Add a second new test for the over-budget copy at the end of `main()`:

```dart
  testWidgets('over-limit hero shows zero left and plain-language overage',
      (tester) async {
    const uzs = CurrencyRegistry.uzs;
    const limit = SafeLimit(
      spendable: Money(0, uzs),
      perDay: Money(50000, uzs),
      daysLeft: 5,
      todaySpent: Money(80000, uzs),
      todayRemaining: Money(-30000, uzs),
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SafeLimitCard(limit: limit))),
    );
    await tester.pumpAndSettle();

    // Big number is 0, not a negative figure.
    expect(find.text(const Money(0, uzs).format()), findsOneWidget);
    expect(find.textContaining('oshdingiz'), findsOneWidget);
    // No naked negative anywhere on the card.
    expect(find.textContaining('-30'), findsNothing);
    expect(find.textContaining('−30'), findsNothing);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/home/safe_limit_cards_test.dart`
Expected: FAIL — old widget still renders `BUGUN BEMALOL` and the negative `Bugun qoldi: −30 000`.

- [ ] **Step 3: Implement the hero changes**

In `lib/features/home/safe_limit_cards.dart`, inside `SafeLimitCard.build`:

Add, near the top of `build` (after `final status = _statusFor(limit);`):

```dart
    final c = limit.perDay.currency;
    // The hero answers "how much can I still spend today", floored at zero so
    // an over-budget day reads as 0 + a plain sentence, never a raw negative.
    final remainingToday = limit.todayRemaining.minorUnits < 0
        ? Money(0, c)
        : limit.todayRemaining;
    final overBy = Money(-limit.todayRemaining.minorUnits, c);
```

Change the label `Text` from `'BUGUN BEMALOL'` to `'BUGUN QOLDI'`.

Change the big-number `Text(limit.perDay.format(), ...)` to `Text(remainingToday.format(), ...)` (keep the surrounding `FittedBox`, `maxLines`, and style unchanged).

Replace the supporting line `Text`:

```dart
                child: Text(
                  'Bugun qoldi: ${limit.todayRemaining.format()} '
                  '· ${limit.daysLeft} kun qoldi',
                  ...
                ),
```

with:

```dart
                child: Text(
                  limit.isOver
                      ? 'Bugungi limitdan ${overBy.format()} oshdingiz '
                        '· ${limit.daysLeft} kun qoldi'
                      : 'Kunlik limit ${limit.perDay.format()} '
                        '· ${limit.daysLeft} kun qoldi',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: onPlum.withValues(alpha: 0.82)),
                ),
```

Leave the progress-bar `fraction` logic, the status icon, and the `overspendCategories` offenders line exactly as they are.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/home/safe_limit_cards_test.dart`
Expected: PASS (both the updated daily test and the new over-limit test; the existing offenders-line test still passes).

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/safe_limit_cards.dart test/features/home/safe_limit_cards_test.dart
git commit -m "feat(home): reframe safe-limit hero as today-remaining, no naked negative"
```

---

### Task 2: Remove the weekly/monthly safe-limit card + its Home plumbing

**Files:**
- Modify: `lib/features/home/home_screen.dart` (remove the `WeeklySafeLimitCard` block, ~lines 185-186)
- Modify: `lib/features/home/safe_limit_cards.dart` (delete the `WeeklySafeLimitCard` widget, ~lines 127-160)
- Modify: `lib/features/home/dashboard_data.dart` (drop `weeklyLimit` field + `buildDashboard` param)
- Modify: `lib/providers/app_providers.dart` (delete `weeklySafeLimitProvider`, ~lines 425-456; drop its use in `dashboardProvider`, lines 95 & 106)
- Test: `test/features/home/home_screen_test.dart`, `test/features/home/safe_limit_cards_test.dart`, `test/providers/safe_limit_providers_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `DashboardData` no longer has a `weeklyLimit` field; `buildDashboard` no longer accepts `weeklyLimit:`; `weeklySafeLimitProvider` no longer exists. Engine `weeklySafeLimit`/`WeeklySafeLimit` remain.

- [ ] **Step 1: Update the failing test — Home no longer shows the weekly card**

In `test/features/home/home_screen_test.dart`, in the `renders the approved hierarchy` test, remove the two lines that reference the weekly card:

```dart
    expect(find.byKey(const Key('weekly-limit-card')), findsOneWidget);
```
and
```dart
    expect(top('unallocated-alert'), lessThan(top('weekly-limit-card')));
    expect(top('weekly-limit-card'), lessThan(top('goal-summary-card')));
```

Replace that second pair with a direct link:

```dart
    expect(top('unallocated-alert'), lessThan(top('goal-summary-card')));
```

Also update the test's docstring/name to drop "weekly/monthly progress".

In `test/features/home/safe_limit_cards_test.dart`, remove any test that constructs or asserts `WeeklySafeLimitCard` (there is none currently beyond the daily/offenders tests — verify and leave the file as-is if so).

In `test/providers/safe_limit_providers_test.dart`, delete the test case(s) that read `weeklySafeLimitProvider`. Keep the daily `safeLimitProvider` cases.

- [ ] **Step 2: Run tests to verify the expected failures / stale references**

Run: `flutter test test/features/home/home_screen_test.dart test/providers/safe_limit_providers_test.dart`
Expected: FAIL — `weekly-limit-card` key still found (card still rendered), and/or `weeklySafeLimitProvider` references cause the provider test to still pass against code we are about to delete. This step confirms the current wiring before removal.

- [ ] **Step 3: Remove the card from Home**

In `lib/features/home/home_screen.dart`, delete:

```dart
        if (d.weeklyLimit != null && d.safeLimit != null)
          WeeklySafeLimitCard(weekly: d.weeklyLimit!, monthly: d.safeLimit!),
        const SizedBox(height: VeloraSpacing.md),
```

Then remove the now-unused `WeeklySafeLimitCard` reference. (The `safe_limit_cards.dart` import stays — `SafeLimitCard` is still used.)

- [ ] **Step 4: Delete the widget**

In `lib/features/home/safe_limit_cards.dart`, delete the entire `WeeklySafeLimitCard` class (the class documented as "Weekly limit and monthly free-budget progress").

- [ ] **Step 5: Drop the `weeklyLimit` plumbing from `DashboardData`**

In `lib/features/home/dashboard_data.dart`:
- Delete the field `final WeeklySafeLimit? weeklyLimit;` and its doc comment fragment.
- Delete `this.weeklyLimit,` from the `DashboardData` constructor.
- Delete the `WeeklySafeLimit? weeklyLimit,` parameter from `buildDashboard` and the `weeklyLimit: weeklyLimit,` line in its `DashboardData(...)` return.
- Remove the now-unused `import '../../core/limit/safe_limit_engine.dart';` **only if** `SafeLimit` is also unused there — it is still used (the `safeLimit` field), so **keep** the import.

- [ ] **Step 6: Delete the provider and its use**

In `lib/providers/app_providers.dart`:
- Delete the entire `weeklySafeLimitProvider` (`final weeklySafeLimitProvider = FutureProvider<WeeklySafeLimit>(...)` through its closing `});`).
- In `dashboardProvider`, delete the line `final weeklyLimit = await ref.watch(weeklySafeLimitProvider.future);` and the `weeklyLimit: weeklyLimit,` argument in the `buildDashboard(...)` call.

- [ ] **Step 7: Fix any remaining compile references**

Run: `flutter analyze lib test`
Expected: no errors. If a test constructs `DashboardData(... weeklyLimit: ...)` or `buildDashboard(... weeklyLimit: ...)`, remove that argument there too. Search: `grep -rn "weeklyLimit\|weeklySafeLimit\|WeeklySafeLimitCard\|weekly-limit-card" lib test`.

- [ ] **Step 8: Run the affected tests**

Run: `flutter test test/features/home/home_screen_test.dart test/providers/safe_limit_providers_test.dart test/features/home/safe_limit_cards_test.dart`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/features/home/home_screen.dart lib/features/home/safe_limit_cards.dart lib/features/home/dashboard_data.dart lib/providers/app_providers.dart test/
git commit -m "feat(home): remove weekly/monthly safe-limit card from Home"
```

---

### Task 3: Merge the two balance cards into one `BalanceCard`

**Files:**
- Modify: `lib/features/home/home_hero.dart` (add `BalanceCard`; delete `MiniBalanceRow`, `DistributionCard`, `DistributionSegment`, `_Mini`)
- Modify: `lib/features/home/home_screen.dart` (`_HomeBody.build`: replace `MiniBalanceRow` + `DistributionCard` with one `BalanceCard`)
- Test: `test/features/home/home_screen_test.dart`

**Interfaces:**
- Consumes: `total: Money`, `free: Money?`, `reserved: Money?`, `hidden: bool` — all already computed in `_HomeBody.build`.
- Produces: `BalanceCard({required Money total, required Money? free, required Money? reserved, required bool hidden})` carrying `Key('balance-card')` on the card and `Key('balance-amount')` on the big number. Renders total (masked when hidden), an Erkin/Rezerv split bar, and Erkin/Rezerv legend rows (em dash when the value is null).

- [ ] **Step 1: Update the tests for the merged card + new order**

In `test/features/home/home_screen_test.dart`:

The `shows the total balance card` test and the `privacy toggle` test both rely on `Key('balance-amount')` and the `1 000 000` figure — these still hold (total is unchanged), so leave them.

In the `renders the approved hierarchy` test, update the ordering: the merged balance card now sits **below** the quick actions / unallocated alert. Replace the ordering block with:

```dart
    expect(top('safe-limit-hero'), lessThan(top('quick-actions-row')));
    expect(top('quick-actions-row'), lessThan(top('unallocated-alert')));
    expect(top('unallocated-alert'), lessThan(top('balance-card')));
    expect(top('balance-card'), lessThan(top('goal-summary-card')));
    expect(top('goal-summary-card'), lessThan(top('mortgage-summary-card')));
```

Add an assertion that the balance card shows both segments:

```dart
    expect(find.textContaining('Erkin'), findsWidgets);
    expect(find.textContaining('Rezerv'), findsWidgets);
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/home/home_screen_test.dart`
Expected: FAIL — old order (`balance-card` above `quick-actions-row`) still holds and there is no single merged card.

- [ ] **Step 3: Add the `BalanceCard` widget**

In `lib/features/home/home_hero.dart`, add this class (it reuses the imports already at the top of the file):

```dart
/// The Home balance card: total on top, then a two-part Erkin/Rezerv split of
/// that total. `reserved` is `total − free`, so goal earmarks and mandatory
/// amounts are already inside it — the split is Erkin/Rezerv only, and always
/// sums to the total. Goals and mortgage keep their own cards, so nothing is
/// lost. Replaces the former `MiniBalanceRow` + `DistributionCard`. All amounts
/// mask together under the privacy toggle; a null figure shows an em dash.
class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.total,
    required this.free,
    required this.reserved,
    required this.hidden,
  });

  final Money total;
  final Money? free; // "Erkin" — spendable
  final Money? reserved; // "Rezerv" — total − free
  final bool hidden;

  static const _mask = '••••••';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final freeMinor = free?.minorUnits ?? 0;
    final reservedMinor = reserved?.minorUnits ?? 0;
    final barTotal = freeMinor + reservedMinor;
    final showBar = free != null && reserved != null && barTotal > 0;

    String amount(Money? m) =>
        m == null ? '—' : (hidden ? _mask : m.formatNumber());

    return Container(
      key: const Key('balance-card'),
      padding: const EdgeInsets.all(VeloraSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(VeloraRadii.card),
        border: Border.all(color: VeloraColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Balans', style: theme.textTheme.titleMedium),
          const SizedBox(height: VeloraSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              hidden ? _mask : total.formatNumber(),
              key: const Key('balance-amount'),
              maxLines: 1,
              softWrap: false,
              semanticsLabel: hidden ? 'Balans yashirilgan' : total.format(),
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (showBar) ...[
            const SizedBox(height: VeloraSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: Row(
                children: [
                  if (freeMinor > 0)
                    Expanded(
                      flex: (freeMinor * 1000 ~/ barTotal).clamp(1, 1000),
                      child: Container(height: 9, color: VeloraColors.coral),
                    ),
                  if (reservedMinor > 0)
                    Expanded(
                      flex: (reservedMinor * 1000 ~/ barTotal).clamp(1, 1000),
                      child: Container(height: 9, color: VeloraColors.plum),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: VeloraSpacing.md),
          _BalanceLegendRow(
              color: VeloraColors.coral, label: 'Erkin', value: amount(free)),
          const SizedBox(height: VeloraSpacing.xs),
          _BalanceLegendRow(
              color: VeloraColors.plum,
              label: 'Rezerv',
              value: amount(reserved)),
        ],
      ),
    );
  }
}

class _BalanceLegendRow extends StatelessWidget {
  const _BalanceLegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: VeloraSpacing.sm),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
```

- [ ] **Step 4: Wire `BalanceCard` into Home and drop the old widgets**

In `lib/features/home/home_screen.dart`, `_HomeBody.build`:

Delete the `MiniBalanceRow(...)` block that currently sits directly under the `SafeLimitCard` block (and its trailing `SizedBox`).

Delete the `DistributionCard(segments: [...])` block (and its trailing `SizedBox`).

Insert the merged card where the `DistributionCard` used to be — i.e. after the unallocated-alert block, before the goal card:

```dart
        const SizedBox(height: VeloraSpacing.md),
        BalanceCard(
          total: total,
          free: free,
          reserved: reserved,
          hidden: hidden,
        ),
```

The `total`, `free`, and `reserved` locals already exist at the top of `build`; leave their computation unchanged.

- [ ] **Step 5: Delete the orphaned widgets**

In `lib/features/home/home_hero.dart`, delete the `MiniBalanceRow` class, the `_Mini` class, the `DistributionCard` class, and the `DistributionSegment` class. Keep `HomeHeader` and `_HeaderIconButton`.

- [ ] **Step 6: Fix compile references + run analyze**

Run: `flutter analyze lib test`
Expected: no errors. If `home_screen.dart` still imports something now unused, leave imports that are still referenced. Search for stragglers: `grep -rn "MiniBalanceRow\|DistributionCard\|DistributionSegment" lib test`.

- [ ] **Step 7: Run the Home tests**

Run: `flutter test test/features/home/home_screen_test.dart`
Expected: PASS (total-balance test, privacy-toggle test, and the reordered hierarchy test all green).

- [ ] **Step 8: Commit**

```bash
git add lib/features/home/home_hero.dart lib/features/home/home_screen.dart test/features/home/home_screen_test.dart
git commit -m "feat(home): merge balance minis + distribution into one Balans card"
```

---

### Task 4: Dead-code cleanup, golden regeneration, full-suite verification

**Files:**
- Modify: `lib/providers/app_providers.dart` and `lib/features/home/dashboard_data.dart` (remove `goalsSavedTotal` wiring **iff** now orphaned)
- Test: all golden tests; whole suite

**Interfaces:**
- Consumes/produces: nothing new — this task only removes dead code and refreshes goldens.

- [ ] **Step 1: Check whether `goalsSavedTotal` is now dead**

The former `DistributionCard` was the only consumer of `DashboardData.goalsSavedTotal` (it fed the "Maqsadlar" segment). Confirm no remaining reference:

Run: `grep -rn "goalsSavedTotal" lib test`
Expected: references only in `dashboard_data.dart` (field + param + default) and `app_providers.dart` (`_goalsSavedTotal` helper + the `goalsSavedTotal:` argument). If the only references are these definitions (no *reader*), it is dead.

- [ ] **Step 2: Remove the dead `goalsSavedTotal` wiring**

If Step 1 confirms it is orphaned, in `lib/features/home/dashboard_data.dart` delete: the `goalsSavedTotal` field + its doc comment, the constructor default `this.goalsSavedTotal = ...`, the `buildDashboard` param `Money goalsSavedTotal = ...`, and the `goalsSavedTotal: goalsSavedTotal,` line in the return. In `lib/providers/app_providers.dart` delete the `goalsSavedTotal:` argument in `dashboardProvider` and the `_goalsSavedTotal(...)` helper function.

If any *reader* exists (a test asserting it, another widget), **skip this step** and leave `goalsSavedTotal` in place — do not chase removals beyond what the merge orphaned.

- [ ] **Step 3: Analyze clean**

Run: `flutter analyze lib test`
Expected: no errors, no unused-element warnings for the removed symbols.

- [ ] **Step 4: Regenerate goldens**

Run: `flutter test --update-goldens`
Expected: golden PNGs under `test/goldens/` and `test/ui/` that render Home cards are rewritten. Eyeball the changed goldens (`git diff --stat`) to confirm they reflect the new hero copy and the merged Balans card — not an unrelated regression.

- [ ] **Step 5: Run the full suite**

Run: `flutter test`
Expected: PASS — all tests green (494+ pre-existing tests plus the updated Home tests).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore(home): drop orphaned goalsSavedTotal wiring; refresh goldens"
```

---

## Self-Review

**Spec coverage:**
- Spec change 1 (hero reframe) → Task 1. ✓
- Spec change 2 (merged Balans card, Erkin/Rezerv only) → Task 3. ✓
- Spec change 3 (remove weekly/monthly card + plumbing, keep engine) → Task 2. ✓
- Spec "consequential cleanup" (`DistributionCard`/`DistributionSegment` deletion, `goalsSavedTotal`) → Task 3 Step 5 + Task 4. ✓
- Spec "testing" (safe_limit_cards, home_screen, safe_limit_providers, goldens; engine untouched) → covered across Tasks 1-4. ✓
- Spec "risks" (golden churn, key continuity, bounded cleanup) → Task 3 preserves keys; Task 4 regenerates goldens and gates removal on Step 1. ✓

**Placeholder scan:** No TBD/TODO; every code step shows the exact code. ✓

**Type consistency:** `BalanceCard({Money total, Money? free, Money? reserved, bool hidden})` is defined in Task 3 Step 3 and consumed in Task 3 Step 4 with the same names/types. `DashboardData` loses `weeklyLimit` (Task 2) before any task depends on it. Hero uses only existing `SafeLimit` members. ✓
