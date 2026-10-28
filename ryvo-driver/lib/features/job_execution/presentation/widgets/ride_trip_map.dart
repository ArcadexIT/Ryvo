import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/constants/mock_data.dart';
import '../../../../core/location/driving_route.dart';
import '../../../../core/location/trip_markers.dart';
import '../../../../core/theme/app_colors.dart';

/// Full-screen road map with a rounded sheet over the bottom.
class RideTripMap extends StatefulWidget {
  const RideTripMap({
    super.key,
    required this.destination,
    required this.sheet,
    this.driver,
    this.pickup,
    this.dropoff,
    this.top,
    this.onRoute,
  });

  /// Live GPS position. The route starts here when it is known.
  final LatLng? driver;

  /// Where the driving line is aimed: pickup while arriving, dropoff on the trip.
  final LatLng destination;

  final LatLng? pickup;
  final LatLng? dropoff;
  final Widget sheet;
  final Widget? top;

  /// Called when a road route (or the straight-line fallback) is ready.
  final void Function(DrivingRoute route)? onRoute;

  @override
  State<RideTripMap> createState() => _RideTripMapState();
}

class _RideTripMapState extends State<RideTripMap> {
  final DrivingRouteService _routes = DrivingRouteService();
  final GlobalKey _sheetKey = GlobalKey();
  GoogleMapController? _mapController;
  List<LatLng> _points = const [];
  String? _routeKey;
  double _sheetHeight = 280;
  TripMarkerSet? _markers;

  @override
  void initState() {
    super.initState();
    _loadMarkers();
    _loadRoute();
  }

  Future<void> _loadMarkers() async {
    final set = await TripMarkers.load();
    if (mounted) setState(() => _markers = set);
  }

  @override
  void didUpdateWidget(RideTripMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    final origin = widget.driver ?? widget.pickup ?? widget.destination;
    final dest = widget.destination;
    final key =
        '${origin.latitude.toStringAsFixed(3)},${origin.longitude.toStringAsFixed(3)}>'
        '${dest.latitude.toStringAsFixed(4)},${dest.longitude.toStringAsFixed(4)}';
    if (key == _routeKey) return;
    _routeKey = key;
    final route = await _routes.fetch(
      originLat: origin.latitude,
      originLng: origin.longitude,
      destinationLat: dest.latitude,
      destinationLng: dest.longitude,
    );
    if (!mounted || _routeKey != key) return;
    final resolved = route ??
        DrivingRoute(
          points: [origin, dest],
          durationMin: _fallbackMinutes(origin, dest),
          distanceKm: _distanceKm(origin, dest),
        );
    setState(() => _points = resolved.points);
    widget.onRoute?.call(resolved);
    _fit(_points);
  }

  void _fit(List<LatLng> points) {
    final controller = _mapController;
    if (controller == null || points.isEmpty) return;
    final all = <LatLng>[...points];
    if (all.isEmpty) {
      all.add(widget.destination);
      final driver = widget.driver;
      if (driver != null) all.add(driver);
    }
    if (all.length == 1) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(all.first, 15));
      return;
    }
    var south = all.first.latitude;
    var north = all.first.latitude;
    var west = all.first.longitude;
    var east = all.first.longitude;
    for (final point in all) {
      south = math.min(south, point.latitude);
      north = math.max(north, point.latitude);
      west = math.min(west, point.longitude);
      east = math.max(east, point.longitude);
    }
    if (south == north) {
      south -= 0.002;
      north += 0.002;
    }
    if (west == east) {
      west -= 0.002;
      east += 0.002;
    }
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(south, west), northeast: LatLng(north, east)),
        72,
      ),
    );
  }

  void _measureSheet() {
    final height = _sheetKey.currentContext?.size?.height ?? 0;
    if (!mounted || height <= 0 || (height - _sheetHeight).abs() < 1) return;
    setState(() => _sheetHeight = height);
    _fit(_points);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureSheet());
    final line = _points.length >= 2 ? _points : const <LatLng>[];
    final topPad = MediaQuery.paddingOf(context).top + 64;

    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: widget.destination, zoom: 14),
            padding: EdgeInsets.only(top: topPad, bottom: _sheetHeight),
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            polylines: {
              if (line.length >= 2) ...[
                Polyline(
                  polylineId: const PolylineId('route-casing'),
                  points: line,
                  color: Colors.white,
                  width: 8,
                  geodesic: false,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                  jointType: JointType.round,
                ),
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: line,
                  color: AppColors.primary,
                  width: 5,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                  jointType: JointType.round,
                ),
              ],
            },
            markers: {
              if (widget.pickup != null)
                Marker(
                  markerId: const MarkerId('pickup'),
                  position: widget.pickup!,
                  anchor: TripMarkers.pickupAnchor,
                  zIndexInt: 1,
                  icon: _markers?.pickup ??
                      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                ),
              if (widget.dropoff != null)
                Marker(
                  markerId: const MarkerId('dropoff'),
                  position: widget.dropoff!,
                  anchor: TripMarkers.dropoffAnchor,
                  zIndexInt: 1,
                  icon: _markers?.dropoff ??
                      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                ),
              if (widget.driver != null)
                Marker(
                  markerId: const MarkerId('driver'),
                  position: widget.driver!,
                  anchor: TripMarkers.carAnchor,
                  zIndexInt: 2,
                  flat: true,
                  icon: _markers?.car ??
                      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                ),
            },
            style: MockData.mapStyle,
            onMapCreated: (controller) {
              _mapController = controller;
              _fit(line);
            },
          ),
        ),
        if (widget.top != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: widget.top!,
          ),
        Positioned(
          right: 16,
          bottom: _sheetHeight + 12,
          child: Material(
            color: AppColors.surface,
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _fit(line),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.center_focus_strong, size: 22),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: KeyedSubtree(
            key: _sheetKey,
            child: widget.sheet,
          ),
        ),
      ],
    );
  }
}

int _fallbackMinutes(LatLng a, LatLng b) {
  final km = _distanceKm(a, b);
  return math.max(1, (km / 30 * 60).round());
}

double _distanceKm(LatLng a, LatLng b) {
  const earth = 6371.0;
  final dLat = (b.latitude - a.latitude) * math.pi / 180;
  final dLng = (b.longitude - a.longitude) * math.pi / 180;
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(a.latitude * math.pi / 180) *
          math.cos(b.latitude * math.pi / 180) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return earth * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}
