import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/models.dart';
import '../providers/app_providers.dart';
import 'ryvo_bottom_sheet.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

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
      if (!_autoSelected && widget.selectedCountry == null && countries.isNotEmpty) {
        _autoSelected = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onCountryChanged(countries.first);
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
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              _DialCodeButton(
                isLoading: isLoading,
                selectedCountry: widget.selectedCountry,
                enabled: countries.isNotEmpty,
                onTap: countries.isEmpty ? null : () => _openPicker(countries),
              ),
              Container(
                width: 1,
                height: 28,
                color: AppColors.divider,
              ),
              Expanded(
                child: TextFormField(
                  controller: widget.controller,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: widget.textInputAction,
                  validator: widget.validator,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.textHint,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  _countriesErrorMessage(countriesAsync.error),
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.error),
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(countriesProvider),
                child: Text(
                  AppLocalizations.of(context).retry,
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ] else if (showEmptyNotice) ...[
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context).noCountriesAreAvailableForRegistrationYetPleaseC,
            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.error),
          ),
        ],
      ],
    );
  }
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
        onTap: enabled ? onTap : null,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                )
              else
                Text(selectedCountry?.icon ?? '🌐', style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                selectedCountry?.dialCode ?? '+',
                style: GoogleFonts.poppins(
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
        : widget.countries
            .where((c) =>
                c.name.toLowerCase().contains(query) ||
                c.dialCode.contains(query) ||
                c.code.toLowerCase().contains(query))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            style: GoogleFonts.poppins(fontSize: 15, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).searchCountryOrCode,
              hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppColors.textHint),
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.grey500),
              filled: true,
              fillColor: AppColors.card,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
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
                      style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final country = filtered[index];
                    final isSelected = country.code == widget.selected?.code;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(country),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.divider,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(country.icon, style: const TextStyle(fontSize: 26)),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      country.name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      country.dialCode,
                                      style: GoogleFonts.poppins(
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
                                  child: const Icon(Icons.check, size: 14, color: Colors.white),
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
