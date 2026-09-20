import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/tracking_recovery_policy.dart';
import 'package:geowake2/services/tracking_state_store.dart';

TrackingSnapshot _snapshot({required DateTime createdAt, int? plannedSeconds}) {
  return TrackingSnapshot(
    destinationName: 'Destination',
    destinationLat: 12.9,
    destinationLng: 77.6,
    alarmMode: 'time',
    alarmValue: 10,
    metroMode: true,
    userLat: 12.8,
    userLng: 77.5,
    createdAt: createdAt,
    directions:
        plannedSeconds == null
            ? null
            : {
              'routes': [
                {
                  'legs': [
                    {
                      'duration': {'value': plannedSeconds},
                    },
                  ],
                },
              ],
            },
  );
}

void main() {
  final now = DateTime.utc(2026, 8, 7, 12);

  test('inactive or missing state never auto-resumes', () {
    expect(
      TrackingRecoveryPolicy.evaluate(
        isActive: false,
        snapshot: _snapshot(createdAt: now),
        now: now,
      ),
      TrackingRecoveryDisposition.discard,
    );
    expect(
      TrackingRecoveryPolicy.evaluate(isActive: true, snapshot: null, now: now),
      TrackingRecoveryDisposition.discard,
    );
  });

  test(
    'recent journey and long planned rail journey survive process death',
    () {
      expect(
        TrackingRecoveryPolicy.evaluate(
          isActive: true,
          snapshot: _snapshot(
            createdAt: now.subtract(const Duration(hours: 1)),
          ),
          now: now,
        ),
        TrackingRecoveryDisposition.restore,
      );
      expect(
        TrackingRecoveryPolicy.evaluate(
          isActive: true,
          snapshot: _snapshot(
            createdAt: now.subtract(const Duration(hours: 14)),
            plannedSeconds: const Duration(hours: 13).inSeconds,
          ),
          now: now,
        ),
        TrackingRecoveryDisposition.restore,
      );
    },
  );

  test('yesterday and implausibly future snapshots are discarded', () {
    expect(
      TrackingRecoveryPolicy.evaluate(
        isActive: true,
        snapshot: _snapshot(
          createdAt: now.subtract(const Duration(hours: 24)),
          plannedSeconds: const Duration(hours: 30).inSeconds,
        ),
        now: now,
      ),
      TrackingRecoveryDisposition.discard,
    );
    expect(
      TrackingRecoveryPolicy.evaluate(
        isActive: true,
        snapshot: _snapshot(createdAt: now.add(const Duration(minutes: 6))),
        now: now,
      ),
      TrackingRecoveryDisposition.discard,
    );
  });
}
