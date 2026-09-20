import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/alarm_threshold_validator.dart';

Map<String, dynamic> _route(List<Map<String, dynamic>> steps) {
  final duration = steps.fold<int>(
    0,
    (sum, step) => sum + ((step['duration'] as Map?)?['value'] as int? ?? 0),
  );
  final distance = steps.fold<int>(
    0,
    (sum, step) => sum + ((step['distance'] as Map?)?['value'] as int? ?? 0),
  );
  return {
    'routes': [
      {
        'legs': [
          {
            'duration': {'value': duration},
            'distance': {'value': distance},
            'steps': steps,
          },
        ],
      },
    ],
  };
}

Map<String, dynamic> _step(
  String mode, {
  required int seconds,
  required int meters,
  int stops = 0,
  String vehicle = 'SUBWAY',
  String line = 'Purple',
}) {
  return {
    'travel_mode': mode,
    'duration': {'value': seconds},
    'distance': {'value': meters},
    if (mode == 'TRANSIT')
      'transit_details': {
        'num_stops': stops,
        'line': {
          'short_name': line,
          'vehicle': {'type': vehicle},
        },
      },
  };
}

void main() {
  group('AlarmThresholdValidator', () {
    test('rejects non-positive, non-finite, and unknown thresholds', () {
      final route = _route([_step('DRIVING', seconds: 600, meters: 5000)]);
      for (final value in [0.0, -1.0, double.nan, double.infinity]) {
        expect(
          AlarmThresholdValidator.validate(
            directions: route,
            alarmMode: 'time',
            alarmValue: value,
            transitMode: false,
          ).isValid,
          isFalse,
        );
      }
      expect(
        AlarmThresholdValidator.validate(
          directions: route,
          alarmMode: 'magic',
          alarmValue: 1,
          transitMode: false,
        ).isValid,
        isFalse,
      );
    });

    test('non-metro time and distance require a threshold below the trip', () {
      final route = _route([_step('DRIVING', seconds: 600, meters: 5000)]);
      for (final pair in [
        ('time', 9.0, true),
        ('time', 10.0, false),
        ('distance', 4.9, true),
        ('distance', 5.0, false),
      ]) {
        expect(
          AlarmThresholdValidator.validate(
            directions: route,
            alarmMode: pair.$1,
            alarmValue: pair.$2,
            transitMode: false,
          ).isValid,
          pair.$3,
          reason: '${pair.$1}/${pair.$2}',
        );
      }
    });

    test('stops threshold is a whole number below every metro segment', () {
      final route = _route([
        _step('WALKING', seconds: 300, meters: 500),
        _step('TRANSIT', seconds: 1200, meters: 8000, stops: 6, line: 'A'),
        _step('WALKING', seconds: 180, meters: 200),
        _step('TRANSIT', seconds: 600, meters: 4000, stops: 2, line: 'B'),
      ]);
      for (final pair in [
        (1.0, true),
        (2.0, true),
        (2.5, false),
        (3.0, false),
        (8.0, false),
      ]) {
        expect(
          AlarmThresholdValidator.validate(
            directions: route,
            alarmMode: 'stops',
            alarmValue: pair.$1,
            transitMode: true,
          ).isValid,
          pair.$2,
          reason: 'threshold ${pair.$1}',
        );
      }
    });

    test(
      'metro time threshold must fit every metro and final non-metro leg',
      () {
        final route = _route([
          _step('DRIVING', seconds: 900, meters: 4000),
          _step('TRANSIT', seconds: 1200, meters: 10000, stops: 8, line: 'A'),
          _step('WALKING', seconds: 180, meters: 250),
          _step('TRANSIT', seconds: 600, meters: 5000, stops: 4, line: 'B'),
          _step('WALKING', seconds: 480, meters: 600),
        ]);
        expect(
          AlarmThresholdValidator.validate(
            directions: route,
            alarmMode: 'time',
            alarmValue: 5,
            transitMode: true,
          ).isValid,
          isTrue,
        );
        // Equal to the final 8-minute walk is impossible for that segment.
        expect(
          AlarmThresholdValidator.validate(
            directions: route,
            alarmMode: 'time',
            alarmValue: 8,
            transitMode: true,
          ).isValid,
          isFalse,
        );
        // Equal to the shortest 10-minute metro segment is also impossible.
        expect(
          AlarmThresholdValidator.validate(
            directions: _route([
              _step(
                'TRANSIT',
                seconds: 1200,
                meters: 10000,
                stops: 8,
                line: 'A',
              ),
              _step('TRANSIT', seconds: 600, meters: 5000, stops: 4, line: 'B'),
            ]),
            alarmMode: 'time',
            alarmValue: 10,
            transitMode: true,
          ).isValid,
          isFalse,
        );
      },
    );

    test('metro selection rejects a bus-only route', () {
      final route = _route([
        _step(
          'TRANSIT',
          seconds: 1800,
          meters: 10000,
          stops: 10,
          vehicle: 'BUS',
        ),
      ]);
      for (final mode in ['stops', 'time']) {
        expect(
          AlarmThresholdValidator.validate(
            directions: route,
            alarmMode: mode,
            alarmValue: 2,
            transitMode: true,
          ).isValid,
          isFalse,
        );
      }
    });
  });
}
