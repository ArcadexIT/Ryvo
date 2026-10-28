import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/location/domain/entities/location_entity.dart';
import '../di_providers.dart';

/// Set when the API forces a provider offline for leaving a service zone.
final coverageNoticeProvider = StateProvider<String?>((ref) => null);

class LocationNotifier extends AsyncNotifier<LocationEntity?> {
  @override
  Future<LocationEntity?> build() async {
    ref.listen(locationStreamProvider, (_, next) {
      next.whenData((loc) {
        state = AsyncData(loc);
        if (ref.read(availabilityNotifierProvider)) {
          ref.read(locationRepositoryProvider).broadcastLocation(loc).then((result) {
            result.fold((_) {}, (forcedOffline) {
              if (!forcedOffline) return;
              ref.read(availabilityNotifierProvider.notifier).restore(false);
              ref.read(coverageNoticeProvider.notifier).state =
                  'RYVO is unavailable in the current area';
            });
          });
        }
      });
    });
    return null;
  }
}

final locationNotifierProvider = AsyncNotifierProvider<LocationNotifier, LocationEntity?>(LocationNotifier.new);
