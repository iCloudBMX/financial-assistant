import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/money.dart';
import '../../providers/app_providers.dart';
import 'accounts_controller.dart';

Future<void> showBalanceAdjustSheet(
    BuildContext context, WidgetRef ref, int accountId) async {
  final settings = await ref.read(settingsProvider.future);
  final currency = settings.primaryCurrency;
  final realCtrl = TextEditingController();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Haqiqiy balansni kiriting'),
          TextField(controller: realCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Balans')),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              final real = Money.tryParse(realCtrl.text, currency);
              if (real == null) return;
              await ref.read(accountsControllerProvider.notifier)
                  .adjust(accountId: accountId, realBalance: real);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Tuzatish'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}
