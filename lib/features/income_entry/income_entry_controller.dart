import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ledger/ledger_entry.dart';
import '../../core/money/money.dart';
import '../../data/recurring/recurring_model.dart';
import '../../providers/app_providers.dart';

class IncomeEntryController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<int> save({
    required int accountId,
    required Money amount,
    required IncomeType incomeType,
    DateTime? occurredAt,
    String? note,
    bool recurring = false,
    IntervalKind intervalKind = IntervalKind.monthly,
    int? anchorDay,
  }) async {
    final when = occurredAt ?? DateTime.now();
    final incomeId = await ref.read(ledgerRepositoryProvider).addIncome(
        accountId: accountId, amount: amount, incomeType: incomeType,
        occurredAt: when, note: note);
    if (recurring) {
      final day = anchorDay ??
          (intervalKind == IntervalKind.monthly ? when.day : when.weekday);
      await ref.read(recurringIncomeRepositoryProvider).create(
            accountId: accountId,
            amount: amount,
            incomeType: incomeType,
            note: note,
            intervalKind: intervalKind,
            anchorDay: day,
            nextDueAt: nextRecurringDate(when, intervalKind, day),
          );
    }
    ref.read(ledgerRevisionProvider.notifier).state++;
    return incomeId;
  }
}

final incomeEntryControllerProvider =
    AsyncNotifierProvider<IncomeEntryController, void>(IncomeEntryController.new);
