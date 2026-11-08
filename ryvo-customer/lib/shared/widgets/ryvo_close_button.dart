import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

/// Top-left dismiss control for screens that slide up from the bottom.
class RyvoCloseButton extends StatelessWidget {
  const RyvoCloseButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).maybePop();
      },
      icon: Icon(
        CupertinoIcons.xmark,
        size: 20,
        color: AppColors.textPrimary,
      ),
    );
  }
}
