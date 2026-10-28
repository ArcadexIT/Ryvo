import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/location_entity.dart';

abstract class ILocationRepository {
  /// Right value is true when the server forced the provider offline.
  Future<Either<Failure, bool>> broadcastLocation(LocationEntity location);
  Future<Either<Failure, void>> setOnlineStatus(bool isOnline);
  Future<Either<Failure, LocationEntity>> getCurrentLocation();
  Stream<LocationEntity> watchCurrentLocation();
}
