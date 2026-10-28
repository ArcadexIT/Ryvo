import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/job/active_job_session.dart';
import '../../../../core/payments/stripe_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/app_config.dart';
import '../../../../data/models/models.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

class PaymentSelectorPage extends ConsumerStatefulWidget {
  const PaymentSelectorPage({super.key});

  @override
  ConsumerState<PaymentSelectorPage> createState() =>
      _PaymentSelectorPageState();
}

class _PaymentSelectorPageState extends ConsumerState<PaymentSelectorPage> {
  String? _selected;
  bool _loading = false;
  bool _googlePayReady = false;
  bool _applePayReady = false;
  bool _providerCharged = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_preparePayments);
  }

  bool _showGooglePay(AppConfig config) =>
      defaultTargetPlatform == TargetPlatform.android &&
      config.paymentMethods.stripe;

  bool _showApplePay(AppConfig config) =>
      defaultTargetPlatform == TargetPlatform.iOS &&
      config.paymentMethods.stripe &&
      AppConstants.appleMerchantId.trim().isNotEmpty;

  bool _googlePayTestEnv(AppConfig config) =>
      (config.stripePublishableKey ?? '').startsWith('pk_test');

  void _initSelection() {
    final config =
        ref.read(appConfigProvider).valueOrNull ?? AppConfig.fallback;
    final draftMethod = ref.read(jobDraftProvider).paymentMethod;
    final enabled = _enabledMethods(config);

    String? selected;
    if (draftMethod == 'wallet' || draftMethod == 'cash') {
      selected = enabled.contains(draftMethod) ? draftMethod : null;
    } else if (enabled.contains('google_pay')) {
      selected = 'google_pay';
    } else if (enabled.contains('apple_pay')) {
      selected = 'apple_pay';
    } else if (enabled.contains(draftMethod)) {
      selected = draftMethod;
    }
    selected ??= enabled.isNotEmpty ? enabled.first : null;

    if (!mounted) return;
    setState(() => _selected = selected);
  }

  List<String> _enabledMethods(AppConfig config) => [
        if (config.walletPaymentEnabled) 'wallet',
        if (_showGooglePay(config)) 'google_pay',
        if (_showApplePay(config)) 'apple_pay',
        if (config.paymentMethods.stripe) 'stripe',
        if (config.paymentMethods.cash) 'cash',
      ];

  Future<AppConfig> _loadConfig() async {
    var config = ref.read(appConfigProvider).valueOrNull;
    if (config == null || (config.stripePublishableKey ?? '').trim().isEmpty) {
      config = await fetchAppConfig();
    }
    return config;
  }

  void _ensureOfferPrice() {
    final draft = ref.read(jobDraftProvider);
    if (!_isBiddingDraft(draft) || draft.offeredPrice != null) return;
    final suggested = draft.estimate?.estimatedFare;
    if (suggested == null || suggested <= 0) return;
    ref.read(jobDraftProvider.notifier).state =
        draft.copyWith(offeredPrice: suggested);
  }

  bool _isBiddingDraft(JobRequestDraft draft) =>
      (draft.activeJob?.jobType ?? draft.jobType) == 'bidding';

  ({double min, double max, double suggested, double value}) _offerBounds(
    JobRequestDraft draft,
    AppConfig config,
  ) {
    final suggested =
        draft.estimate?.estimatedFare ?? draft.activeJob?.estimatedFare ?? 0;
    final min = suggested * config.bidMinFareRatio;
    final maxRaw = suggested * config.bidMaxFareRatio;
    final max = maxRaw <= min ? min + 1 : maxRaw;
    final value = (draft.offeredPrice ??
            draft.activeJob?.offeredPrice ??
            suggested)
        .clamp(min, max)
        .toDouble();
    return (min: min, max: max, suggested: suggested, value: value);
  }

  void _setOfferPrice(double value) {
    ref.read(jobDraftProvider.notifier).state =
        ref.read(jobDraftProvider).copyWith(offeredPrice: value);
  }

  Future<void> _preparePayments() async {
    _initSelection();
    _ensureOfferPrice();
    final config =
        ref.read(appConfigProvider).valueOrNull ?? AppConfig.fallback;
    final checkGoogle = _showGooglePay(config);
    final checkApple = _showApplePay(config);
    if (!checkGoogle && !checkApple) return;
    try {
      final readyConfig = await _loadConfig();
      await configureStripeFromAppConfig(readyConfig);
      final supported = await Stripe.instance.isPlatformPaySupported(
        googlePay: checkGoogle
            ? IsGooglePaySupportedParams(
                testEnv: _googlePayTestEnv(readyConfig),
                existingPaymentMethodRequired: false,
                supportsTapToPay: false,
              )
            : null,
      );
      if (!mounted) return;
      final draftMethod = ref.read(jobDraftProvider).paymentMethod;
      setState(() {
        if (checkGoogle) _googlePayReady = supported;
        if (checkApple) _applePayReady = supported;
        if (supported &&
            draftMethod != 'stripe' &&
            (_selected == null || _selected == 'stripe')) {
          _selected = checkApple ? 'apple_pay' : 'google_pay';
        }
      });
    } catch (_) {}
  }

  Future<JobModel> _createJobFromDraft({
    required JobRequestDraft draft,
    required String paymentMethod,
    String? stripePaymentMethodId,
  }) {
    return ref.read(jobRepositoryProvider).createJob(
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
          offeredPrice: draft.jobType == 'bidding'
              ? _offerBounds(
                  draft,
                  ref.read(appConfigProvider).valueOrNull ?? AppConfig.fallback,
                ).value
              : null,
          recipientName: draft.recipientName,
          recipientPhone: draft.recipientPhone,
          parcelSize: draft.jobType == 'parcel' ? draft.parcelSize : null,
        );
  }

  Future<String> _saveCard() async {
    final config = await _loadConfig();
    await configureStripeFromAppConfig(config);
    final intentData =
        await ref.read(paymentRepositoryProvider).createSetupIntent();
    final clientSecret = intentData['clientSecret'] as String?;
    if (clientSecret == null || clientSecret.isEmpty) {
      throw RyvoStripeConfigException(
        'Card setup is unavailable. Set STRIPE_SECRET_KEY and restart the API.',
      );
    }
    final customerId = intentData['customerId'] as String?;
    final ephemeralKey = intentData['ephemeralKey'] as String?;
    if (!mounted) {
      throw RyvoStripeConfigException('Card setup was interrupted.');
    }
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        setupIntentClientSecret: clientSecret,
        customerId: customerId,
        customerEphemeralKeySecret: ephemeralKey,
        merchantDisplayName: 'Ryvo',
        primaryButtonLabel: 'Save card',
        applePay: _showApplePay(config)
            ? const PaymentSheetApplePay(merchantCountryCode: 'GB')
            : null,
        googlePay: PaymentSheetGooglePay(
          merchantCountryCode: 'GB',
          currencyCode: config.currency.code,
          testEnv: _googlePayTestEnv(config),
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

  Future<void> _pay() async {
    final selected = _selected;
    if (selected == null) {
      showApiError(
          context,
          AppLocalizations.of(context)
              .noPaymentMethodsAreAvailableContactSupport);
      return;
    }

    final draft = ref.read(jobDraftProvider);
    if (draft.activeJob == null) {
      if (draft.serviceCategory == null ||
          draft.dropoffLat == null ||
          draft.estimate == null) {
        showApiError(
            context, AppLocalizations.of(context).missingServiceDetails);
        return;
      }
      if (!isPickupLocationReady(draft)) {
        showApiError(context,
            AppLocalizations.of(context).confirmYourAssistanceAddressFirst);
        return;
      }
    }
    // Keep this snapshot. A GPS refresh can replace the draft with
    // "Locating your position…" while the card sheet is open.

    setState(() => _loading = true);
    _providerCharged = false;
    final container = ProviderScope.containerOf(context, listen: false);
    container.read(paymentCheckoutInProgressProvider.notifier).state = true;

    JobModel? job = draft.activeJob;
    var createdThisAttempt = false;
    var settled = false;

    try {
      if (job != null && !isUnpaidCheckoutJob(job)) {
        context.go(routeForActiveCustomerJobModel(job));
        return;
      }

      final keepChargedJob = job != null &&
          isUnpaidCheckoutJob(job) &&
          ref.read(paymentAwaitingConfirmationProvider);
      if (!keepChargedJob) {
        final active = await fetchAndApplyActiveJob(container);
        if (!mounted) return;
        if (active != null && isResumableCustomerJob(active)) {
          if (!isUnpaidCheckoutJob(active)) {
            context.go(routeForActiveCustomerJobModel(active));
            return;
          }
          job = active;
        } else {
          job = null;
        }
      }

      if (job == null) {
        container.read(paymentAwaitingConfirmationProvider.notifier).state =
            false;
        String? savedCard;
        final method =
            (selected == 'wallet' || selected == 'cash') ? selected : 'stripe';
        if (method == 'stripe') {
          savedCard = await _saveCard();
        }
        final created = await _createJobFromDraft(
          draft: draft,
          paymentMethod: method,
          stripePaymentMethodId: savedCard,
        );
        createdThisAttempt = true;
        _providerCharged = true;
        job = created;
        container.read(jobDraftProvider.notifier).state =
            container.read(jobDraftProvider).copyWith(
                  activeJob: created,
                  paymentMethod: selected,
                );
      }

      if (job.status == 'payment_pending') {
        if (selected == 'wallet') {
          await ref.read(paymentRepositoryProvider).payWithWallet(job.id);
          _providerCharged = true;
        } else if (selected == 'cash') {
          await ref.read(paymentRepositoryProvider).payWithCash(job.id);
          _providerCharged = true;
        } else if (selected == 'google_pay') {
          await _payWithGooglePay(job);
        } else if (selected == 'apple_pay') {
          await _payWithApplePay(job);
        } else {
          await _payWithStripe(job);
        }
      } else {
        _providerCharged = true;
      }

      final updated = await ref.read(jobRepositoryProvider).getJob(job.id);
      container.read(jobDraftProvider.notifier).state =
          container.read(jobDraftProvider).copyWith(
                activeJob: updated,
                paymentMethod: selected,
              );
      ref.invalidate(walletBalanceProvider);
      ref.invalidate(walletTransactionsProvider);
      ref.invalidate(jobsListProvider);
      if (!mounted) return;

      final status = effectiveCustomerJobStatus(updated);
      if (status == 'no_provider_found') {
        container.read(paymentAwaitingConfirmationProvider.notifier).state =
            false;
        settled = true;
        markJobSessionFinished(container, jobId: updated.id);
        context.go('/no-providers');
        return;
      }
      if (status == 'payment_pending') {
        container.read(paymentAwaitingConfirmationProvider.notifier).state =
            true;
        showApiError(
          context,
          AppLocalizations.of(context)
              .paymentWasSubmittedButTheJobIsStillAwaitingConfi,
        );
        return;
      }

      container.read(paymentAwaitingConfirmationProvider.notifier).state =
          false;
      settled = true;
      // Replace the whole stack. pushReplacement onto a tab route (such as
      // /home) while earlier booking pages are still underneath duplicates
      // the shell page key and crashes the navigator.
      context.go(routeForActiveCustomerJob(status));
    } on StripeException catch (e) {
      if (!mounted) return;
      if (e.error.code != FailureCode.Canceled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.error.localizedMessage ??
                  AppLocalizations.of(context).paymentFailedPleaseTryAgain,
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      container.read(paymentCheckoutInProgressProvider.notifier).state = false;
      if (!settled && createdThisAttempt && job != null && !_providerCharged) {
        await abandonUnpaidCheckoutJob(container, job, force: true);
      }
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _payWithGooglePay(JobModel job) async {
    final config = await _loadConfig();
    await configureStripeFromAppConfig(config);
    final intentData = await _createPaymentIntent(job);
    final clientSecret = intentData['clientSecret'] as String;
    await Stripe.instance.confirmPlatformPayPaymentIntent(
      clientSecret: clientSecret,
      confirmParams: PlatformPayConfirmParams.googlePay(
        googlePay: GooglePayParams(
          testEnv: _googlePayTestEnv(config),
          merchantCountryCode: 'GB',
          currencyCode: config.currency.code,
          merchantName: 'Ryvo',
        ),
      ),
    );
    _providerCharged = true;
    final paymentIntentId = clientSecret.split('_secret_').first;
    await ref.read(paymentRepositoryProvider).confirmStripePayment(
          job.id,
          paymentIntentId: paymentIntentId,
        );
  }

  Future<void> _payWithApplePay(JobModel job) async {
    final config = await _loadConfig();
    await configureStripeFromAppConfig(config);
    final intentData = await _createPaymentIntent(job);
    final clientSecret = intentData['clientSecret'] as String;
    final amount = job.displayFare.toStringAsFixed(config.currency.decimals);
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
    _providerCharged = true;
    final paymentIntentId = clientSecret.split('_secret_').first;
    await ref.read(paymentRepositoryProvider).confirmStripePayment(
          job.id,
          paymentIntentId: paymentIntentId,
        );
  }

  Future<Map<String, dynamic>> _createPaymentIntent(JobModel job) async {
    final intentData = await ref
        .read(paymentRepositoryProvider)
        .createIntent(job.id, job.displayFare);
    final clientSecret = intentData['clientSecret'] as String?;
    if (clientSecret == null || clientSecret.isEmpty) {
      throw RyvoStripeConfigException(
        'Card payments are unavailable on the server. Ensure STRIPE_SECRET_KEY is '
        'set in apps/api/.env and restart the API.',
      );
    }
    return intentData;
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

  Future<void> _payWithStripe(JobModel job) async {
    final l10n = AppLocalizations.of(context);
    final merchantName = l10n.ryvo;
    final payLabel = l10n.payFindProvider;
    final config = await _loadConfig();
    await configureStripeFromAppConfig(config);

    final intentData = await _createPaymentIntent(job);
    final clientSecret = intentData['clientSecret'] as String;

    final customerId = intentData['customerId'] as String?;
    final ephemeralKey = intentData['ephemeralKey'] as String?;
    final canReuseCards = customerId != null &&
        customerId.isNotEmpty &&
        ephemeralKey != null &&
        ephemeralKey.isNotEmpty;

    if (!mounted) return;
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        customerId: canReuseCards ? customerId : null,
        customerEphemeralKeySecret: canReuseCards ? ephemeralKey : null,
        merchantDisplayName: merchantName,
        primaryButtonLabel: payLabel,
        applePay: _showApplePay(config)
            ? const PaymentSheetApplePay(merchantCountryCode: 'GB')
            : null,
        googlePay: PaymentSheetGooglePay(
          merchantCountryCode: 'GB',
          currencyCode: config.currency.code,
          testEnv: _googlePayTestEnv(config),
          label: 'Ryvo',
        ),
        linkDisplayParams: const LinkDisplayParams(
          linkDisplay: LinkDisplay.never,
        ),
        style: AppColors.isDark ? ThemeMode.dark : ThemeMode.light,
        appearance: _sheetAppearance(),
      ),
    );

    await Stripe.instance.presentPaymentSheet();
    _providerCharged = true;

    final paymentIntentId = clientSecret.split('_secret_').first;
    await ref.read(paymentRepositoryProvider).confirmStripePayment(
          job.id,
          paymentIntentId: paymentIntentId,
        );
  }

  Future<void> _handleBack() async {
    if (_loading) return;
    final container = ProviderScope.containerOf(context, listen: false);
    final job = ref.read(jobDraftProvider).activeJob;
    if (job != null &&
        shouldAbandonUnpaidCheckout(
          job: job,
          checkoutInProgress: ref.read(paymentCheckoutInProgressProvider),
          awaitingConfirmation: ref.read(paymentAwaitingConfirmationProvider),
          awaitingJobId: job.id,
        )) {
      setState(() => _loading = true);
      final removed = await abandonUnpaidCheckoutJob(container, job);
      if (!mounted) return;
      setState(() => _loading = false);
      if (!removed) {
        showApiError(
            context, AppLocalizations.of(context).couldNotCancelUnpaidRequest);
        return;
      }
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/price-estimate');
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(jobDraftProvider);
    final config =
        ref.watch(appConfigProvider).valueOrNull ?? AppConfig.fallback;
    final job = draft.activeJob;
    final balance = ref.watch(walletBalanceProvider).valueOrNull?.balance ?? 0;
    final bidding = _isBiddingDraft(draft);
    final offer = bidding ? _offerBounds(draft, config) : null;
    final amount = bidding
        ? (offer?.value ??
            draft.offeredPrice ??
            job?.offeredPrice ??
            draft.estimate?.estimatedFare ??
            0)
        : (job?.displayFare ?? draft.estimate?.estimatedFare ?? 0);
    final canEditOffer = bidding && job == null && (offer?.suggested ?? 0) > 0;
    final serviceName = draft.serviceCategory?.name ??
        job?.serviceCategory?.name ??
        AppLocalizations.of(context).service;
    final enabled = _enabledMethods(config);
    final selected = _selected;

    if (enabled.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(AppLocalizations.of(context).securePayment,
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              AppLocalizations.of(context)
                  .noPaymentMethodsAreCurrentlyAvailablePleaseTryAg,
              style: GoogleFonts.poppins(
                  fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text('Payment',
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.w700)),
          leading: IconButton(
            onPressed: _loading ? null : _handleBack,
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(serviceName,
                                style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                            Text(
                              bidding
                                  ? 'Your bid offer'
                                  : (job?.jobNumber ?? ''),
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Text(formatMoney(amount),
                          style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary)),
                    ],
                  ),
                ),
                if (offer != null && offer.suggested > 0) ...[
                  const SizedBox(height: 12),
                  _BidOfferCard(
                    suggested: offer.suggested,
                    min: offer.min,
                    max: offer.max,
                    value: offer.value,
                    enabled: canEditOffer && !_loading,
                    onChanged: _setOfferPrice,
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  bidding
                      ? 'Drivers can accept your offer or send a counter. Nothing is charged until a driver is matched.'
                      : selected == 'cash'
                          ? AppLocalizations.of(context)
                              .youWillPayTheProviderInCashWhenTheServiceIsCompl
                          : AppLocalizations.of(context)
                              .fundsAreHeldSecurelyUntilYourServiceIsCompletedI,
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.5),
                ),
                const SizedBox(height: 24),
                Text('Payment methods',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (config.walletPaymentEnabled) ...[
                        _PaymentCard(
                          icon: Icons.account_balance_wallet,
                          title: AppLocalizations.of(context).wallet,
                          subtitle: 'Balance: ${formatMoney(balance)}',
                          badge: enabled.first == 'wallet'
                              ? AppLocalizations.of(context).recommended
                              : null,
                          color: AppColors.primary,
                          isSelected: selected == 'wallet',
                          onTap: () => setState(() => _selected = 'wallet'),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_showGooglePay(config)) ...[
                        _PaymentCard(
                          icon: Icons.contactless,
                          title: AppLocalizations.of(context).googlePay,
                          subtitle: AppLocalizations.of(context)
                              .payWithCardsInGoogleWallet,
                          badge: _googlePayReady
                              ? AppLocalizations.of(context).recommended
                              : null,
                          color: const Color(0xFF111827),
                          isSelected: selected == 'google_pay',
                          onTap: () =>
                              setState(() => _selected = 'google_pay'),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_showApplePay(config)) ...[
                        _PaymentCard(
                          icon: Icons.apple,
                          title: AppLocalizations.of(context).applePay,
                          subtitle:
                              AppLocalizations.of(context).payWithApplePay,
                          badge: _applePayReady
                              ? AppLocalizations.of(context).recommended
                              : null,
                          color: const Color(0xFF111827),
                          isSelected: selected == 'apple_pay',
                          onTap: () =>
                              setState(() => _selected = 'apple_pay'),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (config.paymentMethods.stripe) ...[
                        _PaymentCard(
                          icon: Icons.credit_card,
                          title: AppLocalizations.of(context).cardStripe,
                          subtitle: AppLocalizations.of(context)
                              .paySecurelyWithYourCard,
                          color: AppColors.info,
                          isSelected: selected == 'stripe',
                          onTap: () => setState(() => _selected = 'stripe'),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (config.paymentMethods.cash)
                        _PaymentCard(
                          icon: Icons.payments_outlined,
                          title: AppLocalizations.of(context).cash,
                          subtitle: AppLocalizations.of(context)
                              .payTheProviderWhenServiceCompletes,
                          color: AppColors.success,
                          isSelected: selected == 'cash',
                          onTap: () => setState(() => _selected = 'cash'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (selected == 'google_pay' || selected == 'apple_pay')
                  _WalletPayButton(loading: _loading, onPressed: _pay)
                else
                  RyvoButton(
                    label: _loading
                        ? AppLocalizations.of(context).processing
                        : selected == 'cash'
                            ? AppLocalizations.of(context).confirmFindProvider
                            : AppLocalizations.of(context).payFindProvider,
                    sublabel: selected == 'cash'
                        ? AppLocalizations.of(context)
                            .payCashToYourProviderOnCompletion
                        : bidding
                            ? 'Hold ${formatMoney(amount)} and find a driver'
                            : AppLocalizations.of(context)
                                .securePaymentBeforeMatching,
                    prefixIcon: Icon(
                      selected == 'wallet'
                          ? Icons.account_balance_wallet
                          : selected == 'cash'
                              ? Icons.payments_outlined
                              : Icons.credit_card,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: _loading || selected == null ? null : _pay,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BidOfferCard extends StatelessWidget {
  final double suggested;
  final double min;
  final double max;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _BidOfferCard({
    required this.suggested,
    required this.min,
    required this.max,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gavel_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Set your offer',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                formatMoney(value),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Suggested fare ${formatMoney(suggested)}',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.divider,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.12),
              trackHeight: 4,
            ),
            child: Slider(
              min: min,
              max: max,
              value: value.clamp(min, max),
              onChanged: enabled ? onChanged : null,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatMoney(min),
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
              Text(
                formatMoney(max),
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletPayButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;

  const _WalletPayButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 54,
          width: double.infinity,
          child: AbsorbPointer(
            absorbing: loading,
            child: PlatformPayButton(
              type: defaultTargetPlatform == TargetPlatform.iOS
                  ? PlatformButtonType.buy
                  : PlatformButtonType.pay,
              appearance: PlatformButtonStyle.black,
              borderRadius: 14,
              onPressed: onPressed,
            ),
          ),
        ),
        if (loading) ...[
          const SizedBox(height: 10),
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected ? color : AppColors.divider,
              width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(badge!,
                              style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                        ),
                      ],
                    ],
                  ),
                  Text(subtitle,
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.primary : AppColors.grey400,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
