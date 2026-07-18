import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ledger/ledger_entry.dart';
import '../../core/money/money.dart';
import '../../providers/app_providers.dart';
import 'income_entry_controller.dart';

Future<void> showIncomeEntrySheet(BuildContext context, WidgetRef ref) async {
  final settings = await ref.read(settingsProvider.future);
  final currency = settings.primaryCurrency;
  final accounts = await ref.read(accountRepositoryProvider).list();
  if (accounts.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avval hisob yarating')));
    }
    return;
  }
  final amountCtrl = TextEditingController();
  var accountId = accounts.first.id;
  var incomeType = IncomeType.salary;
  var recurring = false;
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
            TextField(controller: amountCtrl, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Summa')),
            DropdownButton<IncomeType>(
              value: incomeType, isExpanded: true,
              onChanged: (v) => setState(() => incomeType = v ?? incomeType),
              items: const [
                DropdownMenuItem(value: IncomeType.salary, child: Text('Oylik maosh')),
                DropdownMenuItem(value: IncomeType.bonus, child: Text('Bonus')),
                DropdownMenuItem(value: IncomeType.freelance, child: Text('Freelance')),
                DropdownMenuItem(value: IncomeType.refund, child: Text('Qaytarilgan pul')),
                DropdownMenuItem(value: IncomeType.other, child: Text('Boshqa')),
              ],
            ),
            DropdownButton<int>(
              value: accountId, isExpanded: true,
              onChanged: (v) => setState(() => accountId = v ?? accountId),
              items: [for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name))],
            ),
            SwitchListTile(
              value: recurring,
              onChanged: (v) => setState(() => recurring = v),
              title: const Text('Takroriy kirim'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = Money.tryParse(amountCtrl.text, currency);
                if (amount == null || amount.minorUnits <= 0) return;
                await ref.read(incomeEntryControllerProvider.notifier).save(
                    accountId: accountId, amount: amount, incomeType: incomeType,
                    recurring: recurring);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Saqlash'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}
