import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ledger/ledger_entry.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../core/transactions/transaction_filter.dart';
import '../../core/transactions/transaction_row_content.dart';
import '../../data/categories/category_model.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/velora_async_state.dart';
import '../accounts/accounts_controller.dart';
import 'transaction_filter_sheets.dart';
import 'transactions_controller.dart';
import 'transactions_filter_provider.dart';

IconData _typeIcon(LedgerEntryType t) => switch (t) {
      LedgerEntryType.expense => Icons.arrow_upward,
      LedgerEntryType.income => Icons.arrow_downward,
      LedgerEntryType.transferOut => Icons.call_made,
      LedgerEntryType.transferIn => Icons.call_received,
      LedgerEntryType.adjustment => Icons.tune,
    };

/// The soft tile fill + glyph colour for a row's leading icon. Income leans on
/// the success tint (money in), everything else on the calm plum tint so
/// transfers and adjustments never borrow the income/expense palette.
({Color bg, Color fg}) _iconTones(LedgerEntryType t) => switch (t) {
      LedgerEntryType.income => (
          bg: const Color(0x1F2E9D7C),
          fg: VeloraColors.success,
        ),
      _ => (bg: VeloraColors.plumTint, fg: VeloraColors.plum),
    };

/// The amount colour: income green, expense inkberry, transfers/adjustments
/// neutral so a moved balance never reads as spending or earning (§6.6).
Color _amountColor(LedgerEntryType t) => switch (t) {
      LedgerEntryType.income => VeloraColors.success,
      LedgerEntryType.expense => VeloraColors.inkberry,
      _ => VeloraColors.muted,
    };

/// Signed, currency-formatted amount with an explicit `+` on income.
String _amountText(LedgerEntry e) {
  final formatted = e.amount.format();
  if (e.type == LedgerEntryType.income && !e.amount.isNegative) {
    return '+$formatted';
  }
  return formatted;
}

