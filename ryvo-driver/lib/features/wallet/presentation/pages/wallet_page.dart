import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/di_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';
import 'stripe_onboarding_page.dart';

class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage> with WidgetsBindingObserver {
  bool _statusLoading = true;
  bool? _stripeConnected;
  bool? _payoutsEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<String?> _askForPayoutEmail() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Email for payouts', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'you@email.com'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _connectStripe() async {
    try {
      final profile = await ref.read(providerProfileProvider.future);
      var email = profile?.email.trim() ?? '';
      if (!email.contains('@')) {
        email = (await _askForPayoutEmail()) ?? '';
        if (!email.contains('@')) {
          if (email.isNotEmpty && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Enter a valid email address.')),
            );
          }
          return;
        }
        await ref.read(dioClientProvider).dio.patch('/provider/profile', data: {'email': email});
        ref.invalidate(providerProfileProvider);
      }
      final res = await ref.read(dioClientProvider).dio.post('/provider/stripe/account-link', data: {
        'refreshUrl': 'https://ryvo.arcadexit.com/stripe/refresh',
        'returnUrl': 'https://ryvo.arcadexit.com/stripe/return',
      });
      final body = res.data;
      final data = body is Map ? body['data'] : null;
      final url = data is Map ? data['url']?.toString() : null;
      if (url == null || !mounted) return;
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => StripeOnboardingPage(url: url)),
      );
      await _load();
      if (!mounted || completed != true) return;
      final ready = _payoutsEnabled == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ready
                ? 'Stripe payouts are ready.'
                : 'Stripe details saved. Finish any remaining steps to enable payouts.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final failure = e is DioException ? e.error : null;
      final message = failure is Failure ? failure.message : 'Could not start Stripe payout setup';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _load() async {
    await ref.read(walletNotifierProvider.notifier).loadBalance();
    ref.invalidate(payoutsProvider);
    ref.invalidate(bankAccountsProvider);
    await _loadStripeStatus();
  }

  Future<void> _loadStripeStatus() async {
    try {
      final res = await ref.read(dioClientProvider).dio.get('/provider/stripe/status');
      final data = res.data is Map ? res.data['data'] : null;
      if (!mounted || data is! Map) return;
      setState(() {
        _stripeConnected = data['connected'] == true;
        _payoutsEnabled = data['payoutsEnabled'] == true;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _statusLoading = false);
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    final dt = raw is DateTime ? raw : DateTime.tryParse('$raw');
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletNotifierProvider);
    final payouts = ref.watch(payoutsProvider);
    final wallet = walletState.value?.wallet;
    final loading = walletState.isLoading && wallet == null;
    final available = wallet?.availableBalance ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(AppLocalizations.of(context).wallet, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_outlined),
            tooltip: AppLocalizations.of(context).paymentMethods,
            onPressed: () => context.push('/payment-methods'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _statusLoading
            ? const SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerCard(height: 168, borderRadius: 20),
                    SizedBox(height: 16),
                    ShimmerCard(height: 148, borderRadius: 12),
                    SizedBox(height: 16),
                    ShimmerCard(height: 54, borderRadius: 14),
                    SizedBox(height: 28),
                    ShimmerCard(height: 18, width: 140),
                    SizedBox(height: 12),
                    ShimmerList(count: 4, itemHeight: 72),
                  ],
                ),
              )
            : SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withOpacity(0.25), AppColors.surface],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context).availableToWithdraw, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Text(
                      formatMoney(available),
                      style: GoogleFonts.poppins(fontSize: 40, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _BalanceChip(
                          label: AppLocalizations.of(context).inTransit,
                          value: formatMoney(wallet?.pendingBalance ?? 0),
                          color: AppColors.warning,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _SubscriptionCard(),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _payoutsEnabled == true
                          ? 'Stripe payouts are connected. Withdrawals are paid after RYVO approves the request.'
                          : 'RYVO does not collect your bank details. Withdrawals are paid to a Stripe account after RYVO approves the request.',
                      style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    if (_payoutsEnabled == true)
                      RyvoButton(
                        label: 'Stripe payouts ready',
                        prefixIcon: const Icon(Icons.check_circle_outline, size: 20, color: Colors.black),
                        onPressed: null,
                      )
                    else
                      RyvoButton(
                        label: _stripeConnected == true ? 'Continue Stripe setup' : 'Set up Stripe payouts',
                        variant: RyvoButtonVariant.outline,
                        onPressed: _connectStripe,
                      ),
                  ],
                ),
              ),
              RyvoButton(
                label: available > 0
                    ? AppLocalizations.of(context).withdrawFunds
                    : AppLocalizations.of(context).noFundsAvailable,
                onPressed: available > 0
                    ? () async {
                        await context.push('/withdraw');
                        _load();
                      }
                    : null,
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppLocalizations.of(context).recentPayouts, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  if (payouts.hasValue && payouts.value!.isNotEmpty)
                    Text('${payouts.value!.length} shown', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textHint)),
                ],
              ),
              const SizedBox(height: 12),
              if (loading || payouts.isLoading)
                const ShimmerList(count: 4, itemHeight: 72)
              else if (payouts.hasError || (payouts.value ?? []).isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      Icon(Icons.payments_outlined, color: AppColors.textSecondary.withOpacity(0.6), size: 40),
                      const SizedBox(height: 12),
                      Text(AppLocalizations.of(context).noPayoutsYet, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text(AppLocalizations.of(context).withdrawalsYouRequestWillAppearHere, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                )
              else
                ...payouts.value!.map((p) => _PayoutTile(
                      amount: (p['amount'] as num?)?.toDouble() ?? 0,
                      status: p['status']?.toString() ?? 'pending',
                      bankLabel: p['bankAccountRef']?.toString() ?? p['bankName']?.toString() ?? AppLocalizations.of(context).bankTransfer,
                      date: _formatDate(p['createdAt']),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _BalanceChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
          Text(value, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _PayoutTile extends StatelessWidget {
  final double amount;
  final String status;
  final String bankLabel;
  final String date;

  const _PayoutTile({
    required this.amount,
    required this.status,
    required this.bankLabel,
    required this.date,
  });

  Color _statusColor() {
    switch (status) {
      case 'paid':
        return AppColors.success;
      case 'processing':
      case 'approved':
        return AppColors.info;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  String _statusLabel() {
    switch (status) {
      case 'paid':
        return 'Paid';
      case 'processing':
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.arrow_outward_rounded, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bankLabel, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(date, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('-${formatMoney(amount)}', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(_statusLabel(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends ConsumerStatefulWidget {
  const _SubscriptionCard();

  @override
  ConsumerState<_SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends ConsumerState<_SubscriptionCard> {
  Map<String, dynamic>? _status;
  List<Map<String, dynamic>> _plans = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dio = ref.read(dioClientProvider).dio;
      final statusRes = await dio.get('/provider/subscriptions/current');
      final plansRes = await dio.get('/provider/subscriptions/plans');
      dynamic unwrap(dynamic body) => body is Map && body['data'] != null ? body['data'] : body;
      setState(() {
        final status = unwrap(statusRes.data);
        _status = status is Map ? Map<String, dynamic>.from(status) : null;
        final plans = unwrap(plansRes.data);
        _plans = plans is List
            ? plans.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : const [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _buy(String planId) async {
    try {
      final res = await ref.read(dioClientProvider).dio.post(
        '/provider/subscriptions/purchase',
        data: {'planId': planId},
      );
      final body = res.data;
      final data = body is Map && body['data'] != null ? body['data'] : body;
      final checkoutUrl = data is Map ? data['checkoutUrl'] as String? : null;
      if (checkoutUrl != null && checkoutUrl.isNotEmpty && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StripeOnboardingPage(url: checkoutUrl, title: 'Buy driver plan'),
          ),
        );
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subscription updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final required = _status?['required'] == true;
    final active = _status?['active'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Driver plan', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            required
                ? 'A subscription is required to go online.'
                : 'Commission mode is on. Subscriptions are optional.',
            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
          ),
          if (active is Map) ...[
            const SizedBox(height: 8),
            Text('Active until ${active['expiresAt'] ?? ''}', style: GoogleFonts.poppins(fontSize: 13)),
          ],
          ..._plans.map(
            (plan) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${plan['name']} · ${plan['price']}'),
              trailing: TextButton(onPressed: () => _buy('${plan['id']}'), child: const Text('Buy')),
            ),
          ),
        ],
      ),
    );
  }
}
