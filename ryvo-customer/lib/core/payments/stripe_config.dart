import 'package:flutter_stripe/flutter_stripe.dart';

import '../constants/app_constants.dart';
import '../../data/models/app_config.dart';

const stripeUrlScheme = 'ryvo';

class RyvoStripeConfigException implements Exception {
  RyvoStripeConfigException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Applies Stripe SDK settings from [config] (or dart-define fallback).
/// Call before [Stripe.instance.initPaymentSheet] / presentPaymentSheet.
Future<void> configureStripeFromAppConfig(AppConfig config) async {
  final fromApi = config.stripePublishableKey?.trim() ?? '';
  final key = fromApi.isNotEmpty
      ? fromApi
      : AppConstants.stripePublishableKeyFallback.trim();

  if (key.isEmpty) {
    throw RyvoStripeConfigException(
      'Card payments are not configured yet. Ask your admin to enable card '
      'payments and set the Stripe publishable key in Settings → Billing.',
    );
  }

  Stripe.publishableKey = key;
  Stripe.urlScheme = stripeUrlScheme;
  final merchantId = AppConstants.appleMerchantId.trim();
  if (merchantId.isNotEmpty) {
    Stripe.merchantIdentifier = merchantId;
  }
  await Stripe.instance.applySettings();
}
