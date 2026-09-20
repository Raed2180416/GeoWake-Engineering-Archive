// test/metro_vehicle_types_test.dart
//
// BACKLOG #13: One shared `kMetroVehicleTypes` set drives BOTH metro predicates
//   * TransferUtils._isMetroTransitStep (tracking / stop-enhancement)
//   * RerouteConstraints._routeHasMetroLeg (reroute validation)
// so a TRAM / COMMUTER_TRAIN alternate is no longer rejected on reroute while
// being accepted for tracking.
//
// BACKLOG #28 (minimal safe scope): an explicit geocoded city carried on the
// leg (`TransitLegStops.cityKey`) overrides the majority-vote-over-matched-OSM
// city used for line-sequence / line-filter resolution. The vote is demoted to
// a fallback used only when no explicit city is present.

import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/metro_vehicle_types.dart';
import 'package:geowake2/services/reroute_constraints.dart';
import 'package:geowake2/services/transfer_utils.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// --- Polyline encoder (matches Google's algorithm), copied from sibling tests.
String _encodePolyline(List<LatLng> points) {
  final str = StringBuffer();
  var lastLat = 0;
  var lastLng = 0;
  for (final point in points) {
    final lat = (point.latitude * 1e5).round();
    final lng = (point.longitude * 1e5).round();
    _enc(lat - lastLat, str);
    _enc(lng - lastLng, str);
    lastLat = lat;
    lastLng = lng;
  }
  return str.toString();
}

void _enc(int v, StringBuffer str) {
  v = v < 0 ? ~(v << 1) : v << 1;
  while (v >= 0x20) {
    str.writeCharCode((0x20 | (v & 0x1f)) + 63);
    v >>= 5;
  }
  str.writeCharCode(v + 63);
}

Map<String, dynamic> _directionsForVehicle(String vehicleType) {
  final poly = _encodePolyline(const [LatLng(0.0, 0.0), LatLng(0.02, 0.0)]);
  return {
    'routes': [
      {
        'legs': [
          {
            // Distance/duration so the distance-mode alarm gate (which runs
            // AFTER the transit-metro gate) can also pass — isolating the test
            // to the metro-vehicle-type predicate.
            'distance': {'value': 2224},
            'duration': {'value': 300},
            'steps': [
              {
                'travel_mode': 'TRANSIT',
                'polyline': {'points': poly},
                'transit_details': {
                  'line': {
                    'short_name': 'Test Line',
                    'vehicle': {'type': vehicleType},
                  },
                  'num_stops': 3,
                },
              },
            ],
          },
        ],
      },
    ],
  };
}

