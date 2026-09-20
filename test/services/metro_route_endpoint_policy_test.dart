import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/metro_stop_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  group('metro routing endpoint policy', () {
    final requested = const LatLng(12.97582, 77.60531);
    final wrongLineDecoy = TransitStop(
      name: 'Nearby wrong-line station',
      location: const LatLng(12.97596, 77.60546),
      placeId: 'wrong-line-25m',
    );
    final intendedStation200mAway = TransitStop(
      name: 'Intended station',
      location: const LatLng(12.97750, 77.60531),
      placeId: 'intended-200m',
    );

    test('keeps a pinned last-mile destination despite a closer decoy', () {
      final endpoint = MetroStopService.routingDestination(
        requestedDestination: requested,
        nearbyStops: [wrongLineDecoy, intendedStation200mAway],
      );

      expect(endpoint, same(requested));
      expect(endpoint, isNot(wrongLineDecoy.location));
    });

    test('keeps a destination 200m from its intended station', () {
      final endpoint = MetroStopService.routingDestination(
        requestedDestination: requested,
        nearbyStops: [intendedStation200mAway],
      );

      expect(endpoint.latitude, requested.latitude);
      expect(endpoint.longitude, requested.longitude);
    });

    test('keeps a far first or last mile instead of refusing or snapping', () {
      const farDestination = LatLng(13.03580, 77.59700);
      final endpoint = MetroStopService.routingDestination(
        requestedDestination: farDestination,
        nearbyStops: const <TransitStop>[],
      );

      expect(endpoint, same(farDestination));
    });
  });
}
