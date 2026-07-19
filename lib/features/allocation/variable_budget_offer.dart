import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/money.dart';
import '../../providers/app_providers.dart';
import '../budgets/budgets_controller.dart';

/// Design §4: allocating income to the `variableBudget` bucket, on confirm,
/// offers to set/update the current period's variable budget
/// (`settings.variableBudget`, the numerator of the daily safe limit) to the
/// same amount — so allocation and the daily limit stay consistent.
///
/// Called after a successful [AllocationController.confirm] on both confirm
/// paths (AllocateSheet's "Tasdiqlash" and `showAllocationChoice`'s 'apply'
/// branch). A no-op if the split didn't touch `variableBudget`, the amount
/// is zero/negative, or it already matches the stored value. Declining
/// ("Yo'q") leaves settings untouched — the split itself is already saved.
Future<void> maybeOfferVariableBudgetUpdate(
  BuildContext context,
  WidgetRef ref,
  Map<String, Money> perBucket,
) async {
  final amount = perBucket['variableBudget'];
  if (amount == null || amount.minorUnits <= 0) return;

  final settings = await ref.read(settingsProvider.future);
  if (settings.variableBudget == amount) return;
  if (!context.mounted) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('O\'zgaruvchan budjetni yangilash?'),
      content:
          Text('O\'zgaruvchan budjet ${amount.format()} ga o\'rnatilsinmi?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Yo\'q'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Ha'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await ref.read(budgetsControllerProvider).setVariableBudget(amount);
  }
}
