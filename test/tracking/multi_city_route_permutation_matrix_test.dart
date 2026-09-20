import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geowake2/data/metro_line_sequences.dart';
import 'package:geowake2/services/polyline_decoder.dart';
import 'package:geowake2/services/sensor_fusion.dart';
import 'package:geowake2/services/stop_logic_engine.dart';
import 'package:geowake2/services/transfer_utils.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const _launchLines = <String, String>{
  'bengaluru': 'purple',
  'mumbai': 'blue',
  'chennai': 'blue',
  'hyderabad': 'red',
  'kochi': '1',
};

String _encodePolyline(List<LatLng> points) {
  final out = StringBuffer();
  var lastLat = 0;
  var lastLng = 0;
  for (final point in points) {
    final lat = (point.latitude * 1e5).round();
    final lng = (point.longitude * 1e5).round();
    _encodeValue(lat - lastLat, out);
    _encodeValue(lng - lastLng, out);
    lastLat = lat;
    lastLng = lng;
  }
  return out.toString();
}

void _encodeValue(int value, StringBuffer out) {
  var encoded = value < 0 ? ~(value << 1) : value << 1;
  while (encoded >= 0x20) {
    out.writeCharCode((0x20 | (encoded & 0x1f)) + 63);
    encoded >>= 5;
  }
  out.writeCharCode(encoded + 63);
}

Map<String, dynamic> _directions({
  required List<LatLng> points,
  required String line,
  required int intermediateStops,
}) {
  return {
    'routes': [
      {
        'legs': [
          {
            'steps': [
              {
                'travel_mode': 'TRANSIT',
                'polyline': {'points': _encodePolyline(points)},
                'transit_details': {
                  'line': {
                    'short_name': line,
                    'vehicle': {'type': 'SUBWAY'},
                  },
                  'num_stops': intermediateStops,
                },
              },
            ],
          },
        ],
      },
    ],
  };
}

Position _position(LatLng point) => Position(
  longitude: point.longitude,
  latitude: point.latitude,
  timestamp: DateTime(2026, 8, 7),
  accuracy: 5,
  altitude: 0,
  heading: 0,
  speed: 0,
  speedAccuracy: 0,
  altitudeAccuracy: 0,
  headingAccuracy: 0,
);

LatLng _eastOf(LatLng point, double meters) {
  final longitudeDegrees =
      meters / (111320.0 * math.cos(point.latitude * math.pi / 180.0));
  return LatLng(point.latitude, point.longitude + longitudeDegrees);
}

