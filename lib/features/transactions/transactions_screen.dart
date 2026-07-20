import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ledger/ledger_entry.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../ui/components/velora_async_state.dart';
import '../accounts/accounts_controller.dart';
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

/// The soft tile fill + glyph colour for a row's leading icon. Income leans on
/// the success tint (money in), everything else on the calm plum tint so
/// transfers and adjustments never borrow the income/expense palette.
({Color bg, Color fg}) _iconTones(LedgerEntryType t) => switch (t) {
      LedgerEntryType.income => (
          bg: const Color(0x1F2E9D7C), // success @ ~12%
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

/// Signed, currency-formatted amount with an explicit `+` on income so a
/// positive balance change reads clearly next to a `-` expense.
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
/// adjustments are deliberately excluded so they never distort a day's or the
/// month's spend/earn figure.
Money _incomeExpenseNet(Iterable<LedgerEntry> entries) {
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
    // Resolve account names for the row subtitles. A best-effort read: if the
    // accounts list has not loaded, rows simply omit the account name rather
    // than block the history list.
    final nameById = <int, String>{
      for (final a in ref.watch(accountsControllerProvider).asData?.value ??
          const <AccountWithBalance>[])
        a.account.id: a.account.name,
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
        data: (items) => items.isEmpty
            ? const VeloraEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Hali tranzaksiya yo\'q',
                message: 'Chiqim yoki kirim qo\'shsangiz, shu yerda ko\'rinadi.',
              )
            : _GroupedTransactionsList(entries: items, nameById: nameById),
      ),
    );
  }
}

class _GroupedTransactionsList extends ConsumerWidget {
  const _GroupedTransactionsList({
    required this.entries,
    required this.nameById,
  });

  final List<LedgerEntry> entries;
  final Map<int, String> nameById;

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
      // Bottom padding clears the global floating "Chiqim" FAB so the last
      // row is never trapped beneath it.
      padding: const EdgeInsets.fromLTRB(
        VeloraSpacing.lg,
        VeloraSpacing.sm,
        VeloraSpacing.lg,
        88,
      ),
      children: [
        _MonthSummaryHero(net: _incomeExpenseNet(entries), entries: entries),
        const SizedBox(height: VeloraSpacing.lg),
        for (final day in days) ...[
          _DayHeader(
            label: _groupLabel(day),
            net: _incomeExpenseNet(groups[day]!),
          ),
          _DayCard(entries: groups[day]!, nameById: nameById),
          const SizedBox(height: VeloraSpacing.lg),
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

/// The month net hero: the one dominant, filled plum card on the history
/// screen, mirroring the mockup's summary block — a signed net over the
/// visible entries with Kirim / Chiqim minis beneath it.
class _MonthSummaryHero extends StatelessWidget {
  const _MonthSummaryHero({required this.net, required this.entries});

  final Money net;
  final List<LedgerEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const onPlum = Colors.white;
    final currency = net.currency;
    var incomeMinor = 0;
    var expenseMinor = 0;
    for (final e in entries) {
      if (e.type == LedgerEntryType.income) incomeMinor += e.amount.minorUnits;
      if (e.type == LedgerEntryType.expense) {
        expenseMinor += e.amount.minorUnits;
      }
    }
    return Container(
      key: const Key('transactions-summary-hero'),
      padding: const EdgeInsets.all(VeloraSpacing.lg),
      decoration: BoxDecoration(
        color: VeloraColors.plum,
        borderRadius: BorderRadius.circular(VeloraRadii.card),
        boxShadow: const [
          BoxShadow(
            color: Color(0x335B3A6E),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BU OY · BARCHA HISOBLAR',
            style: theme.textTheme.labelSmall?.copyWith(
              color: onPlum.withValues(alpha: 0.68),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: VeloraSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              net.format(),
              maxLines: 1,
              softWrap: false,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: onPlum,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: VeloraSpacing.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _HeroStat(
                    label: 'Kirimlar',
                    value: '+${Money(incomeMinor, currency).formatNumber()}',
                  ),
                ),
                const SizedBox(width: VeloraSpacing.sm),
                Expanded(
                  child: _HeroStat(
                    label: 'Chiqimlar',
                    value: Money(expenseMinor, currency).formatNumber(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const onPlum = Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VeloraSpacing.md,
        vertical: VeloraSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: onPlum.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(VeloraRadii.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: onPlum.withValues(alpha: 0.70)),
          ),
          const SizedBox(height: VeloraSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: onPlum, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// A day divider: the human label ("Bugun") on the left, that day's signed
/// income+expense net on the right.
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
        bottom: VeloraSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: VeloraColors.muted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(width: VeloraSpacing.sm),
          Text(
            net.formatNumber(),
            style: theme.textTheme.labelLarge
                ?.copyWith(color: VeloraColors.muted, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// One day's entries grouped inside a single rounded card, separated by
/// hairlines — the scannable, statement-style grouping from the mockup.
class _DayCard extends ConsumerWidget {
  const _DayCard({required this.entries, required this.nameById});

  final List<LedgerEntry> entries;
  final Map<int, String> nameById;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(VeloraRadii.card),
        border: Border.all(color: VeloraColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: VeloraSpacing.lg,
                endIndent: VeloraSpacing.lg,
                color: VeloraColors.line,
              ),
            _TransactionRow(
              entry: entries[i],
              accountName: nameById[entries[i].accountId],
            ),
          ],
        ],
      ),
    );
  }
}

class _TransactionRow extends ConsumerWidget {
  const _TransactionRow({required this.entry, this.accountName});

  final LedgerEntry entry;
  final String? accountName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tones = _iconTones(entry.type);
    // The row subtitle stitches together the account (when known), the note,
    // and the time — dropping any part that is missing so it never shows a
    // dangling separator.
    final parts = <String>[
      if (accountName != null && accountName!.isNotEmpty) accountName!,
      if (entry.note != null && entry.note!.isNotEmpty) entry.note!,
      _timeLabel(entry.occurredAt),
    ];
    final subtitle = parts.join(' · ');

    return Dismissible(
      key: Key('txn_${entry.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.errorContainer,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: VeloraSpacing.lg,
          vertical: VeloraSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tones.bg,
                borderRadius: BorderRadius.circular(VeloraRadii.control),
              ),
              child: Icon(_typeIcon(entry.type), size: 20, color: tones.fg),
            ),
            const SizedBox(width: VeloraSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transactionTypeLabel(entry.type),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: VeloraColors.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: VeloraSpacing.sm),
            // `Flexible`, not a bare `Text`: at 320px/200% text scale the
            // formatted amount alone can exceed the space left after the
            // icon and the type/subtitle column, overflowing the Row.
            // Wrapping lets it shrink/ellipsize instead.
            Flexible(
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
          ],
        ),
      ),
    );
  }
}
