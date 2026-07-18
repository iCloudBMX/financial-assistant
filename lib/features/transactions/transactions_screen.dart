import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ledger/ledger_entry.dart';
import 'transactions_controller.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  String _label(LedgerEntryType t) => switch (t) {
        LedgerEntryType.expense => 'Chiqim',
        LedgerEntryType.income => 'Kirim',
        LedgerEntryType.transferOut => 'O\'tkazma (chiqdi)',
        LedgerEntryType.transferIn => 'O\'tkazma (kirdi)',
        LedgerEntryType.adjustment => 'Balans tuzatish',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(transactionsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tranzaksiyalar')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Xatolik yuz berdi')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('Hali tranzaksiya yo\'q'))
            : ListView(
                children: [
                  for (final e in items)
                    Dismissible(
                      key: Key('txn_${e.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Theme.of(context).colorScheme.errorContainer,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Icon(
                          Icons.delete,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                      confirmDismiss: (_) => showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Tranzaksiyani o\'chirish'),
                          content: const Text(
                              'Bu tranzaksiyani o\'chirmoqchimisiz? Bu amalni ortga qaytarib bo\'lmaydi.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Bekor qilish'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('O\'chirish'),
                            ),
                          ],
                        ),
                      ).then((confirmed) => confirmed ?? false),
                      onDismissed: (_) => ref
                          .read(transactionsControllerProvider.notifier)
                          .delete(e.id),
                      child: ListTile(
                        title: Text(_label(e.type)),
                        subtitle: Text(e.note ?? ''),
                        trailing: Text(e.amount.format()),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
