import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/trackingservice.dart';

void main() {
  test('foreground bridge streams can be bound only once per process', () {
    final gate = OneShotBindingGate();

    expect(gate.claim(), isTrue);
    expect(gate.claim(), isFalse);
    expect(gate.claim(), isFalse);
  });

  group('TrackingHandshakePolicy', () {
    test('accepts a confirmed first delivery without recovery', () async {
      var attempts = 0;
      var recoveries = 0;

      await TrackingHandshakePolicy.requireAcknowledgement(
        operation: 'startTracking',
        attempt: () async => ++attempts == 1,
        recover: () async => recoveries++,
      );

      expect(attempts, 1);
      expect(recoveries, 0);
    });

    test(
      'recovers a dropped first message and requires the retry ACK',
      () async {
        var attempts = 0;
        var recoveries = 0;

        await TrackingHandshakePolicy.requireAcknowledgement(
          operation: 'registerRouteDirections',
          attempt: () async => ++attempts == 2,
          recover: () async => recoveries++,
        );

        expect(attempts, 2);
        expect(recoveries, 1);
      },
    );

    test(
      'rolls back and throws when a restarting isolate drops both',
      () async {
        var attempts = 0;
        var rolledBack = false;

        await expectLater(
          TrackingHandshakePolicy.requireAcknowledgement(
            operation: 'registerRouteDirections',
            attempt: () async {
              attempts++;
              return false;
            },
            recover: () async {},
            rollback: () async => rolledBack = true,
          ),
          throwsA(
            isA<TrackingHandshakeException>().having(
              (e) => e.operation,
              'operation',
              'registerRouteDirections',
            ),
          ),
        );

        expect(attempts, 2);
        expect(rolledBack, isTrue);
      },
    );
  });
}
