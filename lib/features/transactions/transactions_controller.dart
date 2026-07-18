import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ledger/ledger_entry.dart';
import '../../core/money/money.dart';
import '../../core/result/result.dart';
import '../../providers/app_providers.dart';

class TransactionsController extends AsyncNotifier<List<LedgerEntry>> {
  @override
  Future<List<LedgerEntry>> build() async {
    ref.watch(ledgerRevisionProvider);
    final entries = await ref.watch(ledgerRepositoryProvider).allEntries();
    entries.sort((a, b) => b.occurredAt.compareTo(a.occurredAt)); // newest first
    return entries;
  }

  Future<void> delete(int id) async {
    await ref.read(ledgerRepositoryProvider).deleteEntry(id);
    ref.read(ledgerRevisionProvider.notifier).state++;
    await future;
  }

  Future<Result<void>> editAmount(int id, Money amount) async {
    final r = await ref.read(ledgerRepositoryProvider).editEntry(id: id, amount: amount);
    if (r.isOk) {
      ref.read(ledgerRevisionProvider.notifier).state++;
      await future;
    }
    return r;
  }
}

final transactionsControllerProvider =
    AsyncNotifierProvider<TransactionsController, List<LedgerEntry>>(
        TransactionsController.new);
