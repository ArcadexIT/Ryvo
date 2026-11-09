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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).availableToWithdraw,
                style: _walletText(size: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                formatMoney(available),
                style: _walletText(
                  size: 44,
                  weight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  spacing: -1.2,
                  height: 1,
                  tabular: true,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${AppLocalizations.of(context).inTransit}  ${formatMoney(wallet?.pendingBalance ?? 0)}',
                style: _walletText(
                  size: 14,
                  weight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  tabular: true,
                ),
              ),
              const SizedBox(height: 24),
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
              const SizedBox(height: 16),
              _StripeRow(
                ready: _payoutsEnabled == true,
                connected: _stripeConnected == true,
                onSetup: _connectStripe,
              ),
              const SizedBox(height: 28),
              const _SubscriptionCard(),
              const SizedBox(height: 28),
              Text(
                AppLocalizations.of(context).recentPayouts,
                style: _walletText(size: 18, weight: FontWeight.w700, spacing: -0.4),
              ),
              const SizedBox(height: 8),
              if (loading || payouts.isLoading)
                const ShimmerList(count: 4, itemHeight: 64)
              else if (payouts.hasError || (payouts.value ?? []).isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                    children: [
                      const Icon(Icons.payments_outlined, color: AppColors.textHint, size: 28),
                      const SizedBox(height: 10),
                      Text(
                        AppLocalizations.of(context).noPayoutsYet,
                        style: _walletText(size: 15, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context).withdrawalsYouRequestWillAppearHere,
                        textAlign: TextAlign.center,
                        style: _walletText(size: 13, color: AppColors.textSecondary),
                      ),
                    ],
                    ),
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

TextStyle _walletText({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double spacing = 0,
  double? height,
  bool tabular = false,
}) {
  return GoogleFonts.poppins(
    fontSize: size,
    fontWeight: weight,
    color: color ?? AppColors.textPrimary,
    letterSpacing: spacing,
    height: height,
    fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
  );
}

class _StripeRow extends StatelessWidget {
  const _StripeRow({
    required this.ready,
    required this.connected,
    required this.onSetup,
  });

  final bool ready;
  final bool connected;
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    if (ready) {
      return Row(
        children: [
          const Icon(Icons.check_circle, size: 18, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Stripe payouts are ready',
              style: _walletText(size: 14, weight: FontWeight.w500),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Withdrawals are paid to Stripe after RYVO approves them. Bank details stay with Stripe.',
          style: _walletText(size: 13, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 12),
        RyvoButton(
          label: connected ? 'Continue Stripe setup' : 'Set up Stripe payouts',
          variant: RyvoButtonVariant.outline,
          height: 48,
          onPressed: onSetup,
        ),
      ],
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
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bankLabel, style: _walletText(size: 15, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(date, style: _walletText(size: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '-${formatMoney(amount)}',
                  style: _walletText(size: 15, weight: FontWeight.w700, tabular: true),
                ),
                const SizedBox(height: 2),
                Text(
                  _statusLabel(),
                  style: _walletText(size: 12, weight: FontWeight.w600, color: color),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.name,
    required this.price,
    required this.onBuy,
  });

  final String name;
  final String price;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(name, style: _walletText(size: 16, weight: FontWeight.w600)),
            ),
            Text(
              price,
              style: _walletText(size: 16, weight: FontWeight.w600, tabular: true),
            ),
            const SizedBox(width: 12),
            Material(
              color: AppColors.lime,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: onBuy,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Text(
                    'Buy',
                    style: _walletText(
                      size: 13,
                      weight: FontWeight.w700,
                      color: AppColors.obsidian,
                    ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Driver plan', style: _walletText(size: 18, weight: FontWeight.w700, spacing: -0.4)),
        const SizedBox(height: 4),
        Text(
          required
              ? 'A subscription is required to go online.'
              : 'Commission stays on. A plan is optional.',
          style: _walletText(size: 13, color: AppColors.textSecondary, height: 1.35),
        ),
        if (active is Map) ...[
          const SizedBox(height: 8),
          Text(
            'Active until ${active['expiresAt'] ?? ''}',
            style: _walletText(size: 13, weight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 8),
        ..._plans.map((plan) {
          final raw = plan['price'];
          final amount = raw is num ? raw.toDouble() : double.tryParse('$raw');
          return _PlanRow(
            name: '${plan['name'] ?? 'Plan'}',
            price: amount == null ? '$raw' : formatMoney(amount),
            onBuy: () => _buy('${plan['id']}'),
          );
        }),
      ],
    );
  }
}
