import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/velora_tokens.dart';
import '../../ui/components/velora_async_state.dart';
import 'account_edit_sheet.dart';
import 'account_labels.dart';
import 'accounts_controller.dart';
import 'balance_adjust_sheet.dart';
import 'transfer_sheet.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(accountsControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hisoblar'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          color: VeloraColors.plum,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: VeloraSpacing.sm),
            child: _HeaderIconButton(
              key: const Key('accounts-transfer-action'),
              icon: Icons.swap_horiz,
              tooltip: 'O\'tkazma',
              onPressed: () => showTransferSheet(context, ref),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: VeloraColors.coral,
        foregroundColor: Colors.white,
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
                // Bottom padding clears the add-account FAB.
                padding: const EdgeInsets.fromLTRB(
                  VeloraSpacing.lg,
                  VeloraSpacing.md,
                  VeloraSpacing.lg,
                  88,
                ),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: VeloraSpacing.md),
                itemBuilder: (context, index) {
                  final it = items[index];
                  return _AccountCard(
                    key: Key('account_${it.account.id}'),
                    item: it,
                    onTap: () =>
                        showBalanceAdjustSheet(context, ref, it.account.id),
                    onArchive: () => ref
                        .read(accountsControllerProvider.notifier)
                        .archive(it.account.id),
                  );
                },
              ),
      ),
    );
  }
}

/// A single account tile in the Velora Human style: a soft plum-tinted icon
/// tile, the account name with its type + currency beneath, the derived
/// available balance as the scannable figure, and an archive affordance.
class _AccountCard extends StatelessWidget {
  const _AccountCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onArchive,
  });

  final AccountWithBalance item;
  final VoidCallback onTap;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final account = item.account;
    final borderRadius = BorderRadius.circular(VeloraRadii.card);
    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: const BorderSide(color: VeloraColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            VeloraSpacing.lg,
            VeloraSpacing.md,
            VeloraSpacing.sm,
            VeloraSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: VeloraColors.plumTint,
                  borderRadius: BorderRadius.circular(VeloraRadii.control),
                ),
                child: Icon(
                  accountTypeIcon(account.type, icon: account.icon),
                  color: VeloraColors.plum,
                ),
              ),
              const SizedBox(width: VeloraSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${accountTypeLabel(account.type)} · ${account.currency.code}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: VeloraColors.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: VeloraSpacing.sm),
              // `Expanded`, not `Flexible`: both share the row's free space
              // 50/50 with the name column, but a loose `Flexible` only
              // consumes its content width — leaving the unused half as a
              // trailing gap that floats the balance and archive button to a
              // different x on every row (balances of different widths never
              // line up). `Expanded` fills the half, so `textAlign.end`
              // right-aligns every balance to the same column and pins the
              // archive button to the edge, while `ellipsis` still guards
              // overflow at 320px/200% text scale.
              Expanded(
                child: Text(
                  item.balance.format(),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                key: Key('account-archive-${account.id}'),
                tooltip: 'Arxivlash',
                icon: const Icon(Icons.archive_outlined,
                    color: VeloraColors.muted),
                onPressed: onArchive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A rounded, hairline-bordered header action button matching the mockup's
/// icon chips.
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VeloraRadii.control),
        side: const BorderSide(color: VeloraColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: Icon(icon, size: 20, color: VeloraColors.plum),
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      ),
    );
  }
}
