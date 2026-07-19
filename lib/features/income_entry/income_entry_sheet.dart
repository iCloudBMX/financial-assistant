import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ledger/ledger_entry.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/result/failure_messages.dart';
import '../../core/theme/velora_tokens.dart';
import '../../data/recurring/recurring_model.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/account_card_picker.dart';
import '../../ui/components/entry_details_section.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_money_field.dart';
import '../../ui/components/velora_sheet.dart';
import '../accounts/accounts_controller.dart';
import '../allocation/income_allocation_prompt.dart';
import 'income_entry_controller.dart';

/// Income entry (Velora design §6.4): the same money input, account picker,
/// and optional-detail pattern as quick expense. After save the user chooses
/// how to allocate the income.
Future<void> showIncomeEntrySheet(BuildContext context, WidgetRef ref) async {
  final settings = await ref.read(settingsProvider.future);
  final currency = settings.primaryCurrency;
  final accounts = await ref.read(accountRepositoryProvider).list();
  if (accounts.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avval hisob yarating')));
    }
    return;
  }
  final defaultAccountId = accounts.first.id;
  if (!context.mounted) return;

  final saved = await showModalBottomSheet<({int incomeId, Money amount})>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _IncomeEntrySheetBody(
      currency: currency,
      defaultAccountId: defaultAccountId,
    ),
  );

  if (saved != null && context.mounted) {
    await showAllocationChoice(context, ref,
        incomeId: saved.incomeId, amount: saved.amount);
  }
}

const _incomeTypeLabels = {
  IncomeType.salary: 'Oylik maosh',
  IncomeType.bonus: 'Bonus',
  IncomeType.freelance: 'Freelance',
  IncomeType.refund: 'Qaytarilgan pul',
  IncomeType.other: 'Boshqa',
};

class _IncomeEntrySheetBody extends ConsumerStatefulWidget {
  const _IncomeEntrySheetBody({
    required this.currency,
    required this.defaultAccountId,
  });

  final Currency currency;
  final int defaultAccountId;

  @override
  ConsumerState<_IncomeEntrySheetBody> createState() =>
      _IncomeEntrySheetBodyState();
}

class _IncomeEntrySheetBodyState extends ConsumerState<_IncomeEntrySheetBody> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  Money? _amount;
  int? _accountId;
  IncomeType _incomeType = IncomeType.salary;
  bool _recurring = false;
  IntervalKind _intervalKind = IntervalKind.monthly;
  DateTime _occurredAt = DateTime.now();
  bool _detailsOpen = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController();
    _noteCtrl = TextEditingController();
    _accountId = widget.defaultAccountId;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      !_saving && _amount != null && _amount!.minorUnits > 0 && _accountId != null;

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
    final controller = ref.read(incomeEntryControllerProvider.notifier);
    final result = await controller.save(
      accountId: _accountId!,
      amount: _amount!,
      incomeType: _incomeType,
      occurredAt: _occurredAt,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      recurring: _recurring,
      intervalKind: _intervalKind,
    );
    if (!mounted) return;
    result.when(
      ok: (value) => Navigator.of(context)
          .pop((incomeId: value.ledgerEntryId, amount: _amount!)),
      err: (f) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userMessageFor(f))));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsControllerProvider);

    return VeloraSheetScaffold(
      title: 'Kirim',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VeloraMoneyField(
            controller: _amountCtrl,
            currency: widget.currency,
            label: 'Summa',
            autofocus: true,
            onChanged: (m) => setState(() => _amount = m),
          ),
          const SizedBox(height: VeloraSpacing.lg),
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
          Wrap(
            spacing: VeloraSpacing.sm,
            runSpacing: VeloraSpacing.sm,
            children: [
              for (final entry in _incomeTypeLabels.entries)
                ChoiceChip(
                  key: Key('income-type-${entry.key.name}'),
                  label: Text(entry.value),
                  selected: _incomeType == entry.key,
                  onSelected: (_) => setState(() => _incomeType = entry.key),
                ),
            ],
          ),
          const SizedBox(height: VeloraSpacing.md),
          SwitchListTile(
            key: const Key('income-recurring-switch'),
            contentPadding: EdgeInsets.zero,
            value: _recurring,
            onChanged: (v) => setState(() => _recurring = v),
            title: const Text('Takroriy kirim'),
            subtitle: const Text(
                'Har oy/hafta rejaga qo\'shiladi; tasdiqlash so\'ralganda yozib olinadi'),
          ),
          const SizedBox(height: VeloraSpacing.sm),
          EntryDetailsSection(
            open: _detailsOpen,
            onToggle: () => setState(() => _detailsOpen = !_detailsOpen),
            occurredAt: _occurredAt,
            onPickDate: _pickDate,
            noteController: _noteCtrl,
            noteFieldKey: const Key('income-note-field'),
            extraChildren: [
              if (_recurring) ...[
                const SizedBox(height: VeloraSpacing.sm),
                SegmentedButton<IntervalKind>(
                  key: const Key('income-interval-kind'),
                  segments: const [
                    ButtonSegment(
                      value: IntervalKind.monthly,
                      label: Text('Oylik'),
                    ),
                    ButtonSegment(
                      value: IntervalKind.weekly,
                      label: Text('Haftalik'),
                    ),
                  ],
                  selected: {_intervalKind},
                  onSelectionChanged: (s) =>
                      setState(() => _intervalKind = s.first),
                ),
              ],
            ],
          ),
        ],
      ),
      primaryAction: VeloraPrimaryButton(
        label: 'Saqlash',
        loading: _saving,
        onPressed: _canSave ? _save : null,
      ),
    );
  }
}

