import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';
import 'currency.dart';

class PaymentMethodsConfig {
  const PaymentMethodsConfig({
    required this.wallet,
    required this.stripe,
    required this.cash,
  });

  factory PaymentMethodsConfig.fromJson(Map<String, dynamic>? json) =>
      PaymentMethodsConfig(
        wallet: json?['wallet'] as bool? ?? false,
        stripe: json?['stripe'] as bool? ?? true,
        cash: json?['cash'] as bool? ?? false,
      );

  final bool wallet;
  final bool stripe;
  final bool cash;

  List<String> get enabledMethods => [
        if (wallet) 'wallet',
        if (stripe) 'stripe',
        if (cash) 'cash',
      ];
}

/// Runtime config from `GET /app-config` (public, no auth).
class AppConfig {
  const AppConfig({
    this.stripePublishableKey,
    required this.customerWalletEnabled,
    required this.paymentMethods,
    this.currency = CurrencyConfig.gbp,
    this.bidMinFareRatio = 0.5,
    this.bidMaxFareRatio = 2,
    this.bidCountersEnabled = true,
    this.parcelOtpEnabled = true,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final currency = CurrencyConfig.fromJson(
      json['currency'] is Map
          ? Map<String, dynamic>.from(json['currency'] as Map)
          : null,
    );
    ActiveCurrency.apply(currency);
    final publishableKey = json['stripePublishableKey']?.toString().trim();
    return AppConfig(
      stripePublishableKey:
          (publishableKey == null || publishableKey.isEmpty) ? null : publishableKey,
      customerWalletEnabled: json['customerWalletEnabled'] == true,
      paymentMethods: PaymentMethodsConfig.fromJson(
        json['paymentMethods'] is Map
            ? Map<String, dynamic>.from(json['paymentMethods'] as Map)
            : null,
      ),
      currency: currency,
      bidMinFareRatio: (json['bidMinFareRatio'] as num?)?.toDouble() ?? 0.5,
      bidMaxFareRatio: (json['bidMaxFareRatio'] as num?)?.toDouble() ?? 2,
      bidCountersEnabled: json['bidCountersEnabled'] != false,
      parcelOtpEnabled: json['parcelOtpEnabled'] != false,
    );
  }

  final String? stripePublishableKey;
  final bool customerWalletEnabled;
  final PaymentMethodsConfig paymentMethods;
  final CurrencyConfig currency;
  final double bidMinFareRatio;
  final double bidMaxFareRatio;
  final bool bidCountersEnabled;
  final bool parcelOtpEnabled;

  bool get walletPaymentEnabled =>
      customerWalletEnabled && paymentMethods.wallet;

  String? get defaultPaymentMethod {
    final methods = paymentMethods.enabledMethods;
    return methods.isEmpty ? null : methods.first;
  }

  static const fallback = AppConfig(
    customerWalletEnabled: false,
    paymentMethods: PaymentMethodsConfig(wallet: false, stripe: true, cash: false),
    currency: CurrencyConfig.gbp,
  );
}

Future<AppConfig> fetchAppConfig() async {
  try {
    final dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {'Accept': 'application/json'},
    ));
    final response = await dio.get<dynamic>('/app-config');
    final body = response.data;
    if (body is! Map) return AppConfig.fallback;
    final map = Map<String, dynamic>.from(body);
    if (map['success'] == false) return AppConfig.fallback;
    final raw = map['data'] is Map ? map['data'] : map;
    if (raw is! Map) return AppConfig.fallback;
    return AppConfig.fromJson(Map<String, dynamic>.from(raw));
  } catch (_) {
    // Network unavailable — use safe defaults.
    return AppConfig.fallback;
  }
}
