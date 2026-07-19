# Task 7 Report: Golden and Responsive Test Harness

## Outcome

Added a reusable Velora widget-test harness and a deterministic foundation
gallery covering the real shared money field, cards, status badges, primary and
loading buttons, skeleton/error states, account-card picker, and quick-category
picker in approved light and dark themes.

The harness exports `pumpVelora`, `phone320`, `phone390`, and `textScale200`.
It loads the bundled Onest, Noto Sans, IBM Plex Mono, and Material Icons fonts,
freezes tickers, disables theme-transition duration, keys each configured test
app so consecutive light/dark pumps cannot retain transition colors, and resets
the test view's physical size and device-pixel ratio in teardown.

## TDD evidence

1. RED: `flutter test test/goldens/velora_foundation_golden_test.dart`
   failed because `golden_devices.dart`, `velora_test_app.dart`, `phone320`,
   `phone390`, `textScale200`, and `pumpVelora` did not exist.
2. GREEN/baselines:
   `flutter test --update-goldens test/goldens/velora_foundation_golden_test.dart`
   passed 2/2 tests and generated both required PNGs without a Flutter layout
   exception.
3. Ordinary comparison:
   `flutter test test/goldens/velora_foundation_golden_test.dart` passed 2/2.
4. The helper contract test confirms the requested logical size,
   device-pixel ratio 1, and 200% text scaling reach descendants.

## Visual inspection

Both final PNGs were opened and inspected at original/high detail with the
local image viewer:

| File | Dimensions | Finding |
| --- | ---: | --- |
| `test/goldens/baselines/foundation-light.png` | 390 x 1100 | Light brand colors, bundled typography/icons, amounts, field, status roles, buttons, async states, card peek, and category controls are readable; no clipping, overflow, broken text, or excess canvas remains. |
| `test/goldens/baselines/foundation-dark-320-scale200.png` | 320 x 1800 | Dark contrast and 200% reflow are readable; narrow controls remain contained, the partial second account is the picker's intentional next-card peek, and no clipping or overflow is present. |

The first visual pass revealed stale light-theme body colors in the consecutive
dark pump because frozen tickers also froze `AnimatedTheme`. The harness was
corrected with a configuration key plus zero theme-animation duration, both
baselines were regenerated, ordinary comparisons rerun, and both final images
were reinspected.

## Verification

- `dart format --set-exit-if-changed test/support test/goldens/velora_foundation_golden_test.dart`
  - PASS; 3 files checked, 0 changed.
- `flutter analyze`
  - PASS; no issues found.
- `flutter test`
  - PASS; 338/338 tests.
- Focused update-goldens and ordinary golden commands
  - PASS; 2/2 tests each.

## Deviations and risks

- `phone390` and `phone320` deliberately retain narrow device widths but use
  extended gallery heights (1100 and 1800 respectively). This captures every
  required shared component in one portable PNG without scroll position,
  stitching, focus, caret, or animation nondeterminism.
- The exact repository-wide command
  `dart format --set-exit-if-changed lib test` was attempted with the current
  SDK and wanted to mechanically reformat 137 pre-existing files. Those
  unrelated formatting changes were reverted. The new Task 7 Dart files pass
  the formatter command scoped to their paths, and analyzer/full tests pass.
- Full-suite output retains the pre-existing Drift debug warning about multiple
  `AppDatabase` instances in a settings repository test; it does not fail the
  suite and Task 7 does not change database construction.
- Golden pixels remain renderer-sensitive by nature, but all fonts and icons
  used by this suite are bundled assets; there is no host-font dependency.
