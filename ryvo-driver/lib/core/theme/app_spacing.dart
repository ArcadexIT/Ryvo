import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: lg, vertical: sm);

  static const SizedBox h8 = SizedBox(height: xs);
  static const SizedBox h12 = SizedBox(height: sm);
  static const SizedBox h16 = SizedBox(height: md);
  static const SizedBox h24 = SizedBox(height: lg);
  static const SizedBox h32 = SizedBox(height: xl);

  static const SizedBox w8 = SizedBox(width: xs);
  static const SizedBox w12 = SizedBox(width: sm);
  static const SizedBox w16 = SizedBox(width: md);
  static const SizedBox w24 = SizedBox(width: lg);
}
