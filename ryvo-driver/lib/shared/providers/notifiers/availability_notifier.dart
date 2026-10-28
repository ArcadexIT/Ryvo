import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../di_providers.dart';

class AvailabilityNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Reflect server status after relaunch without sending a status update.
  void restore(bool online) {
    state = online;
  }

  /// Returns an error message when the server rejects the status change.
  Future<String?> setOnline(bool online) async {
    final result = await ref.read(locationRepositoryProvider).setOnlineStatus(online);
    return result.fold((failure) {
      if (online) state = false;
      return failure.message;
    }, (_) {
      state = online;
      return null;
    });
  }
}
