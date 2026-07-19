import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/velora_tokens.dart';
import '../../ui/components/velora_async_state.dart';
import '../../ui/components/velora_card.dart';
import 'account_edit_sheet.dart';
import 'account_labels.dart';
import 'accounts_controller.dart';
import 'balance_adjust_sheet.dart';
import 'transfer_sheet.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(accountsControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hisoblar'),
        actions: [
          IconButton(
            key: const Key('accounts-transfer-action'),
            tooltip: 'O\'tkazma',
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => showTransferSheet(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAccountEditSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => VeloraErrorState(
          message: 'Xatolik yuz berdi',
          onRetry: () => ref.invalidate(accountsControllerProvider),
        ),
        data: (items) => items.isEmpty
            ? VeloraEmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Hali hisob yo\'q',
                message: 'Chiqim va kirimlarni yozish uchun hisob yarating.',
                action: FilledButton(
                  onPressed: () => showAccountEditSheet(context, ref),
                  child: const Text('Hisob yaratish'),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(VeloraSpacing.lg),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: VeloraSpacing.md),
                itemBuilder: (context, index) {
                  final it = items[index];
                  return VeloraCard(
                    key: Key('account_${it.account.id}'),
                    onTap: () =>
                        showBalanceAdjustSheet(context, ref, it.account.id),
                    child: Row(
                      children: [
                        Icon(
                          accountTypeIcon(it.account.type,
                              icon: it.account.icon),
                          color: VeloraColors.plum,
                        ),
                        const SizedBox(width: VeloraSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                it.account.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                accountTypeLabel(it.account.type),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        // `Flexible`, not a bare `Text`: at 320px/200% text
                        // scale the formatted balance alone can exceed the
                        // space left after the icon, name/type column, and
                        // archive button, overflowing the Row. Wrapping lets
                        // it shrink/ellipsize instead (golden-revealed via
                        // the existing-flow gallery's 320/dark/200% variant).
                        Flexible(
                          child: Text(
                            it.balance.format(),
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          key: Key('account-archive-${it.account.id}'),
                          tooltip: 'Arxivlash',
                          icon: const Icon(Icons.archive_outlined),
                          onPressed: () => ref
                              .read(accountsControllerProvider.notifier)
                              .archive(it.account.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
