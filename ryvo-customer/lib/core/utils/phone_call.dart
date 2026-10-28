import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

Future<void> dialPhone(BuildContext context, String? phone) async {
  final trimmed = phone?.trim() ?? '';
  if (trimmed.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).contactNumberNotAvailableYet)),
    );
    return;
  }

  final uri = Uri(scheme: 'tel', path: trimmed);
  final opened = await launchUrl(uri);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).couldNotStartACall)),
    );
  }
}
