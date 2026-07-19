import 'package:flutter/services.dart';

import 'currency.dart';
import 'money.dart';

Money? parseMoneyInput(String raw, Currency currency) {
  final numeric = raw.replaceAll(RegExp(r'[^0-9,.\-]'), '');
  if (numeric.isEmpty) return null;

  final minusCount = '-'.allMatches(numeric).length;
  if (minusCount > 1 || (minusCount == 1 && !numeric.startsWith('-'))) {
    return null;
  }

  final negative = numeric.startsWith('-');
  final unsigned = negative ? numeric.substring(1) : numeric;
  if (!RegExp(r'\d').hasMatch(unsigned)) return null;

  if (currency.decimalDigits == 0) {
    final digits = unsigned.replaceAll(RegExp(r'[,.]'), '');
    return Money.tryParse('${negative ? '-' : ''}$digits', currency);
  }

  final lastComma = unsigned.lastIndexOf(',');
  final lastDot = unsigned.lastIndexOf('.');
  final hasComma = lastComma >= 0;
  final hasDot = lastDot >= 0;
  int? decimalIndex;

  if (hasComma && hasDot) {
    decimalIndex = lastComma > lastDot ? lastComma : lastDot;
    final fractionalDigits = unsigned.length - decimalIndex - 1;
    if (fractionalDigits > currency.decimalDigits) return null;
  } else if (hasComma || hasDot) {
    final lastSeparator = hasComma ? lastComma : lastDot;
    final trailingDigits = unsigned.length - lastSeparator - 1;
    if (trailingDigits >= 1 && trailingDigits <= currency.decimalDigits) {
      decimalIndex = lastSeparator;
    }
  }

  final normalized = StringBuffer(negative ? '-' : '');
  for (var index = 0; index < unsigned.length; index++) {
    final character = unsigned[index];
    if (RegExp(r'\d').hasMatch(character)) {
      normalized.write(character);
    } else if (index == decimalIndex) {
      normalized.write('.');
    }
  }

  return Money.tryParse(normalized.toString(), currency);
}

class MoneyTextInputFormatter extends TextInputFormatter {
  MoneyTextInputFormatter(this.currency, {this.allowNegative = false});

  final Currency currency;
  final bool allowNegative;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final caretOffset = newValue.selection.end.clamp(0, newValue.text.length);
    final beforeCaret = newValue.text.substring(0, caretOffset);
    final digitsBeforeCaret = RegExp(r'\d').allMatches(beforeCaret).length;
    final parsed = parseMoneyInput(newValue.text, currency);
    if (parsed == null || (!allowNegative && parsed.isNegative)) {
      return TextEditingValue.empty;
    }

    final text = parsed.formatNumber();
    var caret = 0;
    if (digitsBeforeCaret > 0) {
      var seen = 0;
      caret = text.length;
      for (var index = 0; index < text.length; index++) {
        if (RegExp(r'\d').hasMatch(text[index]) &&
            ++seen == digitsBeforeCaret) {
          caret = index + 1;
          break;
        }
      }
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret),
    );
  }
}
