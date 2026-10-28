import '../../shared/models/app_config.dart';

String formatMoney(num amount) {
  final currency = ActiveCurrency.current;
  return '${currency.symbol}${amount.toStringAsFixed(currency.decimals)}';
}

String get currencySymbol => ActiveCurrency.current.symbol;
