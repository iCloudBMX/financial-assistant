import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_money_field.dart';
import '../../ui/components/velora_sheet.dart';
import 'accounts_controller.dart';

Future<void> showBalanceAdjustSheet(
    BuildContext context, WidgetRef ref, int accountId) async {
  final settings = await ref.read(settingsProvider.future);
  final account = await ref.read(accountRepositoryProvider).byId(accountId);
  final currency = account?.currency ?? settings.primaryCurrency;
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _BalanceAdjustSheetBody(
      accountId: accountId,
      currency: currency,
    ),
  );
}

class _BalanceAdjustSheetBody extends ConsumerStatefulWidget {
  const _BalanceAdjustSheetBody({
    required this.accountId,
    required this.currency,
  });

  final int accountId;
  final Currency currency;

  @override
  ConsumerState<_BalanceAdjustSheetBody> createState() =>
      _BalanceAdjustSheetBodyState();
}

class _BalanceAdjustSheetBodyState
    extends ConsumerState<_BalanceAdjustSheetBody> {
  late final TextEditingController _realCtrl;
  Money? _real;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _realCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _realCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_real == null) return;
    setState(() => _saving = true);
    await ref.read(accountsControllerProvider.notifier).adjust(
        accountId: widget.accountId, realBalance: _real!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return VeloraSheetScaffold(
      title: 'Haqiqiy balansni kiriting',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VeloraMoneyField(
            controller: _realCtrl,
            currency: widget.currency,
            label: 'Balans',
            autofocus: true,
            onChanged: (m) => setState(() => _real = m),
          ),
          const SizedBox(height: VeloraSpacing.sm),
          Text(
            'Bu tuzatish tarixda "Balans tuzatish" sifatida ko\'rinadi.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      primaryAction: VeloraPrimaryButton(
        label: 'Tuzatish',
        loading: _saving,
        onPressed: _real == null || _saving ? null : _save,
      ),
    );
  }
}
