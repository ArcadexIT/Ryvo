import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../constants/app_constants.dart';
import 'token_storage.dart';

/// Live provider location for a job.
class JobLocation {
  JobLocation({required this.lat, required this.lng, this.heading, this.jobId});

  factory JobLocation.fromMap(Map<String, dynamic> m) => JobLocation(
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        heading: m['heading'] == null ? null : (m['heading'] as num).toDouble(),
        jobId: m['jobId'] as String?,
      );

  final double lat;
  final double lng;
  final double? heading;
  final String? jobId;
}

/// Thin wrapper over the Socket.IO `/tracking` namespace used by the customer
/// app to receive live provider location, job status changes, chat messages,
/// and in-app notifications.
class TrackingSocket {
  TrackingSocket({TokenStorage? tokenStorage})
      : _tokenStorage = tokenStorage ?? TokenStorage();

  final TokenStorage _tokenStorage;
  io.Socket? _socket;

  final _location = StreamController<JobLocation>.broadcast();
  final _status = StreamController<Map<String, dynamic>>.broadcast();
  final _message = StreamController<Map<String, dynamic>>.broadcast();
  final _notification = StreamController<Map<String, dynamic>>.broadcast();

  Stream<JobLocation> get onLocation => _location.stream;
  Stream<Map<String, dynamic>> get onStatus => _status.stream;
  Stream<Map<String, dynamic>> get onMessage => _message.stream;
  Stream<Map<String, dynamic>> get onNotification => _notification.stream;

  bool get connected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (_socket != null) return;
    final token = await _tokenStorage.getAccessToken();

    final socket = io.io(
      '${AppConstants.wsBaseUrl}/tracking',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token ?? ''})
          .enableReconnection()
          .enableForceNew()
          .build(),
    );

    socket.onConnect((_) {});
    socket.on('job:location', (data) {
      if (data is Map) _location.add(JobLocation.fromMap(Map<String, dynamic>.from(data)));
    });
    socket.on('job:status', (data) {
      if (data is Map) _status.add(Map<String, dynamic>.from(data));
    });
    socket.on('job:provider_assigned', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        _status.add(map);
        final provider = map['provider'];
        if (provider is Map) {
          final lat = provider['currentLat'];
          final lng = provider['currentLng'];
          if (lat is num && lng is num) {
            _location.add(JobLocation(
              lat: lat.toDouble(),
              lng: lng.toDouble(),
              jobId: map['jobId'] as String?,
            ));
          }
        }
      }
    });
    socket.on('job:message', (data) {
      if (data is Map) _message.add(Map<String, dynamic>.from(data));
    });
    socket.on('notification:new', (data) {
      if (data is Map) _notification.add(Map<String, dynamic>.from(data));
    });
    socket.on('job:bid_received', (data) {
      if (data is Map) _status.add(Map<String, dynamic>.from(data));
    });

    _socket = socket;
  }

  void subscribeJob(String jobId) {
    _socket?.emit('job:subscribe', {'jobId': jobId});
  }

  void unsubscribeJob(String jobId) {
    _socket?.emit('job:unsubscribe', {'jobId': jobId});
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    _location.close();
    _status.close();
    _message.close();
    _notification.close();
  }
}
