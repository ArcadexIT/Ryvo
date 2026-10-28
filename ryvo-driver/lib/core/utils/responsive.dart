import 'package:flutter/material.dart';

/// Lightweight responsive helpers — base design width is 390 (iPhone 14).
class R {
  R._();

  static const double _designWidth = 390;
  static const double _compactHeight = 680;

  static double scaleOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return (width / _designWidth).clamp(0.82, 1.15);
  }

  static double w(BuildContext context, double value) => value * scaleOf(context);

  static double h(BuildContext context, double value) {
    final heightScale = (MediaQuery.sizeOf(context).height / 844).clamp(0.82, 1.12);
    return value * heightScale;
  }

  static double sp(BuildContext context, double value) => value * scaleOf(context);

  static bool isCompact(BuildContext context) => MediaQuery.sizeOf(context).height < _compactHeight;

  static bool isNarrow(BuildContext context) => MediaQuery.sizeOf(context).width < 360;

  static EdgeInsets pagePadding(BuildContext context) {
    final hPad = w(context, 16).clamp(12.0, 20.0);
    return EdgeInsets.symmetric(horizontal: hPad);
  }

  /// Compact job sheet — keeps Accept/Reject visible without scroll.
  static double jobSheetHeight(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    if (isCompact(context)) return screenH * 0.46;
    if (isNarrow(context)) return screenH * 0.44;
    return screenH * 0.42;
  }
}
