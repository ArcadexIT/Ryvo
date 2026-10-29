import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';

const shareableTripStatuses = {
  'matched',
  'provider_en_route',
  'arrived',
  'in_progress',
};

class ShareTripButton extends ConsumerStatefulWidget {
  const ShareTripButton.action({super.key, required this.jobId}) : compact = false;

  const ShareTripButton.icon({super.key, required this.jobId}) : compact = true;

  final String jobId;
  final bool compact;

  @override
  ConsumerState<ShareTripButton> createState() => _ShareTripButtonState();
}

class _ShareTripButtonState extends ConsumerState<ShareTripButton> {
  bool _busy = false;

  Future<void> _onPressed() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    try {
      final link = await ref.read(jobRepositoryProvider).shareTrip(widget.jobId);
      if (!mounted) return;
      if (link.reused) {
        await _showExisting(link.url);
      } else {
        await _share(link.url);
      }
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException ? error.message : l10n.couldNotShareTrip;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showExisting(String url) async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.shareTrip,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.tripShareHint,
                  style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                RyvoButton(
                  label: l10n.shareAgain,
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _share(url);
                  },
                ),
                const SizedBox(height: 8),
                RyvoButton(
                  label: l10n.stopSharing,
                  variant: RyvoButtonVariant.ghost,
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _stop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _share(String url) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    await Share.share(
      '${l10n.followMyRyvoTrip}\n$url',
      subject: l10n.followMyRyvoTrip,
      sharePositionOrigin: origin,
    );
  }

  Future<void> _stop() async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(jobRepositoryProvider).stopSharingTrip(widget.jobId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.sharingStopped)));
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException ? error.message : l10n.couldNotShareTrip;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (widget.compact) {
      return IconButton(
        tooltip: l10n.shareTrip,
        onPressed: _busy ? null : _onPressed,
        icon: Icon(
          Icons.ios_share,
          color: _busy ? AppColors.textSecondary : AppColors.primary,
        ),
      );
    }
    return GestureDetector(
      onTap: _busy ? null : _onPressed,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.ios_share,
          color: _busy ? AppColors.textSecondary : AppColors.primary,
          size: 18,
        ),
      ),
    );
  }
}
