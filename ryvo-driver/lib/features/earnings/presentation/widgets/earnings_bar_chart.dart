import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

class EarningsBarChart extends StatelessWidget {
  const EarningsBarChart({super.key, this.values = const []});

  final List<double> values;

  static const _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final data = List<double>.generate(7, (i) => i < values.length ? values[i] : 0);
    final maxVal = data.fold<double>(0, (m, v) => v > m ? v : m);

    return Column(
      children: [
        SizedBox(
          height: 104,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final value = data[i];
              final isPeak = maxVal > 0 && value == maxVal;
              final height = maxVal <= 0 || value <= 0 ? 2.0 : 6 + (value / maxVal) * 98;
              return Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.fastOutSlowIn,
                    width: 7,
                    height: height,
                    decoration: BoxDecoration(
                      color: isPeak ? AppColors.primary : AppColors.grey300,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Container(height: 1, color: AppColors.divider),
        const SizedBox(height: 8),
        Row(
          children: List.generate(7, (i) {
            final value = data[i];
            final isPeak = maxVal > 0 && value == maxVal;
            return Expanded(
              child: Text(
                _weekDays[i],
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: isPeak ? FontWeight.w700 : FontWeight.w500,
                  color: isPeak ? AppColors.textPrimary : AppColors.textHint,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
