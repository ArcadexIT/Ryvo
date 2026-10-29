import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/job/active_job_session.dart';
import '../../../core/payments/stripe_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/app_config.dart';
import '../../../data/models/models.dart';
import '../../../shared/providers/app_providers.dart';

bool checkoutShowsGooglePay(AppConfig config) =>
    defaultTargetPlatform == TargetPlatform.android && config.paymentMethods.stripe;

bool checkoutShowsApplePay(AppConfig config) =>
    defaultTargetPlatform == TargetPlatform.iOS &&
    config.paymentMethods.stripe &&
    AppConstants.appleMerchantId.trim().isNotEmpty;

bool checkoutGooglePayTestEnv(AppConfig config) =>
    (config.stripePublishableKey ?? '').startsWith('pk_test');

bool isBiddingDraft(JobRequestDraft draft) =>
    (draft.activeJob?.jobType ?? draft.jobType) == 'bidding';

class BidOffer {
  const BidOffer({
    required this.min,
    required this.max,
    required this.suggested,
    required this.value,
  });

  final double min;
  final double max;
  final double suggested;
  final double value;
}

BidOffer? bidOfferFor(JobRequestDraft draft, AppConfig config) {
  if (!isBiddingDraft(draft)) return null;
  final suggested = draft.estimate?.estimatedFare ?? draft.activeJob?.estimatedFare ?? 0;
  final min = suggested * config.bidMinFareRatio;
  final maxRaw = suggested * config.bidMaxFareRatio;
  final max = maxRaw <= min ? min + 1 : maxRaw;
  final value = (draft.offeredPrice ?? draft.activeJob?.offeredPrice ?? suggested).clamp(min, max).toDouble();
  return BidOffer(min: min, max: max, suggested: suggested, value: value);
}

bool canEditBidOffer(JobRequestDraft draft, BidOffer? offer) =>
    offer != null && draft.activeJob == null && offer.suggested > 0;

void ensureBidOffer(WidgetRef ref) {
  final draft = ref.read(jobDraftProvider);
  if (!isBiddingDraft(draft) || draft.offeredPrice != null) return;
  final suggested = draft.estimate?.estimatedFare;
  if (suggested == null || suggested <= 0) return;
  ref.read(jobDraftProvider.notifier).state = draft.copyWith(offeredPrice: suggested);
}

void updateBidOffer(WidgetRef ref, double value) {
  ref.read(jobDraftProvider.notifier).state = ref.read(jobDraftProvider).copyWith(offeredPrice: value);
}

double checkoutFare(JobRequestDraft draft, AppConfig config) {
  final offer = bidOfferFor(draft, config);
  if (isBiddingDraft(draft)) {
    return offer?.value ?? draft.offeredPrice ?? draft.activeJob?.offeredPrice ?? draft.estimate?.estimatedFare ?? 0;
  }
  return draft.activeJob?.displayFare ?? draft.estimate?.estimatedFare ?? 0;
}

Future<AppConfig> loadCheckoutConfig(WidgetRef ref) async {
  var config = ref.read(appConfigProvider).valueOrNull;
  if (config == null || (config.stripePublishableKey ?? '').trim().isEmpty) {
    config = await fetchAppConfig();
  }
  return config;
}

Future<bool> detectPlatformPaySupport(AppConfig config, {required bool google}) async {
  await configureStripeFromAppConfig(config);
  return Stripe.instance.isPlatformPaySupported(
    googlePay: google
        ? IsGooglePaySupportedParams(
            testEnv: checkoutGooglePayTestEnv(config),
            existingPaymentMethodRequired: false,
            supportsTapToPay: false,
          )
        : null,
  );
}

/// Charge flow that used to live on the full-screen payment page.
/// Returns the route to open after the dialog closes, or null to stay.
class CustomerCheckout {
  CustomerCheckout(this._ref);

  final WidgetRef _ref;

  Future<AppConfig> _loadConfig() => loadCheckoutConfig(_ref);

