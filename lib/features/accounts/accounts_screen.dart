import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'accounts_controller.dart';
import 'account_edit_sheet.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(accountsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Hisoblar')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAccountEditSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Xatolik: $e')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('Hali hisob yo\'q'))
            : ListView(
                children: [
                  for (final it in items)
                    ListTile(
                      key: Key('account_${it.account.id}'),
                      leading: const Icon(Icons.account_balance_wallet_outlined),
                      title: Text(it.account.name),
                      trailing: Text(it.balance.format()),
                      onLongPress: () =>
                          ref.read(accountsControllerProvider.notifier)
                              .archive(it.account.id),
                    ),
                ],
              ),
      ),
    );
  }
}
