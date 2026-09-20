import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/active_route_manager.dart';
import 'package:geowake2/services/route_registry.dart';
import 'package:geowake2/services/snap_to_route.dart';

void main() {
  test('persisted hintIndex constrains a resumed snap search', () {
    final points = <LatLng>[
      const LatLng(0, 0),
      const LatLng(0, 0.001), // segment 0: close to the test point
      for (var i = 0; i < 9; i++) const LatLng(10, 10),
      const LatLng(0, 0),
      const LatLng(0, 0.001), // segment 11: the persisted arc
    ];
    final withoutHint = SnapToRouteEngine.snap(
      point: const LatLng(0, 0.0005),
      polyline: points,
    );
    final withHint = SnapToRouteEngine.snap(
      point: const LatLng(0, 0.0005),
      polyline: points,
      hintIndex: 11,
      searchWindow: 3,
    );

    expect(withoutHint.segmentIndex, 0);
    expect(withHint.segmentIndex, 11);
  });

  test('live ActiveRouteManager keeps the previous arc at a self-crossing',
      () async {
    final registry = RouteRegistry();
    registry.upsert(
      RouteEntry(
        key: 'loop',
        mode: 'transit',
        destinationName: 'loop',
        points: const [
          LatLng(0, 0),
          LatLng(0, 0.001), // segment 0
          LatLng(0.01, 0.001),
          LatLng(0.01, 0.002),
          LatLng(0, 0.002),
          LatLng(0, 0.001), // segment 4 returns to the first corridor
        ],
      ),
    );
    final manager = ActiveRouteManager(registry: registry);
    manager.setActive('loop');
    final states = <ActiveRouteState>[];
    final sub = manager.stateStream.listen(states.add);

    manager.ingestPosition(const LatLng(0, 0.0005));
    await Future<void>.delayed(Duration.zero);
    manager.ingestPosition(const LatLng(0, 0.001));
    await Future<void>.delayed(Duration.zero);

    expect(states, hasLength(2));
    // The point is physically shared by two arcs.  Continuity must retain the
    // original arc instead of silently jumping to the later loop segment.
    expect(states.last.progressMeters, lessThan(200));

    await sub.cancel();
    manager.dispose();
  });
}
