import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/money.dart';
import '../../data/categories/category_model.dart';
import '../../providers/app_providers.dart';
import 'expense_entry_controller.dart';

/// 3-step quick expense: amount -> category -> save (PRD §9.1). Optional
/// fields (account/date/note) stay hidden behind defaults for speed.
Future<void> showExpenseEntrySheet(BuildContext context, WidgetRef ref) async {
  final settings = await ref.read(settingsProvider.future);
  final currency = settings.primaryCurrency;
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
                if (amount == null || categoryId == null) return;
                await ref.read(expenseEntryControllerProvider.notifier)
                    .save(amount: amount, categoryId: categoryId!);
                if (!ctx.mounted) return;
                final messenger = ScaffoldMessenger.of(ctx);
                Navigator.of(ctx).pop();
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
