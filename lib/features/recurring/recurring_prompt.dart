import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/money.dart';
import '../../core/result/failure.dart';
import '../../core/result/failure_messages.dart';
import '../../core/result/result.dart';
import '../../core/theme/velora_tokens.dart';
import '../../data/recurring/recurring_model.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_card.dart';
import '../../ui/components/velora_money_field.dart';
import '../../ui/components/velora_sheet.dart';

class RecurringPromptController
    extends AsyncNotifier<List<RecurringIncomePlan>> {
  @override
  Future<List<RecurringIncomePlan>> build() async {
    ref.watch(ledgerRevisionProvider);
    return ref.watch(recurringIncomeRepositoryProvider).duePlans(DateTime.now());
  }

  /// Confirm this occurrence: record the income at the plan's own amount and
  /// advance the plan to its next occurrence. The two writes run inside one
  /// `databaseProvider.transaction` (mirrors `IncomeEntryController.save`):
  /// if `markConfirmed` fails after the income is written, the whole
  /// transaction rolls back, so the plan never records income while staying
  /// due -- which would otherwise duplicate the income on the next prompt.
  Future<Result<void>> confirm(RecurringIncomePlan plan) async {
    try {
      await ref.read(databaseProvider).transaction(() async {
        await ref.read(ledgerRepositoryProvider).addIncome(
              accountId: plan.accountId,
              amount: plan.amount,
              incomeType: plan.incomeType,
              occurredAt: DateTime.now(),
              note: plan.note,
            );
        await ref.read(recurringIncomeRepositoryProvider).markConfirmed(plan.id);
      });
    } catch (error) {
      // Diagnostic detail stays inside Failure; userMessageFor never
      // interpolates it into presentation text.
      return Err(PersistenceFailure(error.toString()));
    }
    ref.read(ledgerRevisionProvider.notifier).state++;
    await future;
    return const Ok(null);
  }

  /// Confirm this occurrence with an amount edited for THIS occurrence only.
  /// The recorded income uses [amount]; the plan's own stored amount is left
  /// untouched (occurrence-level edit, not plan-level). Guards mirror the
  /// income-entry flow: non-positive → [ValidationFailure], currency mismatch
  /// with the account → [CurrencyFailure].
  Future<Result<void>> confirmWithAmount(
    RecurringIncomePlan plan, {
    required Money amount,
    DateTime? occurredAt,
  }) async {
    if (amount.minorUnits <= 0) {
      return const Err(ValidationFailure('income amount must be positive'));
    }
    final account =
        await ref.read(accountRepositoryProvider).byId(plan.accountId);
    if (account == null) {
      return const Err(NotFoundFailure('account not found'));
    }
    if (account.currency != amount.currency) {
      return const Err(CurrencyFailure(
          'income currency does not match the account currency'));
    }
    // Same atomic-transaction shape as `confirm` above: a failed
    // markConfirmed rolls back the income write too.
    try {
      await ref.read(databaseProvider).transaction(() async {
        await ref.read(ledgerRepositoryProvider).addIncome(
              accountId: plan.accountId,
              amount: amount,
              incomeType: plan.incomeType,
              occurredAt: occurredAt ?? DateTime.now(),
              note: plan.note,
            );
        await ref.read(recurringIncomeRepositoryProvider).markConfirmed(plan.id);
      });
    } catch (error) {
      return Err(PersistenceFailure(error.toString()));
    }
    ref.read(ledgerRevisionProvider.notifier).state++;
    await future;
    return const Ok(null);
  }

  /// Skip this occurrence: advance to the next occurrence WITHOUT recording
  /// any income (the occurrence is handled, just not received).
  Future<void> skip(RecurringIncomePlan plan) async {
    await ref.read(recurringIncomeRepositoryProvider).markConfirmed(plan.id);
    ref.read(ledgerRevisionProvider.notifier).state++;
    await future;
  }

  /// Postpone this occurrence to an explicit later [newDueAt] (distinct from
  /// skip, which advances a whole period). Records no income. The new date
  /// must be strictly after the current due date.
  Future<Result<void>> postpone(
      RecurringIncomePlan plan, DateTime newDueAt) async {
    if (!newDueAt.isAfter(plan.nextDueAt)) {
      return const Err(
          ValidationFailure('the new date must be after the current due date'));
    }
    await ref
        .read(recurringIncomeRepositoryProvider)
        .postponeTo(plan.id, newDueAt);
    ref.read(ledgerRevisionProvider.notifier).state++;
    await future;
    return const Ok(null);
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
          _RecurringPlanCard(plan: plan),
          const SizedBox(height: VeloraSpacing.md),
        ],
      ],
    );
  }
}

