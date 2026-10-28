import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

class MapsNavigation {
  MapsNavigation._();

  static bool hasCoordinates(double? lat, double? lng) =>
      lat != null && lng != null && lat != 0 && lng != 0;

  static String copyText({
    required String address,
    double? latitude,
    double? longitude,
  }) {
    final trimmed = address.trim();
    final hasCoords = hasCoordinates(latitude, longitude);

    if (trimmed.isNotEmpty && trimmed != 'Customer location') {
      if (hasCoords) {
        return '$trimmed\n$latitude, $longitude';
      }
      return trimmed;
    }
    if (hasCoords) {
      return '$latitude, $longitude';
    }
    return trimmed.isEmpty ? 'Customer location' : trimmed;
  }

  static Future<bool> openGoogleMaps({
    required String address,
    double? latitude,
    double? longitude,
  }) async {
    final hasCoords = hasCoordinates(latitude, longitude);

    if (hasCoords) {
      if (Platform.isAndroid) {
        final navUri = Uri.parse('google.navigation:q=$latitude,$longitude&mode=d');
        if (await canLaunchUrl(navUri)) {
          return launchUrl(navUri, mode: LaunchMode.externalApplication);
        }
      } else if (Platform.isIOS) {
        final iosUri = Uri.parse(
          'comgooglemaps://?daddr=$latitude,$longitude&directionsmode=driving',
        );
        if (await canLaunchUrl(iosUri)) {
          return launchUrl(iosUri, mode: LaunchMode.externalApplication);
        }
      }
    }

    final destination = hasCoords
        ? '$latitude,$longitude'
        : Uri.encodeComponent(address.trim().isEmpty ? 'Customer location' : address.trim());

    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destination&travelmode=driving',
    );
    return launchUrl(webUri, mode: LaunchMode.externalApplication);
  }
}
