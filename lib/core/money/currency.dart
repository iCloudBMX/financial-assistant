enum SymbolPosition { before, after }

class Currency {
  final String code;
  final String symbol;
  final int decimalDigits;
  final SymbolPosition symbolPosition;

  const Currency({
    required this.code,
    required this.symbol,
    required this.decimalDigits,
    required this.symbolPosition,
  });

  @override
  bool operator ==(Object other) =>
      other is Currency && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

class CurrencyRegistry {
  const CurrencyRegistry._();

  static const uzs = Currency(
    code: 'UZS',
    symbol: 'so\u2018m',
    decimalDigits: 0,
    symbolPosition: SymbolPosition.after,
  );
  static const usd = Currency(
    code: 'USD',
    symbol: r'$',
    decimalDigits: 2,
    symbolPosition: SymbolPosition.before,
  );
  static const eur = Currency(
    code: 'EUR',
    symbol: '€',
    decimalDigits: 2,
    symbolPosition: SymbolPosition.before,
  );

  static const _all = {'UZS': uzs, 'USD': usd, 'EUR': eur};

  static Currency byCode(String code) {
    final c = _all[code];
    if (c == null) {
      throw ArgumentError.value(code, 'code', 'Unknown currency code');
    }
    return c;
  }
}
