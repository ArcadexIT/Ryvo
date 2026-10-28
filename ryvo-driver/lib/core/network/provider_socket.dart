import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../constants/app_constants.dart';
import 'session_manager.dart';

/// Socket.IO `/tracking` connection for the provider app. Broadcasts the
/// provider's live GPS to the backend and receives incoming job offers, job
/// status changes, chat messages, and in-app notifications.
class ProviderSocket {
  ProviderSocket(this._session);

  final SessionManager _session;
  io.Socket? _socket;
  String? _activeJobId;

  final _incoming = StreamController<Map<String, dynamic>>.broadcast();
  final _status = StreamController<Map<String, dynamic>>.broadcast();
  final _message = StreamController<Map<String, dynamic>>.broadcast();
  final _notification = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onIncomingJob => _incoming.stream;
  Stream<Map<String, dynamic>> get onJobStatus => _status.stream;
  Stream<Map<String, dynamic>> get onMessage => _message.stream;
  Stream<Map<String, dynamic>> get onNotification => _notification.stream;

  bool get connected => _socket?.connected ?? false;
  String? get activeJobId => _activeJobId;

  Future<void> connect() async {
    if (_socket != null) return;
    final token = await _session.getAccessToken();

    final socket = io.io(
      '${AppConstants.wsBaseUrl}/tracking',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token ?? ''})
          .enableReconnection()
          .enableForceNew()
          .build(),
    );

    socket.on('job:incoming', (d) {
      if (d is Map) _incoming.add(Map<String, dynamic>.from(d));
    });
    socket.on('job:status', (d) {
      if (d is Map) _status.add(Map<String, dynamic>.from(d));
    });
    socket.on('job:message', (d) {
      if (d is Map) _message.add(Map<String, dynamic>.from(d));
    });
    socket.on('notification:new', (d) {
      if (d is Map) _notification.add(Map<String, dynamic>.from(d));
    });

    _socket = socket;
  }

  /// The job the provider is currently servicing. When set, live location is
  /// scoped to this job so the customer's tracking screen receives updates.
  void setActiveJob(String? jobId) {
    _activeJobId = jobId;
    if (jobId != null) subscribeJob(jobId);
  }

  /// Emit the provider's current position (scoped to the active job if any).
  Future<void> broadcastLocation({
    required double lat,
    required double lng,
    String? jobId,
    double? heading,
    double? speed,
  }) async {
    if (_socket == null) await connect();
    final providerId = await _session.getProviderId();
    final scopedJobId = jobId ?? _activeJobId;
    _socket?.emit('provider:location', {
      if (providerId != null) 'providerId': providerId,
      'lat': lat,
      'lng': lng,
      if (scopedJobId != null) 'jobId': scopedJobId,
      if (heading != null) 'heading': heading,
      if (speed != null) 'speed': speed,
    });
  }

  void subscribeJob(String jobId) => _socket?.emit('job:subscribe', {'jobId': jobId});
  void unsubscribeJob(String jobId) => _socket?.emit('job:unsubscribe', {'jobId': jobId});

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _incoming.close();
    _status.close();
    _message.close();
    _notification.close();
  }
}
