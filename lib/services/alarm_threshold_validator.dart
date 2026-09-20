import 'package:geowake2/services/metro_vehicle_types.dart';

class AlarmThresholdValidationResult {
  final bool isValid;
  final String? reason;
  final String? userMessage;

  const AlarmThresholdValidationResult.valid()
    : isValid = true,
      reason = null,
      userMessage = null;

  const AlarmThresholdValidationResult.invalid({
    required this.reason,
    required this.userMessage,
  }) : isValid = false;
}

/// Validates the user's alarm promise against the exact candidate route before
/// the background service is armed. This is intentionally provider-neutral: an
/// Oracle route adapter and the current Google-compatible response must produce
/// the same decision.
class AlarmThresholdValidator {
  const AlarmThresholdValidator._();

  static AlarmThresholdValidationResult validate({
    required Map<String, dynamic> directions,
    required String alarmMode,
    required double alarmValue,
    required bool transitMode,
  }) {
    if (!alarmValue.isFinite || alarmValue <= 0) {
      return const AlarmThresholdValidationResult.invalid(
        reason: 'alarm threshold must be finite and greater than zero',
        userMessage: 'Choose an alarm value greater than zero.',
      );
    }
    if (!const {'stops', 'time', 'distance'}.contains(alarmMode)) {
      return AlarmThresholdValidationResult.invalid(
        reason: 'unsupported alarm mode: $alarmMode',
        userMessage: 'Choose Stops, Time, or Distance for this alarm.',
      );
    }

    final route = _firstRoute(directions);
    final legs = route?['legs'] as List?;
    if (route == null || legs == null || legs.isEmpty) {
      return const AlarmThresholdValidationResult.invalid(
        reason: 'route has no usable legs',
        userMessage: 'This route has no usable journey segments. Try again.',
      );
    }
    final steps = <Map<String, dynamic>>[];
    for (final rawLeg in legs) {
      if (rawLeg is! Map) continue;
      final rawSteps = rawLeg['steps'] as List? ?? const [];
      for (final rawStep in rawSteps) {
        if (rawStep is Map) {
          steps.add(Map<String, dynamic>.from(rawStep));
        }
      }
    }
    if (steps.isEmpty) {
      return const AlarmThresholdValidationResult.invalid(
        reason: 'route has no usable steps',
        userMessage: 'This route has no usable journey steps. Try again.',
      );
    }

    if (alarmMode == 'distance') {
      final totalMeters = _totalMetric(legs, steps, 'distance');
      if (totalMeters <= 0) {
        return const AlarmThresholdValidationResult.invalid(
          reason: 'route distance is unavailable',
          userMessage: 'The route provider did not return a usable distance.',
        );
      }
      if (alarmValue * 1000 >= totalMeters) {
        return AlarmThresholdValidationResult.invalid(
          reason:
              'distance threshold ${alarmValue}km is not below route distance ${totalMeters / 1000}km',
          userMessage:
              'Choose less than ${(totalMeters / 1000).toStringAsFixed(1)} km for this route.',
        );
      }
      return const AlarmThresholdValidationResult.valid();
    }

    final metroSteps = <({int index, Map<String, dynamic> step})>[];
    for (var index = 0; index < steps.length; index++) {
      if (_isMetroStep(steps[index])) {
        metroSteps.add((index: index, step: steps[index]));
      }
    }

    if (alarmMode == 'stops') {
      if (!transitMode || metroSteps.isEmpty) {
        return const AlarmThresholdValidationResult.invalid(
          reason: 'stops alarm requires at least one metro segment',
          userMessage: 'Stops mode needs a route with metro service.',
        );
      }
      if ((alarmValue - alarmValue.round()).abs() > 0.000001) {
        return const AlarmThresholdValidationResult.invalid(
          reason: 'stops threshold must be a whole number',
          userMessage: 'Choose a whole number of stops.',
        );
      }
      final threshold = alarmValue.round();
      for (final entry in metroSteps) {
        final details = entry.step['transit_details'] as Map?;
        final intermediate = details?['num_stops'];
        if (intermediate is! num || intermediate < 0) {
          return const AlarmThresholdValidationResult.invalid(
            reason: 'metro segment has no reliable stop count',
            userMessage:
                'The route provider did not return a reliable metro stop count.',
          );
        }
        final totalToTarget = intermediate.toInt() + 1;
        if (threshold >= totalToTarget) {
          final line = _lineName(entry.step);
          return AlarmThresholdValidationResult.invalid(
            reason:
                'stops threshold $threshold is not below $totalToTarget stops on $line',
            userMessage:
                '$line has only $totalToTarget stop${totalToTarget == 1 ? '' : 's'} to its target. Choose fewer than $totalToTarget.',
          );
        }
      }
      return const AlarmThresholdValidationResult.valid();
    }

    // Time mode.
    final thresholdSeconds = alarmValue * 60;
    if (!transitMode) {
      final totalSeconds = _totalMetric(legs, steps, 'duration');
      if (totalSeconds <= 0) {
        return const AlarmThresholdValidationResult.invalid(
          reason: 'route duration is unavailable',
          userMessage: 'The route provider did not return a usable duration.',
        );
      }
      if (thresholdSeconds >= totalSeconds) {
        return AlarmThresholdValidationResult.invalid(
          reason:
              'time threshold ${alarmValue}min is not below route duration ${totalSeconds / 60}min',
          userMessage:
              'Choose less than ${(totalSeconds / 60).toStringAsFixed(0)} minutes for this route.',
        );
      }
      return const AlarmThresholdValidationResult.valid();
    }

    if (metroSteps.isEmpty) {
      return const AlarmThresholdValidationResult.invalid(
        reason: 'metro mode route has no metro segment',
        userMessage:
            'No metro segment was found. Choose another route or use non-metro mode.',
      );
    }
    for (final entry in metroSteps) {
      final duration = _stepMetric(entry.step, 'duration');
      final line = _lineName(entry.step);
      if (duration <= 0) {
        return AlarmThresholdValidationResult.invalid(
          reason: '$line has no reliable duration',
          userMessage:
              'The route provider did not return a reliable duration for $line.',
        );
      }
      if (thresholdSeconds >= duration) {
        return AlarmThresholdValidationResult.invalid(
          reason:
              'time threshold ${alarmValue}min is not below ${duration / 60}min on $line',
          userMessage:
              '$line is only ${(duration / 60).toStringAsFixed(0)} minutes. Choose a smaller time alarm.',
        );
      }
    }

    // After the final metro, time mode targets the ultimate destination. If the
    // last walk/drive portion is shorter than the chosen threshold it would fire
    // immediately at the interchange, creating a duplicate/meaningless alarm.
    final lastMetroIndex = metroSteps.last.index;
    var finalNonMetroSeconds = 0.0;
    for (var index = lastMetroIndex + 1; index < steps.length; index++) {
      finalNonMetroSeconds += _stepMetric(steps[index], 'duration');
    }
    if (finalNonMetroSeconds > 0 && thresholdSeconds >= finalNonMetroSeconds) {
      return AlarmThresholdValidationResult.invalid(
        reason:
            'time threshold ${alarmValue}min is not below final non-metro duration ${finalNonMetroSeconds / 60}min',
        userMessage:
            'The final segment is only ${(finalNonMetroSeconds / 60).toStringAsFixed(0)} minutes. Choose a smaller time alarm.',
      );
    }

    return const AlarmThresholdValidationResult.valid();
  }

