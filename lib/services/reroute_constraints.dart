/// Validates that rerouted paths respect original alarm constraints.
///
/// When a user deviates and we fetch a new route, this class ensures
/// the new route is compatible with the user's original alarm settings.
/// If constraints are violated, tracking should terminate gracefully.
library;

import 'package:geowake2/services/metro_vehicle_types.dart';
import 'package:geowake2/services/alarm_threshold_validator.dart';

/// Result of constraint validation with details about any failures.
class RerouteValidationResult {
  final bool isValid;
  final String? failureReason;
  final String? userMessage;

  const RerouteValidationResult.valid()
    : isValid = true,
      failureReason = null,
      userMessage = null;

  const RerouteValidationResult.invalid({
    required this.failureReason,
    required this.userMessage,
  }) : isValid = false;

  @override
  String toString() => isValid ? 'Valid' : 'Invalid: $failureReason';
}

/// Constraints that must be satisfied by any rerouted path.
class RerouteConstraints {
  /// The alarm mode: 'stops', 'time', or 'distance'
  final String alarmMode;

  /// The alarm threshold value (stops count, minutes, or km)
  final double alarmValue;

  /// Whether the original route was transit-based
  final bool transitMode;

  /// Maximum allowed transfers (if user specified)
  final int? maxTransfers;

  const RerouteConstraints({
    required this.alarmMode,
    required this.alarmValue,
    required this.transitMode,
    this.maxTransfers,
  });

  /// Validates whether a new directions response satisfies these constraints.
  ///
  /// Returns a [RerouteValidationResult] with details about any failures.
  RerouteValidationResult validate(Map<String, dynamic> newDirections) {
    try {
      // 1. Check transit mode compatibility
      if (transitMode) {
        final hasMetro = _routeHasMetroLeg(newDirections);
        if (!hasMetro) {
          return const RerouteValidationResult.invalid(
            failureReason:
                'transit (metro) mode required but new route has no metro legs',
            userMessage:
                'Tracking ended: Alternate route has no metro service (you selected metro mode)',
          );
        }
      }

      // Initial arming and every reroute must enforce the same promise. The old
      // reroute-only checks summed stops/duration across the whole journey and
      // could accept a threshold that was impossible on one short metro leg.
      final thresholdValidation = AlarmThresholdValidator.validate(
        directions: newDirections,
        alarmMode: alarmMode,
        alarmValue: alarmValue,
        transitMode: transitMode,
      );
      if (!thresholdValidation.isValid) {
        return RerouteValidationResult.invalid(
          failureReason:
              thresholdValidation.reason ?? 'alarm threshold is incompatible',
          userMessage:
              'Tracking ended: ${thresholdValidation.userMessage ?? 'The alternate route cannot honor your alarm setting.'}',
        );
      }

      // 3. Check transfer count if constrained
      if (maxTransfers != null && transitMode) {
        final transfers = _countTransfers(newDirections);
        if (transfers > maxTransfers!) {
          return RerouteValidationResult.invalid(
            failureReason: 'Too many transfers: $transfers > $maxTransfers',
            userMessage:
                'Tracking ended: New route requires $transfers transfers (max allowed: $maxTransfers)',
          );
        }
      }

      return const RerouteValidationResult.valid();
    } catch (e) {
      return RerouteValidationResult.invalid(
        failureReason: 'Validation error: $e',
        userMessage: 'Tracking ended: Unable to validate alternate route',
      );
    }
  }

  /// Check if the route has any transit legs.
  bool _routeHasMetroLeg(Map<String, dynamic> directions) {
    try {
      final routes = directions['routes'] as List?;
      if (routes == null || routes.isEmpty) return false;

      final route = routes.first as Map<String, dynamic>;
      final legs = route['legs'] as List?;
      if (legs == null) return false;

      for (final leg in legs) {
        final steps = (leg as Map<String, dynamic>)['steps'] as List?;
        if (steps == null) continue;
        for (final s in steps) {
          final step = s as Map<String, dynamic>;
          final travelMode = (step['travel_mode'] as String?)?.toUpperCase();
          if (travelMode != 'TRANSIT') continue;
          final td = step['transit_details'] as Map<String, dynamic>?;
          final line = td?['line'] as Map<String, dynamic>?;
          final vehicle = line?['vehicle'] as Map<String, dynamic>?;
          final vType = (vehicle?['type'] as String?)?.toUpperCase();
          if (vType == null) continue;
          // SINGLE SOURCE OF TRUTH: same kMetroVehicleTypes set as
          // TransferUtils._isMetroTransitStep, so a TRAM / COMMUTER_TRAIN /
          // LIGHT_RAIL alternate is no longer rejected on reroute while being
          // accepted for tracking.
          if (kMetroVehicleTypes.contains(vType)) {
            return true;
          }
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Count number of transit transfers in the route.
  int _countTransfers(Map<String, dynamic> directions) {
    try {
      final routes = directions['routes'] as List?;
      if (routes == null || routes.isEmpty) return 0;

      final route = routes.first as Map<String, dynamic>;
      final legs = route['legs'] as List?;
      if (legs == null) return 0;

      int transitCount = 0;
      for (final leg in legs) {
        final steps = (leg as Map<String, dynamic>)['steps'] as List?;
        if (steps == null) continue;

        for (final step in steps) {
          final travelMode =
              (step as Map<String, dynamic>)['travel_mode'] as String?;
          if (travelMode?.toUpperCase() == 'TRANSIT') {
            transitCount++;
          }
        }
      }
      // Transfers = transit legs - 1 (first boarding is not a transfer)
      return transitCount > 0 ? transitCount - 1 : 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  String toString() =>
      'RerouteConstraints(mode=$alarmMode, value=$alarmValue, transit=$transitMode)';
}
