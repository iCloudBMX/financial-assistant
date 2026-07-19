import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/velora_tokens.dart';
import '../../data/recurring/recurring_model.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_card.dart';

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
        for (final plan in due) ...[
          VeloraCard(
            key: Key('recurring_${plan.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.event_repeat, color: VeloraColors.plum),
                    SizedBox(width: VeloraSpacing.sm),
                    Expanded(
                      child: Text('Takroriy kirimni tasdiqlang'),
                    ),
                  ],
                ),
                const SizedBox(height: VeloraSpacing.xs),
                Text(
                  plan.amount.format(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: VeloraSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => ref
                            .read(recurringPromptControllerProvider.notifier)
                            .later(plan),
                        child: const Text('Keyinroq'),
                      ),
                    ),
                    const SizedBox(width: VeloraSpacing.sm),
                    Expanded(
                      child: VeloraPrimaryButton(
                        label: 'Tasdiqlash',
                        onPressed: () => ref
                            .read(recurringPromptControllerProvider.notifier)
                            .confirm(plan),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: VeloraSpacing.md),
        ],
      ],
    );
  }
}
