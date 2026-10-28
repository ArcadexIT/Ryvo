import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/di_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class AddBankAccountPage extends ConsumerStatefulWidget {
  const AddBankAccountPage({super.key});

  @override
  ConsumerState<AddBankAccountPage> createState() => _AddBankAccountPageState();
}

class _AddBankAccountPageState extends ConsumerState<AddBankAccountPage> {
  final _bankName = TextEditingController();
  final _holder = TextEditingController();
  final _accountNumber = TextEditingController();
  final _routingNumber = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _bankName.dispose();
    _holder.dispose();
    _accountNumber.dispose();
    _routingNumber.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final bankName = _bankName.text.trim();
    final holder = _holder.text.trim();
    final accountNumber = _accountNumber.text.replaceAll(' ', '');
    if (bankName.isEmpty || holder.isEmpty || accountNumber.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).fillInBankNameHolderNameAndAccountNumber, style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(dioClientProvider).dio.post('/provider/bank-accounts', data: {
        'bankName': bankName,
        'accountHolder': holder,
        'accountNumber': accountNumber,
        if (_routingNumber.text.trim().isNotEmpty) 'routingNumber': _routingNumber.text.trim(),
      });
      ref.invalidate(bankAccountsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).bankAccountAdded, style: GoogleFonts.poppins()), backgroundColor: AppColors.success),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).couldNotAddBankAccount, style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(AppLocalizations.of(context).addBankAccount, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            RyvoTextField(hint: AppLocalizations.of(context).bankName, label: AppLocalizations.of(context).bankName2, controller: _bankName),
            const SizedBox(height: 16),
            RyvoTextField(hint: AppLocalizations.of(context).accountHolderName, label: AppLocalizations.of(context).accountHolder, controller: _holder),
            const SizedBox(height: 16),
            RyvoTextField(
              hint: AppLocalizations.of(context).accountNumber,
              label: AppLocalizations.of(context).accountNumber2,
              controller: _accountNumber,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            RyvoTextField(
              hint: AppLocalizations.of(context).routingNumberOptional,
              label: AppLocalizations.of(context).routingNumber,
              controller: _routingNumber,
              keyboardType: TextInputType.number,
            ),
            const Spacer(),
            RyvoButton(label: _saving ? AppLocalizations.of(context).saving : AppLocalizations.of(context).saveBankAccount, onPressed: _saving ? null : _save),
          ],
        ),
      ),
    );
  }
}
