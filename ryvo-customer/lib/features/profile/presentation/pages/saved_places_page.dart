import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../../../shared/providers/app_providers.dart';
import '../widgets/ryvo_modal_scaffold.dart';

class SavedPlacesPage extends ConsumerWidget {
  const SavedPlacesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(jobsListProvider).valueOrNull ?? const <JobModel>[];
    final places = _places(jobs);
    return RyvoModalScaffold(
      title: 'Saved places',
      body: places.isEmpty
          ? Center(
              child: Text(
                'No saved places yet',
                style: RyvoTypography.style(color: AppColors.textSecondary),
              ),
            )
          : ListView.builder(
              itemCount: places.length,
              itemBuilder: (context, index) {
                final place = places[index];
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RyvoTypography.style(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (place.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          place.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RyvoTypography.style(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _Place {
  const _Place(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

List<_Place> _places(List<JobModel> jobs) {
  final ordered = [...jobs]..sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
  final seen = <String>{};
  final places = <_Place>[];
  for (final job in ordered) {
    final address = job.dropoffAddress?.trim() ?? '';
    if (address.isEmpty) continue;
    if (job.status == 'cancelled' || job.status.startsWith('cancelled')) {
      continue;
    }
    if (!seen.add(address.toLowerCase())) continue;
    final parts = address.split(',');
    final title = parts.first.trim();
    final rest = parts.length > 1 ? parts.sublist(1).join(',').trim() : '';
    places.add(_Place(title.isEmpty ? address : title, rest));
  }
  return places;
}
