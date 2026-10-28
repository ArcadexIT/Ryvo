import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/app_config.dart';
import '../../../../data/models/models.dart';
import '../../../../shared/providers/app_providers.dart';

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

class _PaymentSheet extends ConsumerStatefulWidget {
  const _PaymentSheet({required this.selected, required this.methods});

  final String? selected;
  final List<String> methods;

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  late String? _selected;
  String _profile = 'personal';

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
  }

  List<String> _methods(AppConfig config) {
    final base = widget.methods.where((method) => method != 'google_pay' && method != 'apple_pay').toList();
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

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider).valueOrNull ?? AppConfig.fallback;
    final balance = ref.watch(walletBalanceProvider).valueOrNull?.balance ?? 0;
    final methods = _methods(config);
    final height = MediaQuery.sizeOf(context).height * 0.92;

    return Align(
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
                    onPressed: () => Navigator.pop(context, _selected),
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
                          selected: _selected == method,
                          onTap: () => setState(() => _selected = method),
                        ),
                        const Divider(height: 1, color: Color(0xFFE8EAED)),
                      ],
                    _LinkRow(
                      icon: Icons.add,
                      label: 'Add payment method',
                      onTap: () {
                        if (methods.contains('stripe')) {
                          setState(() => _selected = 'stripe');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
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

class _MethodRow extends StatelessWidget {
  const _MethodRow({required this.method, required this.selected, required this.onTap});

  final String method;
  final bool selected;
  final VoidCallback onTap;

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
              child: Text(
                presentation,
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.navy),
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
