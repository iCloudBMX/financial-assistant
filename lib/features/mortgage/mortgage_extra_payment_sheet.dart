// Task 11: extra-payment sheet with live recalc preview (§13.4/§13.5).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/mortgage/mortgage_engine.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_card.dart';
import '../../ui/components/velora_money_field.dart';
import '../../ui/components/velora_sheet.dart';
import 'mortgage_controller.dart';

Future<void> showMortgageExtraPaymentSheet(
    BuildContext context, WidgetRef ref, int mortgageId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ExtraSheet(mortgageId: mortgageId),
  );
}

class _ExtraSheet extends ConsumerStatefulWidget {
  final int mortgageId;
  const _ExtraSheet({required this.mortgageId});
  @override
  ConsumerState<_ExtraSheet> createState() => _ExtraSheetState();
}

class _ExtraSheetState extends ConsumerState<_ExtraSheet> {
  final _amount = TextEditingController();
  String? _error;
  static const _uzs = CurrencyRegistry.uzs;

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = Money.tryParse(_amount.text, _uzs);
    final accounts = await ref.read(accountRepositoryProvider).list();
    if (!mounted) return;
    if (amount == null || amount.minorUnits <= 0 || accounts.isEmpty) {
      setState(() => _error = 'Summani kiriting');
      return;
    }
    final res = await ref.read(mortgageControllerProvider).recordExtraPayment(
          mortgageId: widget.mortgageId,
          amount: amount,
          accountId: accounts.first.id,
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
      // the plan itself is flagged approximate.
      preview = 'Taxminiy natija:\n'
          'Muddat qisqarishi: $monthsSaved oy\n'
          'Tejalgan foiz: ${Money(interestSaved, _uzs).format()}'
          '${after.isApproximate ? ' (taxminiy hisob-kitob)' : ''}';
    }
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
          if (preview.isNotEmpty) ...[
            const SizedBox(height: VeloraSpacing.md),
            VeloraCard(child: Text(preview)),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: VeloraSpacing.sm),
              child: Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      primaryAction: VeloraPrimaryButton(
        key: const Key('extra-save'),
        label: 'Saqlash',
        onPressed: _save,
      ),
    );
  }
}