void main() {
  group('BACKLOG #13 — shared kMetroVehicleTypes drives both predicates', () {
    test('set contains the union incl. TRAM / COMMUTER_TRAIN / LIGHT_RAIL', () {
      expect(
        kMetroVehicleTypes,
        containsAll(<String>[
          'SUBWAY',
          'HEAVY_RAIL',
          'RAIL',
          'METRO_RAIL',
          'MONORAIL',
          'TRAM',
          'COMMUTER_TRAIN',
          'LIGHT_RAIL',
        ]),
      );
    });

    // For each metro vehicle type, BOTH predicates must agree it is metro.
    for (final vType in const ['TRAM', 'COMMUTER_TRAIN', 'LIGHT_RAIL']) {
      test('$vType is accepted by BOTH predicates', () {
        final directions = _directionsForVehicle(vType);

        // Transfer side: extractTransitLegStops marks the leg isMetro via
        // _isMetroTransitStep.
        final legs = TransferUtils.extractTransitLegStops(directions);
        expect(legs, isNotEmpty);
        expect(
          legs.first.isMetro,
          isTrue,
          reason: '_isMetroTransitStep must treat $vType as metro',
        );

        // Reroute side: the transit gate (which calls _routeHasMetroLeg) must
        // NOT reject a $vType-only alternate. Use a distance alarm so only the
        // transit-mode gate is exercised.
        const constraints = RerouteConstraints(
          alarmMode: 'distance',
          alarmValue: 1.0, // < route distance so distance gate passes
          transitMode: true,
        );
        final result = constraints.validate(directions);
        expect(
          result.isValid,
          isTrue,
          reason:
              '_routeHasMetroLeg must accept a $vType-only alternate: '
              '${result.failureReason}',
        );
      });
    }

    test('a non-metro BUS alternate is still rejected in transit mode', () {
      final directions = _directionsForVehicle('BUS');
      const constraints = RerouteConstraints(
        alarmMode: 'distance',
        alarmValue: 1.0,
        transitMode: true,
      );
      final result = constraints.validate(directions);
      expect(result.isValid, isFalse);
    });
  });

  group('BACKLOG #28 — exact anchors require explicit trusted city', () {
    // A real contiguous slice of Mumbai Blue. The nearby stops are all labelled
    // city "mumbai". We assert that nearby-stop voting is never enough and
    // that an explicit, DIFFERENT cityKey also cannot adopt those stations.
    // Using a real ordered slice is intentional: arbitrary same-line points
    // must never be promoted to trusted station anchors.
    final onLineStops = <Map<String, dynamic>>[
      {
        'id': 'S1',
        'city': 'mumbai',
        'name': 'DN Nagar',
        'lat': 19.128316,
        'lng': 72.8303036,
        'line': 'Blue Line',
        'status': 'active',
      },
      {
        'id': 'S2',
        'city': 'mumbai',
        'name': 'Azad Nagar',
        'lat': 19.1268998,
        'lng': 72.8376982,
        'line': 'Blue Line',
        'status': 'active',
      },
      {
        'id': 'S3',
        'city': 'mumbai',
        'name': 'Andheri',
        'lat': 19.120561,
        'lng': 72.8487279,
        'line': 'Blue Line',
        'status': 'active',
      },
    ];

    Map<String, dynamic> directions() => {
      'routes': [
        {
          'legs': [
            {
              'steps': [
                {
                  'travel_mode': 'TRANSIT',
                  'polyline': {
                    'points': _encodePolyline(const [
                      LatLng(19.1303249, 72.8214049), // Versova
                      LatLng(19.128316, 72.8303036), // DN Nagar
                      LatLng(19.1268998, 72.8376982), // Azad Nagar
                      LatLng(19.120561, 72.8487279), // Andheri
                      LatLng(19.115875, 72.85648), // WEH
                    ]),
                  },
                  'transit_details': {
                    'line': {
                      'short_name': 'Blue Line',
                      'vehicle': {'type': 'SUBWAY'},
                    },
                    'num_stops': 3,
                  },
                },
              ],
            },
          ],
        },
      ],
    };

    TransitLegStops leg({String? cityKey}) => TransitLegStops(
      legStartMeters: 0.0,
      legEndMeters: 4000.0,
      numStops: 3,
      stopPositions: const [
        LatLng(19.128316, 72.8303036),
        LatLng(19.1268998, 72.8376982),
        LatLng(19.120561, 72.8487279),
      ],
      stopMeters: const [1000.0, 2000.0, 3000.0],
      lineName: 'Blue Line',
      isMetro: true,
      cityKey: cityKey,
    );

    test(
      'no cityKey refuses nearby-stop voting and exact station anchors',
      () async {
        final enhanced = await TransferUtils.enhanceTransitLegStopsWithOsm(
          [leg(cityKey: null)],
          directions(),
          stopsOverride: onLineStops,
        );
        final result = enhanced.single;
        expect(result.isActualPositions, isFalse);
        expect(result.stopNames, isEmpty);
        expect(result.numStops, equals(3));
      },
    );

    test(
      'explicit cityKey ("delhi") overrides the vote and filters them out',
      () async {
        final enhanced = await TransferUtils.enhanceTransitLegStopsWithOsm(
          [leg(cityKey: 'delhi')],
          directions(),
          stopsOverride: onLineStops,
        );
        final result = enhanced.single;
        // legCityKey is now the explicit "delhi" (NOT the "mumbai" vote), so the
        // mumbai-labelled stops fail the city guard and the API-uniform leg is
        // preserved instead of snapping to the wrong-city stations.
        expect(
          result.isActualPositions,
          isFalse,
          reason: 'explicit city must veto the majority-vote city',
        );
        expect(result.stopNames, isNot(contains('DN Nagar')));
        expect(result.stopNames, isNot(contains('Azad Nagar')));
        expect(result.stopNames, isNot(contains('Andheri')));
        expect(result.numStops, equals(3)); // API leg kept intact
      },
    );

    test('cityKey round-trips through toJson / fromJson', () {
      final json = leg(cityKey: 'delhi').toJson();
      expect(json['cityKey'], equals('delhi'));
      final back = TransitLegStops.fromJson(json);
      expect(back.cityKey, equals('delhi'));
    });
  });
}
