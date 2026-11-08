import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:intl/intl.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/app_config.dart';
import '../../../../data/models/models.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/ryvo_bottom_up_page_route.dart';
import '../../../../shared/widgets/ryvo_button.dart';
import '../../../../shared/widgets/ryvo_close_button.dart';
import '../../../service_request/presentation/widgets/bid_controls.dart';
import '../../../wallet/presentation/pages/top_up_page.dart';
import '../customer_checkout.dart';

/// "Payment options": slides up full-screen and returns the chosen method when
/// Done is tapped, or null when the close button is used.
Future<String?> showRyvoPaymentOptions(
  BuildContext context, {
  required String? selected,
  required List<String> methods,
}) {
  return Navigator.of(context).push<String>(
    RyvoBottomUpPageRoute<String>(
      builder: (_) => PaymentOptionsPage(selected: selected, methods: methods),
    ),
  );
}

/// Final checkout: the same full-screen page with the fare, the bid offer and
/// the pay button. Returns the route to open after a successful charge.
Future<String?> showRyvoCheckout(BuildContext context) {
  return Navigator.of(context).push<String>(
    RyvoBottomUpPageRoute<String>(
      builder: (_) => const PaymentOptionsPage(
        selected: null,
        methods: [],
        checkout: true,
      ),
    ),
  );
}

class PaymentOptionsPage extends ConsumerStatefulWidget {
  const PaymentOptionsPage({
    super.key,
    required this.selected,
    required this.methods,
    this.checkout = false,
  });

  final String? selected;
  final List<String> methods;
  final bool checkout;

  @override
  ConsumerState<PaymentOptionsPage> createState() => _PaymentOptionsPageState();
}