  Future<String?> pay({
    required BuildContext context,
    required String selected,
    String? savedCardId,
  }) async {
    final l10n = AppLocalizations.of(context);
    if (selected.isEmpty) {
      showApiError(context, l10n.noPaymentMethodsAreAvailableContactSupport);
      return null;
    }

    final draft = _ref.read(jobDraftProvider);
    if (draft.activeJob == null) {
      if (draft.serviceCategory == null || draft.dropoffLat == null || draft.estimate == null) {
        showApiError(context, l10n.missingServiceDetails);
        return null;
      }
      if (!isPickupLocationReady(draft)) {
        showApiError(context, l10n.confirmYourAssistanceAddressFirst);
        return null;
      }
    }
    // Keep this snapshot. A GPS refresh can replace the draft with
    // "Locating your position…" while the card sheet is open.

    final container = ProviderScope.containerOf(context, listen: false);
    container.read(paymentCheckoutInProgressProvider.notifier).state = true;

    JobModel? job = draft.activeJob;
    var createdThisAttempt = false;
    var providerCharged = false;
    var settled = false;

    Future<JobModel> createJobFromDraft({
      required String paymentMethod,
      String? stripePaymentMethodId,
    }) {
      final config = _ref.read(appConfigProvider).valueOrNull ?? AppConfig.fallback;
      final offer = bidOfferFor(draft, config);
      return _ref.read(jobRepositoryProvider).createJob(
            serviceCategoryId: draft.serviceCategory!.id,
            pickupAddress: draft.pickupAddress,
            pickupLat: draft.pickupLat,
            pickupLng: draft.pickupLng,
            dropoffAddress: draft.dropoffAddress,
            dropoffLat: draft.dropoffLat!,
            dropoffLng: draft.dropoffLng!,
            paymentMethod: paymentMethod,
            stripePaymentMethodId: stripePaymentMethodId,
            customerNotes: draft.customerNotes,
            bookingType: draft.bookingType,
            scheduledAt: draft.scheduledAt,
            jobType: draft.jobType,
            offeredPrice: draft.jobType == 'bidding' ? offer?.value : null,
            recipientName: draft.recipientName,
            recipientPhone: draft.recipientPhone,
            parcelSize: draft.jobType == 'parcel' ? draft.parcelSize : null,
          );
    }

    Future<Map<String, dynamic>> createPaymentIntent(JobModel current) async {
      final intentData = await _ref.read(paymentRepositoryProvider).createIntent(current.id, current.displayFare);
      final clientSecret = intentData['clientSecret'] as String?;
      if (clientSecret == null || clientSecret.isEmpty) {
        throw RyvoStripeConfigException(
          'Card payments are unavailable on the server. Ensure STRIPE_SECRET_KEY is '
          'set in apps/api/.env and restart the API.',
        );
      }
      return intentData;
    }

    Future<void> payWithGooglePay(JobModel current) async {
      final config = await _loadConfig();
      await configureStripeFromAppConfig(config);
      final intentData = await createPaymentIntent(current);
      final clientSecret = intentData['clientSecret'] as String;
      await Stripe.instance.confirmPlatformPayPaymentIntent(
        clientSecret: clientSecret,
        confirmParams: PlatformPayConfirmParams.googlePay(
          googlePay: GooglePayParams(
            testEnv: checkoutGooglePayTestEnv(config),
            merchantCountryCode: 'GB',
            currencyCode: config.currency.code,
            merchantName: 'Ryvo',
          ),
        ),
      );
      providerCharged = true;
      final paymentIntentId = clientSecret.split('_secret_').first;
      await _ref.read(paymentRepositoryProvider).confirmStripePayment(
            current.id,
            paymentIntentId: paymentIntentId,
          );
    }

    Future<void> payWithApplePay(JobModel current) async {
      final config = await _loadConfig();
      await configureStripeFromAppConfig(config);
      final intentData = await createPaymentIntent(current);
      final clientSecret = intentData['clientSecret'] as String;
      final amount = current.displayFare.toStringAsFixed(config.currency.decimals);
      await Stripe.instance.confirmPlatformPayPaymentIntent(
        clientSecret: clientSecret,
        confirmParams: PlatformPayConfirmParams.applePay(
          applePay: ApplePayParams(
            merchantCountryCode: 'GB',
            currencyCode: config.currency.code,
            cartItems: [
              ApplePayCartSummaryItem.immediate(
                label: 'Ryvo',
                amount: amount,
              ),
            ],
          ),
        ),
      );
      providerCharged = true;
      final paymentIntentId = clientSecret.split('_secret_').first;
      await _ref.read(paymentRepositoryProvider).confirmStripePayment(
            current.id,
            paymentIntentId: paymentIntentId,
          );
    }

    Future<void> payWithStripe(JobModel current) async {
      final config = await _loadConfig();
      await configureStripeFromAppConfig(config);
      final intentData = await createPaymentIntent(current);
      final clientSecret = intentData['clientSecret'] as String;
      final customerId = intentData['customerId'] as String?;
      final ephemeralKey = intentData['ephemeralKey'] as String?;
      final canReuseCards = customerId != null &&
          customerId.isNotEmpty &&
          ephemeralKey != null &&
          ephemeralKey.isNotEmpty;

      if (!context.mounted) return;
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          customerId: canReuseCards ? customerId : null,
          customerEphemeralKeySecret: canReuseCards ? ephemeralKey : null,
          merchantDisplayName: l10n.ryvo,
          primaryButtonLabel: l10n.payFindProvider,
          applePay: checkoutShowsApplePay(config) ? const PaymentSheetApplePay(merchantCountryCode: 'GB') : null,
          googlePay: PaymentSheetGooglePay(
            merchantCountryCode: 'GB',
            currencyCode: config.currency.code,
            testEnv: checkoutGooglePayTestEnv(config),
            label: 'Ryvo',
          ),
          linkDisplayParams: const LinkDisplayParams(linkDisplay: LinkDisplay.never),
          style: AppColors.isDark ? ThemeMode.dark : ThemeMode.light,
          appearance: _sheetAppearance(),
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      providerCharged = true;
      final paymentIntentId = clientSecret.split('_secret_').first;
      await _ref.read(paymentRepositoryProvider).confirmStripePayment(
            current.id,
            paymentIntentId: paymentIntentId,
          );
    }

    try {
      if (job != null && !isUnpaidCheckoutJob(job)) {
        return routeForActiveCustomerJobModel(job);
      }

      final keepChargedJob =
          job != null && isUnpaidCheckoutJob(job) && _ref.read(paymentAwaitingConfirmationProvider);
      if (!keepChargedJob) {
        final active = await fetchAndApplyActiveJob(container);
        if (!context.mounted) return null;
        if (active != null && isResumableCustomerJob(active)) {
          if (!isUnpaidCheckoutJob(active)) {
            return routeForActiveCustomerJobModel(active);
          }
          job = active;
        } else {
          job = null;
        }
      }

      if (job == null) {
        container.read(paymentAwaitingConfirmationProvider.notifier).state = false;
        String? savedCard = savedCardId;
        final method = (selected == 'wallet' || selected == 'cash') ? selected : 'stripe';
        if (method == 'stripe' && (savedCard == null || savedCard.isEmpty)) {
          savedCard = await saveCard(context);
        }
        final created = await createJobFromDraft(
          paymentMethod: method,
          stripePaymentMethodId: savedCard,
        );
        createdThisAttempt = true;
        providerCharged = true;
        job = created;
        container.read(jobDraftProvider.notifier).state = container.read(jobDraftProvider).copyWith(
              activeJob: created,
              paymentMethod: selected,
            );
      }

      if (job.status == 'payment_pending') {
        if (selected == 'wallet') {
          await _ref.read(paymentRepositoryProvider).payWithWallet(job.id);
          providerCharged = true;
        } else if (selected == 'cash') {
          await _ref.read(paymentRepositoryProvider).payWithCash(job.id);
          providerCharged = true;
        } else if (selected == 'google_pay') {
          await payWithGooglePay(job);
        } else if (selected == 'apple_pay') {
          await payWithApplePay(job);
        } else {
          await payWithStripe(job);
        }
      } else {
        providerCharged = true;
      }

      final updated = await _ref.read(jobRepositoryProvider).getJob(job.id);
      container.read(jobDraftProvider.notifier).state = container.read(jobDraftProvider).copyWith(
            activeJob: updated,
            paymentMethod: selected,
          );
      _ref.invalidate(walletBalanceProvider);
      _ref.invalidate(walletTransactionsProvider);
      _ref.invalidate(jobsListProvider);
      if (!context.mounted) return null;

      final status = effectiveCustomerJobStatus(updated);
      if (status == 'no_provider_found') {
        container.read(paymentAwaitingConfirmationProvider.notifier).state = false;
        settled = true;
        markJobSessionFinished(container, jobId: updated.id);
        return '/no-providers';
      }
      if (status == 'payment_pending') {
        container.read(paymentAwaitingConfirmationProvider.notifier).state = true;
        showApiError(context, l10n.paymentWasSubmittedButTheJobIsStillAwaitingConfi);
        return null;
      }

      container.read(paymentAwaitingConfirmationProvider.notifier).state = false;
      settled = true;
      // The caller pops this dialog, then go() replaces the booking stack.
      // pushReplacement onto a tab route while earlier pages are still
      // underneath duplicates the shell page key.
      return routeForActiveCustomerJob(status);
    } on StripeException catch (e) {
      if (!context.mounted) return null;
      if (e.error.code != FailureCode.Canceled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.error.localizedMessage ?? l10n.paymentFailedPleaseTryAgain,
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return null;
    } catch (e) {
      if (context.mounted) showApiError(context, e);
      return null;
    } finally {
      container.read(paymentCheckoutInProgressProvider.notifier).state = false;
      if (!settled && createdThisAttempt && job != null && !providerCharged) {
        await abandonUnpaidCheckoutJob(container, job, force: true);
      }
    }
  }

  Future<String> saveCard(BuildContext context) async {
    final config = await _loadConfig();
    await configureStripeFromAppConfig(config);
    final intentData = await _ref.read(paymentRepositoryProvider).createSetupIntent();
    final clientSecret = intentData['clientSecret'] as String?;
    if (clientSecret == null || clientSecret.isEmpty) {
      throw RyvoStripeConfigException(
        'Card setup is unavailable. Set STRIPE_SECRET_KEY and restart the API.',
      );
    }
    final customerId = intentData['customerId'] as String?;
    final ephemeralKey = intentData['ephemeralKey'] as String?;
    if (!context.mounted) {
      throw RyvoStripeConfigException('Card setup was interrupted.');
    }
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        setupIntentClientSecret: clientSecret,
        customerId: customerId,
        customerEphemeralKeySecret: ephemeralKey,
        merchantDisplayName: 'Ryvo',
        primaryButtonLabel: 'Save card',
        applePay: checkoutShowsApplePay(config) ? const PaymentSheetApplePay(merchantCountryCode: 'GB') : null,
        googlePay: PaymentSheetGooglePay(
          merchantCountryCode: 'GB',
          currencyCode: config.currency.code,
          testEnv: checkoutGooglePayTestEnv(config),
          label: 'Ryvo',
        ),
        style: AppColors.isDark ? ThemeMode.dark : ThemeMode.light,
        appearance: _sheetAppearance(),
      ),
    );
    await Stripe.instance.presentPaymentSheet();
    final setup = await Stripe.instance.retrieveSetupIntent(clientSecret);
    if (setup.paymentMethodId.isEmpty) {
      throw RyvoStripeConfigException('No card was saved.');
    }
    return setup.paymentMethodId;
  }

  /// Closes an unpaid checkout the way the payment page back button did.
  /// Returns false when the dialog must stay open.
  Future<bool> abandonIfDismissed(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final job = _ref.read(jobDraftProvider).activeJob;
    if (job != null &&
        shouldAbandonUnpaidCheckout(
          job: job,
          checkoutInProgress: _ref.read(paymentCheckoutInProgressProvider),
          awaitingConfirmation: _ref.read(paymentAwaitingConfirmationProvider),
          awaitingJobId: job.id,
        )) {
      final removed = await abandonUnpaidCheckoutJob(container, job);
      if (!context.mounted) return false;
      if (!removed) {
        showApiError(context, AppLocalizations.of(context).couldNotCancelUnpaidRequest);
        return false;
      }
    }
    return context.mounted;
  }
}

PaymentSheetAppearance _sheetAppearance() {
  const ink = Color(0xFF111827);
  const muted = Color(0xFF6B7280);
  const line = Color(0xFFE5E7EB);
  const button = PaymentSheetPrimaryButtonThemeColors(
    background: AppColors.primary,
    text: Colors.white,
    border: AppColors.primary,
    successBackgroundColor: AppColors.success,
    successTextColor: Colors.white,
  );
  return PaymentSheetAppearance(
    colors: PaymentSheetAppearanceColors(
      primary: AppColors.primary,
      background: AppColors.background,
      componentBackground: AppColors.surface,
      componentBorder: line,
      componentDivider: line,
      componentText: ink,
      primaryText: ink,
      secondaryText: muted,
      placeholderText: AppColors.textHint,
      icon: ink,
      error: AppColors.error,
    ),
    shapes: const PaymentSheetShape(
      borderRadius: 20,
      borderWidth: 1,
    ),
    primaryButton: const PaymentSheetPrimaryButtonAppearance(
      colors: PaymentSheetPrimaryButtonTheme(light: button, dark: button),
      shapes: PaymentSheetPrimaryButtonShape(borderWidth: 0, blurRadius: 0),
    ),
  );
}
