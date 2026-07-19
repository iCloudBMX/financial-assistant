import 'package:flutter/material.dart';

import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/money/money_text_input_formatter.dart';

class VeloraMoneyField extends StatelessWidget {
  const VeloraMoneyField({
    super.key,
    required this.controller,
    required this.currency,
    required this.label,
    this.autofocus = false,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final Currency currency;
  final String label;
  final bool autofocus;
  final bool enabled;
  final ValueChanged<Money?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      enabled: enabled,
      keyboardType: TextInputType.numberWithOptions(
        decimal: currency.decimalDigits > 0,
      ),
      inputFormatters: [MoneyTextInputFormatter(currency)],
      decoration: InputDecoration(
        label: Semantics(
          label: '$label, ${currency.code}',
          excludeSemantics: true,
          child: Text(label),
        ),
        suffix: ExcludeSemantics(child: Text(currency.symbol)),
      ),
      onChanged: (value) {
        onChanged?.call(parseMoneyInput(value, currency));
      },
    );
  }
}
