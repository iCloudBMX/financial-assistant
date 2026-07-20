import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ledger/account.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_money_field.dart';
import '../../ui/components/velora_sheet.dart';
import 'account_labels.dart';
import 'accounts_controller.dart';

Future<void> showAccountEditSheet(BuildContext context, WidgetRef ref) async {
  final settings = await ref.read(settingsProvider.future);
  final currency = settings.primaryCurrency;
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _AccountEditSheetBody(currency: currency),
  );
}

class _AccountEditSheetBody extends ConsumerStatefulWidget {
  const _AccountEditSheetBody({required this.currency});

  final Currency currency;

  @override
  ConsumerState<_AccountEditSheetBody> createState() =>
      _AccountEditSheetBodyState();
}

class _AccountEditSheetBodyState extends ConsumerState<_AccountEditSheetBody> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _balanceCtrl;
  Money? _opening;
  AccountType _type = AccountType.cash;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _balanceCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(accountsControllerProvider.notifier).createAccount(
        name: _nameCtrl.text.trim().isEmpty ? 'Hisob' : _nameCtrl.text.trim(),
        type: _type,
        openingBalance: _opening ?? Money.zero(widget.currency),
        icon: 'wallet');
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return VeloraSheetScaffold(
      title: 'Yangi hisob',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Nomi'),
          ),
          const SizedBox(height: VeloraSpacing.lg),
          VeloraMoneyField(
            controller: _balanceCtrl,
            currency: widget.currency,
            label: 'Boshlang\'ich balans',
            onChanged: (m) => setState(() => _opening = m),
          ),
          const SizedBox(height: VeloraSpacing.lg),
          Wrap(
            spacing: VeloraSpacing.sm,
            runSpacing: VeloraSpacing.sm,
            children: [
              for (final type in accountTypesInDisplayOrder)
                ChoiceChip(
                  key: Key('account-type-${type.name}'),
                  label: Text(accountTypeLabel(type)),
                  selected: _type == type,
                  // Selection is shown by the chip's fill, matching the
                  // mockup. Suppress the leading checkmark: it would widen
                  // the selected chip and reflow the Wrap, making chips jump
                  // rows as the user switches types.
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _type = type),
                ),
            ],
          ),
        ],
      ),
      primaryAction: VeloraPrimaryButton(
        label: 'Saqlash',
        loading: _saving,
        onPressed: _saving ? null : _save,
      ),
    );
  }
}
