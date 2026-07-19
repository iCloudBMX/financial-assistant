// Task 10: mortgage payment sheet (§13.3).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../data/mortgage/mortgage_model.dart';
import '../../providers/app_providers.dart';
import 'mortgage_controller.dart';

Future<void> showMortgagePaymentSheet(
    BuildContext context, WidgetRef ref, int mortgageId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PaymentSheet(mortgageId: mortgageId),
  );
}

class _PaymentSheet extends ConsumerStatefulWidget {
  final int mortgageId;
  const _PaymentSheet({required this.mortgageId});
  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  final _total = TextEditingController();
  final _principal = TextEditingController();
  final _interest = TextEditingController();
  int? _accountId;
  String? _error;
  static const _uzs = CurrencyRegistry.uzs;

  @override
  void dispose() {
    _total.dispose();
    _principal.dispose();
    _interest.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final total = Money.tryParse(_total.text, _uzs);
    final principal = Money.tryParse(_principal.text, _uzs);
    final interest = Money.tryParse(_interest.text, _uzs) ?? Money.zero(_uzs);
    final accounts = await ref.read(accountRepositoryProvider).list();
    final accId = _accountId ?? (accounts.isEmpty ? null : accounts.first.id);
    if (total == null || principal == null || accId == null) {
      setState(() => _error = 'Maydonlarni to\'ldiring');
      return;
    }
    final split = MortgagePaymentSplit(
      totalMinor: total.minorUnits,
      principalMinor: principal.minorUnits,
      interestMinor: interest.minorUnits,
    );
    final res = await ref.read(mortgageControllerProvider).recordPayment(
          mortgageId: widget.mortgageId,
          split: split,
          accountId: accId,
        );
    if (!res.isOk) {
      setState(() => _error = 'Qismlar umumiy summaga teng bo\'lishi kerak');
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
            key: const Key('payment-total'),
            controller: _total,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Umumiy to\'lov')),
        TextField(
            key: const Key('payment-principal'),
            controller: _principal,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Asosiy qarz')),
        TextField(
            key: const Key('payment-interest'),
            controller: _interest,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Foiz')),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: 12),
        FilledButton(
            key: const Key('payment-save'),
            onPressed: _save,
            child: const Text('Saqlash')),
      ]),
    );
  }
}
