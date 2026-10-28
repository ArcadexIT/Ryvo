import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  const UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class RyvoTextField extends StatefulWidget {
  final String hint;
  final String? label;
  final TextEditingController? controller;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? prefixIcon;
  final Widget? prefix;
  final Widget? suffixIcon;
  final EdgeInsetsGeometry? contentPadding;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final void Function(String)? onChanged;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final void Function(String)? onFieldSubmitted;

  const RyvoTextField({
    super.key,
    required this.hint,
    this.label,
    this.controller,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.prefixIcon,
    this.prefix,
    this.suffixIcon,
    this.contentPadding,
    this.inputFormatters,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.focusNode,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onFieldSubmitted,
  });

  @override
  State<RyvoTextField> createState() => _RyvoTextFieldState();
}

class _RyvoTextFieldState extends State<RyvoTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: widget.controller,
          obscureText: widget.isPassword && _obscured,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          inputFormatters: widget.inputFormatters,
          maxLines: widget.isPassword ? 1 : widget.maxLines,
          readOnly: widget.readOnly,
          onTap: widget.onTap,
          onChanged: widget.onChanged,
          focusNode: widget.focusNode,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          onFieldSubmitted: widget.onFieldSubmitted,
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: widget.hint,
            contentPadding: widget.contentPadding ??
                (widget.prefix != null
                    ? const EdgeInsets.fromLTRB(4, 16, 16, 16)
                    : widget.prefixIcon != null
                        ? const EdgeInsets.fromLTRB(4, 16, 16, 16)
                        : null),
            prefix: widget.prefix,
            prefixIcon: widget.prefix == null && widget.prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 14, right: 8),
                    child: Align(
                      alignment: Alignment.center,
                      widthFactor: 1,
                      child: widget.prefixIcon,
                    ),
                  )
                : null,
            prefixIconConstraints: widget.prefix == null && widget.prefixIcon != null
                ? const BoxConstraints(minWidth: 48, minHeight: 48)
                : null,
            suffixIcon: widget.isPassword
                ? GestureDetector(
                    onTap: () => setState(() => _obscured = !_obscured),
                    child: Icon(
                      _obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.grey500,
                      size: 20,
                    ),
                  )
                : widget.suffixIcon,
          ),
        ),
      ],
    );
  }
}
