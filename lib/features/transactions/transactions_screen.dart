import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ledger/ledger_entry.dart';
import '../../core/theme/velora_tokens.dart';
import '../../ui/components/velora_async_state.dart';
import '../../ui/components/velora_card.dart';
import 'transactions_controller.dart';

/// A transaction's type label as it appears in history (Velora design §6.6):
/// transfer legs are never shown as income or expense, and balance
/// adjustments are always visibly labeled.
String transactionTypeLabel(LedgerEntryType t) => switch (t) {
      LedgerEntryType.expense => 'Chiqim',
      LedgerEntryType.income => 'Kirim',
      LedgerEntryType.transferOut => 'O\'tkazma (chiqdi)',
      LedgerEntryType.transferIn => 'O\'tkazma (kirdi)',
      LedgerEntryType.adjustment => 'Balans tuzatish',
    };

IconData _typeIcon(LedgerEntryType t) => switch (t) {
      LedgerEntryType.expense => Icons.arrow_upward,
      LedgerEntryType.income => Icons.arrow_downward,
      LedgerEntryType.transferOut => Icons.call_made,
      LedgerEntryType.transferIn => Icons.call_received,
      LedgerEntryType.adjustment => Icons.tune,
    };

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(transactionsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tranzaksiyalar')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => VeloraErrorState(
          message: 'Xatolik yuz berdi',
          onRetry: () => ref.invalidate(transactionsControllerProvider),
        ),
        data: (items) => items.isEmpty
            ? const VeloraEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Hali tranzaksiya yo\'q',
                message: 'Chiqim yoki kirim qo\'shsangiz, shu yerda ko\'rinadi.',
              )
            : _GroupedTransactionsList(entries: items),
      ),
    );
  }
}

class _GroupedTransactionsList extends ConsumerWidget {
  const _GroupedTransactionsList({required this.entries});

  final List<LedgerEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = <DateTime, List<LedgerEntry>>{};
    for (final entry in entries) {
      final day = DateTime(
          entry.occurredAt.year, entry.occurredAt.month, entry.occurredAt.day);
      groups.putIfAbsent(day, () => []).add(entry);
    }
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.all(VeloraSpacing.lg),
      children: [
        for (final day in days) ...[
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: VeloraSpacing.sm),
            child: Text(
              _groupLabel(day),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          for (final entry in groups[day]!)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: VeloraSpacing.sm),
              child: _TransactionRow(entry: entry),
            ),
          const SizedBox(height: VeloraSpacing.sm),
        ],
      ],
    );
  }

  String _groupLabel(DateTime day) {
    final today = DateTime.now();
    final isToday = day.year == today.year &&
        day.month == today.month &&
        day.day == today.day;
    if (isToday) return 'Bugun';
    final yesterday = today.subtract(const Duration(days: 1));
    final isYesterday = day.year == yesterday.year &&
        day.month == yesterday.month &&
        day.day == yesterday.day;
    if (isYesterday) return 'Kecha';
    return '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }
}

class _TransactionRow extends ConsumerWidget {
  const _TransactionRow({required this.entry});

  final LedgerEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Dismissible(
      key: Key('txn_${entry.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(VeloraRadii.card),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: VeloraSpacing.lg),
        child: Icon(
          Icons.delete,
          color: theme.colorScheme.onErrorContainer,
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
      onDismissed: (_) =>
          ref.read(transactionsControllerProvider.notifier).delete(entry.id),
      child: VeloraCard(
        child: Row(
          children: [
            Icon(_typeIcon(entry.type), color: VeloraColors.plum),
            const SizedBox(width: VeloraSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transactionTypeLabel(entry.type),
                    style: theme.textTheme.titleSmall,
                  ),
                  if (entry.note != null && entry.note!.isNotEmpty)
                    Text(
                      entry.note!,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // `Flexible`, not a bare `Text`: at 320px/200% text scale the
            // formatted amount alone can exceed the space left after the
            // icon and the type/note column, overflowing the Row. Wrapping
            // lets it shrink/ellipsize instead (golden-revealed via the
            // existing-flow gallery's 320/dark/200% variant).
            Flexible(
              child: Text(
                entry.amount.format(),
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