  static Map<String, dynamic>? _firstRoute(Map<String, dynamic> directions) {
    final routes = directions['routes'] as List?;
    if (routes == null || routes.isEmpty || routes.first is! Map) return null;
    return Map<String, dynamic>.from(routes.first as Map);
  }

  static bool _isMetroStep(Map<String, dynamic> step) {
    if (step['travel_mode']?.toString().toUpperCase() != 'TRANSIT') {
      return false;
    }
    final details = step['transit_details'] as Map?;
    final line = details?['line'] as Map?;
    final vehicle = line?['vehicle'] as Map?;
    final type = vehicle?['type']?.toString().toUpperCase();
    return type != null && kMetroVehicleTypes.contains(type);
  }

  static String _lineName(Map<String, dynamic> step) {
    final details = step['transit_details'] as Map?;
    final line = details?['line'] as Map?;
    return (line?['short_name'] ?? line?['name'] ?? 'This metro segment')
        .toString();
  }

  static double _stepMetric(Map<String, dynamic> step, String key) {
    final metric = step[key] as Map?;
    return (metric?['value'] as num?)?.toDouble() ?? 0;
  }

  static double _totalMetric(
    List legs,
    List<Map<String, dynamic>> steps,
    String key,
  ) {
    var total = 0.0;
    for (final rawLeg in legs) {
      if (rawLeg is! Map) continue;
      final metric = rawLeg[key] as Map?;
      total += (metric?['value'] as num?)?.toDouble() ?? 0;
    }
    if (total > 0) return total;
    return steps.fold<double>(0, (sum, step) => sum + _stepMetric(step, key));
  }
}