class _PaymentOptionsPageState extends ConsumerState<PaymentOptionsPage> {
  late String? _selected;
  String? _savedCardId;
  bool _loading = false;
  bool _closing = false;
  bool _googlePayReady = false;
  bool _applePayReady = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
    Future.microtask(_prepare);
  }

  Future<void> _prepare() async {
    if (widget.checkout) {
      ensureBidOffer(ref);
      _initCheckoutSelection();
    }
    final config =
        ref.read(appConfigProvider).valueOrNull ?? AppConfig.fallback;
    final checkGoogle = checkoutShowsGooglePay(config);
    final checkApple = checkoutShowsApplePay(config);
    if (!checkGoogle && !checkApple) return;
    try {
      final readyConfig = await loadCheckoutConfig(ref);
      final supported =
          await detectPlatformPaySupport(readyConfig, google: checkGoogle);
      if (!mounted) return;
      final draftMethod = ref.read(jobDraftProvider).paymentMethod;
      setState(() {
        if (checkGoogle) _googlePayReady = supported;
        if (checkApple) _applePayReady = supported;
        if (widget.checkout &&
            supported &&
            draftMethod != 'stripe' &&
            (_selected == null || _selected == 'stripe')) {
          _selected = checkApple ? 'apple_pay' : 'google_pay';
        }
      });
    } catch (_) {}
  }

  void _initCheckoutSelection() {
    final config =
        ref.read(appConfigProvider).valueOrNull ?? AppConfig.fallback;
    final draftMethod = ref.read(jobDraftProvider).paymentMethod;
    final enabled = _methods(config);
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

  Future<void> _pay() async {
    final selected = _selected;
    if (selected == null || _loading) return;
    setState(() => _loading = true);
    final route = await CustomerCheckout(ref).pay(
      context: context,
      selected: selected,
      savedCardId: _savedCardId,
    );
    if (!mounted) return;
    if (route != null) {
      _popPage(route);
      return;
    }
    setState(() => _loading = false);
  }

  void _popPage(String? result) {
    setState(() => _closing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, result);
    });
  }

  Future<void> _addCard() async {
    if (_loading) return;
    final methods = _methods(
      ref.read(appConfigProvider).valueOrNull ?? AppConfig.fallback,
    );
    if (!methods.contains('stripe')) return;
    setState(() => _loading = true);
    try {
      final id = await CustomerCheckout(ref).saveCardForLater(context);
      if (!mounted || id == null) return;
      setState(() {
        _savedCardId = id;
        _selected = 'stripe';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _dismissCheckout() async {
    if (_loading) return;
    setState(() => _loading = true);
    final allow = await CustomerCheckout(ref).abandonIfDismissed(context);
    if (!mounted) return;
    if (!allow) {
      setState(() => _loading = false);
      return;
    }
    _popPage(null);
  }

  Future<void> _topUp() async {
    await Navigator.of(context).push<void>(
      RyvoBottomUpPageRoute<void>(builder: (_) => const TopUpPage()),
    );
    if (!mounted) return;
    ref.invalidate(walletBalanceProvider);
  }

  /// Wallet credit switch: on selects the wallet, off falls back to the first
  /// other method.
  void _setWalletCredit(bool on, List<String> methods) {
    HapticFeedback.selectionClick();
    setState(() {
      if (on) {
        _selected = 'wallet';
      } else {
        _selected = methods.firstWhere(
          (method) => method != 'wallet',
          orElse: () => 'wallet',
        );
      }
    });
  }

  void _select(String method) {
    if (_loading || _selected == method) return;
    HapticFeedback.selectionClick();
    setState(() => _selected = method);
  }

  /// Platform pay first, then Cash, Card and Wallet.
  List<String> _methods(AppConfig config) {
    final base = widget.checkout
        ? <String>[
            if (config.walletPaymentEnabled) 'wallet',
            if (config.paymentMethods.stripe) 'stripe',
            if (config.paymentMethods.cash) 'cash',
          ]
        : widget.methods
            .where((method) => method != 'google_pay' && method != 'apple_pay')
            .toList();
    final available = <String>{
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          config.paymentMethods.stripe &&
          AppConstants.appleMerchantId.trim().isNotEmpty)
        'apple_pay',
      if (defaultTargetPlatform == TargetPlatform.android &&
          config.paymentMethods.stripe)
        'google_pay',
      ...base,
    };
    const order = ['apple_pay', 'google_pay', 'cash', 'stripe', 'wallet'];
    return order.where(available.contains).toList();
  }

  String? _badgeFor(String method, {required bool walletEnabled}) {
    final l10n = AppLocalizations.of(context);
    if (method == 'google_pay' && _googlePayReady) return l10n.recommended;
    if (method == 'apple_pay' && _applePayReady) return l10n.recommended;
    return null;
  }

  String _titleFor(AppLocalizations l10n, String method) {
    return switch (method) {
      'wallet' => 'Ryvo balance',
      'cash' => l10n.cash,
      'google_pay' => l10n.googlePay,
      'apple_pay' => l10n.applePay,
      _ => l10n.card,
    };
  }

  String _subtitleFor(String method, double balance) {
    final l10n = AppLocalizations.of(context);
    return switch (method) {
      'wallet' => 'Balance ${formatMoney(balance)}',
      'google_pay' => l10n.payWithCardsInGoogleWallet,
      'apple_pay' => l10n.payWithApplePay,
      'cash' => l10n.payTheProviderWhenServiceCompletes,
      _ => l10n.paySecurelyWithYourCard,
    };
  }

  String _chargeNote(
    AppLocalizations l10n, {
    required bool bidding,
    required String? selected,
  }) {
    if (bidding) {
      return 'Drivers can accept your offer or send a counter. Nothing is charged until a driver is matched.';
    }
    if (selected == 'cash') {
      return l10n.youWillPayTheProviderInCashWhenTheServiceIsCompl;
    }
    return l10n.fundsAreHeldSecurelyUntilYourServiceIsCompletedI;
  }

  @override
  Widget build(BuildContext context) {
    final config =
        ref.watch(appConfigProvider).valueOrNull ?? AppConfig.fallback;
    final balanceAsync = ref.watch(walletBalanceProvider);
    final balance = balanceAsync.valueOrNull?.balance ?? 0;
    final draft = ref.watch(jobDraftProvider);
    final methods = _methods(config);
    final l10n = AppLocalizations.of(context);
    final offer = widget.checkout ? bidOfferFor(draft, config) : null;
    final fare = checkoutFare(draft, config);
    final serviceName = draft.serviceCategory?.name ??
        draft.activeJob?.serviceCategory?.name ??
        l10n.service;
    final selected = _selected;
    final walletAvailable = methods.contains('wallet');

    return PopScope(
      canPop: _closing || (!widget.checkout && !_loading),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !widget.checkout || _loading) return;
        _dismissCheckout();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          leading: const RyvoCloseButton(),
          title: Text(
            widget.checkout ? 'Checkout' : 'Payment options',
            style: RyvoTypography.heading(color: AppColors.textPrimary),
          ),
          bottom: _loading
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.primary,
                    backgroundColor: Colors.transparent,
                  ),
                )
              : null,
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (widget.checkout) ...[
                    _FareSummary(
                      serviceName: serviceName,
                      fare: fare,
                      note: isBiddingDraft(draft)
                          ? 'Your bid offer'
                          : (draft.activeJob?.jobNumber ?? ''),
                    ),
                    if (offer != null && offer.suggested > 0)
                      IgnorePointer(
                        ignoring: !canEditBidOffer(draft, offer) || _loading,
                        child: BidControls(
                          suggested: offer.suggested,
                          min: offer.min,
                          max: offer.max,
                          value: offer.value,
                          onChanged: (value) => updateBidOffer(ref, value),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      child: Text(
                        _chargeNote(
                          l10n,
                          bidding: isBiddingDraft(draft),
                          selected: selected,
                        ),
                        style: RyvoTypography.style(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                  _WalletCard(
                    balance: balanceAsync.isLoading && !balanceAsync.hasValue
                        ? null
                        : formatMoney(balance),
                    useCredit: selected == 'wallet',
                    canToggle: walletAvailable && !_loading,
                    onToggle: (on) => _setWalletCredit(on, methods),
                    onTopUp: _loading ? null : _topUp,
                  ),
                  _LinkRow(
                    icon: CupertinoIcons.clock,
                    label: 'Balance transactions',
                    onTap: () => Navigator.of(context).push<void>(
                      RyvoBottomUpPageRoute<void>(
                        builder: (_) => const _TransactionsPage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Payment methods',
                    style: RyvoTypography.heading(
                      fontSize: 20,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (methods.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No payment methods are available right now.',
                        style: RyvoTypography.style(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else
                    for (final method in methods)
                      _MethodRow(
                        method: method,
                        title: _titleFor(l10n, method),
                        subtitle: _subtitleFor(method, balance),
                        badge: _badgeFor(
                          method,
                          walletEnabled: config.walletPaymentEnabled,
                        ),
                        selected: selected == method,
                        onTap: _loading ? null : () => _select(method),
                      ),
                  _LinkRow(
                    icon: CupertinoIcons.plus_circle,
                    label: 'Add payment method',
                    onTap: _loading ? null : _addCard,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Vouchers',
                    style: RyvoTypography.heading(
                      fontSize: 20,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _PromoRow(),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.modal,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: widget.checkout
                      ? _CheckoutPayBar(
                          selected: selected,
                          loading: _loading,
                          bidding: isBiddingDraft(draft),
                          amount: fare,
                          onPressed: _loading ||
                                  selected == null ||
                                  methods.isEmpty
                              ? null
                              : _pay,
                        )
                      : RyvoButton(
                          label: 'Done',
                          onPressed: selected == null
                              ? null
                              : () => Navigator.pop(context, selected),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FareSummary extends StatelessWidget {
  const _FareSummary({
    required this.serviceName,
    required this.fare,
    required this.note,
  });

  final String serviceName;
  final double fare;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  serviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RyvoTypography.style(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    note,
                    style: RyvoTypography.style(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            formatMoney(fare),
            style: RyvoTypography.style(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: AppColors.textPrimary,
              tabular: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// Balance on a high-contrast card, with Top Up and the credit switch.
class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.balance,
    required this.useCredit,
    required this.canToggle,
    required this.onToggle,
    required this.onTopUp,
  });

  /// Formatted balance, or null while it loads.
  final String? balance;
  final bool useCredit;
  final bool canToggle;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onTopUp;

  @override
  Widget build(BuildContext context) {
    final onCard = AppColors.onCta;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cta,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ryvo balance',
                      style: RyvoTypography.style(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: onCard.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      balance ?? '—',
                      style: RyvoTypography.style(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: onCard,
                        tabular: true,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onTopUp == null
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        onTopUp!();
                      },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.lime,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        CupertinoIcons.plus,
                        size: 14,
                        color: AppColors.obsidian,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Top Up',
                        style: RyvoTypography.style(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.obsidian,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: onCard.withValues(alpha: 0.16)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Use wallet credit for this trip',
                  style: RyvoTypography.style(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: onCard,
                  ),
                ),
              ),
              Switch(
                value: useCredit,
                onChanged: canToggle ? onToggle : null,
                thumbColor: const WidgetStatePropertyAll(AppColors.white),
                trackColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppColors.primary
                      : AppColors.grey600,
                ),
                trackOutlineColor:
                    const WidgetStatePropertyAll(Colors.transparent),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.method,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String method;
  final String title;
  final String subtitle;
  final String? badge;
  final bool selected;
  final VoidCallback? onTap;

  static IconData _icon(String method) => switch (method) {
        'wallet' => Icons.account_balance_wallet_outlined,
        'cash' => Icons.payments_outlined,
        'google_pay' => Icons.g_mobiledata,
        'apple_pay' => Icons.apple,
        _ => CupertinoIcons.creditcard,
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _icon(method),
                size: method == 'google_pay' ? 28 : 22,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: RyvoTypography.style(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.lime,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badge!,
                            style: RyvoTypography.style(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.obsidian,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: RyvoTypography.style(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      tabular: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _Check(selected: selected),
          ],
        ),
      ),
    );
  }
}

/// Crisp checkmark on the active method, hollow ring otherwise.
class _Check extends StatelessWidget {
  const _Check({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.fastOutSlowIn,
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.cta : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.cta : AppColors.divider,
          width: 1.5,
        ),
      ),
      child: selected
          ? Icon(CupertinoIcons.checkmark, size: 14, color: AppColors.onCta)
          : null,
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: RyvoTypography.style(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}

/// Promo entry point. The backend has no voucher API yet, so the row is shown
/// as unavailable instead of accepting a code that would not be applied.
class _PromoRow extends StatelessWidget {
  const _PromoRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.tag, size: 20, color: AppColors.textHint),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Add promo code',
              style: RyvoTypography.style(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textHint,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Coming soon',
              style: RyvoTypography.style(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutPayBar extends StatelessWidget {
  const _CheckoutPayBar({
    required this.selected,
    required this.loading,
    required this.bidding,
    required this.amount,
    required this.onPressed,
  });

  final String? selected;
  final bool loading;
  final bool bidding;
  final double amount;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (selected == 'google_pay' || selected == 'apple_pay') {
      return SizedBox(
        height: 56,
        width: double.infinity,
        child: AbsorbPointer(
          absorbing: loading || onPressed == null,
          child: PlatformPayButton(
            type: defaultTargetPlatform == TargetPlatform.iOS
                ? PlatformButtonType.buy
                : PlatformButtonType.pay,
            appearance: PlatformButtonStyle.black,
            borderRadius: 16,
            onPressed: onPressed ?? () {},
          ),
        ),
      );
    }

    return RyvoButton(
      label: loading
          ? l10n.processing
          : selected == 'cash'
              ? l10n.confirmFindProvider
              : l10n.payFindProvider,
      sublabel: selected == 'cash'
          ? l10n.payCashToYourProviderOnCompletion
          : bidding
              ? 'Hold ${formatMoney(amount)} and find a driver'
              : l10n.securePaymentBeforeMatching,
      prefixIcon: Icon(
        selected == 'wallet'
            ? Icons.account_balance_wallet
            : selected == 'cash'
                ? Icons.payments_outlined
                : CupertinoIcons.creditcard,
        color: AppColors.onCta,
        size: 20,
      ),
      onPressed: loading ? null : onPressed,
    );
  }
}

class _TransactionsPage extends ConsumerWidget {
  const _TransactionsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(walletTransactionsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: const RyvoCloseButton(),
        title: Text(
          'Balance transactions',
          style: RyvoTypography.heading(color: AppColors.textPrimary),
        ),
      ),
      body: txAsync.when(
        loading: () => const LinearProgressIndicator(
          minHeight: 2,
          color: AppColors.primary,
          backgroundColor: Colors.transparent,
        ),
        error: (_, __) => Center(
          child: Text(
            'Could not load transactions.',
            style: RyvoTypography.style(color: AppColors.textSecondary),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No transactions yet',
                style: RyvoTypography.style(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: AppColors.divider),
            itemBuilder: (context, index) {
              final tx = items[index];
              final date = tx.createdAt != null
                  ? DateFormat('d MMM yyyy').format(tx.createdAt!)
                  : '';
              final credit = tx.isCredit;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.description ?? tx.type.replaceAll('_', ' '),
                            style: RyvoTypography.style(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            date,
                            style: RyvoTypography.style(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              tabular: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${credit ? '+' : '-'}${formatMoney(tx.amount)}',
                      style: RyvoTypography.style(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: credit
                            ? AppColors.primaryDark
                            : AppColors.textPrimary,
                        tabular: true,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
