// lib/services/tracking/background_handlers.dart
//
// Handles all service.on() listener registrations for the background isolate.
// These handlers process commands from the foreground isolate.

import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:geowake2/core/logging/app_logger.dart';
import 'package:geowake2/services/alarm_player.dart';
import 'package:geowake2/services/location_manager.dart';

/// Callbacks that BackgroundHandlers invokes when events are received.
class BackgroundHandlerCallbacks {
  /// Called when startTracking is received with all parameters.
  final Future<void> Function({
    required LatLng destination,
    required String destinationName,
    required String alarmMode,
    required double alarmValue,
    required bool transitMode,
    bool isSimulationMode,
    required bool Function() isCommandCurrent,
    required ServiceInstance service,
  })
  onStartTracking;

  /// Called when stopTracking is received.
  final Future<void> Function({bool stopSelf}) onStopTracking;

  /// Called when registerRoute is received.
  final void Function({
    required String key,
    required String mode,
    required String destinationName,
    required List<LatLng> points,
    List<Map<String, dynamic>>? segments,
    List<Map<String, dynamic>>? switchPoints,
    List<Map<String, dynamic>>? events,
  })
  onRegisterRoute;

  /// Called when registerRouteDirections is received.
  final Future<void> Function({
    required Map<String, dynamic> directions,
    required LatLng origin,
    required LatLng destination,
    required bool transitMode,
    String? destinationName,
    bool activateRoute,
    required bool Function() isCommandCurrent,
  })
  onRegisterRouteDirections;

  /// Called when stopAlarm is received.
  final Future<void> Function() onStopAlarm;

  /// Invoked on foreground heartbeat
  final void Function() onForegroundHeartbeat;

  /// Invoked when foreground resumed
  final Future<void> Function() onForegroundResumed;

  /// Invoked when simulation mode is set
  final void Function(bool enabled) onSetSimulationMode;

  BackgroundHandlerCallbacks({
    required this.onStartTracking,
    required this.onStopTracking,
    required this.onRegisterRoute,
    required this.onRegisterRouteDirections,
    required this.onStopAlarm,
    required this.onForegroundHeartbeat,
    required this.onForegroundResumed,
    required this.onSetSimulationMode,
  });
}

/// Registers all background service event handlers.
/// Should be called once during _onStart.
class BackgroundHandlers {
  final ServiceInstance _service;
  final BackgroundHandlerCallbacks _callbacks;
  int _startGeneration = 0;
  String? _activeArmId;
  String? _startedArmId;
  String? _pendingArmId;
  Future<void>? _pendingStart;
  Future<void>? _pendingRouteRegistration;

  BackgroundHandlers({
    required ServiceInstance service,
    required BackgroundHandlerCallbacks callbacks,
  }) : _service = service,
       _callbacks = callbacks;

  /// Registers all handlers on the service instance.
  void registerAll() {
    _service.on('stopService').listen((_) {
      _service.stopSelf();
    });

    _service.on('startTracking').listen(_handleStartTracking);
    _service.on('stopTracking').listen(_handleStopTracking);
    _service.on('stopAlarm').listen(_handleStopAlarm);
    _service.on('registerRoute').listen(_handleRegisterRoute);
    _service
        .on('registerRouteDirections')
        .listen(_handleRegisterRouteDirections);

    // Position injection for demo/testing
    _service.on('useInjectedPositions').listen((_) {
      // LocationManager handles auto-switch
    });

    _service.on('injectPosition').listen(_handleInjectPosition);

    // Heartbeat mechanism
    _service.on('foregroundHeartbeat').listen((_) {
      _callbacks.onForegroundHeartbeat();
    });

    _service.on('foregroundResumed').listen((_) async {
      await _callbacks.onForegroundResumed();
    });

    _service.on('setSimulationMode').listen((event) {
      if (event != null) {
        _callbacks.onSetSimulationMode(event['enabled'] == true);
      }
    });
  }

