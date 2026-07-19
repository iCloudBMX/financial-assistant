import 'package:flutter/services.dart';

import 'currency.dart';
import 'money.dart';

final _digitPattern = RegExp(r'\d');
final _moneyCharactersPattern = RegExp(r'[^0-9,.\-]');

Money? parseMoneyInput(String raw, Currency currency) {
  final numeric = raw.replaceAll(_moneyCharactersPattern, '');
  if (numeric.isEmpty) return null;

  final minusCount = '-'.allMatches(numeric).length;
  if (minusCount > 1 || (minusCount == 1 && !numeric.startsWith('-'))) {
    return null;
  }

  final negative = numeric.startsWith('-');
  final unsigned = negative ? numeric.substring(1) : numeric;
  if (!_digitPattern.hasMatch(unsigned)) return null;

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
    if (_digitPattern.hasMatch(character)) {
      normalized.write(character);
    } else if (index == decimalIndex) {
      normalized.write('.');
    }
  }

  return Money.tryParse(normalized.toString(), currency);
}

class _DecimalDraft {
  const _DecimalDraft._({
    this.money,
    this.text,
    this.numericDecimalIndex,
    this.exceedsPrecision = false,
  });

  factory _DecimalDraft.valid({
    required Money money,
    required String text,
    required int? numericDecimalIndex,
  }) {
    return _DecimalDraft._(
      money: money,
      text: text,
      numericDecimalIndex: numericDecimalIndex,
    );
  }

  static const precisionExceeded = _DecimalDraft._(exceedsPrecision: true);

  final Money? money;
  final String? text;
  final int? numericDecimalIndex;
  final bool exceedsPrecision;
}

_DecimalDraft? _normalizeDecimalDraft(
  String raw,
  Currency currency, {
  required bool isSequentialInsertion,
}) {
  final numeric = raw.replaceAll(_moneyCharactersPattern, '');
  if (numeric.isEmpty) return null;

  final minusCount = '-'.allMatches(numeric).length;
  if (minusCount > 1 || (minusCount == 1 && !numeric.startsWith('-'))) {
    return null;
  }

  final negative = numeric.startsWith('-');
  final unsigned = negative ? numeric.substring(1) : numeric;
  if (!_digitPattern.hasMatch(unsigned)) return null;

  final lastComma = unsigned.lastIndexOf(',');
  final lastDot = unsigned.lastIndexOf('.');
  final hasComma = lastComma >= 0;
  final hasDot = lastDot >= 0;
  int? decimalIndex;

  if (hasComma && hasDot) {
    decimalIndex = lastComma > lastDot ? lastComma : lastDot;
    final fractionalDigits = unsigned.length - decimalIndex - 1;
    if (fractionalDigits > currency.decimalDigits) {
      return _DecimalDraft.precisionExceeded;
    }
  } else if (hasComma || hasDot) {
    final lastSeparator = hasComma ? lastComma : lastDot;
    final trailingDigits = unsigned.length - lastSeparator - 1;
    if (trailingDigits <= currency.decimalDigits) {
      decimalIndex = lastSeparator;
    } else if (isSequentialInsertion) {
      return _DecimalDraft.precisionExceeded;
    }
  }

  final integerDigits = StringBuffer();
  final fractionDigits = StringBuffer();
  for (var index = 0; index < unsigned.length; index++) {
    final character = unsigned[index];
    if (!_digitPattern.hasMatch(character)) continue;
    if (decimalIndex != null && index > decimalIndex) {
      fractionDigits.write(character);
    } else {
      integerDigits.write(character);
    }
  }

  var integer = integerDigits.toString();
  if (integer.isEmpty) integer = '0';
  integer = integer.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  final fraction = fractionDigits.toString();
  final sign = negative ? '-' : '';
  final parseText = decimalIndex == null
      ? '$sign$integer'
      : '$sign$integer.$fraction';
  final money = Money.tryParse(parseText, currency);
  if (money == null) return null;

  final groupedInteger = _groupDigits(integer);
  final text = decimalIndex == null
      ? '$sign$groupedInteger'
      : '$sign$groupedInteger.$fraction';
  final numericDecimalIndex = decimalIndex == null
      ? null
      : decimalIndex + (negative ? 1 : 0);
  return _DecimalDraft.valid(
    money: money,
    text: text,
    numericDecimalIndex: numericDecimalIndex,
  );
}

String _groupDigits(String digits) {
  final grouped = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      grouped.write(' ');
    }
    grouped.write(digits[index]);
  }
  return grouped.toString();
}

bool _isSingleCharacterInsertion(
  TextEditingValue oldValue,
  TextEditingValue newValue,
) {
  final oldSelection = oldValue.selection;
  final newSelection = newValue.selection;
  if (!oldSelection.isValid ||
      !oldSelection.isCollapsed ||
      !newSelection.isValid ||
      !newSelection.isCollapsed ||
      newValue.text.length != oldValue.text.length + 1) {
    return false;
  }

  final insertionOffset = oldSelection.baseOffset;
  if (insertionOffset < 0 || insertionOffset > oldValue.text.length) {
    return false;
  }
  if (newSelection.baseOffset != insertionOffset + 1) return false;

  return newValue.text.startsWith(
        oldValue.text.substring(0, insertionOffset),
      ) &&
      newValue.text.substring(insertionOffset + 1) ==
          oldValue.text.substring(insertionOffset);
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
    final digitsBeforeCaret = _digitPattern.allMatches(beforeCaret).length;
    final numericBeforeCaret = beforeCaret.replaceAll(
      _moneyCharactersPattern,
      '',
    );

    final Money? parsed;
    final String text;
    int? numericDecimalIndex;
    if (currency.decimalDigits == 0) {
      parsed = parseMoneyInput(newValue.text, currency);
      text = parsed?.formatNumber() ?? '';
    } else {
      final draft = _normalizeDecimalDraft(
        newValue.text,
        currency,
        isSequentialInsertion: _isSingleCharacterInsertion(oldValue, newValue),
      );
      if (draft?.exceedsPrecision ?? false) return oldValue;
      parsed = draft?.money;
      text = draft?.text ?? '';
      numericDecimalIndex = draft?.numericDecimalIndex;
    }

    if (parsed == null || (!allowNegative && parsed.isNegative)) {
      return TextEditingValue.empty;
    }

    var caret = 0;
    if (digitsBeforeCaret > 0) {
      var seen = 0;
      caret = text.length;
      for (var index = 0; index < text.length; index++) {
        if (_digitPattern.hasMatch(text[index]) &&
            ++seen == digitsBeforeCaret) {
          caret = index + 1;
          break;
        }
      }
    }

    if (numericDecimalIndex != null &&
        numericBeforeCaret.length > numericDecimalIndex) {
      final fractionBeforeCaret = numericBeforeCaret.substring(
        numericDecimalIndex + 1,
      );
      if (!_digitPattern.hasMatch(fractionBeforeCaret)) {
        caret = text.indexOf('.') + 1;
      }
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret),
    );
  }
}
