import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/money.dart';
import '../../core/result/failure_messages.dart';
import 'allocate_sheet.dart';
import 'allocation_controller.dart';
import 'variable_budget_offer.dart';

/// §7.2: after an income is saved, offer allocate-now / later / apply-template.
Future<void> showAllocationChoice(
  BuildContext context,
  WidgetRef ref, {
  required int incomeId,
  required Money amount,
}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Hozir taqsimlash'),
            onTap: () => Navigator.pop(context, 'now'),
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add_check),
            title: const Text('Rejani qo‘llash'),
            subtitle:
                const Text('Andozadagi taqsimotni to‘g‘ridan-to‘g‘ri qo‘llash'),
            onTap: () => Navigator.pop(context, 'apply'),
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Keyinroq'),
            onTap: () => Navigator.pop(context, 'later'),
          ),
        ],
      ),
    ),
  );

  if (choice == 'now' && context.mounted) {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AllocateSheet(incomeId: incomeId, income: amount),
    );
  } else if (choice == 'apply') {
    final preview =
        await ref.read(allocationControllerProvider).preview(amount);
    final confirmResult = await ref
        .read(allocationControllerProvider)
        .confirm(incomeId, preview.perBucket);
    if (!context.mounted) return;
    if (!confirmResult.isOk) {
      confirmResult.when(
        ok: (_) {},
        err: (f) => ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userMessageFor(f)))),
      );
      return;
    }
    await maybeOfferVariableBudgetUpdate(context, ref, preview.perBucket);
  }
  // 'later' / dismissed: leave the income undistributed.
}
