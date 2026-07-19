# Velora UI Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Velora visual foundation, responsive shared components, formatted money entry, account/category pickers, and approved five-tab shell used by every later screen.

**Architecture:** Keep financial parsing in `core/money`, reusable presentation-only widgets in `lib/ui/components`, and route composition in `features/shell`. Widgets consume immutable values and callbacks; they do not access repositories directly.

**Tech Stack:** Flutter 3.38.1+, Dart 3.12+, Material 3, Riverpod 3, GoRouter 17, Flutter widget/golden tests.

## Global Constraints

- Brand colors: Plum `#5B3A6E`, Coral `#E96F5C`, Apricot `#FFB46A`, Blush `#FFF8F5`, Inkberry `#332A3A`, Success `#2E9D7C`.
- UZS display uses space grouping and zero decimals: `12 500 000 so‘m`.
- Money remains integer minor units plus currency code; no floating-point conversion.
- Minimum touch target is 48×48 logical pixels.
- UI must reflow at 320 px width and 200% system text scale.
- Red is only for errors/critical states; status always includes text and icon.
- Motion is 180–240 ms and respects reduced motion.
- Light and dark themes must both pass widget and golden tests.

---

## File map

- `assets/fonts/`: bundled Onest, Noto Sans, IBM Plex Mono font files and licenses.
- `lib/core/theme/velora_tokens.dart`: colors, radii, spacing, motion, semantic status tokens.
- `lib/core/theme/app_theme.dart`: Material theme mapping.
- `lib/core/theme/app_typography.dart`: bundled font families and tabular amount styles.
- `lib/core/money/money_text_input_formatter.dart`: caret-safe normalization.
- `lib/ui/components/`: buttons, cards, states, money field, account picker, category picker, sheet scaffold.
- `lib/features/shell/app_shell.dart`: indexed five-tab navigation and global expense action.
- `lib/features/shell/routes.dart`: typed route constants for the approved IA.
- `test/ui/` and `test/core/money/`: component behavior, accessibility, and responsive coverage.

### Task 1: Bundle Velora typography and semantic tokens

**Files:**
- Create: `assets/fonts/Onest-Variable.ttf`
- Create: `assets/fonts/NotoSans-Variable.ttf`
- Create: `assets/fonts/IBMPlexMono-Regular.ttf`
- Create: `assets/fonts/OFL-Onest.txt`
- Create: `assets/fonts/OFL-NotoSans.txt`
- Create: `assets/fonts/OFL-IBMPlexMono.txt`
- Create: `lib/core/theme/velora_tokens.dart`
- Modify: `pubspec.yaml`
- Modify: `lib/core/theme/app_colors.dart`
- Modify: `lib/core/theme/app_typography.dart`
- Modify: `lib/core/theme/app_theme.dart`
- Test: `test/core/theme/velora_theme_test.dart`

**Interfaces:**
- Produces: `VeloraColors`, `VeloraSpacing`, `VeloraRadii`, `VeloraMotion`, `VeloraStatus`, `buildLightTheme()`, `buildDarkTheme()`.

- [ ] **Step 1: Write the failing theme test**

