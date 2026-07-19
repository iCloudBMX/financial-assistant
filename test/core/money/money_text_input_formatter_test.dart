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
      expect(
        parseMoneyInput("1 250 000 so'm", CurrencyRegistry.uzs)?.minorUnits,
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
        expect(
          parseMoneyInput('1.234', CurrencyRegistry.eur)?.minorUnits,
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
    TextEditingValue enter(
      MoneyTextInputFormatter formatter,
      TextEditingValue oldValue,
      String text,
    ) {
      return formatter.formatEditUpdate(
        oldValue,
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      );
    }

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

    test('preserves each sequential decimal draft keystroke', () {
      final formatter = MoneyTextInputFormatter(CurrencyRegistry.usd);
      var value = TextEditingValue.empty;

      for (final step in const [
        (input: '1', expected: '1'),
        (input: '1.', expected: '1.'),
        (input: '1.2', expected: '1.2'),
        (input: '1.25', expected: '1.25'),
      ]) {
        value = enter(formatter, value, step.input);
        expect(value.text, step.expected);
        expect(value.selection.baseOffset, step.expected.length);
      }
    });

    test(
      'groups only the integer portion during a mid-string decimal edit',
      () {
        final formatter = MoneyTextInputFormatter(CurrencyRegistry.usd);
        final out = formatter.formatEditUpdate(
          const TextEditingValue(
            text: '123.45',
            selection: TextSelection.collapsed(offset: 2),
          ),
          const TextEditingValue(
            text: '1293.45',
            selection: TextSelection.collapsed(offset: 3),
          ),
        );

        expect(out.text, '1 293.45');
        expect(out.selection.baseOffset, 4);
      },
    );

    test('backspaces through fraction, trailing separator, and integer', () {
      final formatter = MoneyTextInputFormatter(CurrencyRegistry.usd);
      var value = const TextEditingValue(
        text: '1.25',
        selection: TextSelection.collapsed(offset: 4),
      );

      for (final expected in const ['1.2', '1.', '1']) {
        value = enter(formatter, value, expected);
        expect(value.text, expected);
        expect(value.selection.baseOffset, expected.length);
      }
    });

    test(
      'preserves the previous value for an adjacent third fraction digit',
      () {
        final formatter = MoneyTextInputFormatter(CurrencyRegistry.usd);
        const oldValue = TextEditingValue(
          text: '1.25',
          selection: TextSelection.collapsed(offset: 4),
        );

        final out = enter(formatter, oldValue, '1.256');

        expect(out, oldValue);
      },
    );

    test('re-evaluates a whole-selection replacement as a grouped integer', () {
      final formatter = MoneyTextInputFormatter(CurrencyRegistry.usd);
      final out = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '1.25',
          selection: TextSelection(baseOffset: 0, extentOffset: 4),
        ),
        const TextEditingValue(
          text: '1.234',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );

      expect(out.text, '1 234');
      expect(out.selection.baseOffset, 5);
    });

    test('re-evaluates a single-separator paste into empty as grouping', () {
      final formatter = MoneyTextInputFormatter(CurrencyRegistry.eur);
      final out = enter(formatter, TextEditingValue.empty, '1.234');

      expect(out.text, '1 234');
      expect(out.selection.baseOffset, 5);
    });

    test(
      'preserves the previous value when fraction precision is exceeded in the middle',
      () {
        final formatter = MoneyTextInputFormatter(CurrencyRegistry.usd);
        const oldValue = TextEditingValue(
          text: '1.25',
          selection: TextSelection.collapsed(offset: 3),
        );

        final out = formatter.formatEditUpdate(
          oldValue,
          const TextEditingValue(
            text: '1.235',
            selection: TextSelection.collapsed(offset: 4),
          ),
        );

        expect(out, oldValue);
      },
    );

    test('normalizes a pasted US-style decimal value', () {
      final formatter = MoneyTextInputFormatter(CurrencyRegistry.usd);
      final out = enter(formatter, TextEditingValue.empty, r'$1,234.56');

      expect(out.text, '1 234.56');
      expect(out.selection.baseOffset, 8);
    });

    test('normalizes a pasted European-style decimal value', () {
      final formatter = MoneyTextInputFormatter(CurrencyRegistry.eur);
      final out = enter(formatter, TextEditingValue.empty, '1.234,56 €');

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