void main() {
  test(
    'all launch-city windows, directions, and decoys preserve route identity',
    () async {
      var cases = 0;
      for (final entry in _launchLines.entries) {
        final city = entry.key;
        final line = entry.value;
        final sequence = kMetroLineSequences[city]![line]!;
        final windowLengths = <int>{4, math.min(8, sequence.length)};

        for (final windowLength in windowLengths) {
          for (
            var start = 0;
            start + windowLength <= sequence.length;
            start++
          ) {
            final sourceWindow = sequence.sublist(start, start + windowLength);
            for (final reverse in const [false, true]) {
              final window =
                  reverse
                      ? sourceWindow.reversed.toList()
                      : sourceWindow.toList();
              final points =
                  window
                      .map((station) => LatLng(station.lat, station.lng))
                      .toList();
              final lengthMeters = polylineLength(points);
              final intermediateCount = window.length - 2;
              final expectedNames =
                  window
                      .sublist(1, window.length - 1)
                      .map((station) => station.name)
                      .toList();

              final stops =
                  sequence
                      .asMap()
                      .entries
                      .map(
                        (station) => <String, dynamic>{
                          'id': '${city}_${line}_${station.key}',
                          'city': city,
                          'name': station.value.name,
                          'lat': station.value.lat,
                          'lng': station.value.lng,
                          'line': line,
                          'status': 'active',
                        },
                      )
                      .toList()
                    ..addAll([
                      <String, dynamic>{
                        'id': 'wrong_line_$cases',
                        'city': city,
                        'name': 'WRONG LINE DECOY',
                        'lat': points[points.length ~/ 2].latitude,
                        'lng': points[points.length ~/ 2].longitude,
                        'line': 'not-$line',
                        'status': 'active',
                      },
                      <String, dynamic>{
                        'id': 'wrong_city_$cases',
                        'city': 'not-$city',
                        'name': 'WRONG CITY DECOY',
                        'lat': points[(points.length ~/ 2) - 1].latitude,
                        'lng': points[(points.length ~/ 2) - 1].longitude,
                        'line': line,
                        'status': 'active',
                      },
                    ]);

              final apiUniformMeters = List<double>.generate(
                intermediateCount,
                (index) => lengthMeters * (index + 1) / (intermediateCount + 1),
              );
              final input = TransitLegStops(
                legStartMeters: 0,
                legEndMeters: lengthMeters,
                numStops: intermediateCount,
                stopPositions: points.sublist(1, points.length - 1),
                stopMeters: apiUniformMeters,
                lineName: line,
                isMetro: true,
                stopCountConfidence: 0.5,
                // Half the matrix carries independently trusted city context;
                // the other half proves that an unproven city refuses exact
                // anchors instead of inferring one from nearby stations.
                cityKey: start.isEven ? city : null,
              );

              final enhanced =
                  await TransferUtils.enhanceTransitLegStopsWithOsm(
                    [input],
                    _directions(
                      points: points,
                      line: line,
                      intermediateStops: intermediateCount,
                    ),
                    stopsOverride: stops,
                  );
              final result = enhanced.single;
              final label =
                  '$city/$line start=$start len=$windowLength '
                  'reverse=$reverse';

              final hasTrustedCity = start.isEven;
              expect(result.isActualPositions, hasTrustedCity, reason: label);
              expect(
                result.stopCountConfidence,
                hasTrustedCity ? 1.0 : 0.5,
                reason: label,
              );
              expect(
                result.stopNames,
                hasTrustedCity ? expectedNames : isEmpty,
                reason: label,
              );
              expect(
                result.stopNames,
                isNot(contains('WRONG LINE DECOY')),
                reason: label,
              );
              expect(
                result.stopNames,
                isNot(contains('WRONG CITY DECOY')),
                reason: label,
              );
              final trustedMeters =
                  SensorFusionManager.trustedStationMetersForLeg(result);
              expect(
                trustedMeters,
                hasTrustedCity ? result.stopMeters : isEmpty,
                reason: label,
              );
              cases++;
            }
          }
        }
      }

      expect(cases, greaterThan(250));
    },
  );

  test(
    'launch-city station, 200m, far, and approach starts are classified',
    () {
      final engine = StopLogicEngine();
      for (final entry in _launchLines.entries) {
        final stationData = kMetroLineSequences[entry.key]![entry.value]!.first;
        final station = LatLng(stationData.lat, stationData.lng);

        for (final nearMeters in const [0.0, 200.0]) {
          final start = _eastOf(station, nearMeters);
          final result =
              engine.checkPreBoarding(
                currentPosition: _position(start),
                firstTransitBoarding: station,
                startPosition: start,
              )!;
          expect(
            result.shouldTrigger,
            isFalse,
            reason: '${entry.key}: start ${nearMeters}m from station',
          );
          expect(
            result.shouldSuppress,
            isTrue,
            reason: '${entry.key}: start ${nearMeters}m from station',
          );
        }

        final farStart = _eastOf(station, 1200);
        final stillFar =
            engine.checkPreBoarding(
              currentPosition: _position(_eastOf(station, 800)),
              firstTransitBoarding: station,
              startPosition: farStart,
            )!;
        expect(stillFar.shouldTrigger, isFalse, reason: entry.key);
        expect(stillFar.shouldSuppress, isFalse, reason: entry.key);

        final approaching =
            engine.checkPreBoarding(
              currentPosition: _position(_eastOf(station, 550)),
              firstTransitBoarding: station,
              startPosition: farStart,
            )!;
        expect(approaching.shouldTrigger, isTrue, reason: entry.key);
        expect(approaching.shouldSuppress, isFalse, reason: entry.key);
      }
    },
  );

  test('valid and impossible stop thresholds are distinguished per city', () {
    final engine = StopLogicEngine();
    for (final entry in _launchLines.entries) {
      final sequence = kMetroLineSequences[entry.key]![entry.value]!;
      final firstCount = math.min(6, sequence.length - 2);
      final secondCount = math.min(3, sequence.length - 2);
      final legs = [
        TransitLegStops(
          legStartMeters: 0,
          legEndMeters: 6000,
          numStops: firstCount,
          stopPositions: const [],
          stopMeters: const [],
          lineName: '${entry.value}-first',
          isMetro: true,
        ),
        TransitLegStops(
          legStartMeters: 6000,
          legEndMeters: 6300,
          numStops: 0,
          stopPositions: const [],
          stopMeters: const [],
          lineName: 'transfer walk',
          isMetro: false,
        ),
        TransitLegStops(
          legStartMeters: 6300,
          legEndMeters: 11000,
          numStops: secondCount,
          stopPositions: const [],
          stopMeters: const [],
          lineName: '${entry.value}-second',
          isMetro: true,
        ),
      ];
      final minimumTotalStops = secondCount + 1;

      expect(
        engine
            .validateThresholdAgainstMetroLegs(
              userThreshold: minimumTotalStops - 1,
              transitLegs: legs,
            )
            .isValid,
        isTrue,
        reason: entry.key,
      );
      for (final invalid in [minimumTotalStops, minimumTotalStops + 5]) {
        expect(
          engine
              .validateThresholdAgainstMetroLegs(
                userThreshold: invalid,
                transitLegs: legs,
              )
              .isValid,
          isFalse,
          reason: '${entry.key}: threshold $invalid must fail',
        );
      }
    }
  });
}