```dart
test('Velora light theme maps exact approved semantic colors', () {
  final theme = buildLightTheme();
  expect(theme.colorScheme.primary, const Color(0xFF5B3A6E));
  expect(theme.colorScheme.secondary, const Color(0xFFE96F5C));
  expect(theme.scaffoldBackgroundColor, const Color(0xFFFFF8F5));
  expect(theme.textTheme.headlineSmall?.fontFamily, 'Onest');
  expect(theme.textTheme.bodyMedium?.fontFamily, 'NotoSans');
});
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `flutter test test/core/theme/velora_theme_test.dart`

Expected: FAIL because Velora token classes and bundled fonts do not exist.

- [ ] **Step 3: Add assets and implement exact tokens**

Download the OFL font files and licenses from the official Google Fonts repository, then declare the three families in `pubspec.yaml`:

```powershell
Invoke-WebRequest 'https://raw.githubusercontent.com/google/fonts/main/ofl/onest/Onest%5Bwght%5D.ttf' -OutFile 'assets/fonts/Onest-Variable.ttf'
Invoke-WebRequest 'https://raw.githubusercontent.com/google/fonts/main/ofl/onest/OFL.txt' -OutFile 'assets/fonts/OFL-Onest.txt'
Invoke-WebRequest 'https://raw.githubusercontent.com/google/fonts/main/ofl/notosans/NotoSans%5Bwdth,wght%5D.ttf' -OutFile 'assets/fonts/NotoSans-Variable.ttf'
Invoke-WebRequest 'https://raw.githubusercontent.com/google/fonts/main/ofl/notosans/OFL.txt' -OutFile 'assets/fonts/OFL-NotoSans.txt'
Invoke-WebRequest 'https://raw.githubusercontent.com/google/fonts/main/ofl/ibmplexmono/IBMPlexMono-Regular.ttf' -OutFile 'assets/fonts/IBMPlexMono-Regular.ttf'
Invoke-WebRequest 'https://raw.githubusercontent.com/google/fonts/main/ofl/ibmplexmono/OFL.txt' -OutFile 'assets/fonts/OFL-IBMPlexMono.txt'
```

Then add:

```dart
abstract final class VeloraColors {
  static const plum = Color(0xFF5B3A6E);
  static const coral = Color(0xFFE96F5C);
  static const apricot = Color(0xFFFFB46A);
  static const blush = Color(0xFFFFF8F5);
  static const inkberry = Color(0xFF332A3A);
  static const success = Color(0xFF2E9D7C);
  static const critical = Color(0xFFC94E58);
}

abstract final class VeloraSpacing {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 24.0;
}

abstract final class VeloraRadii {
  static const control = 16.0, card = 22.0, sheet = 28.0;
}

abstract final class VeloraMotion {
  static const standard = Duration(milliseconds: 200);
}
```

Map `ColorScheme.primary` to Plum, `secondary` to Coral, `surface` to Blush, `error` to Critical, and build dark equivalents with the same semantic roles.

- [ ] **Step 4: Run theme tests and analyzer**

Run: `flutter test test/core/theme/velora_theme_test.dart && flutter analyze`

Expected: PASS and `No issues found!`.

- [ ] **Step 5: Commit**

```bash
git add assets/fonts pubspec.yaml lib/core/theme test/core/theme/velora_theme_test.dart
git commit -m "feat: add Velora design tokens and typography"
```

### Task 2: Add shared cards, buttons, sheet scaffold, and global states

**Files:**
- Create: `lib/ui/components/velora_card.dart`
- Create: `lib/ui/components/velora_button.dart`
- Create: `lib/ui/components/velora_sheet.dart`
- Create: `lib/ui/components/velora_status.dart`
- Create: `lib/ui/components/velora_async_state.dart`
- Create: `test/ui/components/velora_components_test.dart`

**Interfaces:**
- Produces: `VeloraCard`, `VeloraPrimaryButton`, `VeloraSheetScaffold`, `VeloraStatusBadge`, `VeloraEmptyState`, `VeloraErrorState`, `VeloraSkeleton`.

- [ ] **Step 1: Write failing responsive and semantic tests**

```dart
testWidgets('primary button is at least 48px and exposes its label', (t) async {
  await t.pumpWidget(MaterialApp(home: VeloraPrimaryButton(label: 'Saqlash', onPressed: () {})));
  expect(t.getSize(find.byType(VeloraPrimaryButton)).height, greaterThanOrEqualTo(48));
  expect(t.getSemantics(find.text('Saqlash')).label, contains('Saqlash'));
});

testWidgets('error state exposes cause and retry', (t) async {
  await t.pumpWidget(MaterialApp(home: VeloraErrorState(message: 'Saqlanmadi', onRetry: () {})));
  expect(find.text('Saqlanmadi'), findsOneWidget);
  expect(find.text('Qayta urinish'), findsOneWidget);
});
```

- [ ] **Step 2: Run the test and verify missing classes**

Run: `flutter test test/ui/components/velora_components_test.dart`

Expected: FAIL with undefined Velora component names.

- [ ] **Step 3: Implement focused reusable widgets**

```dart
class VeloraPrimaryButton extends StatelessWidget {
  const VeloraPrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(label),
    ),
  );
}
```

Implement the other classes with no repository imports. `VeloraStatusBadge` requires icon and label in addition to color. `VeloraSheetScaffold` applies safe area, keyboard inset, title, scroll body, and one fixed CTA.

- [ ] **Step 4: Verify at narrow width and text scale**

Run: `flutter test test/ui/components/velora_components_test.dart`

Expected: PASS at 320×700 and `textScaler: TextScaler.linear(2)` test configurations.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/components test/ui/components
git commit -m "feat: add reusable Velora UI components"
```

