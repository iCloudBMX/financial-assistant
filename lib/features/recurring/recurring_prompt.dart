import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/recurring/recurring_model.dart';
import '../../providers/app_providers.dart';

class RecurringPromptController
    extends AsyncNotifier<List<RecurringIncomePlan>> {
  @override
  Future<List<RecurringIncomePlan>> build() async {
    ref.watch(ledgerRevisionProvider);
    return ref.watch(recurringIncomeRepositoryProvider).duePlans(DateTime.now());
  }

  Future<void> confirm(RecurringIncomePlan plan) async {
    await ref.read(ledgerRepositoryProvider).addIncome(
          accountId: plan.accountId,
          amount: plan.amount,
          incomeType: plan.incomeType,
          occurredAt: DateTime.now(),
          note: plan.note,
        );
    await ref.read(recurringIncomeRepositoryProvider).markConfirmed(plan.id);
    ref.read(ledgerRevisionProvider.notifier).state++;
    await future;
  }

  Future<void> later(RecurringIncomePlan plan) async {
    await ref.read(recurringIncomeRepositoryProvider).markConfirmed(plan.id);
    ref.invalidateSelf();
    await future;
  }
}

final recurringPromptControllerProvider =
    AsyncNotifierProvider<RecurringPromptController, List<RecurringIncomePlan>>(
        RecurringPromptController.new);

class RecurringPromptBanner extends ConsumerWidget {
  const RecurringPromptBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(recurringPromptControllerProvider).value ?? [];
    if (due.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final plan in due)
          Card(
            key: Key('recurring_${plan.id}'),
            child: ListTile(
              title: const Text('Takroriy kirimni tasdiqlang'),
              subtitle: Text(plan.amount.format()),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => ref
                        .read(recurringPromptControllerProvider.notifier)
                        .later(plan),
                    child: const Text('Keyinroq'),
                  ),
                  FilledButton(
                    onPressed: () => ref
                        .read(recurringPromptControllerProvider.notifier)
                        .confirm(plan),
                    child: const Text('Tasdiqlash'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
