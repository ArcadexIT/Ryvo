import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class RatingStars extends StatelessWidget {
  final double rating;
  final double size;
  final bool interactive;
  final ValueChanged<int>? onRatingChanged;

  const RatingStars({
    super.key,
    required this.rating,
    this.size = 20,
    this.interactive = false,
    this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating.floor();
        final half = !filled && i < rating;
        return GestureDetector(
          onTap: interactive ? () => onRatingChanged?.call(i + 1) : null,
          child: Icon(
            filled
                ? Icons.star_rounded
                : half
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            color: AppColors.primary,
            size: size,
          ),
        );
      }),
    );
  }
}

class StarBreakdown extends StatelessWidget {
  final Map<int, double> breakdown;

  const StarBreakdown({super.key, required this.breakdown});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(5, (i) {
        final stars = 5 - i;
        final pct = breakdown[stars] ?? 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Text('$stars', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const Icon(Icons.star_rounded, color: AppColors.primary, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: AppColors.grey800,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 32,
                child: Text(
                  '${(pct * 100).toInt()}%',
                  style: const TextStyle(color: AppColors.textHint, fontSize: 11),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