### Task 3: Implement caret-safe money normalization

**Files:**
- Create: `lib/core/money/money_text_input_formatter.dart`
- Modify: `lib/core/money/money.dart`
- Test: `test/core/money/money_text_input_formatter_test.dart`
- Modify: `test/core/money/money_test.dart`

**Interfaces:**
- Produces: `MoneyTextInputFormatter(Currency currency, {bool allowNegative = false})` and `Money? parseMoneyInput(String, Currency)`.

- [ ] **Step 1: Write failing normalization tests**

```dart
test('formats UZS while preserving digit-relative caret', () {
  final f = MoneyTextInputFormatter(CurrencyRegistry.uzs);
  final out = f.formatEditUpdate(
    const TextEditingValue(text: '12500', selection: TextSelection.collapsed(offset: 5)),
    const TextEditingValue(text: '125000', selection: TextSelection.collapsed(offset: 6)),
  );
  expect(out.text, '125 000');
  expect(out.selection.baseOffset, 7);
});

test('normalizes pasted currency and separators', () {
  expect(parseMoneyInput('1\u00a0250,000 so‘m', CurrencyRegistry.uzs)?.minorUnits, 1250000);
});
```

- [ ] **Step 2: Run and verify failure**

Run: `flutter test test/core/money/money_text_input_formatter_test.dart`

Expected: FAIL because formatter and paste parser are absent.

- [ ] **Step 3: Implement digit-relative formatting**

```dart
Money? parseMoneyInput(String raw, Currency currency) {
  final numeric = raw.replaceAll(RegExp(r"[^0-9,\.\-]"), '');
  return Money.tryParse(numeric, currency);
}

class MoneyTextInputFormatter extends TextInputFormatter {
  MoneyTextInputFormatter(this.currency, {this.allowNegative = false});
  final Currency currency;
  final bool allowNegative;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final beforeCaret = newValue.text.substring(0, newValue.selection.end.clamp(0, newValue.text.length));
    final digitsBeforeCaret = RegExp(r'\d').allMatches(beforeCaret).length;
    final parsed = parseMoneyInput(newValue.text, currency);
    if (parsed == null || (!allowNegative && parsed.isNegative)) return const TextEditingValue();
    final text = parsed.formatNumber();
    var seen = 0, caret = text.length;
    for (var i = 0; i < text.length; i++) {
      if (RegExp(r'\d').hasMatch(text[i]) && ++seen == digitsBeforeCaret) { caret = i + 1; break; }
    }
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: caret));
  }
}
```

Add overflow handling by using `int.tryParse` in `Money.tryParse` and returning `null` instead of throwing.

- [ ] **Step 4: Run all money tests**

Run: `flutter test test/core/money`

Expected: PASS for UZS, USD/EUR decimals, paste, mid-string edit, clear, negative rejection, and integer overflow.

- [ ] **Step 5: Commit**

```bash
git add lib/core/money test/core/money
git commit -m "feat: add formatted money input engine"
```

### Task 4: Build `VeloraMoneyField`

**Files:**
- Create: `lib/ui/components/velora_money_field.dart`
- Create: `test/ui/components/velora_money_field_test.dart`

**Interfaces:**
- Consumes: `MoneyTextInputFormatter`, `Currency`.
- Produces: `VeloraMoneyField(controller, currency, label, autofocus, enabled, onChanged)`.

- [ ] **Step 1: Write failing widget tests**

```dart
testWidgets('autofocuses, formats UZS, and announces currency', (t) async {
  final c = TextEditingController();
  await t.pumpWidget(MaterialApp(home: Scaffold(body: VeloraMoneyField(
    controller: c, currency: CurrencyRegistry.uzs, label: 'Summa', autofocus: true,
  ))));
  await t.enterText(find.byType(TextField), '1250000');
  expect(c.text, '1 250 000');
  expect(find.text('so‘m'), findsOneWidget);
});
```

- [ ] **Step 2: Run and verify failure**

Run: `flutter test test/ui/components/velora_money_field_test.dart`

Expected: FAIL because `VeloraMoneyField` is undefined.

