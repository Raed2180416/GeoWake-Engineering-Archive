// Route geometry API (v1).

import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteGeometry {
  RouteGeometry.fromPoints(
    this._points, {
    double maxLateralErrorMeters = 75,
    double tangentInterpolationMeters = 7.5,
  })  : _maxLateralErrorMeters = maxLateralErrorMeters,
        _tangentInterpolationMeters = tangentInterpolationMeters,
        _cumMeters = _computeCumMeters(_points),
        _segmentLengths = _computeSegmentLengths(_points),
        _tangents = _computeTangents(_points);

  final List<LatLng> _points;
  final List<double> _cumMeters;
  final List<double> _segmentLengths;
  final List<List<double>> _tangents;
  final double _maxLateralErrorMeters;
  final double _tangentInterpolationMeters;

  double get totalLengthMeters => _cumMeters.isEmpty ? 0 : _cumMeters.last;

  /// Projects lat/lng to route progress meters.
  ///
  /// When [previousProgressMeters] is supplied, candidates are scored with a
  /// continuity term instead of blindly selecting the globally nearest arc.
  /// This matters on loops, station approaches that run in parallel, and
  /// self-crossings: the two arcs can be equally close in GPS space while only
  /// one is reachable from the last trusted EKF state.  The continuity term is
  /// deliberately soft and bounded; after a genuine blackout/re-route, a much
  /// closer candidate can still recover the filter.
  ///
  /// Returns NaN when every candidate exceeds the configured lateral threshold.
  double projectLatLng(
    double lat,
    double lng, {
    double? previousProgressMeters,
    double? headingDegrees,
    bool enforceForward = false,
  }) {
    if (_points.length < 2) return double.nan;

    final p = LatLng(lat, lng);
    double bestScore = double.infinity;
    double bestS = double.nan;
    double bestDistance = double.infinity;

    final hasHistory =
        previousProgressMeters != null && previousProgressMeters.isFinite;
    final priorS = hasHistory
        ? previousProgressMeters.clamp(0.0, totalLengthMeters).toDouble()
        : double.nan;

    for (var i = 0; i < _points.length - 1; i++) {
      final a = _points[i];
      final b = _points[i + 1];
      final segLength = _segmentLengths[i];
      if (segLength <= 0) continue;

      final t = _projectionT(p, a, b).clamp(0.0, 1.0);
      final proj = LatLng(
        a.latitude + t * (b.latitude - a.latitude),
        a.longitude + t * (b.longitude - a.longitude),
      );
      final dist = Geolocator.distanceBetween(
        p.latitude,
        p.longitude,
        proj.latitude,
        proj.longitude,
      );

      if (dist > _maxLateralErrorMeters) continue;

      final candidateS = _cumMeters[i] + t * segLength;
      // Keep geometry distance dominant.  A 1 m lateral improvement may beat
      // a continuity preference, while two near-equal crossing candidates are
      // resolved by the prior route arc.
      var score = dist;
      if (hasHistory) {
        final delta = candidateS - priorS;
        // Penalise implausibly large progress jumps, but do not hard-reject
        // them: a real GPS reacquisition after a tunnel can legitimately jump.
        final jump = delta.abs();
        score += (jump.clamp(0.0, 1500.0) * 0.035).toDouble();
        if (enforceForward && delta < -30.0) {
          score += (-delta - 30.0) * 3.0;
        }

        if (headingDegrees != null && headingDegrees.isFinite) {
          final tangent = _tangents[i];
          final tangentHeading =
              (math.atan2(tangent[0], tangent[1]) * 180.0 / math.pi + 360.0) %
              360.0;
          var diff = (headingDegrees - tangentHeading).abs() % 360.0;
          if (diff > 180.0) diff = 360.0 - diff;
          if (diff > 45.0) {
            score += ((diff - 45.0) / 135.0) * 12.0;
          }
        }
      }

      if (score < bestScore ||
          (score == bestScore && dist < bestDistance)) {
        bestScore = score;
        bestDistance = dist;
        bestS = candidateS;
      }
    }

    if (!bestS.isFinite) return double.nan;
    return bestS.clamp(0.0, totalLengthMeters).toDouble();
  }

  /// Returns tangent unit vector [x, y] (east, north) at progress s (meters).
  /// Applies boundary interpolation over ±Δs to ensure continuity.
  List<double> tangentAt(double sMeters) {
    if (_points.length < 2) return const [1.0, 0.0];
    if (_tangents.isEmpty) return const [1.0, 0.0];

    final s = sMeters.clamp(0.0, totalLengthMeters);
    final segIndex = _segmentIndexForS(s);

    final prevBoundary = _cumMeters[segIndex];
    final nextBoundary = _cumMeters[segIndex + 1];
    final distPrev = (s - prevBoundary).abs();
    final distNext = (s - nextBoundary).abs();

    final withinPrev =
        segIndex > 0 && distPrev <= _tangentInterpolationMeters;
    final withinNext =
        segIndex < _tangents.length - 1 &&
        distNext <= _tangentInterpolationMeters;

    if (withinPrev || withinNext) {
      if (withinNext && (!withinPrev || distNext <= distPrev)) {
        final w1 = (1 - distNext / _tangentInterpolationMeters).clamp(
          0.0,
          1.0,
        );
        final w2 = 1 - w1;
        final tLeft = _tangents[segIndex];
        final tRight = _tangents[segIndex + 1];
        return _normalize([
          tLeft[0] * w1 + tRight[0] * w2,
          tLeft[1] * w1 + tRight[1] * w2,
        ]);
      }

      if (withinPrev) {
        final w1 = (1 - distPrev / _tangentInterpolationMeters).clamp(
          0.0,
          1.0,
        );
        final w2 = 1 - w1;
        final tLeft = _tangents[segIndex - 1];
        final tRight = _tangents[segIndex];
        return _normalize([
          tLeft[0] * w1 + tRight[0] * w2,
          tLeft[1] * w1 + tRight[1] * w2,
        ]);
      }
    }

    return _tangents[segIndex];
  }

  /// Returns LatLng position along the route for progress s (meters).
  /// Uses the same cumulative meters used by EKF projection to avoid scale mismatch.
  LatLng positionAt(double sMeters) {
    if (_points.isEmpty) return const LatLng(0.0, 0.0);
    if (_points.length == 1) return _points.first;

    final s = sMeters.clamp(0.0, totalLengthMeters);
    final segIndex = _segmentIndexForS(s);
    final segStart = _cumMeters[segIndex];
    final segLen = _segmentLengths[segIndex];
    if (segLen <= 0) return _points[segIndex];

    final t = ((s - segStart) / segLen).clamp(0.0, 1.0);
    final a = _points[segIndex];
    final b = _points[segIndex + 1];
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  int _segmentIndexForS(double s) {
    for (var i = 0; i < _cumMeters.length - 1; i++) {
      if (s <= _cumMeters[i + 1]) return i;
    }
    return _cumMeters.length - 2;
  }

  static List<double> _computeSegmentLengths(List<LatLng> pts) {
    if (pts.length < 2) return const <double>[];
    final list = <double>[];
    for (var i = 1; i < pts.length; i++) {
      list.add(
        Geolocator.distanceBetween(
          pts[i - 1].latitude,
          pts[i - 1].longitude,
          pts[i].latitude,
          pts[i].longitude,
        ),
      );
    }
    return list;
  }

  static List<double> _computeCumMeters(List<LatLng> pts) {
    if (pts.isEmpty) return const <double>[];
    final list = List<double>.filled(pts.length, 0.0);
    for (var i = 1; i < pts.length; i++) {
      list[i] =
          list[i - 1] +
          Geolocator.distanceBetween(
            pts[i - 1].latitude,
            pts[i - 1].longitude,
            pts[i].latitude,
            pts[i].longitude,
          );
    }
    return list;
  }

  static List<List<double>> _computeTangents(List<LatLng> pts) {
    if (pts.length < 2) return const <List<double>>[];
    final list = <List<double>>[];
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      final midLat = (a.latitude + b.latitude) * 0.5;
      const metersPerDegLat = 110540.0;
      final metersPerDegLng =
          111320.0 * math.cos(midLat * math.pi / 180).abs();
      final dx = (b.longitude - a.longitude) * metersPerDegLng;
      final dy = (b.latitude - a.latitude) * metersPerDegLat;
      list.add(_normalize([dx, dy]));
    }
    return list;
  }

  static List<double> _normalize(List<double> v) {
    final norm = math.sqrt(v[0] * v[0] + v[1] * v[1]);
    if (norm == 0) return const [1.0, 0.0];
    return [v[0] / norm, v[1] / norm];
  }

  static double _projectionT(LatLng p, LatLng a, LatLng b) {
    // Project in a local metre frame, not raw degrees.  At Indian latitudes a
    // longitude degree is ~0.85–0.99 of a latitude degree; raw-degree
    // projection biases diagonal segments and can move the inferred progress
    // tens of metres on long provider steps.
    final midLat = (a.latitude + b.latitude) * 0.5;
    const metersPerDegLat = 110540.0;
    final metersPerDegLng =
        111320.0 * math.cos(midLat * math.pi / 180.0).abs();
    final dx = (b.longitude - a.longitude) * metersPerDegLng;
    final dy = (b.latitude - a.latitude) * metersPerDegLat;
    if (dx == 0 && dy == 0) return 0;
    final wx = (p.longitude - a.longitude) * metersPerDegLng;
    final wy = (p.latitude - a.latitude) * metersPerDegLat;
    return (wx * dx + wy * dy) / (dx * dx + dy * dy);
  }
}
