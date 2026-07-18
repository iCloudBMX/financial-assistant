import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ledger/ledger_entry.dart';
import '../../core/money/money.dart';
import '../../providers/app_providers.dart';

/// Recent-first distinct category ids, back-filled by most-used, capped.
List<int> quickPickCategoryIds(List<LedgerEntry> expenses, {int limit = 6}) {
  final recent = <int>[];
  final counts = <int, int>{};
  for (final e in expenses.reversed) {
    final id = e.categoryId;
    if (id == null) continue;
    counts[id] = (counts[id] ?? 0) + 1;
    if (!recent.contains(id)) recent.add(id);
  }
  final byUse = counts.keys.toList()
    ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  final ordered = <int>[...recent];
  for (final id in byUse) {
    if (!ordered.contains(id)) ordered.add(id);
  }
  return ordered.take(limit).toList();
}

class ExpenseEntryState {
  final int? defaultAccountId;
  final List<int> quickPickCategoryIds;
  final int? lastSavedEntryId;
  const ExpenseEntryState({
    this.defaultAccountId,
    this.quickPickCategoryIds = const [],
    this.lastSavedEntryId,
  });
  ExpenseEntryState copyWith({int? defaultAccountId, List<int>? quickPickCategoryIds, int? lastSavedEntryId}) =>
      ExpenseEntryState(
        defaultAccountId: defaultAccountId ?? this.defaultAccountId,
        quickPickCategoryIds: quickPickCategoryIds ?? this.quickPickCategoryIds,
        lastSavedEntryId: lastSavedEntryId ?? this.lastSavedEntryId,
      );
}

class ExpenseEntryController extends AsyncNotifier<ExpenseEntryState> {
  @override
  Future<ExpenseEntryState> build() async {
    ref.watch(ledgerRevisionProvider);
    final entries = await ref.watch(ledgerRepositoryProvider).allEntries();
    final accounts = await ref.watch(accountRepositoryProvider).list();
    final expenses =
        entries.where((e) => e.type == LedgerEntryType.expense).toList();
    // last-used account = the account of the most recent entry (PRD §9.1)
    int? lastAccount;
    if (entries.isNotEmpty) {
      entries.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
      lastAccount = entries.last.accountId;
    }
    return ExpenseEntryState(
      defaultAccountId: lastAccount ?? (accounts.isEmpty ? null : accounts.first.id),
      quickPickCategoryIds: quickPickCategoryIds(expenses),
    );
  }

  Future<void> save({
    required Money amount,
    required int categoryId,
    int? accountId,
    DateTime? occurredAt,
    String? note,
    bool? planned,
  }) async {
    if (amount.minorUnits <= 0) return;
    final accId = accountId ?? state.value?.defaultAccountId;
    if (accId == null) return;
    final id = await ref.read(ledgerRepositoryProvider).addExpense(
        accountId: accId, amount: amount, categoryId: categoryId,
        occurredAt: occurredAt ?? DateTime.now(), note: note, planned: planned);
    ref.read(ledgerRevisionProvider.notifier).state++;
    await future; // rebuild default/quick-pick
    state = AsyncData(
        (state.value ?? const ExpenseEntryState()).copyWith(lastSavedEntryId: id));
  }

  Future<void> undo() async {
    final id = state.value?.lastSavedEntryId;
    if (id == null) return;
    await ref.read(ledgerRepositoryProvider).deleteEntry(id);
    ref.read(ledgerRevisionProvider.notifier).state++;
    await future;
  }
}

final expenseEntryControllerProvider =
    AsyncNotifierProvider<ExpenseEntryController, ExpenseEntryState>(
        ExpenseEntryController.new);
