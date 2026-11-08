import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/app_colors.dart';

/// A rasterised driver marker plus whether it should follow the heading.
///
/// Top-down art points up and rotates with the car. A side-profile image
/// sits in a round medallion instead, and a rotated circle would tilt the
/// picture, so it stays upright.
class DriverMarkerIcon {
  const DriverMarkerIcon(this.descriptor, {required this.rotates});

  final BitmapDescriptor descriptor;
  final bool rotates;
}

/// The single renderer for every driver vehicle on every map.
///
/// Markers are 32×32 logical pixels, centred on the road
/// ([DriverMarkerRenderer.anchor], `flat: true`). Each icon is built once per
/// `(imageUrl, pixel ratio, theme)` and kept for the session, so socket ticks
/// and camera moves never rasterise or download anything.
class DriverMarkerRenderer {
  DriverMarkerRenderer._();

  /// Logical footprint handed to the map.
  static const double logicalSize = 32;

  /// Medallion diameter for side-profile artwork.
  static const double _medallionSize = 30;

  /// Room left inside the canvas for the drop shadow.
  static const double _artBox = 28;

  /// Anchor that seats the marker dead-centre on the lane.
  static const Offset anchor = Offset(0.5, 0.5);

  /// Images wider than this (width / height) read as side-profile art.
  static const double _sideProfileAspect = 1.2;

  static const Duration _retryAfterFailure = Duration(seconds: 60);

  static final Map<String, DriverMarkerIcon> _cache = {};
  static final Map<String, Future<DriverMarkerIcon>> _inflight = {};
  static final Map<String, DateTime> _failedAt = {};

  static final Dio _http = Dio(
    BaseOptions(
      responseType: ResponseType.bytes,
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  static double get _devicePixelRatio {
    final views = ui.PlatformDispatcher.instance.views;
    return views.isEmpty ? 3.0 : views.first.devicePixelRatio;
  }

  static String _key(String? imageUrl, double dpr, bool dark) =>
      '${imageUrl ?? 'vector'}_${dpr}_${dark ? 'dark' : 'light'}';

  /// Cached icon, or null when it has not been built yet.
  static DriverMarkerIcon? peek({
    String? imageUrl,
    double? devicePixelRatio,
    bool? dark,
  }) {
    final url = _normalise(imageUrl);
    return _cache[_key(
      url,
      devicePixelRatio ?? _devicePixelRatio,
      dark ?? AppColors.isDark,
    )];
  }

  /// Returns the cached icon, building it on first use. A missing, slow, or
  /// broken backend image falls back to the built-in silhouette, so the map
  /// never waits on the network and never shows a stock pin.
  static Future<DriverMarkerIcon> load({
    String? imageUrl,
    double? devicePixelRatio,
    bool? dark,
  }) {
    final dpr = devicePixelRatio ?? _devicePixelRatio;
    final isDark = dark ?? AppColors.isDark;
    var url = _normalise(imageUrl);

    final failedAt = url == null ? null : _failedAt[url];
    if (failedAt != null &&
        DateTime.now().difference(failedAt) < _retryAfterFailure) {
      url = null;
    }

    final key = _key(url, dpr, isDark);
    final cached = _cache[key];
    if (cached != null) return Future.value(cached);

    return _inflight[key] ??= _build(url, dpr, isDark, key)
        .whenComplete(() => _inflight.remove(key));
  }

  static String? _normalise(String? url) {
    final trimmed = url?.trim();
    if (trimmed == null || !trimmed.startsWith('http')) return null;
    return trimmed;
  }

  static Future<DriverMarkerIcon> _build(
    String? url,
    double dpr,
    bool dark,
    String key,
  ) async {
    DriverMarkerIcon? icon;
    if (url != null) {
      try {
        icon = await _renderNetwork(url, dpr);
      } catch (_) {
        _failedAt[url] = DateTime.now();
      }
    }
    if (icon == null) {
      final vectorKey = _key(null, dpr, dark);
      final existing = _cache[vectorKey];
      if (existing != null) return existing;
      icon = await _renderVector(dpr, dark);
      _cache[vectorKey] = icon;
      return icon;
    }
    _cache[key] = icon;
    return icon;
  }

  // ─── Top-down silhouette ───────────────────────────────────────────────

  static Future<DriverMarkerIcon> _renderVector(double dpr, bool dark) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(dpr);
    const c = Offset(logicalSize / 2, logicalSize / 2);
    final paint = Paint()..isAntiAlias = true;

    RRect body(double w, double h, double r, [double dy = 0]) =>
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c.translate(0, dy), width: w, height: h),
          Radius.circular(r),
        );

