import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class SearchableDropdownField extends FormField<String> {
  SearchableDropdownField({
    super.key,
    required this.label,
    required String hint,
    required List<String> options,
    this.value,
    bool enabled = true,
    bool loading = false,
    List<String> pinnedOptions = const [],
    super.validator,
    required ValueChanged<String?> onChanged,
  }) : super(
          initialValue: value,
          enabled: enabled && !loading,
          builder: (state) {
            final selected = state.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: (!enabled || loading)
                      ? null
                      : () async {
                          final picked = await showModalBottomSheet<String>(
                            context: state.context,
                            isScrollControlled: true,
                            backgroundColor: AppColors.modal,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            builder: (ctx) => _SearchSheet(
                              title: label,
                              options: options,
                              selected: selected,
                              pinnedOptions: pinnedOptions,
                            ),
                          );
                          if (picked != null) {
                            state.didChange(picked);
                            onChanged(picked);
                          }
                        },
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      hintText: loading ? AppLocalizations.of(state.context).loading : hint,
                      hintStyle: GoogleFonts.poppins(color: AppColors.textHint, fontSize: 14),
                      errorText: state.errorText,
                      suffixIcon: loading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              ),
                            )
                          : Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: enabled ? AppColors.textSecondary : AppColors.textHint,
                            ),
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
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    isEmpty: selected == null || selected.isEmpty,
                    child: Text(
                      selected ?? '',
                      style: GoogleFonts.poppins(
                        color: enabled ? AppColors.textPrimary : AppColors.textHint,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            );
          },
        );

  final String label;
  final String? value;

  @override
  FormFieldState<String> createState() => _SearchableDropdownFieldState();
}

class _SearchableDropdownFieldState extends FormFieldState<String> {
  @override
  void didUpdateWidget(covariant FormField<String> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = widget as SearchableDropdownField;
    final previous = oldWidget as SearchableDropdownField;
    if (current.value != previous.value && current.value != value) {
      setValue(current.value);
    }
  }
}

class _SearchSheet extends StatefulWidget {
  const _SearchSheet({
    required this.title,
    required this.options,
    required this.selected,
    this.pinnedOptions = const [],
  });

  final String title;
  final List<String> options;
  final String? selected;
  final List<String> pinnedOptions;

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  late final TextEditingController _search;
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
    _filtered = _compose('');
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<String> _compose(String query) {
    final pinned = <String>[];
    final seen = <String>{};
    for (final item in widget.pinnedOptions) {
      if (widget.options.contains(item) && seen.add(item)) {
        pinned.add(item);
      }
    }
    final rest = widget.options.where((o) => !seen.contains(o));
    final q = query.trim().toLowerCase();
    final filteredRest = q.isEmpty
        ? rest.toList()
        : rest.where((o) => o.toLowerCase().contains(q)).toList();
    return [...pinned, ...filteredRest];
  }

  void _onSearch(String query) {
    setState(() => _filtered = _compose(query));
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.7;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select ${widget.title}',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: _onSearch,
                style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).search,
                  hintStyle: GoogleFonts.poppins(color: AppColors.textHint, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
                  filled: true,
                  fillColor: AppColors.surface,
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(
                        AppLocalizations.of(context).noMatches,
                        style: GoogleFonts.poppins(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final item = _filtered[index];
                        final selected = item == widget.selected;
                        return ListTile(
                          title: Text(
                            item,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          trailing: selected
                              ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                              : null,
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