- [ ] **Step 3: Implement the shared field**

```dart
class VeloraMoneyField extends StatelessWidget {
  const VeloraMoneyField({super.key, required this.controller, required this.currency,
    required this.label, this.autofocus = false, this.enabled = true, this.onChanged});
  final TextEditingController controller;
  final Currency currency;
  final String label;
  final bool autofocus, enabled;
  final ValueChanged<Money?>? onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    textField: true,
    label: '$label, ${currency.code}',
    child: TextField(
      controller: controller,
      autofocus: autofocus,
      enabled: enabled,
      keyboardType: TextInputType.numberWithOptions(decimal: currency.decimalDigits > 0),
      inputFormatters: [MoneyTextInputFormatter(currency)],
      decoration: InputDecoration(labelText: label, suffixText: currency.symbol),
      onChanged: (v) => onChanged?.call(parseMoneyInput(v, currency)),
    ),
  );
}
```

- [ ] **Step 4: Verify widget and accessibility tests**

Run: `flutter test test/ui/components/velora_money_field_test.dart`

Expected: PASS including empty-vs-zero, 200% scale, and disabled-state cases.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/components/velora_money_field.dart test/ui/components/velora_money_field_test.dart
git commit -m "feat: add Velora money field"
```

### Task 5: Build swipeable account cards and hybrid category picker

**Files:**
- Create: `lib/ui/components/account_card_picker.dart`
- Create: `lib/ui/components/category_picker.dart`
- Create: `test/ui/components/account_card_picker_test.dart`
- Create: `test/ui/components/category_picker_test.dart`

**Interfaces:**
- Produces: `AccountCardPicker(accounts, selectedId, onSelected)` and `CategoryPicker(categories, quickIds, selectedId, onSelected)`.

- [ ] **Step 1: Write failing interaction tests**

```dart
testWidgets('account cards show next-card peek and tap selection', (t) async {
  await t.pumpWidget(testApp(AccountCardPicker(accounts: accounts, selectedId: 1, onSelected: selected.add)));
  expect(find.byType(PageView), findsOneWidget);
  await t.tap(find.text('Naqd'));
  expect(selected.last, 2);
});

testWidgets('category picker shows four quick items then searchable sheet', (t) async {
  await t.pumpWidget(testApp(CategoryPicker(categories: categories, quickIds: const [1,2,3,4], onSelected: (_) {})));
  expect(find.byKey(const Key('quick-category')), findsNWidgets(4));
  await t.tap(find.text('Kategoriya tanlash'));
  expect(find.byType(SearchBar), findsOneWidget);
});
```

- [ ] **Step 2: Run and verify failure**

Run: `flutter test test/ui/components/account_card_picker_test.dart test/ui/components/category_picker_test.dart`

Expected: FAIL because both picker widgets are absent.

- [ ] **Step 3: Implement callback-only pickers**

```dart
class AccountCardPicker extends StatelessWidget {
  const AccountCardPicker({super.key, required this.accounts, required this.selectedId, required this.onSelected});
  final List<Account> accounts;
  final int? selectedId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 116,
    child: PageView.builder(
      controller: PageController(viewportFraction: .88),
      onPageChanged: (i) => onSelected(accounts[i].id),
      itemCount: accounts.length,
      itemBuilder: (_, i) => Semantics(
        selected: accounts[i].id == selectedId,
        button: true,
        child: InkWell(onTap: () => onSelected(accounts[i].id), child: VeloraAccountCard(account: accounts[i])),
      ),
    ),
  );
}
```

Implement `CategoryPicker` with exactly four quick items, a labeled button, and a modal sheet containing `SearchBar` plus grouped active categories.

- [ ] **Step 4: Verify swipe, tap, search, and semantics**

Run: `flutter test test/ui/components/account_card_picker_test.dart test/ui/components/category_picker_test.dart`

Expected: PASS with archived categories absent and selected state announced.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/components/account_card_picker.dart lib/ui/components/category_picker.dart test/ui/components
git commit -m "feat: add account and category pickers"
```

### Task 6: Replace the app shell with the approved five-tab IA

**Files:**
- Modify: `lib/features/shell/app_shell.dart`
- Modify: `lib/features/shell/routes.dart`
- Modify: `test/features/shell/app_shell_test.dart`
- Create: `test/features/shell/routes_test.dart`

