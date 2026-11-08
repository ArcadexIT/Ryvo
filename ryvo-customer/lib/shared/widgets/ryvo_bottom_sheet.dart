import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';

/// Near full-screen sheet. Opens at 90% and can stretch to the top of the screen.
Future<T?> showRyvoModalSheet<T>({
  required BuildContext context,
  required Widget child,
  bool isDismissible = true,
  bool enableDrag = true,
  double initialChildSize = 0.9,
  double minChildSize = 0.5,
  double maxChildSize = 1.0,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: initialChildSize,
          minChildSize: minChildSize,
          maxChildSize: maxChildSize,
          builder: (context, scrollController) {
            return Material(
              color: AppColors.surface,
              clipBehavior: Clip.antiAlias,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PrimaryScrollController(
                      controller: scrollController,
                      child: child,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

class RyvoBottomSheet extends StatelessWidget {
  final String? title;
  final Widget child;
  final bool showHandle;
  final double? maxHeight;

  const RyvoBottomSheet({
    super.key,
    this.title,
    required this.child,
    this.showHandle = true,
    this.maxHeight,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool isDismissible = true,
    bool enableDrag = true,
    double? maxHeight,
  }) {
    return showRyvoModalSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            AppSpacing.h8,
            Padding(
              padding: AppSpacing.pagePadding,
              child: Text(
                title,
                style: RyvoTypography.heading(
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            AppSpacing.h12,
          ],
          Expanded(child: child),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: maxHeight != null
          ? BoxConstraints(maxHeight: maxHeight!)
          : BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
      decoration: BoxDecoration(
        color: AppColors.modal,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        mainAxisSize: maxHeight != null ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (showHandle) ...[
            AppSpacing.h8,
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
          if (title != null) ...[
            AppSpacing.h16,
            Padding(
              padding: AppSpacing.pagePadding,
              child: Text(
                title!,
                style: RyvoTypography.heading(
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          Flexible(child: child),
        ],
      ),
    );
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom,
      ),
      child: content,
    );
  }
}
