/// Active display currency. Only this one object is kept in memory.
class CurrencyConfig {
  const CurrencyConfig({
    required this.code,
    required this.symbol,
    required this.decimals,
  });

  final String code;
  final String symbol;
  final int decimals;

  static const gbp = CurrencyConfig(code: 'GBP', symbol: '£', decimals: 2);

  factory CurrencyConfig.fromJson(Map<String, dynamic>? json) {
    final code = json?['code']?.toString().trim().toUpperCase() ?? '';
    final symbol = json?['symbol']?.toString().trim() ?? '';
    final rawDecimals = json?['decimals'];
    final decimals = rawDecimals is num ? rawDecimals.toInt() : 2;
    if (code.isEmpty || symbol.isEmpty) return gbp;
    return CurrencyConfig(
      code: code,
      symbol: symbol,
      decimals: decimals.clamp(0, 4),
    );
  }
}

class ActiveCurrency {
  static CurrencyConfig current = CurrencyConfig.gbp;

  static void apply(CurrencyConfig currency) {
    current = currency;
  }
}