  Future<void> _handleStartTracking(Map<String, dynamic>? data) async {
    dev.log(
      'Background received startTracking event',
      name: 'BackgroundHandlers',
    );

    if (data == null) return;
    final requestId = data['requestId'] as String?;
    final armId =
        data['armSessionId'] as String? ?? requestId ?? 'legacy-arm-command';

    // Every foreground retry for one arm carries the same armSessionId. Join
    // the in-flight initialization instead of starting another location stream.
    final existing = _pendingArmId == armId ? _pendingStart : null;
    if (existing != null) {
      try {
        await existing;
        if (_activeArmId == armId && requestId != null) {
          _service.invoke('startTrackingAck', {'requestId': requestId});
        }
      } catch (_) {
        // The owning handler logs the failure and deliberately withholds ACK.
      }
      return;
    }

    // A duplicate delivered after successful initialization is idempotent: ACK
    // it without resetting route/alarm/location state.
    if (_activeArmId == armId && _startedArmId == armId) {
      if (requestId != null) {
        _service.invoke('startTrackingAck', {'requestId': requestId});
      }
      return;
    }

    final generation = ++_startGeneration;
    _activeArmId = armId;
    bool isCurrent() => generation == _startGeneration && _activeArmId == armId;

    try {
      final destination = LatLng(
        (data['destinationLat'] as num).toDouble(),
        (data['destinationLng'] as num).toDouble(),
      );
      final destinationName = data['destinationName'] as String;
      final alarmMode = data['alarmMode'] as String;
      final alarmValue = (data['alarmValue'] as num).toDouble();
      final transitMode = data['transitMode'] as bool? ?? false;
      final isSimulationMode = data['isSimulationMode'] as bool? ?? false;

      // ACK means the alarm engine accepted the command, not merely that the
      // platform channel delivered bytes. Await initialization first so a
      // callback failure or restarting isolate cannot produce false success.
      final start = _callbacks.onStartTracking(
        destination: destination,
        destinationName: destinationName,
        alarmMode: alarmMode,
        alarmValue: alarmValue,
        transitMode: transitMode,
        isSimulationMode: isSimulationMode,
        isCommandCurrent: isCurrent,
        service: _service,
      );
      _pendingArmId = armId;
      _pendingStart = start;
      await start;

      if (!isCurrent()) return;
      _startedArmId = armId;
      if (requestId != null) {
        _service.invoke('startTrackingAck', {'requestId': requestId});
      }
    } catch (e) {
      // Deliberately withhold ACK. Foreground retry/rollback owns recovery.
      dev.log(
        'Background: startTracking initialization failed: $e',
        name: 'BackgroundHandlers',
      );
    } finally {
      if (_pendingArmId == armId) {
        _pendingArmId = null;
        _pendingStart = null;
      }
    }
  }

  void _handleStopTracking(Map<String, dynamic>? event) async {
    // Invalidate before the first await. A delayed start callback can no longer
    // publish an ACK or begin a stream after foreground rollback.
    _startGeneration++;
    _activeArmId = null;
    _startedArmId = null;
    final pendingStart = _pendingStart;
    final pendingRoute = _pendingRouteRegistration;

    try {
      await AlarmPlayer.stop();
    } catch (e) {
      dev.log('Error stopping alarm: $e', name: 'BackgroundHandlers');
    }

    await _callbacks.onStopTracking(stopSelf: event?['stopSelf'] == true);

    // If start was inside an await when stop arrived, wait a bounded interval
    // and clean up once more. This closes the late-write/resurrection race even
    // when platform delivery overlaps route restoration or stream start.
    if (pendingStart != null) {
      try {
        await pendingStart.timeout(const Duration(seconds: 6));
      } catch (_) {}
      await _callbacks.onStopTracking(stopSelf: event?['stopSelf'] == true);
    }
    if (pendingRoute != null) {
      try {
        await pendingRoute.timeout(const Duration(seconds: 6));
      } catch (_) {}
      await _callbacks.onStopTracking(stopSelf: event?['stopSelf'] == true);
    }

    if (event?['stopSelf'] == true) {
      _service.stopSelf();
    }
  }

  void _handleStopAlarm(Map<String, dynamic>? _) async {
    dev.log('Received stopAlarm event', name: 'BackgroundHandlers');
    try {
      await _callbacks.onStopAlarm();
    } catch (e) {
      dev.log('Error stopping alarm: $e', name: 'BackgroundHandlers');
    }
  }