    paint
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawRRect(body(17, 28, 6, 2), paint);
    paint.maskFilter = null;

    final shell = dark ? AppColors.white : AppColors.obsidian;
    final keyline = dark ? AppColors.obsidian : AppColors.white;
    final glass = dark ? AppColors.obsidian : AppColors.grey300;

    paint.color = keyline;
    canvas.drawRRect(body(17, 28, 6), paint);
    paint.color = shell;
    canvas.drawRRect(body(14.6, 25.6, 4.8), paint);

    paint.color = glass;
    canvas.drawRRect(body(9.6, 6, 1.8, -6.2), paint); // windscreen (front)
    canvas.drawRRect(body(9.6, 4.6, 1.6, 6.4), paint); // rear glass

    return _encode(recorder, dpr, rotates: true);
  }

  // ─── Backend artwork ───────────────────────────────────────────────────

  static Future<DriverMarkerIcon> _renderNetwork(String url, double dpr) async {
    final response = await _http.get<List<int>>(url);
    final data = response.data;
    if (data == null || data.isEmpty) throw StateError('empty image');

    // Decode straight at display resolution instead of full size.
    final target = (logicalSize * dpr).ceil();
    final codec = await ui.instantiateImageCodec(
      data is Uint8List ? data : Uint8List.fromList(data),
      targetWidth: target,
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    final image = frame.image;

    try {
      final aspect = image.width / image.height;
      final sideProfile = aspect > _sideProfileAspect;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(dpr);
      return sideProfile
          ? await _paintMedallion(recorder, canvas, image, dpr)
          : await _paintTopDown(recorder, canvas, image, dpr);
    } finally {
      image.dispose();
    }
  }

  static Rect _fit(ui.Image image, double box, double dpr) {
    // Image pixels are physical; the canvas is already scaled to logical.
    final w = image.width / dpr;
    final h = image.height / dpr;
    final scale = math.min(box / w, box / h);
    final fw = w * scale;
    final fh = h * scale;
    return Rect.fromLTWH(
      (logicalSize - fw) / 2,
      (logicalSize - fh) / 2,
      fw,
      fh,
    );
  }

  static Future<DriverMarkerIcon> _paintTopDown(
    ui.PictureRecorder recorder,
    Canvas canvas,
    ui.Image image,
    double dpr,
  ) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = _fit(image, _artBox, dpr);

    // Crisp 2px shadow cut from the art's own silhouette.
    canvas.drawImageRect(
      image,
      src,
      dst.shift(const Offset(0, 2)),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = ColorFilter.mode(
          Colors.black.withValues(alpha: 0.18),
          BlendMode.srcIn,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.medium,
    );
    return _encode(recorder, dpr, rotates: true);
  }

  static Future<DriverMarkerIcon> _paintMedallion(
    ui.PictureRecorder recorder,
    Canvas canvas,
    ui.Image image,
    double dpr,
  ) {
    const center = Offset(logicalSize / 2, logicalSize / 2);
    const radius = _medallionSize / 2;
    final paint = Paint()..isAntiAlias = true;

    paint
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawCircle(center.translate(0, 2), radius, paint);
    paint.maskFilter = null;

    paint.color = AppColors.white;
    canvas.drawCircle(center, radius, paint);

    // Inset so the clip-art never touches the ring.
    const inner = _medallionSize - 10;
    final dst = _fit(image, inner, dpr);
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius - 2)));
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.medium,
    );
    canvas.restore();

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.obsidian;
    canvas.drawCircle(center, radius - 0.75, paint);

    return _encode(recorder, dpr, rotates: false);
  }

  static Future<DriverMarkerIcon> _encode(
    ui.PictureRecorder recorder,
    double dpr, {
    required bool rotates,
  }) async {
    final picture = recorder.endRecording();
    final px = (logicalSize * dpr).ceil();
    final image = await picture.toImage(px, px);
    picture.dispose();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return DriverMarkerIcon(
      BitmapDescriptor.bytes(
        bytes!.buffer.asUint8List(),
        imagePixelRatio: dpr,
        width: logicalSize,
        height: logicalSize,
      ),
      rotates: rotates,
    );
  }
}
