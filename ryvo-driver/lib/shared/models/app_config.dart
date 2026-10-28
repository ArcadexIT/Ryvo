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

/// Runtime config from `GET /app-config` (public, no auth).
class AppConfig {
  const AppConfig({
    required this.providerOtpEnabled,
    this.currency = CurrencyConfig.gbp,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final currency = CurrencyConfig.fromJson(
      (json['currency'] as Map?)?.cast<String, dynamic>(),
    );
    ActiveCurrency.apply(currency);
    return AppConfig(
      providerOtpEnabled: json['providerOtpEnabled'] as bool? ?? true,
      currency: currency,
    );
  }

  final bool providerOtpEnabled;
  final CurrencyConfig currency;

  static const fallback = AppConfig(providerOtpEnabled: true);
}
