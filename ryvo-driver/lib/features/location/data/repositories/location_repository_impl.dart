import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/network/provider_socket.dart';
import '../../domain/entities/location_entity.dart';
import '../../domain/repositories/i_location_repository.dart';

class LocationRemoteDataSource {
  LocationRemoteDataSource(this._dio, this._socket);
  final Dio _dio;
  final ProviderSocket _socket;

  Future<bool> broadcastLocation(LocationEntity location) async {
    // REST path: keeps the provider in the Redis geo index even if the socket
    // handshake fails (common when switching between apps on one emulator).
    final res = await _dio.patch('/provider/location', data: {
      'lat': location.latitude,
      'lng': location.longitude,
      if (_socket.activeJobId != null) 'jobId': _socket.activeJobId,
    });
    final body = res.data;
    final data = body is Map ? body['data'] : null;
    if (data is Map && data['forcedOffline'] == true) return true;
    // Realtime path: push to the /tracking socket so subscribed customers and
    // the admin live-map update instantly.
    await _socket.broadcastLocation(lat: location.latitude, lng: location.longitude);
    return false;
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

  Stream<LocationEntity> watchCurrentLocation() async* {
    await _ensureLocationPermission();
    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).map((p) => LocationEntity(
          latitude: p.latitude,
          longitude: p.longitude,
          timestamp: DateTime.now(),
        ));
  }
}

class LocationRepositoryImpl implements ILocationRepository {
  LocationRepositoryImpl(this._remote);
  final LocationRemoteDataSource _remote;

  @override
  Future<Either<Failure, bool>> broadcastLocation(LocationEntity location) async {
    try {
      return Right(await _remote.broadcastLocation(location));
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
