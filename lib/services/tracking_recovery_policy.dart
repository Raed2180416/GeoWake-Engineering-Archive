import 'package:geowake2/services/tracking_state_store.dart';
import 'package:geowake2/services/transfer_utils.dart';

enum TrackingRecoveryDisposition { restore, discard }

/// Decides whether an OS/boot restart still represents the rider's current
/// journey. A stale `tracking_active` bit must never resurrect yesterday's
/// alarm, but a legitimate long rail journey must survive process death.
class TrackingRecoveryPolicy {
  static const Duration _futureClockTolerance = Duration(minutes: 5);
  static const Duration _routeGrace = Duration(hours: 2);
  static const Duration _noRouteMaximum = Duration(hours: 6);
  static const Duration _absoluteMaximum = Duration(hours: 18);

  static TrackingRecoveryDisposition evaluate({
    required bool isActive,
    required TrackingSnapshot? snapshot,
    required DateTime now,
  }) {
    if (!isActive || snapshot == null) {
      return TrackingRecoveryDisposition.discard;
    }

    final age = now.difference(snapshot.createdAt);
    if (age < -_futureClockTolerance) {
      return TrackingRecoveryDisposition.discard;
    }

    var maximumAge = _noRouteMaximum;
    final directions = snapshot.directions;
    if (directions != null) {
      final plannedSeconds = TransferUtils.totalPlannedDurationSeconds(
        directions,
      );
      if (plannedSeconds > 0) {
        maximumAge = Duration(seconds: plannedSeconds) + _routeGrace;
        if (maximumAge > _absoluteMaximum) {
          maximumAge = _absoluteMaximum;
        }
      }
    }

    return age <= maximumAge
        ? TrackingRecoveryDisposition.restore
        : TrackingRecoveryDisposition.discard;
  }
}
