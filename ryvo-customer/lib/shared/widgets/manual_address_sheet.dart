import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../providers/app_providers.dart';
import 'ryvo_button.dart';
import 'ryvo_text_field.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

/// Shows a typed-address sheet. Returns true if the draft pickup was updated.
Future<bool> showManualAddressSheet({
  required BuildContext context,
  required WidgetRef ref,
  String? initialAddress,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.modal,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _ManualAddressSheet(
      initialAddress: initialAddress,
    ),
  );
  return result == true;
}

class _ManualAddressSheet extends ConsumerStatefulWidget {
  const _ManualAddressSheet({this.initialAddress});

  final String? initialAddress;

  @override
  ConsumerState<_ManualAddressSheet> createState() => _ManualAddressSheetState();
}

class _ManualAddressSheetState extends ConsumerState<_ManualAddressSheet> {
  late final TextEditingController _controller;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAddress?.trim() ?? '';
    _controller = TextEditingController(
      text: (initial.isEmpty || initial == 'Locating your position…') ? '' : initial,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() => _error = 'Enter an address to continue.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await applyManualPickupAddress(ref, query);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _submitting = false;
        _error = error;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            AppLocalizations.of(context).enterAddress,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context).typeTheAssistanceAddressThenConfirmItOnTheMap,
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          RyvoTextField(
            hint: AppLocalizations.of(context).streetCityOrLandmark,
            label: AppLocalizations.of(context).assistanceAddress,
            controller: _controller,
            prefixIcon: const Icon(Icons.search, size: 20),
            textInputAction: TextInputAction.search,
            onFieldSubmitted: (_) {
              if (!_submitting) _submit();
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.error),
            ),
          ],
          const SizedBox(height: 16),
          RyvoButton(
            label: _submitting ? AppLocalizations.of(context).findingAddress : AppLocalizations.of(context).useThisAddress,
            isLoading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