String _timeLabel(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// The signed income+expense net for a set of entries. Transfers and balance
/// adjustments are excluded so they never distort a day's spend/earn figure.
Money _incomeExpenseNet(Iterable<LedgerEntry> entries) {
  if (entries.isEmpty) return const Money(0, CurrencyRegistry.uzs);
  var minor = 0;
  Money? sample;
  for (final e in entries) {
    if (e.type == LedgerEntryType.income ||
        e.type == LedgerEntryType.expense) {
      minor += e.amount.minorUnits;
      sample ??= e.amount;
    }
  }
  final currency = sample?.currency ?? entries.first.amount.currency;
  return Money(minor, currency);
}

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(transactionsControllerProvider);
    final filter = ref.watch(transactionFilterProvider);
    final nameById = <int, String>{
      for (final a in ref.watch(accountsControllerProvider).asData?.value ??
          const <AccountWithBalance>[])
        a.account.id: a.account.name,
    };
    final categoryById = <int, String>{
      for (final c in ref.watch(categoriesProvider).asData?.value ??
          const <Category>[])
        c.id: c.name,
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tranzaksiyalar'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          color: VeloraColors.plum,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => VeloraErrorState(
          message: 'Xatolik yuz berdi',
          onRetry: () => ref.invalidate(transactionsControllerProvider),
        ),
        data: (all) {
          // A totally empty ledger keeps the original first-transaction nudge
          // (no chips, no summary) — there is nothing to filter yet. Only once
          // entries exist do the filter chips + summary cards appear, and an
          // over-narrow filter shows the "widen your filter" message instead.
          if (all.isEmpty) {
            return const VeloraEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Hali tranzaksiya yo\'q',
              message: 'Chiqim yoki kirim qo\'shsangiz, shu yerda ko\'rinadi.',
            );
          }
          final items = applyTransactionFilter(all, filter);
          return Column(
            children: [
              _FilterChipsRow(filter: filter),
              Expanded(
                child: _TransactionsBody(
                  entries: items,
                  nameById: nameById,
                  categoryById: categoryById,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The scrollable body: two summary cards, then the day-grouped list. When the
/// filter empties the list the summary cards still render (as zero) so the user
/// keeps context while widening the filter.
class _TransactionsBody extends StatelessWidget {
  const _TransactionsBody({
    required this.entries,
    required this.nameById,
    required this.categoryById,
  });

  final List<LedgerEntry> entries;
  final Map<int, String> nameById;
  final Map<int, String> categoryById;

  @override
  Widget build(BuildContext context) {
    final groups = <DateTime, List<LedgerEntry>>{};
    for (final entry in entries) {
      final day = DateTime(
          entry.occurredAt.year, entry.occurredAt.month, entry.occurredAt.day);
      groups.putIfAbsent(day, () => []).add(entry);
    }
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      // Bottom padding clears the global floating "Chiqim" FAB.
      padding: const EdgeInsets.fromLTRB(
        VeloraSpacing.lg,
        VeloraSpacing.sm,
        VeloraSpacing.lg,
        88,
      ),
      children: [
        _SummaryCards(entries: entries),
        const SizedBox(height: VeloraSpacing.lg),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: VeloraSpacing.xl),
            child: VeloraEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Tranzaksiya topilmadi',
              message: 'Tanlangan filtrga mos yozuv yo\'q. Filtrni kengaytiring.',
            ),
          )
        else
          for (final day in days) ...[
            _DayHeader(
              label: _groupLabel(day),
              net: _incomeExpenseNet(groups[day]!),
            ),
            const SizedBox(height: VeloraSpacing.sm),
            for (final entry in groups[day]!) ...[
              _TransactionCard(
                entry: entry,
                accountName: nameById[entry.accountId],
                categoryName: entry.categoryId == null
                    ? null
                    : categoryById[entry.categoryId],
              ),
              const SizedBox(height: VeloraSpacing.sm),
            ],
            const SizedBox(height: VeloraSpacing.md),
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

/// Two equal-width cards: total income (left) and total expense (right) over
/// the filtered set.
class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.entries});

  final List<LedgerEntry> entries;

  @override
  Widget build(BuildContext context) {
    final currency = entries.isNotEmpty
        ? entries.first.amount.currency
        : CurrencyRegistry.uzs;
    var incomeMinor = 0;
    var expenseMinor = 0;
    for (final e in entries) {
      if (e.type == LedgerEntryType.income) incomeMinor += e.amount.minorUnits;
      if (e.type == LedgerEntryType.expense) {
        expenseMinor += e.amount.minorUnits;
      }
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _SummaryCard(
              cardKey: const Key('transactions-summary-income'),
              label: 'Kirim',
              value: '+${Money(incomeMinor, currency).formatNumber()}',
              color: VeloraColors.success,
              icon: Icons.arrow_downward,
            ),
          ),
          const SizedBox(width: VeloraSpacing.md),
          Expanded(
            child: _SummaryCard(
              cardKey: const Key('transactions-summary-expense'),
              label: 'Chiqim',
              value: Money(expenseMinor, currency).formatNumber(),
              color: VeloraColors.inkberry,
              icon: Icons.arrow_upward,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.cardKey,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final Key cardKey;
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: cardKey,
      padding: const EdgeInsets.all(VeloraSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(VeloraRadii.card),
        border: Border.all(color: VeloraColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(VeloraRadii.control),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: VeloraSpacing.sm),
              // `Expanded`, not a bare `Text`: at 320px width and 200% text
              // scale the label alone can exceed the space left after the
              // icon tile inside a two-column card, overflowing the Row.
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: VeloraColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: VeloraSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A day divider: the human label ("Bugun") + "Sarflangan" on the left, that
/// day's signed income+expense net on the right.
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label, required this.net});

  final String label;
  final Money net;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: VeloraSpacing.xs,
        end: VeloraSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: VeloraColors.inkberry,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Sarflangan',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: VeloraColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: VeloraSpacing.sm),
          Text(
            net.formatNumber(),
            style: theme.textTheme.labelLarge?.copyWith(
                color: VeloraColors.muted, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// One transaction as its own rounded card (Click-style): leading icon, a
/// title/subtitle column, and a right column with the amount over the time.
class _TransactionCard extends ConsumerWidget {
  const _TransactionCard({
    required this.entry,
    this.accountName,
    this.categoryName,
  });

  final LedgerEntry entry;
  final String? accountName;
  final String? categoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tones = _iconTones(entry.type);
    final content = resolveRowContent(
      entry,
      accountName: accountName,
      categoryName: categoryName,
    );

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
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
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
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(VeloraRadii.card),
          border: Border.all(color: VeloraColors.line),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: VeloraSpacing.md,
          vertical: VeloraSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tones.bg,
                borderRadius: BorderRadius.circular(VeloraRadii.control),
              ),
              child: Icon(_typeIcon(entry.type), size: 22, color: tones.fg),
            ),
            const SizedBox(width: VeloraSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (content.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      content.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: VeloraColors.muted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: VeloraSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    _amountText(entry),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: _amountColor(entry.type),
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _timeLabel(entry.occurredAt),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: VeloraColors.muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The three history filters as tappable chips. A chip is filled and shows its
/// selection when that axis is narrowed; otherwise it shows the bare axis name.
class _FilterChipsRow extends ConsumerWidget {
  const _FilterChipsRow({required this.filter});

  final TransactionFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountLabel = filter.accountIds.isEmpty
        ? 'Kartalar'
        : 'Kartalar · ${filter.accountIds.length} ta';
    final typeLabel = _typeChipLabel(filter.types);
    final periodLabel =
        filter.period == null ? 'Davr' : 'Davr · ${filter.periodLabel ?? ''}';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
          VeloraSpacing.lg, VeloraSpacing.sm, VeloraSpacing.lg, VeloraSpacing.sm),
      child: Row(
        children: [
          _FilterChip(
            chipKey: const Key('filter-chip-account'),
            label: accountLabel,
            active: filter.accountIds.isNotEmpty,
            onTap: () => showAccountFilterSheet(context, ref),
          ),
          const SizedBox(width: VeloraSpacing.sm),
          _FilterChip(
            chipKey: const Key('filter-chip-type'),
            label: typeLabel,
            active: filter.types.isNotEmpty,
            onTap: () => showTypeFilterSheet(context, ref),
          ),
          const SizedBox(width: VeloraSpacing.sm),
          _FilterChip(
            chipKey: const Key('filter-chip-period'),
            label: periodLabel,
            active: filter.period != null,
            onTap: () => showPeriodFilterSheet(context, ref),
          ),
        ],
      ),
    );
  }

  String _typeChipLabel(Set<LedgerEntryType> types) {
    if (types.isEmpty) return 'Operatsiya turi';
    final parts = <String>[
      if (types.contains(LedgerEntryType.income)) 'Kirim',
      if (types.contains(LedgerEntryType.expense)) 'Chiqim',
      if (types.contains(LedgerEntryType.transferOut) ||
          types.contains(LedgerEntryType.transferIn))
        "O'tkazma",
    ];
    return 'Turi · ${parts.join(', ')}';
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.chipKey,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final Key chipKey;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: chipKey,
      color: active ? VeloraColors.plum : theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(VeloraRadii.control),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VeloraRadii.control),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: VeloraSpacing.md, vertical: VeloraSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(VeloraRadii.control),
            border: Border.all(
                color: active ? VeloraColors.plum : VeloraColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: active ? Colors.white : VeloraColors.inkberry,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: VeloraSpacing.xs),
              Icon(Icons.keyboard_arrow_down,
                  size: 18,
                  color: active ? Colors.white : VeloraColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
