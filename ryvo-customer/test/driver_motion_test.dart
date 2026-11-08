import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ryvo_customer/core/location/driver_motion.dart';

void main() {
  group('shortestAngleDelta', () {
    test('turns the short way across north', () {
      expect(shortestAngleDelta(350, 10), 20);
      expect(shortestAngleDelta(10, 350), -20);
    });

    test('never exceeds half a turn', () {
      for (var from = 0.0; from < 360; from += 15) {
        for (var to = 0.0; to < 360; to += 15) {
          expect(shortestAngleDelta(from, to).abs(), lessThanOrEqualTo(180));
        }
      }
    });
  });

  group('lerpBearing', () {
    test('crosses north without spinning backward', () {
      expect(lerpBearing(350, 10, 0.5), closeTo(0, 1e-9));
      expect(lerpBearing(350, 10, 1), closeTo(10, 1e-9));
      expect(lerpBearing(350, 10, 0), closeTo(350, 1e-9));
    });
  });

  test('bearingBetween points along the compass', () {
    const origin = LatLng(0, 0);
    expect(bearingBetween(origin, const LatLng(1, 0)), closeTo(0, 1e-6));
    expect(bearingBetween(origin, const LatLng(0, 1)), closeTo(90, 1e-6));
    expect(bearingBetween(origin, const LatLng(-1, 0)), closeTo(180, 1e-6));
    expect(bearingBetween(origin, const LatLng(0, -1)), closeTo(270, 1e-6));
  });
}
