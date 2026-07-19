import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/money.dart';
import '../../data/categories/category_model.dart';
import '../../providers/app_providers.dart';
import '../accounts/account_edit_sheet.dart';
import 'expense_entry_controller.dart';

/// 3-step quick expense: amount -> category -> save (PRD §9.1). Optional
/// fields (account/date/note) stay hidden behind defaults for speed.
Future<void> showExpenseEntrySheet(BuildContext context, WidgetRef ref) async {
  final settings = await ref.read(settingsProvider.future);
  final currency = settings.primaryCurrency;
  // A fresh user (straight after onboarding) has no account yet, and an
  // expense cannot be booked without one — saving would silently no-op. Guide
  // them to create an account first instead of showing a dead entry form.
  final accounts = await ref.read(accountRepositoryProvider).list();
  if (accounts.isEmpty) {
    if (!context.mounted) return;
    await _promptCreateFirstAccount(context, ref);
    return;
  }
  final categories = await ref.read(categoryRepositoryProvider).list();
  if (categories.isEmpty) return;
  final amountCtrl = TextEditingController();
  int? categoryId = categories.first.id;
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: StatefulBuilder(
        builder: (ctx, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Summa'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final Category cat in categories)
                  ChoiceChip(
                    label: Text(cat.name),
                    selected: categoryId == cat.id,
                    onSelected: (_) => setState(() => categoryId = cat.id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final amount = Money.tryParse(amountCtrl.text, currency);
                if (amount == null || amount.minorUnits <= 0 || categoryId == null) return;
                final id = await ref.read(expenseEntryControllerProvider.notifier)
                    .save(amount: amount, categoryId: categoryId!);
                if (!ctx.mounted) return;
                final messenger = ScaffoldMessenger.of(ctx);
                Navigator.of(ctx).pop();
                // Only report success when the entry actually persisted; a null
                // id means nothing was written, so never show a false "saved".
                if (id == null) {
                  messenger.showSnackBar(const SnackBar(
                      content: Text('Chiqim saqlanmadi. Qayta urinib ko\'ring.')));
                  return;
                }
                messenger.showSnackBar(SnackBar(
                  content: const Text('Chiqim saqlandi'),
                  action: SnackBarAction(
                    label: 'Bekor qilish',
                    onPressed: () =>
                        ref.read(expenseEntryControllerProvider.notifier).undo(),
                  ),
                ));
              },
              child: const Text('Saqlash'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}

/// Shown when the user tries to add an expense before any account exists.
/// Offers to open the account-create sheet so they can proceed (PRD §28.1 —
/// accounts are created from the Accounts flow, not during onboarding).
Future<void> _promptCreateFirstAccount(
    BuildContext context, WidgetRef ref) async {
  final create = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Avval hisob yarating'),
      content: const Text(
          'Chiqim qo\'shish uchun kamida bitta hisob (masalan, Naqd pul) '
          'bo\'lishi kerak. Hozir yaratasizmi?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Bekor qilish')),
        FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hisob yaratish')),
      ],
    ),
  );
  if (create != true || !context.mounted) return;
  await showAccountEditSheet(context, ref);
}
