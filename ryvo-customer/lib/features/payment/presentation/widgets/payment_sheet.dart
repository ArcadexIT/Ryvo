import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/app_config.dart';
import '../../../../data/models/models.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../customer_checkout.dart';

/// Bolt-style payment picker. Returns the selected method when Done is tapped.
Future<String?> showRyvoPaymentSheet(
  BuildContext context, {
  required String? selected,
  required List<String> methods,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _PaymentSheet(selected: selected, methods: methods),
  );
}

/// Checkout sheet. Returns the route to open after a successful charge.
Future<String?> showRyvoCheckoutSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (context) => const _PaymentSheet(selected: null, methods: [], checkout: true),
  );
}

class _PaymentSheet extends ConsumerStatefulWidget {
  const _PaymentSheet({
    required this.selected,
    required this.methods,
    this.checkout = false,
  });

  final String? selected;
  final List<String> methods;
  final bool checkout;

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  late String? _selected;
  String _profile = 'personal';
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
    final config = ref.read(appConfigProvider).valueOrNull ?? AppConfig.fallback;
    final checkGoogle = checkoutShowsGooglePay(config);
    final checkApple = checkoutShowsApplePay(config);
    if (!checkGoogle && !checkApple) return;
    try {
      final readyConfig = await loadCheckoutConfig(ref);
      final supported = await detectPlatformPaySupport(readyConfig, google: checkGoogle);
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
    final config = ref.read(appConfigProvider).valueOrNull ?? AppConfig.fallback;
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
      _popSheet(route);
      return;
    }
    setState(() => _loading = false);
  }

  void _popSheet(String? result) {
    setState(() => _closing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, result);
    });
  }

  Future<void> _addCard() async {
    if (_loading) return;
    final methods = _methods(ref.read(appConfigProvider).valueOrNull ?? AppConfig.fallback);
    if (!methods.contains('stripe')) return;
    setState(() => _loading = true);
    try {
      final id = await CustomerCheckout(ref).saveCard(context);
      if (!mounted) return;
      setState(() => _savedCardId = id);
      setState(() => _selected = 'stripe');
    } on StripeException catch (e) {
      if (mounted && e.error.code != FailureCode.Canceled) {
        showApiError(context, e);
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
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
    _popSheet(null);
  }

  List<String> _methods(AppConfig config) {
    final base = widget.checkout
        ? <String>[
            if (config.walletPaymentEnabled) 'wallet',
            if (config.paymentMethods.stripe) 'stripe',
            if (config.paymentMethods.cash) 'cash',
          ]
        : widget.methods.where((method) => method != 'google_pay' && method != 'apple_pay').toList();
    final withPlatform = <String>[
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          config.paymentMethods.stripe &&
          AppConstants.appleMerchantId.trim().isNotEmpty)
        'apple_pay',
      if (defaultTargetPlatform == TargetPlatform.android && config.paymentMethods.stripe) 'google_pay',
      ...base.where((method) => method != 'wallet'),
      if (base.contains('wallet')) 'wallet',
    ];
    return withPlatform;
  }

  String? _badgeFor(String method, {required bool walletEnabled}) {
    final l10n = AppLocalizations.of(context);
    if (method == 'google_pay' && _googlePayReady) return l10n.recommended;
    if (method == 'apple_pay' && _applePayReady) return l10n.recommended;
    if (method == 'wallet' && walletEnabled) return l10n.recommended;
    return null;
  }

  String _subtitleFor(String method, double balance) {
    final l10n = AppLocalizations.of(context);
    return switch (method) {
      'wallet' => 'Balance: ${formatMoney(balance)}',
      'google_pay' => l10n.payWithCardsInGoogleWallet,
      'apple_pay' => l10n.payWithApplePay,
      'cash' => l10n.payTheProviderWhenServiceCompletes,
      _ => l10n.paySecurelyWithYourCard,
    };
  }

  String _chargeNote(AppLocalizations l10n, {required bool bidding, required String? selected}) {
    if (bidding) {
      return 'Drivers can accept your offer or send a counter. Nothing is charged until a driver is matched.';
    }
    if (selected == 'cash') return l10n.youWillPayTheProviderInCashWhenTheServiceIsCompl;
    return l10n.fundsAreHeldSecurelyUntilYourServiceIsCompletedI;
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider).valueOrNull ?? AppConfig.fallback;
    final balance = ref.watch(walletBalanceProvider).valueOrNull?.balance ?? 0;
    final draft = ref.watch(jobDraftProvider);
    final methods = _methods(config);
    final l10n = AppLocalizations.of(context);
    final offer = widget.checkout ? bidOfferFor(draft, config) : null;
    final fare = checkoutFare(draft, config);
    final serviceName = draft.serviceCategory?.name ?? draft.activeJob?.serviceCategory?.name ?? l10n.service;
    final height = MediaQuery.sizeOf(context).height * 0.92;
    final selected = _selected;

    return PopScope(
      canPop: _closing || (!widget.checkout && !_loading),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !widget.checkout || _loading) return;
        _dismissCheckout();
      },
      child: Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            if (widget.checkout) {
                              _dismissCheckout();
                            } else {
                              Navigator.pop(context, _selected);
                            }
                          },
                    child: Text(
                      'Done',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    Text(
                      'Payment',
                      style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.navy),
                    ),
                    if (widget.checkout) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              serviceName,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                          Text(
                            formatMoney(fare),
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      if (isBiddingDraft(draft) || (draft.activeJob?.jobNumber.isNotEmpty ?? false)) ...[
                        const SizedBox(height: 4),
                        Text(
                          isBiddingDraft(draft) ? 'Your bid offer' : draft.activeJob!.jobNumber,
                          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                      if (offer != null && offer.suggested > 0) ...[
                        const SizedBox(height: 8),
                        _BidSlider(
                          offer: offer,
                          enabled: canEditBidOffer(draft, offer) && !_loading,
                          onChanged: (value) => updateBidOffer(ref, value),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        _chargeNote(l10n, bidding: isBiddingDraft(draft), selected: selected),
                        style: GoogleFonts.poppins(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _BalanceCard(amount: formatMoney(balance)),
                    const SizedBox(height: 8),
                    _LinkRow(
                      icon: Icons.help_outline,
                      label: 'What is Ryvo balance?',
                      onTap: () => _explainBalance(context),
                    ),
                    const Divider(height: 1, color: Color(0xFFE8EAED)),
                    _LinkRow(
                      icon: Icons.schedule,
                      label: 'See Ryvo balance transactions',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const _TransactionsPage()),
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Payment methods',
                      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.navy),
                    ),
                    const SizedBox(height: 14),
                    _ProfileToggle(
                      value: _profile,
                      onChanged: (value) => setState(() => _profile = value),
                    ),
                    const SizedBox(height: 8),
                    if (_profile == 'work')
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 4),
                        child: Text(
                          'Work billing is not set up on this account. Personal methods are used for this ride.',
                          style: GoogleFonts.poppins(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
                        ),
                      ),
                    if (methods.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          'No payment methods are available right now.',
                          style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary),
                        ),
                      )
                    else
                      for (final method in methods) ...[
                        _MethodRow(
                          method: method,
                          subtitle: _subtitleFor(method, balance),
                          badge: _badgeFor(method, walletEnabled: config.walletPaymentEnabled),
                          selected: _selected == method,
                          onTap: _loading ? null : () => setState(() => _selected = method),
                        ),
                        const Divider(height: 1, color: Color(0xFFE8EAED)),
                      ],
                    _LinkRow(
                      icon: Icons.add,
                      label: 'Add payment method',
                      onTap: _addCard,
                    ),
                  ],
                ),
              ),
              if (widget.checkout)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _CheckoutPayBar(
                    selected: selected,
                    loading: _loading,
                    bidding: isBiddingDraft(draft),
                    amount: fare,
                    onPressed: _loading || selected == null || methods.isEmpty ? null : _pay,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  void _explainBalance(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('What is Ryvo balance?', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'Ryvo balance is credit stored on your account. When you choose it for a ride, the fare is taken from this balance.',
          style: GoogleFonts.poppins(fontSize: 14, height: 1.45, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Done', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.amount});

  final String amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F6EE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ryvo balance',
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.grey600),
          ),
          const SizedBox(height: 2),
          Text(
            amount,
            style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.navy),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.grey700),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.navy),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.grey400),
          ],
        ),
      ),
    );
  }
}

