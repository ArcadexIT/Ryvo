import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  const UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
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
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final void Function(String)? onChanged;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final void Function(String)? onFieldSubmitted;
  final Iterable<String>? autofillHints;

  const RyvoTextField({
    super.key,
    required this.hint,
    this.label,
    this.controller,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.inputFormatters,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.focusNode,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onFieldSubmitted,
    this.autofillHints,
  });

  @override
  State<RyvoTextField> createState() => _RyvoTextFieldState();
}

class _RyvoTextFieldState extends State<RyvoTextField> {
  bool _obscured = true;
  FocusNode? _ownedFocus;
  late FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _bindFocus(widget.focusNode);
  }

  void _bindFocus(FocusNode? external) {
    if (external != null) {
      _focus = external;
      _ownedFocus = null;
    } else {
      _ownedFocus = FocusNode();
      _focus = _ownedFocus!;
    }
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(RyvoTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;
    _focus.removeListener(_onFocus);
    _ownedFocus?.dispose();
    _bindFocus(widget.focusNode);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownedFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: widget.validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      initialValue: widget.controller?.text ?? '',
      builder: (state) {
        final borderColor = state.hasError
            ? AppColors.error
            : _focus.hasFocus
                ? AppColors.focusBorder
                : Colors.transparent;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.label != null) ...[
              Text(
                widget.label!,
                style: RyvoTypography.style(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: -0.2,
                ),
              ),
              AppSpacing.h8,
            ],
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.fastOutSlowIn,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1.5),
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                obscureText: widget.isPassword && _obscured,
                keyboardType: widget.keyboardType,
                autofillHints: widget.autofillHints,
                inputFormatters: widget.inputFormatters,
                maxLines: widget.isPassword ? 1 : widget.maxLines,
                readOnly: widget.readOnly,
                onTap: widget.onTap,
                textInputAction: widget.textInputAction,
                textCapitalization: widget.textCapitalization,
                onChanged: (value) {
                  state.didChange(value);
                  widget.onChanged?.call(value);
                },
                onSubmitted: widget.onFieldSubmitted,
                style: RyvoTypography.style(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
                cursorColor: AppColors.focusBorder,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  prefixIcon: widget.prefixIcon != null
                      ? Padding(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.sm,
                            right: AppSpacing.xxs,
                          ),
                          child: widget.prefixIcon,
                        )
                      : null,
                  prefixIconConstraints: widget.prefixIcon != null
                      ? const BoxConstraints(minWidth: 0, minHeight: 48)
                      : null,
                  suffixIcon: widget.isPassword
                      ? GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _obscured = !_obscured);
                          },
                          child: Icon(
                            _obscured
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                        )
                      : widget.suffixIcon,
                ),
              ),
            ),
            _AnimatedFieldError(message: state.errorText),
          ],
        );
      },
    );
  }
}

class _AnimatedFieldError extends StatelessWidget {
  const _AnimatedFieldError({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final visible = message != null && message!.isNotEmpty;
    return ClipRect(
      child: AnimatedAlign(
        alignment: Alignment.topLeft,
        heightFactor: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.fastOutSlowIn,
        child: Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text(
            message ?? '',
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
    );
  }
}
