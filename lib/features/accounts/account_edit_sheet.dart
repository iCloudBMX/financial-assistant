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

/// Opens the account sheet. With no [accountId] it creates a new account;
/// with an [accountId] it edits that account (name, type, role, balance).
Future<void> showAccountEditSheet(
  BuildContext context,
  WidgetRef ref, {
  int? accountId,
}) async {
  final settings = await ref.read(settingsProvider.future);
  AccountWithBalance? existing;
  if (accountId != null) {
    final list = await ref.read(accountsControllerProvider.future);
    for (final e in list) {
      if (e.account.id == accountId) {
        existing = e;
        break;
      }
    }
  }
  final currency = existing?.account.currency ?? settings.primaryCurrency;
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _AccountEditSheetBody(currency: currency, existing: existing),
  );
}

class _AccountEditSheetBody extends ConsumerStatefulWidget {
  const _AccountEditSheetBody({required this.currency, this.existing});

  final Currency currency;
  final AccountWithBalance? existing;

  @override
  ConsumerState<_AccountEditSheetBody> createState() =>
      _AccountEditSheetBodyState();
}

class _AccountEditSheetBodyState extends ConsumerState<_AccountEditSheetBody> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _balanceCtrl;
  Money? _balance;
  AccountType _type = AccountType.cash;
  AccountRole _role = AccountRole.spending;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameCtrl = TextEditingController(text: existing?.account.name ?? '');
    // In edit mode prefill the balance field with the current balance, using
    // the symbol-less grouped form the money formatter round-trips.
    _balanceCtrl = TextEditingController(
        text: existing != null ? existing.balance.formatNumber() : '');
    if (existing != null) {
      _type = existing.account.type;
      _role = existing.account.role;
      _balance = existing.balance;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final notifier = ref.read(accountsControllerProvider.notifier);
    if (_isEdit) {
      final existing = widget.existing!;
      final acc = existing.account;
      final name = _nameCtrl.text.trim();
      // Only pass fields that actually changed. An empty name is treated as
      // "unchanged" so the user can't blank the account name.
      await notifier.edit(
        id: acc.id,
        name: (name.isNotEmpty && name != acc.name) ? name : null,
        type: _type != acc.type ? _type : null,
        role: _role != acc.role ? _role : null,
        realBalance:
            (_balance != null && _balance != existing.balance) ? _balance : null,
      );
    } else {
      await notifier.createAccount(
          name: _nameCtrl.text.trim().isEmpty ? 'Hisob' : _nameCtrl.text.trim(),
          type: _type,
          openingBalance: _balance ?? Money.zero(widget.currency),
          icon: 'wallet',
          role: _role);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return VeloraSheetScaffold(
      title: _isEdit ? 'Hisobni tahrirlash' : 'Yangi hisob',
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
            label: _isEdit ? 'Balans' : 'Boshlang\'ich balans',
            onChanged: (m) => setState(() => _balance = m),
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
          const SizedBox(height: VeloraSpacing.lg),
          const Text('Byudjet roli'),
          const SizedBox(height: VeloraSpacing.sm),
          Wrap(
            spacing: VeloraSpacing.sm,
            runSpacing: VeloraSpacing.sm,
            children: [
              for (final role in accountRolesInDisplayOrder)
                ChoiceChip(
                  key: Key('account-role-${role.name}'),
                  label: Text(accountRoleLabel(role)),
                  selected: _role == role,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _role = role),
                ),
            ],
          ),
          const SizedBox(height: VeloraSpacing.sm),
          Text(
            accountRoleHelper(_role),
            style: Theme.of(context).textTheme.bodySmall,
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
