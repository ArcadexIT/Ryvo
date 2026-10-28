import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../models/country_entity.dart';
import '../providers/app_providers.dart';
import 'ryvo_bottom_sheet.dart';
import 'ryvo_text_field.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

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
  final CountryEntity? selectedCountry;
  final ValueChanged<CountryEntity> onCountryChanged;
  final String label;
  final String hint;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;

  @override
  ConsumerState<PhoneCountryField> createState() => _PhoneCountryFieldState();
}

class _PhoneCountryFieldState extends ConsumerState<PhoneCountryField> {
  bool _autoSelected = false;

  Future<void> _openPicker(List<CountryEntity> countries) async {
    final selected = await RyvoBottomSheet.show<CountryEntity>(
      context: context,
      title: AppLocalizations.of(context).selectCountry,
      maxHeight: MediaQuery.of(context).size.height * 0.75,
      child: _CountrySearchList(countries: countries, selected: widget.selectedCountry),
    );
    if (selected != null) widget.onCountryChanged(selected);
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

    final countries = countriesAsync.valueOrNull ?? const <CountryEntity>[];
    final isLoading = countriesAsync.isLoading && countries.isEmpty;
    final hasError = countriesAsync.hasError;
    final showEmptyNotice = countriesAsync.hasValue && countries.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text(
            widget.label,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: widget.controller,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: widget.hint,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            prefixIcon: _CountryPrefix(
              isLoading: isLoading,
              selectedCountry: widget.selectedCountry,
              enabled: countries.isNotEmpty,
              onTap: countries.isEmpty ? null : () => _openPicker(countries),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 112, minHeight: 48),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context).couldNotLoadCountriesCheckYourConnection,
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

class _CountryPrefix extends StatelessWidget {
  const _CountryPrefix({
    required this.isLoading,
    required this.selectedCountry,
    required this.enabled,
    this.onTap,
  });

  final bool isLoading;
  final CountryEntity? selectedCountry;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.only(left: 12, right: 4, top: 8, bottom: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.grey400),
                      )
                    else
                      Text(selectedCountry?.icon ?? '🌐', style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 4),
                    Text(
                      selectedCountry?.dialCode ?? '+',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (enabled)
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.grey500),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.only(right: 4),
            color: AppColors.divider,
          ),
        ],
      ),
    );
  }
}

class _CountrySearchList extends StatefulWidget {
  const _CountrySearchList({required this.countries, this.selected});

  final List<CountryEntity> countries;
  final CountryEntity? selected;

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
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: RyvoTextField(
            hint: AppLocalizations.of(context).searchCountryOrDialCode,
            controller: _searchController,
            prefixIcon: const Icon(Icons.search, size: 20),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Flexible(
          child: filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    AppLocalizations.of(context).noCountriesFound,
                    style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final country = filtered[index];
                    final isSelected = country.code == widget.selected?.code;
                    return Material(
                      color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(country),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      country.dialCode,
                                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
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
                                  child: const Icon(Icons.check, size: 14, color: Colors.black),
                                )
                              else
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.divider, width: 1.5),
                                  ),
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