**Interfaces:**
- Produces route names: `home`, `history`, `plan`, `goals`, `reports`, `settings`, `accounts`.
- Bottom labels: `Bugun`, `Tarix`, `Reja`, `Maqsad`, `Tahlil`.

- [ ] **Step 1: Write failing shell-state tests**

```dart
testWidgets('shows approved labels and preserves tab state', (t) async {
  await t.pumpWidget(const MaterialApp(home: AppShell()));
  for (final label in ['Bugun', 'Tarix', 'Reja', 'Maqsad', 'Tahlil']) {
    expect(find.text(label), findsOneWidget);
  }
  await t.tap(find.text('Tarix'));
  await t.pumpAndSettle();
  expect(find.byKey(const PageStorageKey('history-tab')), findsOneWidget);
});
```

- [ ] **Step 2: Run and verify old labels fail**

Run: `flutter test test/features/shell/app_shell_test.dart test/features/shell/routes_test.dart`

Expected: FAIL because the shell still uses old labels and a temporary reports tab.

- [ ] **Step 3: Implement indexed tab preservation and routes**

```dart
static const _destinations = <NavigationDestination>[
  NavigationDestination(icon: Icon(Icons.today_outlined), label: 'Bugun'),
  NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Tarix'),
  NavigationDestination(icon: Icon(Icons.account_tree_outlined), label: 'Reja'),
  NavigationDestination(icon: Icon(Icons.flag_outlined), label: 'Maqsad'),
  NavigationDestination(icon: Icon(Icons.insights_outlined), label: 'Tahlil'),
];

body: IndexedStack(index: _index, children: _tabs),
floatingActionButton: FloatingActionButton.extended(
  key: const Key('global-expense-action'),
  onPressed: () => showExpenseEntrySheet(context, ref),
  icon: const Icon(Icons.remove),
  label: const Text('Chiqim'),
),
```

Use `PageStorageKey` per tab and keep the expense action available from all five destinations.

- [ ] **Step 4: Run shell and full regression tests**

Run: `flutter test test/features/shell && flutter test`

Expected: PASS; no existing navigation regression.

- [ ] **Step 5: Commit**

```bash
git add lib/features/shell test/features/shell
git commit -m "feat: add Velora five-tab shell"
```

### Task 7: Add golden and responsive test harness

**Files:**
- Create: `test/support/velora_test_app.dart`
- Create: `test/support/golden_devices.dart`
- Create: `test/goldens/velora_foundation_golden_test.dart`
- Create: `test/goldens/baselines/`

**Interfaces:**
- Produces: `pumpVelora`, `phone320`, `phone390`, `textScale200` test helpers.

- [ ] **Step 1: Write the golden suite**

```dart
testWidgets('foundation components match approved light and dark visuals', (t) async {
  await pumpVelora(t, child: const FoundationGallery(), size: phone390, brightness: Brightness.light);
  await expectLater(find.byType(FoundationGallery), matchesGoldenFile('baselines/foundation-light.png'));
  await pumpVelora(t, child: const FoundationGallery(), size: phone320, brightness: Brightness.dark, textScale: 2);
  await expectLater(find.byType(FoundationGallery), matchesGoldenFile('baselines/foundation-dark-320-scale200.png'));
});
```

- [ ] **Step 2: Generate baselines and inspect them**

Run: `flutter test --update-goldens test/goldens/velora_foundation_golden_test.dart`

Expected: baseline PNGs generated with no overflow exceptions. Inspect every PNG before accepting it.

- [ ] **Step 3: Add reusable pump helpers**

```dart
Future<void> pumpVelora(WidgetTester t, {required Widget child, required Size size,
  Brightness brightness = Brightness.light, double textScale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  await t.pumpWidget(MediaQuery(
    data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
    child: MaterialApp(theme: buildLightTheme(), darkTheme: buildDarkTheme(),
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light, home: child),
  ));
  await t.pumpAndSettle();
}
```

- [ ] **Step 4: Run foundation verification**

Run: `dart format --set-exit-if-changed lib test && flutter analyze && flutter test`

Expected: formatter exits 0, analyzer has no issues, and all tests pass.

- [ ] **Step 5: Commit**

```bash
git add test/support test/goldens
git commit -m "test: add Velora visual regression harness"
```
