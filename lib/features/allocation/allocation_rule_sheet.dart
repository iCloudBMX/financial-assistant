import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/account_card_picker.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_money_field.dart';
import '../../ui/components/velora_sheet.dart';
import '../accounts/accounts_controller.dart';

/// Add or edit one plan rule: pick a destination card (never the source) and a
/// fixed amount. Returns the (destinationAccountId, amount) pair, or null on
/// cancel.
Future<({int destinationAccountId, Money amount})?> showAllocationRuleSheet(
  BuildContext context,
  WidgetRef ref, {
  required int sourceAccountId,
  ({int destinationAccountId, Money amount})? initial,
}) async {
  final settings = await ref.read(settingsProvider.future);
  if (!context.mounted) return null;
  return showModalBottomSheet<({int destinationAccountId, Money amount})>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _RuleSheetBody(
      currency: settings.primaryCurrency,
      sourceAccountId: sourceAccountId,
      initial: initial,
    ),
  );
}

class _RuleSheetBody extends ConsumerStatefulWidget {
  const _RuleSheetBody({
    required this.currency,
    required this.sourceAccountId,
    required this.initial,
  });
  final Currency currency;
  final int sourceAccountId;
  final ({int destinationAccountId, Money amount})? initial;

  @override
  ConsumerState<_RuleSheetBody> createState() => _RuleSheetBodyState();
}

class _RuleSheetBodyState extends ConsumerState<_RuleSheetBody> {
  late final TextEditingController _amountCtrl;
  Money? _amount;
  int? _destId;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
        text: widget.initial?.amount.formatNumber() ?? '');
    _amount = widget.initial?.amount;
    _destId = widget.initial?.destinationAccountId;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsControllerProvider);
    return VeloraSheetScaffold(
      title: widget.initial == null ? 'Yangi qator' : 'Qatorni tahrirlash',
      body: accountsAsync.when(
        loading: () => const SizedBox(
            height: 200, child: Center(child: CircularProgressIndicator())),
        error: (_, _) => const SizedBox.shrink(),
        data: (list) {
          // Destination cards = everything except the source card.
          final dests = [
            for (final a in list)
              if (a.account.id != widget.sourceAccountId) a.account
          ];
          final balances = {for (final a in list) a.account.id: a.balance};
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Qaysi kartaga',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: VeloraSpacing.sm),
              AccountCardPicker(
                key: const Key('rule-dest-picker'),
                accounts: dests,
                availableBalances: balances,
                selectedId: _destId,
                onSelected: (id) => setState(() => _destId = id),
              ),
              const SizedBox(height: VeloraSpacing.lg),
              VeloraMoneyField(
                controller: _amountCtrl,
                currency: widget.currency,
                label: 'Summa',
                onChanged: (mv) => setState(() => _amount = mv),
              ),
            ],
          );
        },
      ),
      primaryAction: VeloraPrimaryButton(
        label: 'Saqlash',
        onPressed: (_destId == null ||
                _amount == null ||
                _amount!.minorUnits <= 0)
            ? null
            : () => Navigator.of(context)
                .pop((destinationAccountId: _destId!, amount: _amount!)),
      ),
    );
  }
}
