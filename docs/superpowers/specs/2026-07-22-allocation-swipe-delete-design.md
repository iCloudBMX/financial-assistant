# Swipe-to-delete for allocation rules

## Problem

On the Taqsimlash rejasi (allocation plan) screen, each rule row carries a red ⊖
`IconButton` that deletes the rule immediately with no confirmation. On mobile a
swipe gesture is a more natural, less cramped delete affordance.

## Decision

Replace the per-row ⊖ button with swipe-to-delete. Deletion is immediate but
reversible via an Undo snackbar.

- **Affordance:** swipe replaces the button entirely — the ⊖ `IconButton` is
  removed. Delete is available only by swiping a row left.
- **Confirmation:** none up front. The row deletes on swipe and an Undo snackbar
  ("Bekor qilish") appears to restore it.

## Scope

Single production file: `lib/features/allocation/allocation_plan_screen.dart`.
Plus tests in `test/features/allocation/allocation_plan_screen_test.dart`.

The source-card picker at the top (its own horizontal page-swipe) is untouched.

## Design

Each rule row is currently a `VeloraCard` (tap = edit) with a trailing ⊖
`IconButton` (tap = delete). Change:

1. Remove the `IconButton` keyed `plan-delete-rule-$i`.
2. Wrap the row's `VeloraCard` in a `Dismissible`:
   - `key: ValueKey(i)` — the row index. Safe here: deletion rebuilds the whole
     list from the provider and there is no drag-reorder. (`AllocationRule` has
     no unique id, and `sortOrder` can collide after a delete-then-add because
     `_addRule` assigns `sortOrder = rules.length`.)
   - `direction: DismissDirection.endToStart` (swipe left).
   - `background`: red (`VeloraColors.critical`) panel with a right-aligned white
     `Icons.delete_outline`, visible as the row slides.
   - `onDismissed`: capture the current `plan.rules`, call the existing
     `_deleteRule(i)`, then show an Undo snackbar. Undo re-saves the captured
     list via `saveRules`.
3. The row tap (`_editRule`) is unchanged.

## Undo behaviour

- Snackbar text: "Qator o'chirildi", action label: "Bekor qilish".
- On Undo: `saveRules(<captured rules>)` restores the exact prior list
  (including original `sortOrder` values).
- If the user does not tap Undo, the snackbar auto-dismisses and the deletion
  stands (already persisted by `_deleteRule`).

## Tests

- **Swipe deletes:** render a plan with rules, fling a row `endToStart`,
  `pumpAndSettle`, assert the row is gone and `saveRules` persisted the shorter
  list.
- **Undo restores:** after the swipe, tap "Bekor qilish", assert the rule is
  back and the restore was persisted.

## Out of scope

- Confirmation dialog.
- Keeping the ⊖ button alongside swipe.
- Drag-reorder of rules.
- Changes to the source-card picker.
