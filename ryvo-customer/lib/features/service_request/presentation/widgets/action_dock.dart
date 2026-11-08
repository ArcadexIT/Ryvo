import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// Pinned footer of the vehicle sheet: payment method row above the primary
/// action. It sits at the bottom of the sheet, so it stays reachable while the
/// tiers, parcel fields or bid controls scroll above it.
class RequestActionDock extends StatelessWidget {
  const RequestActionDock({
    super.key,
    required this.paymentMethod,
    required this.paymentLabel,
    required this.noMethodsLabel,
    required this.onPickPayment,
    required this.buttonLabel,
    required this.buttonPrice,
    required this.loading,
    required this.onPressed,
  });

  /// Raw method id (`wallet`, `cash`, ...), or null before one is chosen.
  final String? paymentMethod;
  final String paymentLabel;

  /// Shown instead of the row when no method is available; null otherwise.
  final String? noMethodsLabel;
  final VoidCallback? onPickPayment;
  final String buttonLabel;
  final String? buttonPrice;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.modal,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (noMethodsLabel != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  noMethodsLabel!,
                  style: RyvoTypography.style(
                    fontSize: 12,
                    color: AppColors.error,
                  ),
                ),
              )
            else
              InkWell(
                onTap: onPickPayment,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      PaymentChip(method: paymentMethod),
                      const SizedBox(width: 8),
                      Text(
                        paymentLabel,
                        style: RyvoTypography.style(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.1,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: RequestButton(
                label: buttonLabel,
                price: buttonPrice,
                loading: loading,
                onPressed: onPressed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentChip extends StatelessWidget {
  const PaymentChip({super.key, required this.method});

  final String? method;

  @override
  Widget build(BuildContext context) {
    final card = method == null ||
        method == 'stripe' ||
        method == 'google_pay' ||
        method == 'apple_pay';
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: card ? AppColors.cta : AppColors.surface,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        switch (method) {
          'wallet' => 'WALLET',
          'cash' => 'CASH',
          'apple_pay' => 'APPLE',
          'google_pay' => 'G PAY',
          _ => 'CARD',
        },
        style: RyvoTypography.style(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: card ? AppColors.onCta : AppColors.textPrimary,
          height: 1,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Primary CTA. Reads "Choose UberX • £12.40": the label, a bullet, then the
/// fare in tabular figures so it never jitters when the price changes.
class RequestButton extends StatelessWidget {
  const RequestButton({
    super.key,
    required this.label,
    required this.price,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final String? price;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final fill = enabled ? AppColors.cta : AppColors.cta.withValues(alpha: 0.4);
    final text = '$label|$price';
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: label,
                          style: RyvoTypography.button(
                            fontSize: 16,
                            color: AppColors.onCta,
                          ),
                        ),
                        if (price != null) ...[
                          TextSpan(
                            text: '  •  ',
                            style: RyvoTypography.button(
                              fontSize: 16,
                              color: AppColors.onCta.withValues(alpha: 0.6),
                            ),
                          ),
                          TextSpan(
                            text: price,
                            style: RyvoTypography.price(
                              fontSize: 16,
                              color: AppColors.onCta,
                            ),
                          ),
                        ],
                      ],
                    ),
                    key: ValueKey(text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              if (loading)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    color: AppColors.onCta,
                    backgroundColor: AppColors.onCta.withValues(alpha: 0.16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
