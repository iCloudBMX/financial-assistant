import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/result/failure_messages.dart';
import '../../core/theme/velora_tokens.dart';
import '../../data/categories/category_model.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/account_card_picker.dart';
import '../../ui/components/category_picker.dart';
import '../../ui/components/entry_details_section.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_money_field.dart';
import '../../ui/components/velora_sheet.dart';
import '../accounts/account_edit_sheet.dart';
import '../accounts/accounts_controller.dart';
import 'expense_entry_controller.dart';

/// Quick expense (PRD §9.1, Velora design §6.3): amount focused first, last-
/// used account preselected, four one-tap categories plus a searchable full
/// selector, and optional fields collapsed behind "Batafsil" for speed.
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
  final entryState = await ref.read(expenseEntryControllerProvider.future);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _ExpenseEntrySheetBody(
      currency: currency,
      categories: categories,
      quickIds: entryState.quickPickCategoryIds,
      defaultAccountId: entryState.defaultAccountId,
    ),
  );
}

class _ExpenseEntrySheetBody extends ConsumerStatefulWidget {
  const _ExpenseEntrySheetBody({
    required this.currency,
    required this.categories,
    required this.quickIds,
    required this.defaultAccountId,
  });

  final Currency currency;
  final List<Category> categories;
  final List<int> quickIds;
  final int? defaultAccountId;

  @override
  ConsumerState<_ExpenseEntrySheetBody> createState() =>
      _ExpenseEntrySheetBodyState();
}

class _ExpenseEntrySheetBodyState
    extends ConsumerState<_ExpenseEntrySheetBody> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  Money? _amount;
  int? _categoryId;
  int? _accountId;
  DateTime _occurredAt = DateTime.now();
  bool _planned = true;
  bool _detailsOpen = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController();
    _noteCtrl = TextEditingController();
    _accountId = widget.defaultAccountId;
    final quickFirst = widget.quickIds.isNotEmpty ? widget.quickIds.first : null;
    _categoryId = quickFirst ??
        (widget.categories.isEmpty ? null : widget.categories.first.id);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      !_saving && _amount != null && _amount!.minorUnits > 0 &&
      _categoryId != null && _accountId != null;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _occurredAt = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    // Captured before the sheet pops (and this State disposes) so the undo
    // action — invoked later, from a SnackBar that outlives this widget —
    // never touches a `ref` from an unmounted ConsumerState.
    final controller = ref.read(expenseEntryControllerProvider.notifier);
    final result = await controller.save(
      amount: _amount!,
      categoryId: _categoryId!,
      accountId: _accountId,
      occurredAt: _occurredAt,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      planned: _planned,
    );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    result.when(
      ok: (_) => messenger.showSnackBar(SnackBar(
        content: const Text('Chiqim saqlandi'),
        action: SnackBarAction(
          label: 'Bekor qilish',
          onPressed: controller.undo,
        ),
      )),
      err: (f) => messenger.showSnackBar(SnackBar(content: Text(userMessageFor(f)))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsControllerProvider);

    return VeloraSheetScaffold(
      title: 'Chiqim',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AmountCaption('Qancha sarfladingiz?'),
          VeloraMoneyField(
            controller: _amountCtrl,
            currency: widget.currency,
            label: 'Summa',
            autofocus: true,
            onChanged: (m) => setState(() => _amount = m),
          ),
          const SizedBox(height: VeloraSpacing.lg),
          const _SheetSectionLabel('Qaysi hisobdan?'),
          const SizedBox(height: VeloraSpacing.sm),
          accountsAsync.when(
            data: (list) => AccountCardPicker(
              accounts: [for (final a in list) a.account],
              availableBalances: {
                for (final a in list) a.account.id: a.balance,
              },
              selectedId: _accountId,
              onSelected: (id) => setState(() => _accountId = id),
            ),
            loading: () => const SizedBox(height: 116),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: VeloraSpacing.lg),
          const _SheetSectionLabel('Tez kategoriyalar'),
          CategoryPicker(
            categories: widget.categories,
            quickIds: widget.quickIds,
            selectedId: _categoryId,
            onSelected: (id) => setState(() => _categoryId = id),
          ),
          const SizedBox(height: VeloraSpacing.sm),
          EntryDetailsSection(
            open: _detailsOpen,
            onToggle: () => setState(() => _detailsOpen = !_detailsOpen),
            occurredAt: _occurredAt,
            onPickDate: _pickDate,
            noteController: _noteCtrl,
            noteFieldKey: const Key('expense-note-field'),
            extraChildren: [
              const SizedBox(height: VeloraSpacing.sm),
              SwitchListTile(
                key: const Key('expense-planned-switch'),
                contentPadding: EdgeInsets.zero,
                value: _planned,
                onChanged: (v) => setState(() => _planned = v),
                title: const Text('Rejalashtirilgan xarajat'),
              ),
            ],
          ),
        ],
      ),
      primaryAction: _CoralPrimaryAction(
        child: VeloraPrimaryButton(
          label: 'Saqlash',
          loading: _saving,
          onPressed: _canSave ? _save : null,
        ),
      ),
    );
  }
}

/// The muted "what are we asking?" caption the mockups place directly above the
/// amount field, giving the money input its Velora Human framing without
/// touching the shared field component.
class _AmountCaption extends StatelessWidget {
  const _AmountCaption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: VeloraSpacing.sm),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: VeloraColors.muted,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
}

/// The small uppercase muted section header ("Qaysi hisobdan?", "Tez
/// kategoriyalar") the approved money-flow mockups put above each picker.
class _SheetSectionLabel extends StatelessWidget {
  const _SheetSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: VeloraColors.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
      );
}

/// Recolors its subtree's primary to Velora coral so the pinned save CTA is the
/// single coral primary action from the mockups, while keeping the shared
/// [VeloraPrimaryButton] (its loading + a11y semantics) unchanged.
class _CoralPrimaryAction extends StatelessWidget {
  const _CoralPrimaryAction({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: VeloraColors.coral,
          onPrimary: Colors.white,
        ),
      ),
      child: child,
    );
  }
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
