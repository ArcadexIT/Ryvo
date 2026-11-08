import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/app_config.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../payment/presentation/customer_checkout.dart';
import '../widgets/ryvo_modal_scaffold.dart';

class PaymentMethodsPage extends ConsumerStatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  ConsumerState<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends ConsumerState<PaymentMethodsPage> {
  var _saving = false;

  Future<void> _addCard() async {
    if (_saving) return;
    setState(() => _saving = true);
    final id = await CustomerCheckout(ref).saveCardForLater(context);
    if (!mounted) return;
    setState(() => _saving = false);
    if (id == null) return;
    final draft = ref.read(jobDraftProvider);
    ref.read(jobDraftProvider.notifier).state =
        draft.copyWith(paymentMethod: 'stripe');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final config =
        ref.watch(appConfigProvider).valueOrNull ?? AppConfig.fallback;
    final selected = ref.watch(jobDraftProvider).paymentMethod;
    final savedCard = ref.watch(savedStripeCardIdProvider);
    final cardEnabled = config.paymentMethods.stripe;
    final methods = <String>[
      if (checkoutShowsApplePay(config)) 'apple_pay',
      if (checkoutShowsGooglePay(config)) 'google_pay',
      if (cardEnabled) 'stripe',
      if (config.paymentMethods.cash) 'cash',
      if (config.walletPaymentEnabled) 'wallet',
    ];

    return RyvoModalScaffold(
      title: 'Payment methods',
      body: methods.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  l10n.noPaymentMethodsAreAvailable,
                  textAlign: TextAlign.center,
                  style: RyvoTypography.style(color: AppColors.textSecondary),
                ),
              ),
            )
          : ListView(
              children: [
                for (final method in methods)
                  _MethodRow(
                    label: _label(method, l10n),
                    trailing: method == 'stripe' && savedCard != null
                        ? 'Saved'
                        : null,
                    selected: selected == method,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      final draft = ref.read(jobDraftProvider);
                      ref.read(jobDraftProvider.notifier).state =
                          draft.copyWith(paymentMethod: method);
                    },
                  ),
                if (cardEnabled)
                  _MethodRow(
                    icon: CupertinoIcons.add,
                    label: _saving ? 'Saving card…' : 'Add card',
                    onTap: _saving ? null : _addCard,
                  ),
              ],
            ),
    );
  }
}

String _label(String method, AppLocalizations l10n) {
  return switch (method) {
    'wallet' => l10n.wallet,
    'cash' => l10n.cash,
    'google_pay' => l10n.googlePay,
    'apple_pay' => l10n.applePay,
    _ => l10n.card,
  };
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.label,
    this.onTap,
    this.icon,
    this.trailing,
    this.selected = false,
  });

  final String label;
  final IconData? icon;
  final String? trailing;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.surface,
        splashColor: AppColors.textPrimary.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: AppColors.textPrimary),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Text(
                  label,
                  style: RyvoTypography.style(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (trailing != null) ...[
                Text(
                  trailing!,
                  style: RyvoTypography.style(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (selected)
                const Icon(
                  CupertinoIcons.checkmark,
                  size: 18,
                  color: AppColors.primaryDark,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
