import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:geolocator/geolocator.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/network/provider_socket.dart';
import '../../domain/entities/location_entity.dart';
import '../../domain/repositories/i_location_repository.dart';

class LocationRemoteDataSource {
  LocationRemoteDataSource(this._dio, this._socket);
  final Dio _dio;
  final ProviderSocket _socket;

  /// Minimum gap between outgoing GPS broadcasts.
  static const Duration _minBroadcastGap = Duration(milliseconds: 2500);

  final Stopwatch _clock = Stopwatch()..start();
  Duration? _lastBroadcastAt;

  bool _throttled() {
    final now = _clock.elapsed;
    final last = _lastBroadcastAt;
    if (last != null && now - last < _minBroadcastGap) return true;
    // Stamp before any await so concurrent callers cannot slip through.
    _lastBroadcastAt = now;
    return false;
  }

  /// Returns true when the server forced the provider offline.
  ///
  /// Socket first: a connected socket gets a single emit and nothing else.
  /// REST `PATCH` is only the fallback while the socket is disconnected (it also
  /// keeps the provider in the Redis geo index). A [seed] call is the one-off
  /// "going online" check and always goes through REST, unthrottled, because
  /// only REST returns the `forcedOffline` coverage verdict.
  Future<bool> broadcastLocation(LocationEntity location, {bool seed = false}) async {
    if (!seed && _throttled()) return false;
    if (seed) _lastBroadcastAt = _clock.elapsed;

    if (!seed) {
      final emitted = await _socket.broadcastLocation(
        lat: location.latitude,
        lng: location.longitude,
      );
      if (emitted) return false;
    }

    final res = await _dio.patch('/provider/location', data: {
      'lat': location.latitude,
      'lng': location.longitude,
      if (_socket.activeJobId != null) 'jobId': _socket.activeJobId,
    });
    final body = res.data;
    final data = body is Map ? body['data'] : null;
    return data is Map && data['forcedOffline'] == true;
  }

  Future<void> setOnlineStatus(bool isOnline) async {
    await _dio.patch('/provider/status', data: {'status': isOnline ? 'online' : 'offline'});
  }

  Future<void> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Location services are disabled.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are denied.');
    }
  }

  Future<LocationEntity> getCurrentLocation() async {
    await _ensureLocationPermission();
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return LocationEntity(
      latitude: p.latitude,
      longitude: p.longitude,
      timestamp: DateTime.now(),
    );
  }

  /// Platform-specific stream settings. Android runs the stream inside a
  /// foreground service (persistent notification + wake lock) and iOS keeps
  /// delivering fixes under the `location` background mode, so the OS does not
  /// kill tracking when the driver backgrounds Ryvo for Waze / Google Maps.
  LocationSettings _streamSettings() {
    const accuracy = LocationAccuracy.high;
    const distanceFilter = 5;
    if (kIsWeb) {
      return const LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter);
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilter,
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationText: 'Sharing your location while you are online for ride matching',
            notificationTitle: 'Ryvo Driver is online',
            enableWakeLock: true,
          ),
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilter,
          activityType: ActivityType.automotiveNavigation,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        );
      default:
        return const LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter);
    }
  }

  Stream<LocationEntity> watchCurrentLocation() async* {
    await _ensureLocationPermission();
    yield* Geolocator.getPositionStream(locationSettings: _streamSettings()).map(
      (p) => LocationEntity(
        latitude: p.latitude,
        longitude: p.longitude,
        timestamp: DateTime.now(),
      ),
    );
  }
}

class LocationRepositoryImpl implements ILocationRepository {
  LocationRepositoryImpl(this._remote);
  final LocationRemoteDataSource _remote;

  @override
  Future<Either<Failure, bool>> broadcastLocation(
    LocationEntity location, {
    bool seed = false,
  }) async {
    try {
      return Right(await _remote.broadcastLocation(location, seed: seed));
    } catch (e) {
      final failure = e is DioException ? e.error : null;
      if (failure is Failure) return Left(failure);
      return Left(NetworkFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setOnlineStatus(bool isOnline) async {
    try {
      await _remote.setOnlineStatus(isOnline);
      return const Right(null);
    } catch (e) {
      final failure = e is DioException ? e.error : null;
      if (failure is Failure) return Left(failure);
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LocationEntity>> getCurrentLocation() async {
    try {
      return Right(await _remote.getCurrentLocation());
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  @override
  Stream<LocationEntity> watchCurrentLocation() => _remote.watchCurrentLocation();
}
