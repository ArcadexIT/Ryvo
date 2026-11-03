import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/phone_utils.dart';
import '../../data/models/models.dart';
import '../providers/app_providers.dart';
import 'ryvo_bottom_sheet.dart';

/// Phone number input with a tappable country/dial-code prefix, backed by
/// the admin-managed list of active countries (`GET /countries`).
class PhoneCountryField extends ConsumerStatefulWidget {
  const PhoneCountryField({
    super.key,
    required this.controller,
    required this.selectedCountry,
    required this.onCountryChanged,
    this.label = 'Phone Number',
    this.hint = 'Phone number',
    this.textInputAction,
    this.validator,
  });

  final TextEditingController controller;
  final Country? selectedCountry;
  final ValueChanged<Country> onCountryChanged;
  final String label;
  final String hint;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;

  @override
  ConsumerState<PhoneCountryField> createState() => _PhoneCountryFieldState();
}

class _PhoneCountryFieldState extends ConsumerState<PhoneCountryField> {
  bool _autoSelected = false;
  late final FocusNode _focus;
  void Function(String)? _reportToForm;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(PhoneCountryField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onControllerChanged);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _focus.dispose();
    super.dispose();
  }

  /// Autofill writes straight to the controller and can skip [TextField.onChanged].
  void _onControllerChanged() {
    _reportToForm?.call(widget.controller.text);
  }

  Country _preferredCountry(List<Country> countries) {
    final region = WidgetsBinding.instance.platformDispatcher.locale.countryCode
        ?.toUpperCase();
    if (region != null) {
      for (final country in countries) {
        if (country.code.toUpperCase() == region) return country;
      }
    }
    return countries.first;
  }

  Future<void> _openPicker(List<Country> countries) async {
    final selected = await RyvoBottomSheet.show<Country>(
      context: context,
      title: AppLocalizations.of(context).selectCountry,
      maxHeight: MediaQuery.of(context).size.height * 0.72,
      child: _CountrySearchList(
        countries: countries,
        selected: widget.selectedCountry,
      ),
    );
    if (selected != null) widget.onCountryChanged(selected);
  }

  String _countriesErrorMessage(Object? error) {
    if (error is ApiException) {
      if (error.statusCode == 404) {
        return 'Countries are not available on this server yet.';
      }
      return error.message;
    }
    return 'Could not load countries. Check your connection.';
  }

  @override
  Widget build(BuildContext context) {
    final countriesAsync = ref.watch(countriesProvider);

    countriesAsync.whenData((countries) {
      if (!_autoSelected &&
          widget.selectedCountry == null &&
          countries.isNotEmpty) {
        _autoSelected = true;
        final country = _preferredCountry(countries);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onCountryChanged(country);
        });
      }
    });

    final countries = countriesAsync.valueOrNull ?? const <Country>[];
    final isLoading = countriesAsync.isLoading && countries.isEmpty;
    final hasError = countriesAsync.hasError;
    final showEmptyNotice = countriesAsync.hasValue && countries.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text(
            widget.label,
            style: RyvoTypography.style(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
        ],
        FormField<String>(
          validator: widget.validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          initialValue: widget.controller.text,
          builder: (state) {
            _reportToForm = state.didChange;
            final borderColor = state.hasError
                ? AppColors.error
                : _focus.hasFocus
                    ? AppColors.focusBorder
                    : Colors.transparent;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.fastOutSlowIn,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      ExcludeFocus(
                        child: _DialCodeButton(
                          isLoading: isLoading,
                          selectedCountry: widget.selectedCountry,
                          enabled: countries.isNotEmpty,
                          onTap: countries.isEmpty
                              ? null
                              : () => _openPicker(countries),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 28,
                        color: AppColors.divider,
                      ),
                      Expanded(
                        child: TextField(
                          controller: widget.controller,
                          focusNode: _focus,
                          keyboardType: TextInputType.phone,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.telephoneNumber,
                          ],
                          inputFormatters: [
                            _PhoneAutofillFormatter(
                              widget.selectedCountry?.dialCode ?? '',
                            ),
                          ],
                          textInputAction: widget.textInputAction,
                          onChanged: state.didChange,
                          onSubmitted:
                              widget.textInputAction == TextInputAction.done
                                  ? (_) => FocusScope.of(context).unfocus()
                                  : null,
                          style: RyvoTypography.style(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                            tabular: true,
                          ),
                          cursorColor: AppColors.focusBorder,
                          decoration: InputDecoration(
                            hintText: widget.hint,
                            hintStyle: RyvoTypography.style(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textHint,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ClipRect(
                  child: AnimatedAlign(
                    alignment: Alignment.topLeft,
                    heightFactor: state.hasError ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.fastOutSlowIn,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(
                        state.errorText ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: RyvoTypography.style(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.error,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        if (hasError) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _countriesErrorMessage(countriesAsync.error),
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: AppColors.error),
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(countriesProvider),
                child: Text(
                  AppLocalizations.of(context).retry,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ] else if (showEmptyNotice) ...[
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)
                .noCountriesAreAvailableForRegistrationYetPleaseC,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: AppColors.error),
          ),
        ],
      ],
    );
  }
}

/// Keeps digits, and drops a pasted or autofilled country code.
/// A trunk `0` stays so a local number can be typed.
class _PhoneAutofillFormatter extends TextInputFormatter {
  const _PhoneAutofillFormatter(this.dialCode);

  final String dialCode;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final code = dialDigits(dialCode);
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (code.isNotEmpty && digits.startsWith(code)) {
      final rest = digits.substring(code.length);
      final includedCode =
          newValue.text.trimLeft().startsWith('+') || rest.length >= 7;
      if (includedCode && rest.isNotEmpty) digits = rest;
    }
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

bool _countryMatches(Country country, String query) {
  final name = country.name.toLowerCase();
  final code = country.code.toLowerCase();
  final dial = country.dialCode.toLowerCase();
  if (name.contains(query) || code.contains(query) || dial.contains(query)) {
    return true;
  }
  if (code == 'gb' &&
      (query == 'uk' ||
          query == 'u.k' ||
          query == 'britain' ||
          query == 'england')) {
    return true;
  }
  final queryDigits = query.replaceAll(RegExp(r'\D'), '');
  final codeDigits = dialDigits(country.dialCode);
  if (queryDigits.isEmpty || codeDigits.isEmpty) return false;
  return codeDigits.startsWith(queryDigits) ||
      queryDigits.startsWith(codeDigits);
}

class _DialCodeButton extends StatelessWidget {
  const _DialCodeButton({
    required this.isLoading,
    required this.selectedCountry,
    required this.enabled,
    this.onTap,
  });

  final bool isLoading;
  final Country? selectedCountry;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled && onTap != null
            ? () {
                HapticFeedback.lightImpact();
                onTap!();
              }
            : null,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                )
              else
                Text(selectedCountry?.icon ?? '🌐',
                    style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                selectedCountry?.dialCode ?? '+',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (enabled) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: enabled ? AppColors.primary : AppColors.grey500,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CountrySearchList extends StatefulWidget {
  const _CountrySearchList({required this.countries, this.selected});

  final List<Country> countries;
  final Country? selected;

  @override
  State<_CountrySearchList> createState() => _CountrySearchListState();
}

class _CountrySearchListState extends State<_CountrySearchList> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.countries
        : widget.countries.where((c) => _countryMatches(c, query)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            style: GoogleFonts.plusJakartaSans(
                fontSize: 15, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).searchCountryOrCode,
              hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 14, color: AppColors.textHint),
              prefixIcon:
                  const Icon(Icons.search, size: 20, color: AppColors.grey500),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.transparent,
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.transparent,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: AppColors.focusBorder, width: 1.5),
              ),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      AppLocalizations.of(context).noCountriesFound,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final country = filtered[index];
                    final isSelected = country.code == widget.selected?.code;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pop(country);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.divider,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(country.icon,
                                  style: const TextStyle(fontSize: 26)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      country.name,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      country.dialCode,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check,
                                      size: 16, color: AppColors.white),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