class _ProfileToggle extends StatelessWidget {
  const _ProfileToggle({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _side('Personal', value == 'personal', () => onChanged('personal')),
          _side('Work', value == 'work', () => onChanged('work')),
        ],
      ),
    );
  }

  Widget _side(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.navy,
            ),
          ),
        ),
      ),
    );
  }
}

class _BidSlider extends StatelessWidget {
  const _BidSlider({required this.offer, required this.enabled, required this.onChanged});

  final BidOffer offer;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Set your offer',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy),
            ),
            const Spacer(),
            Text(
              formatMoney(offer.value),
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ],
        ),
        Text(
          'Suggested fare ${formatMoney(offer.suggested)}',
          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
        ),
        Slider(
          min: offer.min,
          max: offer.max,
          value: offer.value.clamp(offer.min, offer.max),
          activeColor: AppColors.primary,
          onChanged: enabled ? onChanged : null,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatMoney(offer.min), style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
            Text(formatMoney(offer.max), style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ],
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
      return Column(
        children: [
          SizedBox(
            height: 54,
            width: double.infinity,
            child: AbsorbPointer(
              absorbing: loading || onPressed == null,
              child: PlatformPayButton(
                type: defaultTargetPlatform == TargetPlatform.iOS ? PlatformButtonType.buy : PlatformButtonType.pay,
                appearance: PlatformButtonStyle.black,
                borderRadius: 14,
                onPressed: onPressed ?? () {},
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
                : Icons.credit_card,
        color: Colors.white,
        size: 20,
      ),
      onPressed: loading ? null : onPressed,
    );
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.method,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String method;
  final String subtitle;
  final String? badge;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final presentation = _presentation(method);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            _MethodBadge(method: method),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          presentation,
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.navy),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badge!,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.primary : AppColors.grey400,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  String _presentation(String method) {
    return switch (method) {
      'wallet' => 'Ryvo balance',
      'cash' => 'Cash',
      'google_pay' => 'Google Pay',
      'apple_pay' => 'Apple Pay',
      _ => 'Card',
    };
  }
}

class _MethodBadge extends StatelessWidget {
  const _MethodBadge({required this.method});

  final String method;

  @override
  Widget build(BuildContext context) {
    final icon = switch (method) {
      'wallet' => Icons.account_balance_wallet_outlined,
      'cash' => Icons.payments_outlined,
      'google_pay' => Icons.g_mobiledata,
      'apple_pay' => Icons.apple,
      _ => Icons.credit_card,
    };
    return Container(
      width: 36,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFD7DBE0)),
      ),
      child: Icon(icon, size: method == 'google_pay' ? 22 : 16, color: AppColors.navy),
    );
  }
}

class _TransactionsPage extends ConsumerWidget {
  const _TransactionsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(walletTransactionsProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
        title: Text(
          'Ryvo balance',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: txAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => Center(
          child: Text(
            'Could not load transactions.',
            style: GoogleFonts.poppins(color: AppColors.textSecondary),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No transactions yet',
                style: GoogleFonts.poppins(fontSize: 15, color: AppColors.textSecondary),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final tx = items[index];
              final date = tx.createdAt != null ? DateFormat('d MMM yyyy').format(tx.createdAt!) : '';
              final credit = tx.isCredit;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  tx.description ?? tx.type.replaceAll('_', ' '),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(date, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                trailing: Text(
                  '${credit ? '+' : '-'}${formatMoney(tx.amount)}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: credit ? AppColors.primary : AppColors.navy,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
