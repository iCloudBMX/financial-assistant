import 'package:flutter/material.dart' show DateTimeRange, immutable;

import '../ledger/ledger_entry.dart';

/// The active history filter. All fields are "widening by default": a null
/// [period], an empty [accountIds], or an empty [types] each mean "no
/// restriction on that axis". [periodLabel] is a display-only caption for the
/// Davr chip (e.g. 'Bu oy', 'O'tgan hafta', or a formatted range).
@immutable
class TransactionFilter {
  final DateTimeRange? period;
  final String? periodLabel;
  final Set<int> accountIds;
  final Set<LedgerEntryType> types;

  const TransactionFilter({
    this.period,
    this.periodLabel,
    this.accountIds = const {},
    this.types = const {},
  });

  TransactionFilter copyWith({
    DateTimeRange? period,
    String? periodLabel,
    Set<int>? accountIds,
    Set<LedgerEntryType>? types,
    bool clearPeriod = false,
  }) =>
      TransactionFilter(
        period: clearPeriod ? null : (period ?? this.period),
        periodLabel: clearPeriod ? null : (periodLabel ?? this.periodLabel),
        accountIds: accountIds ?? this.accountIds,
        types: types ?? this.types,
      );

  @override
  bool operator ==(Object other) =>
      other is TransactionFilter &&
      other.period?.start == period?.start &&
      other.period?.end == period?.end &&
      other.periodLabel == periodLabel &&
      _setEq(other.accountIds, accountIds) &&
      _setEq(other.types, types);

  @override
  int get hashCode => Object.hash(
        period?.start,
        period?.end,
        periodLabel,
        Object.hashAllUnordered(accountIds),
        Object.hashAllUnordered(types),
      );

  static bool _setEq<T>(Set<T> a, Set<T> b) =>
      a.length == b.length && a.containsAll(b);
}

/// Applies [filter] to [entries]. Period bounds are inclusive to whole-day
/// granularity on both ends. Adjustments always survive the type filter.
List<LedgerEntry> applyTransactionFilter(
  List<LedgerEntry> entries,
  TransactionFilter filter,
) {
  final period = filter.period;
  DateTime? start, end;
  if (period != null) {
    start = DateTime(period.start.year, period.start.month, period.start.day);
    end = DateTime(period.end.year, period.end.month, period.end.day);
  }
  return entries.where((e) {
    if (start != null && end != null) {
      final d = DateTime(
          e.occurredAt.year, e.occurredAt.month, e.occurredAt.day);
      if (d.isBefore(start) || d.isAfter(end)) return false;
    }
    if (filter.accountIds.isNotEmpty &&
        !filter.accountIds.contains(e.accountId)) {
      return false;
    }
    if (filter.types.isNotEmpty &&
        e.type != LedgerEntryType.adjustment &&
        !filter.types.contains(e.type)) {
      return false;
    }
    return true;
  }).toList();
}

/// The default filter: the whole current month, labelled 'Bu oy'.
TransactionFilter currentMonthFilter(DateTime now) {
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 0); // last day of month
  return TransactionFilter(
    period: DateTimeRange(start: start, end: end),
    periodLabel: 'Bu oy',
  );
}
