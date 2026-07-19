import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ledger/ledger_entry.dart';
import '../../core/money/money.dart';
import '../../core/result/failure.dart';
import '../../core/result/result.dart';
import '../../data/recurring/recurring_model.dart';
import '../../providers/app_providers.dart';

/// The outcome of a successful income save: the ledger entry id, and the
/// recurring-plan id when the income was also marked recurring.
class IncomeSaveResult {
  final int ledgerEntryId;
  final int? recurringPlanId;
  const IncomeSaveResult({required this.ledgerEntryId, this.recurringPlanId});
}

class IncomeEntryController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Persists an income entry and, when [recurring] is set, its recurring
  /// plan, as a single atomic write: if the plan write fails the income
  /// entry rolls back too, so a partially-saved income never appears on the
  /// dashboard without its plan (or vice versa).
  Future<Result<IncomeSaveResult>> save({
    required int accountId,
    required Money amount,
    required IncomeType incomeType,
    DateTime? occurredAt,
    String? note,
    bool recurring = false,
    IntervalKind intervalKind = IntervalKind.monthly,
    int? anchorDay,
  }) async {
    if (amount.minorUnits <= 0) {
      return const Err(ValidationFailure('income amount must be positive'));
    }
    final account = await ref.read(accountRepositoryProvider).byId(accountId);
    if (account == null) {
      return const Err(NotFoundFailure('account not found'));
    }
    if (account.currency != amount.currency) {
      return const Err(
          CurrencyFailure('income currency does not match the account currency'));
    }

    final when = occurredAt ?? DateTime.now();
    late int incomeId;
    int? recurringId;
    try {
      await ref.read(databaseProvider).transaction(() async {
        incomeId = await ref.read(ledgerRepositoryProvider).addIncome(
            accountId: accountId, amount: amount, incomeType: incomeType,
            occurredAt: when, note: note);
        if (recurring) {
          final day = anchorDay ??
              (intervalKind == IntervalKind.monthly ? when.day : when.weekday);
          recurringId = await ref.read(recurringIncomeRepositoryProvider).create(
                accountId: accountId,
                amount: amount,
                incomeType: incomeType,
                note: note,
                intervalKind: intervalKind,
                anchorDay: day,
                nextDueAt: nextRecurringDate(when, intervalKind, day),
              );
        }
      });
    } catch (error) {
      // Diagnostic detail stays inside Failure; userMessageFor never
      // interpolates it into presentation text.
      return Err(PersistenceFailure(error.toString()));
    }
    ref.read(ledgerRevisionProvider.notifier).state++;
    return Ok(IncomeSaveResult(
        ledgerEntryId: incomeId, recurringPlanId: recurringId));
  }
}

final incomeEntryControllerProvider =
    AsyncNotifierProvider<IncomeEntryController, void>(IncomeEntryController.new);
