import 'currency.dart';

class CurrencyMismatchError extends Error {
  final Currency a;
  final Currency b;
  CurrencyMismatchError(this.a, this.b);
  @override
  String toString() => 'CurrencyMismatchError: ${a.code} vs ${b.code}';
}

class Money {
  final int minorUnits;
  final Currency currency;

  const Money(this.minorUnits, this.currency);

  factory Money.zero(Currency currency) => Money(0, currency);

  void _assertSame(Money other) {
    if (other.currency != currency) {
      throw CurrencyMismatchError(currency, other.currency);
    }
  }

  Money add(Money other) {
    _assertSame(other);
    return Money(minorUnits + other.minorUnits, currency);
  }

  Money subtract(Money other) {
    _assertSame(other);
    return Money(minorUnits - other.minorUnits, currency);
  }

  Money negate() => Money(-minorUnits, currency);

  bool get isNegative => minorUnits < 0;

  int compareTo(Money other) {
    _assertSame(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  // Integer-only parsing — no double/num is used for the amount, per the
  // project's "No floating-point money, ever" constraint.
  static Money? tryParse(String text, Currency currency) {
    final cleaned =
        text.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    final negative = cleaned.startsWith('-');
    final unsigned = negative ? cleaned.substring(1) : cleaned;
    final parts = unsigned.split('.');
    if (parts.length > 2) return null; // malformed
    final majorText = parts[0].isEmpty ? '0' : parts[0];
    final major = int.tryParse(majorText);
    if (major == null) return null; // non-numeric -> null
    var minor = 0;
    if (parts.length == 2 && parts[1].isNotEmpty) {
      if (int.tryParse(parts[1]) == null) return null; // non-digit fraction
      final frac = parts[1].padRight(currency.decimalDigits, '0');
      final take = currency.decimalDigits;
      minor = take == 0 ? 0 : int.parse(frac.substring(0, take));
    }
    final total = major * _pow10(currency.decimalDigits) + minor;
    return Money(negative ? -total : total, currency);
  }

  String format() {
    final scale = _pow10(currency.decimalDigits);
    final major = (minorUnits.abs() ~/ scale);
    final grouped = _group(major.toString());
    final sign = isNegative ? '-' : '';
    String number = grouped;
    if (currency.decimalDigits > 0) {
      final frac = (minorUnits.abs() % scale)
          .toString()
          .padLeft(currency.decimalDigits, '0');
      number = '$grouped.$frac';
    }
    return currency.symbolPosition == SymbolPosition.before
        ? '$sign${currency.symbol}$number'
        : '$sign$number ${currency.symbol}';
  }

  static int _pow10(int n) {
    var r = 1;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }

  static String _group(String digits) {
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => 'Money(${format()})';
}
