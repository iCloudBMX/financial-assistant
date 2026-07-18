import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ledger/account.dart';
import '../../core/money/money.dart';
import '../../providers/app_providers.dart';
import 'accounts_controller.dart';

Future<void> showAccountEditSheet(BuildContext context, WidgetRef ref) async {
  final settings = await ref.read(settingsProvider.future);
  final currency = settings.primaryCurrency;
  final nameCtrl = TextEditingController();
  final balanceCtrl = TextEditingController();
  var type = AccountType.cash;
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16, right: 16, top: 16),
      child: StatefulBuilder(
        builder: (ctx, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nomi')),
            TextField(
                controller: balanceCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Boshlang\'ich balans')),
            DropdownButton<AccountType>(
              value: type,
              isExpanded: true,
              onChanged: (v) => setState(() => type = v ?? type),
              items: const [
                DropdownMenuItem(value: AccountType.cash, child: Text('Naqd pul')),
                DropdownMenuItem(value: AccountType.bankCard, child: Text('Bank kartasi')),
                DropdownMenuItem(value: AccountType.savings, child: Text('Jamg\'arma')),
                DropdownMenuItem(value: AccountType.other, child: Text('Boshqa')),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final opening = Money.tryParse(balanceCtrl.text, currency) ??
                    Money.zero(currency);
                await ref.read(accountsControllerProvider.notifier).createAccount(
                    name: nameCtrl.text.trim().isEmpty ? 'Hisob' : nameCtrl.text.trim(),
                    type: type,
                    openingBalance: opening,
                    icon: 'wallet');
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
