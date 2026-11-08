import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../constants/app_constants.dart';
import 'session_manager.dart';

/// Socket.IO `/tracking` connection for the provider app. Broadcasts the
/// provider's live GPS to the backend and receives incoming job offers, job
/// status changes, chat messages, and in-app notifications.
///
/// Lifecycle guarantees:
/// * The JWT is read from secure storage on **every** handshake (initial and
///   each reconnect) via an auth function, so a token refreshed by the REST
///   layer is never replaced by a stale one captured at first connect.
/// * After every (re)connect the active job room is re-joined with
///   `job:subscribe`, so the driver keeps receiving status updates.
/// * A server-initiated disconnect or auth rejection (which socket.io does not
///   retry on its own) is retried with capped exponential backoff.
class ProviderSocket {
  ProviderSocket(this._session);

  final SessionManager _session;
  io.Socket? _socket;
  String? _activeJobId;

  /// Job room that the *current* connection has already joined. Cleared on
  /// disconnect so the next connect re-subscribes exactly once.
  String? _subscribedJobId;
  String? _providerId;

  Timer? _retryTimer;
  int _retryAttempt = 0;

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

    final socket = io.io(
      '${AppConstants.wsBaseUrl}/tracking',
      io.OptionBuilder()
          .setTransports(['websocket'])
          // Invoked for every CONNECT packet, including reconnects: always the
          // latest token from secure storage, never a cached copy.
          .setAuthFn(_provideFreshAuth)
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

    socket.onConnect((_) => _onConnect());
    socket.onDisconnect(_onDisconnect);
    socket.onConnectError(_onConnectError);
    socket.onReconnect((_) => _onReconnect());

    _socket = socket;
  }

  void _provideFreshAuth(void Function(Map auth) callback) {
    _session.getAccessToken().then(
      (token) => callback({'token': token ?? ''}),
      onError: (Object _) => callback({'token': ''}),
    );
  }

  void _onConnect() {
    _retryAttempt = 0;
    _retryTimer?.cancel();
    _resubscribeActiveJob();
  }

  void _onReconnect() {
    _retryAttempt = 0;
    _resubscribeActiveJob();
  }

  void _onDisconnect(dynamic reason) {
    _subscribedJobId = null;
    if (kDebugMode) debugPrint('[ProviderSocket] disconnected: $reason');
    // socket.io only auto-reconnects for transport drops. When the server
    // closes the session (e.g. expired JWT) we must reconnect ourselves; the
    // auth function guarantees a fresh token on that attempt.
    if (reason == 'io server disconnect') _scheduleRetry();
  }

  void _onConnectError(dynamic error) {
    _subscribedJobId = null;
    if (kDebugMode) debugPrint('[ProviderSocket] connect error: $error');
    _scheduleRetry();
  }

  void _scheduleRetry() {
    final socket = _socket;
    if (socket == null || socket.connected) return;
    if (_retryTimer?.isActive ?? false) return;
    final delayMs = math.min(2000 * math.pow(2, _retryAttempt).toInt(), 30000);
    _retryAttempt = math.min(_retryAttempt + 1, 5);
    _retryTimer = Timer(Duration(milliseconds: delayMs), () {
      final s = _socket;
      if (s == null || s.connected) return;
      s.connect();
    });
  }

  /// Re-join the active job room on the (re)established connection.
  void _resubscribeActiveJob() {
    final jobId = _activeJobId;
    if (jobId != null) subscribeJob(jobId);
  }

  /// The job the provider is currently servicing. When set, live location is
  /// scoped to this job so the customer's tracking screen receives updates.
  void setActiveJob(String? jobId) {
    final previous = _activeJobId;
    _activeJobId = jobId;
    if (previous != null && previous != jobId) {
      unsubscribeJob(previous);
    }
    if (jobId != null) subscribeJob(jobId);
  }

  /// Emit the provider's current position (scoped to the active job if any).
  ///
  /// Returns `true` when the fix was handed to a connected socket, `false`
  /// when the socket is down so the caller can fall back to REST.
  Future<bool> broadcastLocation({
    required double lat,
    required double lng,
    String? jobId,
    double? heading,
    double? speed,
  }) async {
    if (_socket == null) await connect();
    final socket = _socket;
    if (socket == null || !socket.connected) return false;

    _providerId ??= await _session.getProviderId();
    final scopedJobId = jobId ?? _activeJobId;
    socket.emit('provider:location', {
      if (_providerId != null) 'providerId': _providerId,
      'lat': lat,
      'lng': lng,
      if (scopedJobId != null) 'jobId': scopedJobId,
      if (heading != null) 'heading': heading,
      if (speed != null) 'speed': speed,
    });
    return true;
  }

  /// Idempotent: a room already joined on this connection is not re-emitted,
  /// so repeated `setActiveJob(sameId)` calls (e.g. from polling) cost nothing.
  void subscribeJob(String jobId) {
    final socket = _socket;
    if (socket == null || !socket.connected) return;
    if (_subscribedJobId == jobId) return;
    socket.emit('job:subscribe', {'jobId': jobId});
    _subscribedJobId = jobId;
  }

  void unsubscribeJob(String jobId) {
    _socket?.emit('job:unsubscribe', {'jobId': jobId});
    if (_subscribedJobId == jobId) _subscribedJobId = null;
  }

  void disconnect() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;
    _subscribedJobId = null;
    _providerId = null;
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
