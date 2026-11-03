import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import 'ryvo_bottom_sheet.dart';
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
  final result = await showRyvoModalSheet<bool>(
    context: context,
    child: _ManualAddressSheet(
      initialAddress: initialAddress,
    ),
  );
  return result == true;
}

class _ManualAddressSheet extends ConsumerStatefulWidget {
  const _ManualAddressSheet({this.initialAddress});

  final String? initialAddress;

  @override
  ConsumerState<_ManualAddressSheet> createState() =>
      _ManualAddressSheetState();
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
      text: (initial.isEmpty || initial == 'Locating your position…')
          ? ''
          : initial,
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
      padding: EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.sm,
          AppSpacing.s20, AppSpacing.md + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).enterAddress,
            style: RyvoTypography.heading(
                fontSize: 18, color: AppColors.textPrimary),
          ),
          AppSpacing.h8,
          Text(
            AppLocalizations.of(context)
                .typeTheAssistanceAddressThenConfirmItOnTheMap,
            style: RyvoTypography.style(
                fontSize: 13, color: AppColors.textSecondary),
          ),
          AppSpacing.h16,
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
            AppSpacing.h8,
            Text(
              _error!,
              style: RyvoTypography.style(fontSize: 12, color: AppColors.error),
            ),
          ],
          AppSpacing.h16,
          RyvoButton(
            label: _submitting
                ? AppLocalizations.of(context).findingAddress
                : AppLocalizations.of(context).useThisAddress,
            isLoading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
          AppSpacing.h8,
        ],
      ),
    );
  }
}
