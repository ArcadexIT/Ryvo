import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../features/job/domain/entities/job_entity.dart';
import '../../../../shared/providers/app_providers.dart';

/// Customer vehicle summary shown while navigating to a job.
class JobVehicleCard extends StatelessWidget {
  const JobVehicleCard({super.key, required this.job});

  final MockJob job;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vehicle = job.vehicle;
    final shown = vehicle != null && !vehicle.isBlank ? vehicle : null;
    final title = _title(l10n, shown);
    final specs = shown == null ? const <_VehicleSpec>[] : _specs(l10n, shown);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Icon(
                  shown?.type == 'motorcycle' ? Icons.two_wheeler : Icons.directions_car_filled_outlined,
                  color: AppColors.textPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.vehicle.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textHint,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              if (shown != null && shown.plate.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE8FCCE)),
                  ),
                  child: Text(
                    shown.plate,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF92400E),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (specs.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final spec in specs) _SpecChip(icon: spec.icon, label: spec.label),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _title(AppLocalizations l10n, JobVehicle? shown) {
    if (shown == null) {
      final fallback = job.vehicleInfo.trim();
      return fallback.isEmpty ? l10n.vehicleNotProvided : fallback;
    }
    if (shown.headline.isNotEmpty) return shown.headline;
    return l10n.vehicle;
  }

  List<_VehicleSpec> _specs(AppLocalizations l10n, JobVehicle vehicle) {
    String? engine(String? raw) {
      final value = raw?.trim() ?? '';
      if (value.isEmpty) return null;
      if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) return value;
      final n = double.tryParse(value);
      if (n == null) return value;
      if (n >= 50) return '${n.round()} cc';
      return '${value}L';
    }

    String? labelFor(String? raw) {
      switch (raw?.toLowerCase()) {
        case 'car':
          return l10n.car;
        case 'motorcycle':
          return l10n.motorcycle;
        case 'petrol':
          return l10n.petrol;
        case 'diesel':
          return l10n.diesel;
        case 'electric':
          return l10n.electric;
        case 'manual':
          return l10n.manual;
        case 'auto':
        case 'automatic':
          return l10n.automatic;
        default:
          final value = raw?.trim() ?? '';
          if (value.isEmpty) return null;
          return value
              .split(RegExp(r'\s+'))
              .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
              .join(' ');
      }
    }

    return [
      if (labelFor(vehicle.type) case final type?) _VehicleSpec(Icons.directions_car_outlined, type),
      if (labelFor(vehicle.fuelType) case final fuel?) _VehicleSpec(Icons.local_gas_station_outlined, fuel),
      if (labelFor(vehicle.transmission) case final transmission?)
        _VehicleSpec(Icons.settings_outlined, transmission),
      if (labelFor(vehicle.color) case final color?) _VehicleSpec(Icons.palette_outlined, color),
      if (engine(vehicle.engineCapacity) case final capacity?) _VehicleSpec(Icons.speed_outlined, capacity),
    ];
  }
}

class _VehicleSpec {
  const _VehicleSpec(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _SpecChip extends StatelessWidget {
  const _SpecChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
