// lib/services/sensor_fusion.dart
//
// ============================================================================
// 🚀 PRODUCTION EKF SENSOR FUSION MANAGER
// ============================================================================
//
// This class orchestrates the Extended Kalman Filter (EKF) pipeline for
// robust 1D progress tracking on transit routes.
//
// Responsibilities:
// 1. Manages IMU streams (accelerometer + gyroscope).
// 2. Maintains EKF state (EkfOrchestrator).
// 3. Fuses GPS updates, ZUPT events, and Station Snaps.
// 4. Provides continuous progress estimates even during GPS dropouts.
//
// Architecture:
// - Wiring: LocationStreamHandler -> SensorFusionManager -> EkfOrchestrator
// - Outputs: ekfStateStream (consumed by LocationStreamHandler/TrackingService)
//
// See: docs/ekf_planning/ for architectural details.
// ============================================================================

import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geowake2/core/ekf/ekf_orchestrator.dart';
import 'package:geowake2/core/ekf/ekf_logger.dart';
import 'package:geowake2/core/ekf/ekf_types.dart';
import 'package:geowake2/core/ekf/route_geometry.dart';
import 'package:geowake2/services/transfer_utils.dart';

/// Orchestrates the EKF pipeline, fusing GPS, IMU, and Route Geometry.
/// Replaces the legacy dead reckoning placeholder.
class SensorFusionManager {
  late double _initialLat;
  late double _initialLon;
  double _posX = 0.0; // Displacement in meters eastwards.
  double _posY = 0.0; // Displacement in meters northwards.
  double _velX = 0.0; // Velocity in m/s eastwards.
  double _velY = 0.0; // Velocity in m/s northwards.
  DateTime _lastUpdate = DateTime.now();

  // Maximum duration for sensor fusion before resetting integration (limits drift).
  final Duration maxFusionDuration = const Duration(seconds: 10);
  late DateTime _fusionStartTime;

  // Damping factor to reduce noise impact, value between 0 and 1.
  // Higher value means more damping.
  final double accelerationDecayFactor = 0.9;

  final StreamController<LatLng> _positionController =
      StreamController<LatLng>.broadcast();

  /// Exposes a stream of fused positions.
  Stream<LatLng> get fusedPositionStream => _positionController.stream;

  /// Optional EKF public state stream (not wired into app yet).
  Stream<EkfPublicState> get ekfStateStream => _ekfStateController.stream;
  EkfPublicState? get lastEkfState => _lastEkfState;

  /// Accept an optional accelerometer stream (for testing).
  final Stream<AccelerometerEvent>? accelerometerStream;

  /// Accept an optional gyroscope stream (for testing).
  final Stream<GyroscopeEvent>? gyroscopeStream;

  /// Optional raw field-validation capture. Null in normal production builds.
  final EkfLogger? diagnosticLogger;

  /// Optional EKF route geometry (enables EKF path when provided).
  RouteGeometry? _routeGeometry;

  /// Flag to enable EKF path (default false to avoid regression).
  bool _enableEkf;

  final StreamController<EkfPublicState> _ekfStateController =
      StreamController<EkfPublicState>.broadcast();
  EkfPublicState? _lastEkfState;

  EkfOrchestrator? _ekfOrchestrator;
  bool _fftEnabled = true;
  List<TransitLegStops> _transitLegStops = const [];

  /// Callback for station snap confirmed events from EKF (§24.2).
  void Function(StationSnapConfirmed)? onStationSnapConfirmed;

  SensorFusionManager({
    required LatLng initialPosition,
    this.accelerometerStream,
    this.gyroscopeStream,
    this.diagnosticLogger,
    RouteGeometry? routeGeometry,
    bool enableEkf = false,
  }) : _routeGeometry = routeGeometry,
       _enableEkf = enableEkf {
    _initialLat = initialPosition.latitude;
    _initialLon = initialPosition.longitude;
    _lastUpdate = DateTime.now();
    _fusionStartTime = DateTime.now();
    _positionController.add(initialPosition);

    if (_enableEkf && _routeGeometry != null) {
      _ekfOrchestrator = EkfOrchestrator(route: _routeGeometry!);
      _ekfOrchestrator!.setFftEnabled(_fftEnabled);
      _ekfOrchestrator!.onStationSnapConfirmed = _handleStationSnapConfirmed;
    }
  }

