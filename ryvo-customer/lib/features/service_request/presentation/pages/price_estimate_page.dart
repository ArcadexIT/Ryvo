import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/job/active_job_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/app_config.dart';
import '../../../../data/models/models.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

class PriceEstimatePage extends ConsumerStatefulWidget {
  const PriceEstimatePage({super.key});

  @override
  ConsumerState<PriceEstimatePage> createState() => _PriceEstimatePageState();
}

class _PriceEstimatePageState extends ConsumerState<PriceEstimatePage> {
  String? _selectedPayment;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_initPaymentSelection);
  }

  void _initPaymentSelection() {
    final config = ref.read(appConfigProvider).valueOrNull ?? AppConfig.fallback;
    final methods = _enabledMethods(config);
    if (!mounted) return;
    setState(() => _selectedPayment = methods.isNotEmpty ? methods.first : null);
  }

  List<String> _enabledMethods(AppConfig config) => [
        if (config.walletPaymentEnabled) 'wallet',
        if (config.paymentMethods.stripe) 'stripe',
        if (config.paymentMethods.cash) 'cash',
      ];

  void _handleBack() {
    if (_loading) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/service-request');
    }
  }

  Future<void> _confirm() async {
    final draft = ref.read(jobDraftProvider);
    if (draft.serviceCategory == null ||
        draft.dropoffLat == null ||
        draft.estimate == null) {
      showApiError(context, AppLocalizations.of(context).missingServiceDetails);
      return;
    }
    if (!isPickupLocationReady(draft)) {
      showApiError(context, AppLocalizations.of(context).confirmYourAssistanceAddressFirst);
      return;
    }
    if (_selectedPayment == null) {
      showApiError(context, AppLocalizations.of(context).noPaymentMethodsAreAvailable);
      return;
    }

    setState(() => _loading = true);
    try {
      // Nothing is written until the customer confirms payment. An existing
      // unpaid checkout row is cancelled so it cannot sit beside a new request.
      final container = ProviderScope.containerOf(context, listen: false);
      final active = await fetchAndApplyActiveJob(container);
      if (!mounted) return;
      if (active != null &&
          isResumableCustomerJob(active) &&
          !isUnpaidCheckoutJob(active)) {
        context.go(routeForActiveCustomerJobModel(active));
        return;
      }

      ref.read(jobDraftProvider.notifier).state =
          ref.read(jobDraftProvider).copyWith(paymentMethod: _selectedPayment!);
      context.push('/payment');
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(jobDraftProvider);
    final config = ref.watch(appConfigProvider).valueOrNull ?? AppConfig.fallback;
    final balance = ref.watch(walletBalanceProvider).valueOrNull?.balance ?? 0;
    final estimate = draft.estimate;
    final serviceName = draft.serviceCategory?.name ?? AppLocalizations.of(context).service;
    final total = estimate?.estimatedFare ?? 0;
    final sufficient = balance >= total;
    final enabled = _enabledMethods(config);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          title: Text(
            AppLocalizations.of(context).priceEstimate,
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            onPressed: _loading ? null : _handleBack,
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  _SummaryCard(
                    icon: serviceIcon(draft.serviceCategory?.slug, draft.serviceCategory?.icon),
                    title: serviceName,
                    address: draft.pickupAddress,
                    fareLabel: AppLocalizations.of(context).estimatedFare,
                    fare: formatMoney(total),
                    timingIcon: draft.bookingType == 'scheduled' && draft.scheduledAt != null
                        ? Icons.calendar_month_outlined
                        : Icons.schedule,
                    timing: draft.bookingType == 'scheduled' && draft.scheduledAt != null
                        ? DateFormat('EEE, MMM d · h:mm a').format(draft.scheduledAt!)
                        : '${AppLocalizations.of(context).estimatedArrival}${AppLocalizations.of(context).text38Minutes}',
                  ),
                  if (draft.dropoffAddress.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _DetailTile(
                      icon: Icons.flag_outlined,
                      title: draft.dropoffAddress,
                      trailing: 'Dropoff',
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text(
                    AppLocalizations.of(context).priceBreakdown,
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  _BreakdownCard(
                    rows: [
                      _PriceRow(label: AppLocalizations.of(context).estimatedFare, value: formatMoney(total)),
                      if (estimate != null && estimate.distanceKm > 0)
                        _PriceRow(
                          label: 'Distance (${estimate.distanceKm.toStringAsFixed(1)} km)',
                          value: 'Included',
                        ),
                    ],
                    totalLabel: AppLocalizations.of(context).total,
                    totalValue: formatMoney(total),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    AppLocalizations.of(context).paymentMethod,
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  if (enabled.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        AppLocalizations.of(context).noPaymentMethodsAreCurrentlyAvailablePleaseConta,
                        style: GoogleFonts.poppins(fontSize: 13, height: 1.4, color: AppColors.error),
                      ),
                    )
                  else ...[
                    if (config.walletPaymentEnabled)
                      _PayOption(
                        label: AppLocalizations.of(context).wallet,
                        subtitle: sufficient
                            ? '${AppLocalizations.of(context).walletBalance}${formatMoney(balance)} · ${AppLocalizations.of(context).sufficient}'
                            : '${AppLocalizations.of(context).walletBalance}${formatMoney(balance)} · ${AppLocalizations.of(context).lowBalance}',
                        icon: Icons.account_balance_wallet_outlined,
                        isSelected: _selectedPayment == 'wallet',
                        onTap: () => setState(() => _selectedPayment = 'wallet'),
                      ),
                    if (config.paymentMethods.stripe) ...[
                      if (config.walletPaymentEnabled) const SizedBox(height: 10),
                      _PayOption(
                        label: AppLocalizations.of(context).card,
                        subtitle: AppLocalizations.of(context).paySecurelyWithYourCard,
                        icon: Icons.credit_card_outlined,
                        isSelected: _selectedPayment == 'stripe',
                        onTap: () => setState(() => _selectedPayment = 'stripe'),
                      ),
                    ],
                    if (config.paymentMethods.cash) ...[
                      if (config.walletPaymentEnabled || config.paymentMethods.stripe) const SizedBox(height: 10),
                      _PayOption(
                        label: AppLocalizations.of(context).cash,
                        subtitle: AppLocalizations.of(context).payTheProviderWhenServiceCompletes,
                        icon: Icons.payments_outlined,
                        isSelected: _selectedPayment == 'cash',
                        onTap: () => setState(() => _selectedPayment = 'cash'),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: RyvoButton(
                    label: AppLocalizations.of(context).continueToPayment,
                    sublabel: AppLocalizations.of(context).payFirstThenWeFindYourProvider,
                    prefixIcon: Icon(
                      _loading ? Icons.hourglass_top_rounded : Icons.lock_outline,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: _loading || enabled.isEmpty ? null : _confirm,
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

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String address;
  final String fareLabel;
  final String fare;
  final IconData timingIcon;
  final String timing;

  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.address,
    required this.fareLabel,
    required this.fare,
    required this.timingIcon,
    required this.timing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: AppColors.primaryDark, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 12, height: 1.35, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fareLabel,
                        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Text(
                        fare,
                        style: GoogleFonts.poppins(fontSize: 32, height: 1.1, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(timingIcon, size: 16, color: AppColors.primaryDark),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            timing,
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String trailing;

  const _DetailTile({required this.icon, required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(
              trailing,
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final List<_PriceRow> rows;
  final String totalLabel;
  final String totalValue;

  const _BreakdownCard({required this.rows, required this.totalLabel, required this.totalValue});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.divider),
            rows[i],
          ],
          Container(
            color: AppColors.primary.withValues(alpha: 0.1),
            child: _PriceRow(label: totalLabel, value: totalValue, isTotal: true),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;
  const _PriceRow({required this.label, required this.value, this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: isTotal ? 15 : 14, fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400, color: isTotal ? AppColors.textPrimary : AppColors.textSecondary)),
          Text(value, style: GoogleFonts.poppins(fontSize: isTotal ? 18 : 14, fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500, color: isTotal ? AppColors.primary : AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _PayOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PayOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withValues(alpha: 0.18) : AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: isSelected ? AppColors.primaryDark : AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              size: 22,
              color: isSelected ? AppColors.primary : AppColors.grey400,
            ),
          ],
        ),
      ),
    );
  }
}