/// One due-plan card offering the four §6.4 occurrence actions: confirm,
/// edit (this occurrence's amount), postpone (to a chosen later date), and
/// skip (advance without recording income).
class _RecurringPlanCard extends ConsumerWidget {
  const _RecurringPlanCard({required this.plan});

  final RecurringIncomePlan plan;

  RecurringPromptController _controller(WidgetRef ref) =>
      ref.read(recurringPromptControllerProvider.notifier);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return VeloraCard(
      key: Key('recurring_${plan.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.event_repeat, color: VeloraColors.plum),
              SizedBox(width: VeloraSpacing.sm),
              Expanded(child: Text('Takroriy kirimni tasdiqlang')),
            ],
          ),
          const SizedBox(height: VeloraSpacing.xs),
          Text(plan.amount.format(), style: theme.textTheme.titleLarge),
          const SizedBox(height: VeloraSpacing.md),
          VeloraPrimaryButton(
            key: Key('recurring-confirm-${plan.id}'),
            label: 'Tasdiqlash',
            onPressed: () => _confirm(context, ref),
          ),
          const SizedBox(height: VeloraSpacing.sm),
          // Secondary occurrence actions. Wrap so all three stay reachable at
          // 320 px / 200% text scale without overflow; each is a ≥48 dp target.
          Wrap(
            spacing: VeloraSpacing.sm,
            runSpacing: VeloraSpacing.xs,
            children: [
              TextButton.icon(
                key: Key('recurring-edit-${plan.id}'),
                onPressed: () => _openEdit(context, ref),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Tahrirlash'),
              ),
              TextButton.icon(
                key: Key('recurring-postpone-${plan.id}'),
                onPressed: () => _openPostpone(context, ref),
                icon: const Icon(Icons.schedule),
                label: const Text('Keyinroqqa qoldirish'),
              ),
              TextButton.icon(
                key: Key('recurring-skip-${plan.id}'),
                onPressed: () => _controller(ref).skip(plan),
                icon: const Icon(Icons.skip_next_outlined),
                label: const Text('O\'tkazib yuborish'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await _controller(ref).confirm(plan);
    result.when(
      ok: (_) {},
      err: (f) =>
          messenger.showSnackBar(SnackBar(content: Text(userMessageFor(f)))),
    );
  }

  Future<void> _openEdit(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _RecurringEditSheet(plan: plan),
    );
  }

  Future<void> _openPostpone(BuildContext context, WidgetRef ref) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: plan.nextDueAt.add(const Duration(days: 1)),
      firstDate: plan.nextDueAt.add(const Duration(days: 1)),
      lastDate: DateTime(2100),
    );
    if (picked == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final result = await _controller(ref).postpone(plan, picked);
    result.when(
      ok: (_) {},
      err: (f) =>
          messenger.showSnackBar(SnackBar(content: Text(userMessageFor(f)))),
    );
  }
}

/// Edits THIS occurrence's amount before confirming. Reuses the shared money
/// field bound to the plan's currency; the plan's own amount is untouched.
class _RecurringEditSheet extends ConsumerStatefulWidget {
  const _RecurringEditSheet({required this.plan});

  final RecurringIncomePlan plan;

  @override
  ConsumerState<_RecurringEditSheet> createState() =>
      _RecurringEditSheetState();
}

class _RecurringEditSheetState extends ConsumerState<_RecurringEditSheet> {
  late final TextEditingController _amountCtrl;
  late Money _amount;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amount = widget.plan.amount;
    _amountCtrl =
        TextEditingController(text: widget.plan.amount.formatNumber());
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(recurringPromptControllerProvider.notifier)
        .confirmWithAmount(widget.plan, amount: _amount);
    if (!mounted) return;
    result.when(
      ok: (_) => Navigator.of(context).pop(),
      err: (f) {
        setState(() => _saving = false);
        messenger.showSnackBar(SnackBar(content: Text(userMessageFor(f))));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return VeloraSheetScaffold(
      title: 'Kirim summasini tahrirlash',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VeloraMoneyField(
            controller: _amountCtrl,
            currency: widget.plan.amount.currency,
            label: 'Summa',
            autofocus: true,
            onChanged: (m) => setState(() {
              if (m != null) _amount = m;
            }),
          ),
          const SizedBox(height: VeloraSpacing.sm),
          Text(
            'Bu faqat shu galgi kirim summasiga taalluqli; takroriy reja o\'zgarmaydi.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      primaryAction: VeloraPrimaryButton(
        label: 'Tasdiqlash',
        loading: _saving,
        onPressed: _saving || _amount.minorUnits <= 0 ? null : _save,
      ),
    );
  }
}