  void _handleStationSnapConfirmed(StationSnapConfirmed event) {
    onStationSnapConfirmed?.call(event);
  }

  void setFftEnabled(bool enabled) {
    _fftEnabled = enabled;
    _ekfOrchestrator?.setFftEnabled(enabled);
  }

  void updateRouteGeometry(
    RouteGeometry? geometry, {
    double? preserveProgressMeters,
  }) {
    final previousState = _ekfOrchestrator?.publicState ?? _lastEkfState;
    _routeGeometry = geometry;
    _enableEkf = geometry != null;
    if (!_enableEkf || _routeGeometry == null) {
      _ekfOrchestrator = null;
      _lastEkfState = null;
      return;
    }

    _ekfOrchestrator = EkfOrchestrator(route: _routeGeometry!);
    _ekfOrchestrator!.setFftEnabled(_fftEnabled);
    if (previousState != null) {
      _ekfOrchestrator!.seedFromState(
        previousState,
        progressMeters: preserveProgressMeters,
      );
    }
    _ekfOrchestrator!.onStationSnapConfirmed = _handleStationSnapConfirmed;
    _lastEkfState = _ekfOrchestrator!.publicState;
  }

  void updateGps(Position position) {
    _lastGpsAccepted = false;
    final timestamp = Duration(
      microseconds:
          _imuClock?.elapsedMicroseconds ??
          DateTime.now().millisecondsSinceEpoch * 1000,
    );
    final ekf = _ekfOrchestrator;
    if (ekf == null) {
      diagnosticLogger?.logGps(
        timestamp: timestamp,
        lat: position.latitude,
        lng: position.longitude,
        accuracy: position.accuracy,
      );
      return;
    }
    final priorState = _lastEkfState;
    final sGps = _routeGeometry?.projectLatLng(
      position.latitude,
      position.longitude,
      previousProgressMeters:
          _lastGpsFixTs == null ? null : priorState?.s,
      headingDegrees:
          position.heading.isFinite && position.heading >= 0
              ? position.heading
              : null,
    );
    if (sGps != null && sGps.isFinite) {
      final leg = _legForProgress(sGps);
      if (leg != null) {
        ekf.setStationContext(
          stationMeters: trustedStationMetersForLeg(leg),
          isMetroLeg: leg.isMetro,
        );
      } else {
        ekf.setStationContext(stationMeters: const [], isMetroLeg: false);
      }
    }
    final accepted = ekf.onGpsFixAuto(
      GpsFix(
        lat: position.latitude,
        lng: position.longitude,
        accuracyMeters: position.accuracy,
        speedMps: position.speed,
        timestamp: timestamp,
      ),
    );
    diagnosticLogger?.logGps(
      timestamp: timestamp,
      lat: position.latitude,
      lng: position.longitude,
      accuracy: position.accuracy,
      ekfState: ekf.publicState,
      mode: ekf.publicState.mode,
    );
    if (accepted) {
      // Only a fix actually fused by the EKF marks GPS alive. Merely projecting
      // onto the route is insufficient: a frozen phantom or innovation-gated
      // outlier must let the no-fix timer continue into degraded DR.
      _lastGpsFixTs = timestamp;
      _lastGpsAccepted = true;
    }
  }

  /// Station anchors are a high-trust correction, not a generic stop-count
  /// hint. Estimated/unverified positions may still support conservative alarm
  /// timing, but must never pull the EKF onto a station that is not demonstrably
  /// part of the active route segment.
  static List<double> trustedStationMetersForLeg(TransitLegStops? leg) {
    if (leg == null ||
        !leg.isMetro ||
        !leg.isActualPositions ||
        leg.stopCountConfidence < 0.999 ||
        leg.numStops <= 0 ||
        leg.stopMeters.length != leg.numStops ||
        leg.stopPositions.length != leg.numStops ||
        leg.stopNames.length != leg.numStops) {
      return const [];
    }

    var previous = leg.legStartMeters;
    for (final meters in leg.stopMeters) {
      if (!meters.isFinite ||
          meters <= previous ||
          meters <= leg.legStartMeters ||
          meters >= leg.legEndMeters) {
        return const [];
      }
      previous = meters;
    }
    return List<double>.unmodifiable(leg.stopMeters);
  }

