import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/money.dart';
import '../../core/result/failure_messages.dart';
import '../../providers/app_providers.dart';
import 'accounts_controller.dart';

Future<void> showTransferSheet(BuildContext context, WidgetRef ref) async {
  final settings = await ref.read(settingsProvider.future);
  final currency = settings.primaryCurrency;
  final accounts = await ref.read(accountsControllerProvider.future);
  if (accounts.length < 2) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('O\'tkazma uchun kamida 2 ta hisob kerak')));
    }
    return;
  }
  final amountCtrl = TextEditingController();
  var fromId = accounts[0].account.id;
  var toId = accounts[1].account.id;
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: StatefulBuilder(
        builder: (ctx, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<int>(
              value: fromId, isExpanded: true,
              onChanged: (v) => setState(() => fromId = v ?? fromId),
              items: [for (final a in accounts) DropdownMenuItem(value: a.account.id, child: Text('Dan: ${a.account.name}'))],
            ),
            DropdownButton<int>(
              value: toId, isExpanded: true,
              onChanged: (v) => setState(() => toId = v ?? toId),
              items: [for (final a in accounts) DropdownMenuItem(value: a.account.id, child: Text('Ga: ${a.account.name}'))],
            ),
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Summa')),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final amount = Money.tryParse(amountCtrl.text, currency);
                if (amount == null) return;
                final r = await ref.read(accountsControllerProvider.notifier)
                    .transfer(fromId: fromId, toId: toId, amount: amount);
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                r.when(ok: (_) {}, err: (f) => ScaffoldMessenger.of(ctx)
                    .showSnackBar(SnackBar(content: Text(userMessage(f)))));
              },
              child: const Text('O\'tkazish'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}