  void _handleRegisterRoute(Map<String, dynamic>? data) {
    if (data == null) return;
    try {
      final requestId = data['requestId'] as String?;
      final key = data['key'] as String;
      final mode = data['mode'] as String;
      final destinationName = data['destinationName'] as String;
      final pointsJson = data['points'] as List;
      final points =
          pointsJson
              .map(
                (p) => LatLng(
                  (p['lat'] as num).toDouble(),
                  (p['lng'] as num).toDouble(),
                ),
              )
              .toList();

      List<Map<String, dynamic>>? segments;
      if (data['segments'] != null) {
        segments =
            (data['segments'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
      }

      List<Map<String, dynamic>>? switchPoints;
      if (data['switch_points'] != null) {
        switchPoints =
            (data['switch_points'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
      }

      List<Map<String, dynamic>>? events;
      if (data['events'] != null) {
        events =
            (data['events'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
      }

      dev.log(
        'Background: Received registerRoute for $key',
        name: 'BackgroundHandlers',
      );

      _callbacks.onRegisterRoute(
        key: key,
        mode: mode,
        destinationName: destinationName,
        points: points,
        segments: segments,
        switchPoints: switchPoints,
        events: events,
      );

      if (requestId != null) {
        _service.invoke('registerRouteAck', {'requestId': requestId});
      }
    } catch (e) {
      dev.log(
        'Background: Error in registerRoute listener: $e',
        name: 'BackgroundHandlers',
      );
    }
  }

  void _handleRegisterRouteDirections(Map<String, dynamic>? data) async {
    if (data == null) return;
    try {
      final requestId = data['requestId'] as String?;
      final armId = data['armSessionId'] as String?;
      if (armId != null && armId != _activeArmId) return;
      final generation = _startGeneration;
      bool isCurrent() =>
          generation == _startGeneration &&
          (armId == null || armId == _activeArmId);
      final directions = Map<String, dynamic>.from(data['directions'] as Map);
      final originMap = Map<String, dynamic>.from(data['origin'] as Map);
      final destMap = Map<String, dynamic>.from(data['destination'] as Map);
      final origin = LatLng(
        (originMap['lat'] as num).toDouble(),
        (originMap['lng'] as num).toDouble(),
      );
      final destination = LatLng(
        (destMap['lat'] as num).toDouble(),
        (destMap['lng'] as num).toDouble(),
      );
      final transitMode = (data['transitMode'] as bool?) ?? false;
      final destinationName = data['destinationName'] as String?;
      final activateRoute = (data['activateRoute'] as bool?) ?? false;

      final registration = _callbacks.onRegisterRouteDirections(
        directions: directions,
        origin: origin,
        destination: destination,
        transitMode: transitMode,
        destinationName: destinationName,
        activateRoute: activateRoute,
        isCommandCurrent: isCurrent,
      );
      _pendingRouteRegistration = registration;
      await registration;
      if (!isCurrent()) return;

      if (requestId != null) {
        _service.invoke('registerRouteDirectionsAck', {'requestId': requestId});
      }
    } catch (e) {
      dev.log(
        'Background: Error in registerRouteDirections: $e',
        name: 'BackgroundHandlers',
      );
    } finally {
      _pendingRouteRegistration = null;
    }
  }

  void _handleInjectPosition(Map<String, dynamic>? data) {
    try {
      if (data == null) return;
      final p = Position(
        latitude: (data['latitude'] as num).toDouble(),
        longitude: (data['longitude'] as num).toDouble(),
        timestamp: DateTime.now(),
        accuracy: (data['accuracy'] as num?)?.toDouble() ?? 5.0,
        altitude: (data['altitude'] as num?)?.toDouble() ?? 0.0,
        altitudeAccuracy: (data['altitudeAccuracy'] as num?)?.toDouble() ?? 0.0,
        heading: (data['heading'] as num?)?.toDouble() ?? 0.0,
        headingAccuracy: (data['headingAccuracy'] as num?)?.toDouble() ?? 0.0,
        speed: (data['speed'] as num?)?.toDouble() ?? 12.0,
        speedAccuracy: (data['speedAccuracy'] as num?)?.toDouble() ?? 1.0,
      );
      LocationManager().injectPosition(p);
    } catch (e) {
      gpsLog.warn(
        'Failed to parse injected position',
        data: {'error': e.toString()},
      );
    }
  }
}
