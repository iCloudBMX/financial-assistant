import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/transactions/transaction_filter.dart';

/// The active history filter. Session-only (not persisted). Defaults to the
/// current month so history opens on the same scope the old "BU OY" hero used.
final transactionFilterProvider = StateProvider<TransactionFilter>(
  (ref) => currentMonthFilter(DateTime.now()),
);
