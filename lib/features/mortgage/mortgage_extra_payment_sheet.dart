// Task 11: extra-payment sheet with live recalc preview (§13.4/§13.5).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/mortgage/mortgage_engine.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/account_card_picker.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_money_field.dart';
import '../../ui/components/velora_sheet.dart';
import '../accounts/accounts_controller.dart';
import 'mortgage_controller.dart';

Future<void> showMortgageExtraPaymentSheet(
    BuildContext context, WidgetRef ref, int mortgageId,
    {Money? initialAmount}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ExtraSheet(
        mortgageId: mortgageId, initialAmount: initialAmount),
  );
}

class _ExtraSheet extends ConsumerStatefulWidget {
  final int mortgageId;
  final Money? initialAmount;
  const _ExtraSheet({required this.mortgageId, this.initialAmount});
  @override
  ConsumerState<_ExtraSheet> createState() => _ExtraSheetState();
}

class _ExtraSheetState extends ConsumerState<_ExtraSheet> {
  final _amount = TextEditingController();
  int? _accountId;
  String? _error;
  static const _uzs = CurrencyRegistry.uzs;

  @override
  void initState() {
    super.initState();
    if (widget.initialAmount != null) {
      _amount.text = widget.initialAmount!.formatNumber();
    }
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = Money.tryParse(_amount.text, _uzs);
    if (amount == null || amount.minorUnits <= 0 || _accountId == null) {
      setState(() => _error = 'Summa va kartani tanlang');
      return;
    }
    final res = await ref.read(mortgageControllerProvider).recordExtraPayment(
          mortgageId: widget.mortgageId,
          amount: amount,
          accountId: _accountId!,
        );
    if (!mounted) return;
    if (!res.isOk) {
      setState(() => _error = 'Xatolik');
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = ref.watch(mortgagesProvider).value;
    MortgageWithProjection? item;
    for (final e in (list ?? const <MortgageWithProjection>[])) {
      if (e.mortgage.id == widget.mortgageId) {
        item = e;
        break;
      }
    }
    final amount = Money.tryParse(_amount.text, _uzs);
    String preview = '';
    if (item != null && amount != null && amount.minorUnits > 0) {
      final before = item.projection;
      final after = applyExtraPayment(
        currentPrincipalMinor: item.currentPrincipalMinor,
        extraMinor: amount.minorUnits,
        annualRateBp: item.mortgage.annualRateBp,
        type: item.mortgage.paymentType,
        monthlyPaymentMinor: item.mortgage.mandatoryPaymentMinor,
        monthlyPrincipalMinor: item.monthlyPrincipalMinor,
        strategy: item.mortgage.payoffStrategy,
        asOf: DateTime.now(),
      );
      final monthsSaved =
          (before.monthsRemaining - after.monthsRemaining).clamp(0, 100000);
      final interestSaved = (before.totalRemainingInterestMinor -
              after.totalRemainingInterestMinor)
          .clamp(0, 1 << 62);
      // §6.9: every projection is informational, never a bank statement —
      // the "Taxminiy" (estimate) word is always present here, not only when
      // the plan itself is flagged approximate. The single-Text body keeps the
      // "Muddat qisqarishi: N oy" line whole for the differential-preview test.
      preview = 'Muddat qisqarishi: $monthsSaved oy\n'
          'Tejalgan foiz: ${Money(interestSaved, _uzs).format()}'
          '${after.isApproximate ? ' (taxminiy hisob-kitob)' : ''}';
    }
    final accountsAsync = ref.watch(accountsControllerProvider);
    final balances = {
      for (final a in (accountsAsync.value ?? const <AccountWithBalance>[]))
        a.account.id: a.balance.minorUnits,
    };
    final selectedBalance = _accountId == null ? null : balances[_accountId];
    // The extra payment can't draw more than the chosen card holds.
    final exceedsBalance = amount != null &&
        selectedBalance != null &&
        amount.minorUnits > selectedBalance;
    return VeloraSheetScaffold(
      title: 'Qo\'shimcha to\'lov',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VeloraMoneyField(
              key: const Key('extra-amount'),
              controller: _amount,
              currency: _uzs,
              label: 'Qo\'shimcha to\'lov summasi',
              autofocus: true),
          const SizedBox(height: VeloraSpacing.sm),
          Text(
            'Qo\'shimcha to\'lov to\'g\'ridan-to\'g\'ri asosiy qarzni '
            'kamaytiradi.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: VeloraColors.muted),
          ),
          if (preview.isNotEmpty) ...[
            const SizedBox(height: VeloraSpacing.md),
            _PreviewCard(body: preview),
          ],
          const SizedBox(height: VeloraSpacing.lg),
          Text('Qaysi kartadan?', style: theme.textTheme.labelLarge),
          const SizedBox(height: VeloraSpacing.sm),
          accountsAsync.when(
            data: (accts) {
              if (_accountId == null && accts.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() => _accountId = accts.first.account.id);
                  }
                });
              }
              return AccountCardPicker(
                accounts: [for (final a in accts) a.account],
                availableBalances: {
                  for (final a in accts) a.account.id: a.balance,
                },
                selectedId: _accountId,
                onSelected: (id) => setState(() => _accountId = id),
              );
            },
            loading: () => const SizedBox(height: 116),
            error: (_, _) => const Text('Hisoblarni yuklab bo\'lmadi'),
          ),
          if (exceedsBalance)
            Padding(
              padding: const EdgeInsets.only(top: VeloraSpacing.sm),
              child: Text('Kartada yetarli mablag\' yo\'q',
                  style: TextStyle(color: theme.colorScheme.error)),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: VeloraSpacing.sm),
              child: Text(_error!,
                  style: TextStyle(color: theme.colorScheme.error)),
            ),
        ],
      ),
      primaryAction: VeloraPrimaryButton(
        key: const Key('extra-save'),
        label: 'Saqlash',
        onPressed: exceedsBalance ? null : _save,
      ),
    );
  }
}

/// The plum-tinted estimate preview: a header labeling the figures as an
/// estimate, over the whole "months / interest saved" body text.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(VeloraSpacing.md),
      decoration: BoxDecoration(
        color: VeloraColors.plumTint,
        borderRadius: BorderRadius.circular(VeloraRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_outlined,
                  size: 18, color: VeloraColors.plum),
              const SizedBox(width: VeloraSpacing.sm),
              Text('Taxminiy natija',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: VeloraColors.plum)),
            ],
          ),
          const SizedBox(height: VeloraSpacing.sm),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
