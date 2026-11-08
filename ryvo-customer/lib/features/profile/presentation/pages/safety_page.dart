import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/ryvo_grab_list_tile.dart';
import '../widgets/ryvo_modal_scaffold.dart';

class SafetyPage extends StatelessWidget {
  const SafetyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RyvoModalScaffold(
      title: 'Emergency contacts',
      body: ListView(
        padding: const EdgeInsets.only(top: 4),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'No emergency contacts yet. If you need help during a trip, Ryvo Support stays with you until you are safe.',
              style: RyvoTypography.style(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          RyvoGrabListTile(
            label: 'Help Center',
            onTap: () => context.push('/help'),
          ),
        ],
      ),
    );
  }
}
