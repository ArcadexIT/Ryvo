import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/location_entity.dart';

abstract class ILocationRepository {
  /// Right value is true when the server forced the provider offline.
  ///
  /// Live updates are socket-first and throttled (max 1 per 2.5s); REST is only
  /// used while the socket is down. Pass [seed] for the one-off "going online"
  /// check, which must reach the REST endpoint to receive the coverage verdict.
  Future<Either<Failure, bool>> broadcastLocation(
    LocationEntity location, {
    bool seed = false,
  });
  Future<Either<Failure, void>> setOnlineStatus(bool isOnline);
  Future<Either<Failure, LocationEntity>> getCurrentLocation();
  Stream<LocationEntity> watchCurrentLocation();
}
