import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money_text_input_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseMoneyInput', () {
    test('normalizes pasted UZS currency and grouping separators', () {
      expect(
        parseMoneyInput(
          '1\u00a0250,000 so‘m',
          CurrencyRegistry.uzs,
        )?.minorUnits,
        1250000,
      );
    });

    test('normalizes US-style grouped decimal input', () {
      expect(
        parseMoneyInput(r'$1,234.56', CurrencyRegistry.usd)?.minorUnits,
        123456,
      );
    });

    test('normalizes European-style grouped decimal input', () {
      expect(
        parseMoneyInput('1.234,56 €', CurrencyRegistry.eur)?.minorUnits,
        123456,
      );
    });

    test(
      'treats a lone separator with too many trailing digits as grouping',
      () {
        expect(
          parseMoneyInput('1,234', CurrencyRegistry.usd)?.minorUnits,
          123400,
        );
      },
    );

    test('rejects unambiguous fractional precision beyond the currency', () {
      expect(parseMoneyInput(r'$1,234.567', CurrencyRegistry.usd), isNull);
    });

    test('returns null instead of throwing on integer overflow', () {
      const overflow = '99999999999999999999999999999999999999999999999999';
      expect(parseMoneyInput(overflow, CurrencyRegistry.uzs), isNull);
    });
  });

  group('MoneyTextInputFormatter', () {
    test('formats UZS while preserving digit-relative caret', () {
      final formatter = MoneyTextInputFormatter(CurrencyRegistry.uzs);
      final out = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '12500',
          selection: TextSelection.collapsed(offset: 5),
        ),
        const TextEditingValue(
          text: '125000',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );

      expect(out.text, '125 000');
      expect(out.selection.baseOffset, 7);
    });

    test('formats decimal currency input', () {
      final formatter = MoneyTextInputFormatter(CurrencyRegistry.usd);
      final out = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '1234.56',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );

      expect(out.text, '1 234.56');
      expect(out.selection.baseOffset, 8);
    });

    test('preserves the digit-relative caret during a mid-string edit', () {
      final formatter = MoneyTextInputFormatter(CurrencyRegistry.uzs);
      final out = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '1 250',
          selection: TextSelection.collapsed(offset: 2),
        ),
        const TextEditingValue(
          text: '1250',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );

      expect(out.text, '1 250');
      expect(out.selection.baseOffset, 1);
    });

    test('allows clearing the input', () {
      final formatter = MoneyTextInputFormatter(CurrencyRegistry.uzs);

      expect(
        formatter.formatEditUpdate(
          const TextEditingValue(text: '1'),
          TextEditingValue.empty,
        ),
        TextEditingValue.empty,
      );
    });

    test('rejects negative input by default', () {
      final formatter = MoneyTextInputFormatter(CurrencyRegistry.uzs);

      expect(
        formatter.formatEditUpdate(
          TextEditingValue.empty,
          const TextEditingValue(
            text: '-1250',
            selection: TextSelection.collapsed(offset: 5),
          ),
        ),
        TextEditingValue.empty,
      );
    });

    test('formats negative input when enabled', () {
      final formatter = MoneyTextInputFormatter(
        CurrencyRegistry.uzs,
        allowNegative: true,
      );
      final out = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '-1250',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );

      expect(out.text, '-1 250');
      expect(out.selection.baseOffset, 6);
    });
  });
}
