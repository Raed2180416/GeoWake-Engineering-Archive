import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/tracking/background_handlers.dart';

class _Invocation {
  final String method;
  final Map<String, dynamic>? args;

  const _Invocation(this.method, this.args);
}

class _FakeService implements ServiceInstance {
  final _events = <String, StreamController<Map<String, dynamic>?>>{};
  final invocations = <_Invocation>[];

  @override
  void invoke(String method, [Map<String, dynamic>? args]) {
    invocations.add(_Invocation(method, args));
  }

  @override
  Stream<Map<String, dynamic>?> on(String event) =>
      _events
          .putIfAbsent(
            event,
            () => StreamController<Map<String, dynamic>?>.broadcast(),
          )
          .stream;

  @override
  Future<void> stopSelf() async {}

  void emit(String event, Map<String, dynamic> data) {
    _events[event]!.add(data);
  }

  Future<void> dispose() async {
    for (final controller in _events.values) {
      await controller.close();
    }
  }
}

BackgroundHandlerCallbacks _callbacks({
  required Future<void> Function() onStart,
  Future<void> Function()? onStop,
  Future<void> Function(bool activateRoute)? onRegisterDirections,
}) {
  return BackgroundHandlerCallbacks(
    onStartTracking: ({
      required destination,
      required destinationName,
      required alarmMode,
      required alarmValue,
      required transitMode,
      isSimulationMode = false,
      required isCommandCurrent,
      required service,
    }) async {
      if (!isCommandCurrent()) return;
      await onStart();
    },
    onStopTracking: ({stopSelf = true}) async {
      await onStop?.call();
    },
    onRegisterRoute:
        ({
          required key,
          required mode,
          required destinationName,
          required points,
          segments,
          switchPoints,
          events,
        }) {},
    onRegisterRouteDirections: ({
      required directions,
      required origin,
      required destination,
      required transitMode,
      destinationName,
      activateRoute = false,
      required isCommandCurrent,
    }) async {
      if (!isCommandCurrent()) return;
      await onRegisterDirections?.call(activateRoute);
    },
    onStopAlarm: () async {},
    onForegroundHeartbeat: () {},
    onForegroundResumed: () async {},
    onSetSimulationMode: (_) {},
  );
}

Map<String, dynamic> _startPayload() => {
  'requestId': 'arm-1',
  'destinationLat': 12.97,
  'destinationLng': 77.59,
  'destinationName': 'Destination',
  'alarmMode': 'distance',
  'alarmValue': 1.0,
  'transitMode': false,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'start ACK is emitted only after background initialization completes',
    () async {
      final service = _FakeService();
      final initialized = Completer<void>();
      BackgroundHandlers(
        service: service,
        callbacks: _callbacks(onStart: () => initialized.future),
      ).registerAll();

      service.emit('startTracking', _startPayload());
      await pumpEventQueue();
      expect(service.invocations, isEmpty);

      initialized.complete();
      await pumpEventQueue();
      expect(service.invocations, hasLength(1));
      expect(service.invocations.single.method, 'startTrackingAck');
      expect(service.invocations.single.args?['requestId'], 'arm-1');
      await service.dispose();
    },
  );

  test('failed background initialization withholds ACK', () async {
    final service = _FakeService();
    BackgroundHandlers(
      service: service,
      callbacks: _callbacks(onStart: () async => throw StateError('boom')),
    ).registerAll();

    service.emit('startTracking', _startPayload());
    await pumpEventQueue();
    expect(service.invocations, isEmpty);
    await service.dispose();
  });

  test('retry joins one start and stop invalidates every late ACK', () async {
    final service = _FakeService();
    final release = Completer<void>();
    var starts = 0;
    var stops = 0;
    BackgroundHandlers(
      service: service,
      callbacks: _callbacks(
        onStart: () {
          starts++;
          return release.future;
        },
        onStop: () async {
          stops++;
        },
      ),
    ).registerAll();

    service.emit('startTracking', {
      ..._startPayload(),
      'requestId': 'arm-request-1',
      'armSessionId': 'same-arm',
    });
    service.emit('startTracking', {
      ..._startPayload(),
      'requestId': 'arm-request-2',
      'armSessionId': 'same-arm',
    });
    await pumpEventQueue();
    expect(starts, 1);

    service.emit('stopTracking', {'stopSelf': false});
    await pumpEventQueue();
    release.complete();
    await pumpEventQueue(times: 20);

    expect(
      service.invocations.where((i) => i.method == 'startTrackingAck'),
      isEmpty,
    );
    expect(stops, greaterThanOrEqualTo(2));
    await service.dispose();
  });

  test('stop cleans again after delayed route registration', () async {
    final service = _FakeService();
    final release = Completer<void>();
    var stops = 0;
    BackgroundHandlers(
      service: service,
      callbacks: _callbacks(
        onStart: () async {},
        onStop: () async {
          stops++;
        },
        onRegisterDirections: (_) => release.future,
      ),
    ).registerAll();

    // Establish the arm generation first.
    service.emit('startTracking', {
      ..._startPayload(),
      'armSessionId': 'route-arm',
    });
    await pumpEventQueue();
    service.invocations.clear();
    service.emit('registerRouteDirections', {
      'requestId': 'route-request',
      'armSessionId': 'route-arm',
      'directions': <String, dynamic>{'routes': <dynamic>[]},
      'origin': {'lat': 12.97, 'lng': 77.59},
      'destination': {'lat': 13.01, 'lng': 77.63},
      'transitMode': true,
      'activateRoute': true,
    });
    await pumpEventQueue();
    service.emit('stopTracking', {'stopSelf': false});
    await pumpEventQueue();
    release.complete();
    await pumpEventQueue(times: 20);

    expect(
      service.invocations.where(
        (i) => i.method == 'registerRouteDirectionsAck',
      ),
      isEmpty,
    );
    expect(stops, greaterThanOrEqualTo(2));
    await service.dispose();
  });

  test('route activation intent reaches background before ACK', () async {
    final service = _FakeService();
    bool? receivedActivate;
    BackgroundHandlers(
      service: service,
      callbacks: _callbacks(
        onStart: () async {},
        onRegisterDirections: (activate) async {
          receivedActivate = activate;
        },
      ),
    ).registerAll();

    service.emit('registerRouteDirections', {
      'requestId': 'reroute-1',
      'directions': <String, dynamic>{'routes': <dynamic>[]},
      'origin': {'lat': 12.97, 'lng': 77.59},
      'destination': {'lat': 13.01, 'lng': 77.63},
      'transitMode': true,
      'activateRoute': true,
    });
    await pumpEventQueue();

    expect(receivedActivate, isTrue);
    expect(service.invocations, hasLength(1));
    expect(service.invocations.single.method, 'registerRouteDirectionsAck');
    expect(service.invocations.single.args?['requestId'], 'reroute-1');
    await service.dispose();
  });
}
