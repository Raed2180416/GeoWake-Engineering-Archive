import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geowake2/core/ekf/route_geometry.dart';
import 'package:geowake2/services/sensor_fusion.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Position _position({required double longitude, required double speed}) {
  return Position(
    latitude: 12.0,
    longitude: longitude,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 90,
    headingAccuracy: 5,
    speed: speed,
    speedAccuracy: 1,
  );
}

void main() {
  test(
    'frozen projected GPS does not refresh the accepted-fix clock',
    () async {
      final manager = SensorFusionManager(
        initialPosition: const LatLng(12.0, 77.0),
        routeGeometry: RouteGeometry.fromPoints(const [
          LatLng(12.0, 77.0),
          LatLng(12.0, 77.01),
        ]),
        enableEkf: true,
      );
      addTearDown(manager.dispose);

      manager.updateGps(_position(longitude: 77.0, speed: 10));
      final acceptedAt = manager.lastAcceptedGpsTimestampForTest;
      expect(acceptedAt, isNotNull);

      await Future<void>.delayed(const Duration(milliseconds: 3));
      manager.updateGps(_position(longitude: 77.0, speed: 10));

      expect(
        manager.lastAcceptedGpsTimestampForTest,
        acceptedAt,
        reason: 'a frozen phantom must let the no-fix timer keep running',
      );
    },
  );
}
