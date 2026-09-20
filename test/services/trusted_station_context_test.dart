import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/sensor_fusion.dart';
import 'package:geowake2/services/transfer_utils.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

TransitLegStops _leg({
  bool isMetro = true,
  bool isActual = true,
  double confidence = 1.0,
  List<double> meters = const [200, 500, 800],
  List<String> names = const ['A', 'B', 'C'],
}) {
  return TransitLegStops(
    legStartMeters: 100,
    legEndMeters: 900,
    numStops: meters.length,
    stopPositions: List.generate(
      meters.length,
      (index) => LatLng(12.9 + index * 0.001, 77.6),
    ),
    stopMeters: meters,
    stopNames: names,
    lineName: 'Purple',
    isMetro: isMetro,
    isActualPositions: isActual,
    stopCountConfidence: confidence,
  );
}

void main() {
  group('trusted transit-step city provenance', () {
    Map<String, dynamic> step() => {
      'travel_mode': 'TRANSIT',
      'transit_details': {
        'line': {
          'short_name': 'Purple Line',
          'vehicle': {'type': 'SUBWAY'},
        },
        'departure_stop': {
          'name': 'Baiyappanahalli Metro Station',
          'location': {'lat': 12.9907594, 'lng': 77.6523612},
        },
        'arrival_stop': {
          'name': 'Whitefield (Kadugodi)',
          'location': {'lat': 12.9957428, 'lng': 77.7579489},
        },
      },
    };

    final trustedStops = <Map<String, dynamic>>[
      {
        'id': 'dep',
        'city': 'bengaluru',
        'name': 'Baiyappanahalli',
        'line': 'Purple',
        'lat': 12.9907594,
        'lng': 77.6523612,
        'status': 'active',
      },
      {
        'id': 'arr',
        'city': 'bengaluru',
        'name': 'Whitefield (Kadugodi)',
        'line': 'Purple',
        'lat': 12.9957428,
        'lng': 77.7579489,
        'status': 'active',
      },
    ];

    test(
      'both provider endpoints must independently agree on city and line',
      () {
        expect(
          TransferUtils.trustedTransitStepCityKey(
            step(),
            stopsOverride: trustedStops,
          ),
          'bengaluru',
        );
      },
    );

    test('provider station aliases do not disable geographic city proof', () {
      final aliased = step();
      final td = aliased['transit_details'] as Map<String, dynamic>;
      (td['departure_stop'] as Map<String, dynamic>)['name'] =
          'Different provider spelling';
      (td['arrival_stop'] as Map<String, dynamic>).remove('name');
      expect(
        TransferUtils.trustedTransitStepCityKey(
          aliased,
          stopsOverride: trustedStops,
        ),
        'bengaluru',
      );
    });

    test('overlaid same-line cross-city ambiguity refuses exact context', () {
      final ambiguous = [
        ...trustedStops,
        {...trustedStops.first, 'id': 'decoy-dep', 'city': 'mumbai'},
      ];
      expect(
        TransferUtils.trustedTransitStepCityKey(
          step(),
          stopsOverride: ambiguous,
        ),
        isNull,
      );
    });

    test('production extraction threads the verified city onto the leg', () {
      final directions = {
        'routes': [
          {
            'legs': [
              {
                'steps': [
                  {
                    ...step(),
                    'distance': {'value': 12000},
                    'polyline': {'points': ''},
                    'transit_details': {
                      ...(step()['transit_details'] as Map<String, dynamic>),
                      'num_stops': 3,
                    },
                  },
                ],
              },
            ],
          },
        ],
      };
      final legs = TransferUtils.extractTransitLegStops(directions);
      expect(legs, hasLength(1));
      expect(legs.single.cityKey, 'bengaluru');
    });
  });

  group('EKF trusted station context', () {
    test('accepts only a complete verified ordered metro slice', () {
      expect(SensorFusionManager.trustedStationMetersForLeg(_leg()), [
        200,
        500,
        800,
      ]);
    });

    test(
      'rejects estimated API-uniform positions even at nominal confidence',
      () {
        expect(
          SensorFusionManager.trustedStationMetersForLeg(_leg(isActual: false)),
          isEmpty,
        );
      },
    );

    test('rejects low-confidence, non-metro, and incomplete identity data', () {
      expect(
        SensorFusionManager.trustedStationMetersForLeg(_leg(confidence: 0.5)),
        isEmpty,
      );
      expect(
        SensorFusionManager.trustedStationMetersForLeg(_leg(isMetro: false)),
        isEmpty,
      );
      expect(
        SensorFusionManager.trustedStationMetersForLeg(
          _leg(names: const ['A', 'B']),
        ),
        isEmpty,
      );
    });

    test('rejects non-monotonic and out-of-leg station positions', () {
      expect(
        SensorFusionManager.trustedStationMetersForLeg(
          _leg(meters: const [200, 190, 800]),
        ),
        isEmpty,
      );
      expect(
        SensorFusionManager.trustedStationMetersForLeg(
          _leg(meters: const [100, 500, 800]),
        ),
        isEmpty,
      );
      expect(
        SensorFusionManager.trustedStationMetersForLeg(
          _leg(meters: const [200, 500, 900]),
        ),
        isEmpty,
      );
    });
  });
}
