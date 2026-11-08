import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// Minimal auth chrome: dismisses the keyboard on an outside tap and keeps
/// the back control out of a shadowed app bar.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.child,
    this.onBack,
  });

  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (onBack != null)
                IconButton(
                  onPressed: onBack,
                  icon: Icon(
                    Icons.arrow_back,
                    size: 22,
                    color: AppColors.textPrimary,
                  ),
                )
              else
                const SizedBox(height: 12),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle authTitleStyle() {
  return RyvoTypography.style(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.6,
    height: 1.15,
  );
}

TextStyle authBodyStyle() {
  return RyvoTypography.style(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: -0.2,
    height: 1.4,
  );
}