  void updateTransitLegStops(List<TransitLegStops> stops) {
    _transitLegStops = stops;
  }

  StreamSubscription? _accelerometerSubscription;
  StreamSubscription? _gyroscopeSubscription;
  GyroscopeEvent? _lastGyro;
  Stopwatch? _imuClock;
  // G21: no-gyroscope detection. If no gyro sample arrives during a warm-up
  // window of accel samples, the device has no gyro (common on budget phones).
  int _accelSampleCount = 0;
  bool _noGyroDeclared = false;
  // E1: IMU-clock timestamp of the last real GPS fix. Used to transition the
  // EKF to DEGRADED mode when GPS goes silent (tunnels) — without this the
  // orchestrator never enters degraded DR in production.
  Duration? _lastGpsFixTs;
  bool _lastGpsAccepted = false;

  /// Exposes acceptance timing only for deterministic regression tests.
  Duration? get lastAcceptedGpsTimestampForTest => _lastGpsFixTs;
  bool get lastGpsAccepted => _lastGpsAccepted;
  static const Duration _noFixDegradeThreshold = Duration(seconds: 3);
  Duration? _lastGpsUnavailableTs;

  /// Starts sensor fusion by listening to accelerometer events.
  void startFusion() {
    try {
      if (diagnosticLogger != null && !diagnosticLogger!.isActive) {
        unawaited(diagnosticLogger!.startSession());
      }
      _imuClock ??= Stopwatch()..start();
      _lastGyro = null;
      _accelSampleCount = 0; // G21: restart no-gyro detection each session
      _noGyroDeclared = false;
      _lastGpsFixTs = null; // E1: restart GPS-silence tracking each session
      _lastGpsAccepted = false;
      _lastGpsUnavailableTs = null;

      // Lazily resolve the default sensors stream so unit/widget tests that
      // don't have the plugin registered don't throw during construction.
      final Stream<AccelerometerEvent> stream = (accelerometerStream ??
              accelerometerEventStream(
                samplingPeriod: SensorInterval.gameInterval,
              ))
          .handleError((_) {});

      _accelerometerSubscription = stream.listen(
        (AccelerometerEvent event) {
          final now = DateTime.now();
          final dt = now.difference(_lastUpdate).inMilliseconds / 1000.0;
          _lastUpdate = now;

          // Check if fusion has been running longer than the maximum duration.
          if (now.difference(_fusionStartTime) > maxFusionDuration) {
            // Reset integration to limit accumulated error.
            _velX = 0.0;
            _velY = 0.0;
            _posX = 0.0;
            _posY = 0.0;
            _fusionStartTime = now;
            // Optionally, update _initialLat and _initialLon with the last fused position.
          }

          // Apply damping to current velocity and then integrate acceleration.
          _velX =
              _velX * accelerationDecayFactor +
              event.x * dt * (1 - accelerationDecayFactor);
          _velY =
              _velY * accelerationDecayFactor +
              event.y * dt * (1 - accelerationDecayFactor);

          // Update displacement based on damped velocity.
          _posX += _velX * dt;
          _posY += _velY * dt;

          // Convert displacement to change in latitude and longitude (approximate conversion).
          final dLat = _posY / 111320; // meters to degrees latitude.
          final dLon = _posX / (111320 * cos(_initialLat * pi / 180));
          final fusedLat = _initialLat + dLat;
          final fusedLon = _initialLon + dLon;
          _positionController.add(LatLng(fusedLat, fusedLon));

          final ekf = _ekfOrchestrator;
          final timestamp = Duration(
            microseconds:
                _imuClock?.elapsedMicroseconds ??
                now.millisecondsSinceEpoch * 1000,
          );
          final gx = _lastGyro?.x ?? 0.0;
          final gy = _lastGyro?.y ?? 0.0;
          final gz = _lastGyro?.z ?? 0.0;
          if (ekf != null) {
            // G21: detect a gyroscope-less device. If no gyro sample has arrived
            // after a ~2s warm-up (100 accel samples @ ~50Hz), the device has no
            // gyro; a missing gyro otherwise reads as "perfectly quiet" and
            // over-triggers ZUPT/stationary. Tell the filter so it keeps σs
            // honest (wider floor → the critical-fractile fires earlier = safe).
            if (!_noGyroDeclared) {
              _accelSampleCount++;
              if (_lastGyro != null) {
                _noGyroDeclared = true; // gyro present; stop checking
              } else if (_accelSampleCount >= 100) {
                _noGyroDeclared = true;
                ekf.setNoGyro(true);
              }
            }
            // E1: if GPS has gone silent past the threshold, notify the EKF so
            // it enters DEGRADED mode (honest σ growth + DR damping). Throttled
            // so we don't re-notify on every 50Hz sample.
            if (_lastGpsFixTs != null &&
                (timestamp - _lastGpsFixTs!) > _noFixDegradeThreshold &&
                (_lastGpsUnavailableTs == null ||
                    (timestamp - _lastGpsUnavailableTs!) >
                        const Duration(milliseconds: 500))) {
              _lastGpsUnavailableTs = timestamp;
              ekf.onGpsUnavailable(timestamp);
            }
            ekf.onImuSample(
              ImuSample(
                ax: event.x,
                ay: event.y,
                az: event.z,
                gx: gx,
                gy: gy,
                gz: gz,
                timestamp: timestamp,
              ),
            );
            _lastEkfState = ekf.publicState;
            _ekfStateController.add(_lastEkfState!);
          }
          // Capture the physical sample even when there is no route geometry
          // (and therefore no EKF).  This is the evidence needed to diagnose
          // sensor behaviour before/after a route refresh or a GPS blackout.
          diagnosticLogger?.logImu(
            timestamp: timestamp,
            ax: event.x,
            ay: event.y,
            az: event.z,
            gx: gx,
            gy: gy,
            gz: gz,
            ekfState: _lastEkfState,
            motionState: _lastEkfState?.motion.name,
            mode: _lastEkfState?.mode,
          );
        },
        onError: (_) {
          // If the platform stream errors (e.g., MissingPluginException), disable fusion.
          _accelerometerSubscription?.cancel();
          _accelerometerSubscription = null;
        },
        cancelOnError: true,
      );

      final gyroStream =
          gyroscopeStream ??
          gyroscopeEventStream(samplingPeriod: SensorInterval.gameInterval);
      _gyroscopeSubscription = gyroStream
          .handleError((_) {})
          .listen(
            (GyroscopeEvent event) {
              _lastGyro = event;
            },
            onError: (_) {
              _gyroscopeSubscription?.cancel();
              _gyroscopeSubscription = null;
            },
            cancelOnError: true,
          );
    } catch (_) {
      // In widget/unit tests or unsupported platforms, sensors_plus may not be registered.
      // Treat sensor fusion as unavailable instead of crashing.
      _accelerometerSubscription = null;
      _gyroscopeSubscription = null;
    }
  }

  /// Stops sensor fusion.
  void stopFusion() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;
    _imuClock = null;
    _lastGyro = null;
    if (diagnosticLogger?.isActive ?? false) {
      unawaited(diagnosticLogger!.endSession());
    }
  }

  /// Resets the fusion manager with a new initial position.
  void reset(LatLng initialPosition) {
    _initialLat = initialPosition.latitude;
    _initialLon = initialPosition.longitude;
    _posX = 0.0;
    _posY = 0.0;
    _velX = 0.0;
    _velY = 0.0;
    _lastUpdate = DateTime.now();
    _fusionStartTime = DateTime.now();
    _positionController.add(initialPosition);
    _imuClock = Stopwatch()..start();
    _lastGyro = null;
    _transitLegStops = const [];
  }

  TransitLegStops? _legForProgress(double s) {
    for (final leg in _transitLegStops) {
      if (s >= leg.legStartMeters && s <= leg.legEndMeters) {
        return leg;
      }
    }
    return null;
  }

  void dispose() {
    stopFusion();
    _positionController.close();
    _ekfStateController.close();
  }
}
