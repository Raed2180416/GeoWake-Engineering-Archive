import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:geowake2/core/clock/app_clock.dart';
import 'package:geowake2/config/fire_decision_config.dart';
import 'package:geowake2/services/route_registry.dart';
import 'package:geowake2/services/tracking/alarm_controller.dart';
import 'package:geowake2/services/trackingservice.dart';
import 'package:geowake2/services/transfer_utils.dart';

class _MutableClock implements AppClock {
  double seconds = 0;
  final DateTime epoch = DateTime.utc(2026, 1, 1);

  @override
  DateTime now() => epoch.add(
    Duration(microseconds: (seconds * Duration.microsecondsPerSecond).round()),
  );

  @override
  double monotonicSeconds() => seconds;

  @override
  bool get isSimulating => false;

  @override
  double get warpFactor => 1;

  @override
  void setWarpFactor(double factor) {}

  @override
  void enableSimulation({DateTime? startAt}) {}

  @override
  void disableSimulation() {}

  @override
  Duration since(DateTime past) => now().difference(past);

  @override
  bool hasElapsed(DateTime since, Duration duration) =>
      now().difference(since) >= duration;

  @override
  Timer createPeriodicTimer(
    Duration interval,
    void Function(DateTime now) callback,
  ) => Timer.periodic(interval, (_) => callback(now()));

  @override
  Timer createTimer(Duration duration, void Function(DateTime now) callback) =>
      Timer(duration, () => callback(now()));
}

Position _position(_MutableClock clock, {required double accuracy}) => Position(
  latitude: 12.97,
  longitude: 77.59,
  timestamp: clock.now(),
  accuracy: accuracy,
  altitude: 0,
  heading: 0,
  speed: 0,
  speedAccuracy: 0,
  altitudeAccuracy: 0,
  headingAccuracy: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MutableClock clock;
  setUp(() {
    clock = _MutableClock();
    AppClock.install(clock);
  });
  tearDown(AppClock.reset);

  test(
    'production alarm tightens trusted single-metro blackout but fails open for estimated stops',
    () async {
      final registry = RouteRegistry();
      const routeKey = 'purple-line-proof';
      final points = <LatLng>[
        for (var i = 0; i <= 100; i++) LatLng(12.97, 77.59 + i * 0.001),
      ];
      registry.upsert(
        RouteEntry(
          key: routeKey,
          mode: 'transit',
          destinationName: 'Proof destination',
          points: points,
        ),
      );
      final routeEnd = registry.getByKey(routeKey)!.lengthMeters;
      final stops = [
        routeEnd * 0.2,
        routeEnd * 0.4,
        routeEnd * 0.6,
        routeEnd * 0.8,
      ];

      AlarmContext context({required bool trusted}) => AlarmContext(
        destination: points.last,
        alarmMode: 'stops',
        alarmValue: 2,
        trackingSessionActive: true,
        isTestMode: true,
        registry: registry,
        activeKey: routeKey,
        // Keep the statistical estimate frozen to emulate total GPS loss.
        progressMeters: 0,
        transitLegs: [
          TransitLegStops(
            legStartMeters: 0,
            legEndMeters: routeEnd,
            numStops: stops.length,
            stopPositions: [for (final _ in stops) points.first],
            stopMeters: stops,
            lineName: 'Purple Line',
            isActualPositions: trusted,
            isMetro: true,
            stopNames: [for (var i = 0; i < stops.length; i++) 'S$i'],
          ),
        ],
      );

      Future<bool> evaluate(
        AlarmController controller,
        AlarmContext ctx, {
        required double atSeconds,
        required double accuracy,
      }) async {
        clock.seconds = atSeconds;
        var fired = false;
        await controller.checkAndTriggerAlarm(
          currentPosition: _position(clock, accuracy: accuracy),
          service: TestServiceInstance(),
          context: ctx,
          onAlarmFired: () => fired = true,
        );
        return fired;
      }

      final trusted = AlarmController();
      expect(
        await evaluate(
          trusted,
          context(trusted: true),
          atSeconds: 0,
          accuracy: 5,
        ),
        isFalse,
      );
      // The flat 28 m/s cone crosses the two-stops-prior target before 240 s.
      // A real stopping train cannot: the trusted profile must brake to zero at
      // the earlier served stops, avoiding a needless early alarm.
      expect(
        await evaluate(
          trusted,
          context(trusted: true),
          atSeconds: 240,
          accuracy: FireDecisionConfig.deadReckonAccuracySentinel,
        ),
        isFalse,
      );
      expect(
        await evaluate(
          trusted,
          context(trusted: true),
          atSeconds: 260,
          accuracy: FireDecisionConfig.deadReckonAccuracySentinel,
        ),
        isTrue,
      );

      // Estimated topology must not constrain the physics. It deliberately
      // falls back to the earlier free-run alarm because a phantom stop could
      // otherwise make the rider miss the destination.
      clock.seconds = 0;
      final estimated = AlarmController();
      expect(
        await evaluate(
          estimated,
          context(trusted: false),
          atSeconds: 0,
          accuracy: 5,
        ),
        isFalse,
      );
      expect(
        await evaluate(
          estimated,
          context(trusted: false),
          atSeconds: 240,
          accuracy: FireDecisionConfig.deadReckonAccuracySentinel,
        ),
        isTrue,
      );
    },
  );
}
