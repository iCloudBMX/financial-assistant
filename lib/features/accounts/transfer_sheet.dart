import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/result/failure_messages.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/account_card_picker.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_money_field.dart';
import '../../ui/components/velora_sheet.dart';
import 'accounts_controller.dart';

/// Resolves the (from, to) account pair after the user picks [id] for one
/// side. When the pick collides with the other side, the two live selections
/// swap so source and destination always stay distinct — correct for any
/// number of accounts, because it compares the current live [from]/[to], not
/// the sheet's initial snapshot.
({int from, int to}) resolveTransferSelection({
  required bool selectingFrom,
  required int id,
  required int from,
  required int to,
}) {
  if (selectingFrom) {
    return id == to ? (from: id, to: from) : (from: id, to: to);
  }
  return id == from ? (from: to, to: id) : (from: from, to: id);
}

Future<void> showTransferSheet(BuildContext context, WidgetRef ref) async {
  final settings = await ref.read(settingsProvider.future);
  final currency = settings.primaryCurrency;
  final accounts = await ref.read(accountsControllerProvider.future);
  if (accounts.length < 2) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('O\'tkazma uchun kamida 2 ta hisob kerak')));
    }
    return;
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _TransferSheetBody(
      currency: currency,
      fromId: accounts[0].account.id,
      toId: accounts[1].account.id,
    ),
  );
}

class _TransferSheetBody extends ConsumerStatefulWidget {
  const _TransferSheetBody({
    required this.currency,
    required this.fromId,
    required this.toId,
  });

  final Currency currency;
  final int fromId;
  final int toId;

  @override
  ConsumerState<_TransferSheetBody> createState() => _TransferSheetBodyState();
}

class _TransferSheetBodyState extends ConsumerState<_TransferSheetBody> {
  late final TextEditingController _amountCtrl;
  Money? _amount;
  late int _fromId;
  late int _toId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController();
    _fromId = widget.fromId;
    _toId = widget.toId;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _selectFrom(int id) {
    final next = resolveTransferSelection(
        selectingFrom: true, id: id, from: _fromId, to: _toId);
    setState(() {
      _fromId = next.from;
      _toId = next.to;
    });
  }

  void _selectTo(int id) {
    final next = resolveTransferSelection(
        selectingFrom: false, id: id, from: _fromId, to: _toId);
    setState(() {
      _fromId = next.from;
      _toId = next.to;
    });
  }

  Future<void> _save() async {
    if (_amount == null) return;
    setState(() => _saving = true);
    final result = await ref.read(accountsControllerProvider.notifier)
        .transfer(fromId: _fromId, toId: _toId, amount: _amount!);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
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
    final accountsAsync = ref.watch(accountsControllerProvider);

    return VeloraSheetScaffold(
      title: 'O\'tkazma',
      body: accountsAsync.when(
        data: (list) {
          final accounts = [for (final a in list) a.account];
          final balances = {for (final a in list) a.account.id: a.balance};
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Qayerdan', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: VeloraSpacing.sm),
              AccountCardPicker(
                key: const Key('transfer-from-picker'),
                accounts: accounts,
                availableBalances: balances,
                selectedId: _fromId,
                onSelected: _selectFrom,
              ),
              const SizedBox(height: VeloraSpacing.lg),
              Text('Qayerga', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: VeloraSpacing.sm),
              AccountCardPicker(
                key: const Key('transfer-to-picker'),
                accounts: accounts,
                availableBalances: balances,
                selectedId: _toId,
                onSelected: _selectTo,
              ),
              const SizedBox(height: VeloraSpacing.lg),
              VeloraMoneyField(
                controller: _amountCtrl,
                currency: widget.currency,
                label: 'Summa',
                onChanged: (m) => setState(() => _amount = m),
              ),
            ],
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const SizedBox.shrink(),
      ),
      primaryAction: VeloraPrimaryButton(
        label: 'O\'tkazish',
        loading: _saving,
        onPressed: _amount == null || _saving || _fromId == _toId ? null : _save,
      ),
    );
  }
}
