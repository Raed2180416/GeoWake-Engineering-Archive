import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'polyline_decoder.dart';
import 'polyline_simplifier.dart';
import 'package:geowake2/services/api_client.dart';
import 'package:geowake2/services/route_cache.dart';
import 'package:geowake2/services/route_logger.dart';
import 'dart:convert' show utf8;
import 'package:crypto/crypto.dart' as crypto;
import 'dart:developer' as dev;
import 'package:geowake2/metro_color_map.dart';

class DirectionService {
  final ApiClient _apiClient = ApiClient.instance;
  Map<String, dynamic>? _cachedDirections;
  DateTime? _lastFetchTime;
  String? _cachedDirectionsKey;
  // In-memory cache for decode+simplify keyed by hash 'len:md5' of polyline+tol
  final Map<String, List<LatLng>> _polylineSimplifyCache = {};

  // Tiered intervals for updating directions.
  final Duration farInterval = const Duration(minutes: 15);
  final Duration midInterval = const Duration(minutes: 7);
  final Duration nearInterval = const Duration(minutes: 3);

  DirectionService();

  String _makeRequestKey({
    required LatLng origin,
    required LatLng destination,
    required String mode,
    String? transitVariant,
    int? departureTime,
  }) {
    return RouteCache.makeKey(
      origin: origin,
      destination: destination,
      mode: mode,
      transitVariant: transitVariant,
      departureTime: departureTime,
    );
  }

  /// Fetches directions using a tiered strategy through your secure API.
  Future<Map<String, dynamic>> getDirections(
    double startLat,
    double startLng,
    double endLat,
    double endLng, {
    required bool isDistanceMode,
    required double threshold,
    required bool transitMode,
    bool preferMetroEvenIfClosed = false,
    bool forceRefresh = false,
  }) async {
    // L2 persistent cache check (Hive)
    final origin = LatLng(startLat, startLng);
    final dest = LatLng(endLat, endLng);
    final mode = transitMode ? 'transit' : 'driving';

    bool routeContainsMetroLeg(Map<String, dynamic> route) {
      try {
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
            if (vType == 'SUBWAY' ||
                vType == 'HEAVY_RAIL' ||
                vType == 'RAIL' ||
                vType == 'METRO_RAIL' ||
                vType == 'MONORAIL') {
              return true;
            }
          }
        }
      } catch (_) {}
      return false;
    }

    double routeDurationSeconds(Map<String, dynamic> route) {
      try {
        final legs = route['legs'] as List?;
        if (legs == null || legs.isEmpty) return double.infinity;
        double total = 0;
        for (final leg in legs) {
          final dur = (leg as Map<String, dynamic>)['duration'] as Map?;
          total += (dur?['value'] as num?)?.toDouble() ?? 0;
        }
        return total > 0 ? total : double.infinity;
      } catch (_) {
        return double.infinity;
      }
    }

    int pickFastestRouteIndex(List routes, {required bool requireMetroLeg}) {
      int bestIdx = -1;
      double bestDur = double.infinity;
      for (int i = 0; i < routes.length; i++) {
        final r = routes[i];
        if (r is! Map<String, dynamic>) continue;
        if (requireMetroLeg && !routeContainsMetroLeg(r)) continue;
        final dur = routeDurationSeconds(r);
        if (dur < bestDur) {
          bestDur = dur;
          bestIdx = i;
        }
      }
      return bestIdx;
    }

    void promoteRouteToFront(Map<String, dynamic> directions, int routeIndex) {
      if (routeIndex <= 0) return;
      final routes = directions['routes'];
      if (routes is! List || routeIndex >= routes.length) return;
      final picked = routes.removeAt(routeIndex);
      routes.insert(0, picked);
    }

    int nextServiceAnchorDepartureEpochSeconds() {
      // Conservative default: 09:00 local time (today if still ahead, else tomorrow).
      final now = DateTime.now();
      var anchor = DateTime(now.year, now.month, now.day, 9, 0);
      if (!anchor.isAfter(now)) {
        anchor = anchor.add(const Duration(days: 1));
      }
      return (anchor.millisecondsSinceEpoch / 1000).round();
    }

    if (!forceRefresh) {
      final cached = await RouteCache.get(
        origin: origin,
        destination: dest,
        mode: mode,
        transitVariant: transitMode ? 'rail' : null,
      );
      if (cached != null) {
        dev.log('Using RouteCache entry for $mode', name: 'DirectionService');
        _cachedDirections = cached.directions;
        _lastFetchTime = cached.timestamp;
      }
    }
    // Calculate the straight-line distance in meters.
    double straightDistance = Geolocator.distanceBetween(
      startLat,
      startLng,
      endLat,
      endLng,
    );

    // Determine the update interval.
    Duration updateInterval;
    if (isDistanceMode) {
      double thresholdMeters = threshold * 1000;
      if (straightDistance > 5 * thresholdMeters) {
        updateInterval = farInterval;
      } else if (straightDistance > 2 * thresholdMeters) {
        updateInterval = midInterval;
      } else {
        updateInterval = nearInterval;
      }
    } else {
      updateInterval = nearInterval;
    }

    // Return in-memory cached data if available, recent, AND for the same request.
    final requestKey = _makeRequestKey(
      origin: origin,
      destination: dest,
      mode: mode,
      transitVariant: transitMode ? 'rail' : null,
    );
    if (!forceRefresh &&
        _cachedDirections != null &&
        _lastFetchTime != null &&
        _cachedDirectionsKey == requestKey) {
      final elapsed = DateTime.now().difference(_lastFetchTime!);
      if (elapsed < updateInterval) {
        return _cachedDirections!;
      }
    }

    try {
      Map<String, dynamic> directions;
      String? transitVariant = transitMode ? 'rail' : null;
      int? departureTime;

      // 1) Primary request
      directions = await _apiClient.getDirections(
        origin: '$startLat,$startLng',
        destination: '$endLat,$endLng',
        mode: transitMode ? 'transit' : 'driving',
        transitMode: transitVariant,
      );

      final primaryOk =
          directions['status'] == 'OK' &&
          (directions['routes'] as List?) != null &&
          (directions['routes'] as List).isNotEmpty;

      bool primaryHasMetroRoute = false;
      if (primaryOk && transitMode) {
        final routes = directions['routes'] as List;
        final bestIdx = pickFastestRouteIndex(routes, requireMetroLeg: true);
        if (bestIdx >= 0) {
          primaryHasMetroRoute = true;
          promoteRouteToFront(directions, bestIdx);
        }
      }

      // 2) If user is in metro mode and Google returns no feasible route (often because
      // metro is currently closed), retry with a future departure_time to force a metro route.
      if (transitMode && preferMetroEvenIfClosed) {
        if (!primaryOk || !primaryHasMetroRoute) {
          transitVariant = 'subway';
          departureTime = nextServiceAnchorDepartureEpochSeconds();
          directions = await _apiClient.getDirections(
            origin: '$startLat,$startLng',
            destination: '$endLat,$endLng',
            mode: 'transit',
            transitMode: transitVariant,
            departureTime: departureTime,
          );

          // After fallback, select the fastest metro-containing route (if any)
          final ok =
              directions['status'] == 'OK' &&
              (directions['routes'] as List?) != null &&
              (directions['routes'] as List).isNotEmpty;
          if (ok) {
            final routes = directions['routes'] as List;
            final bestIdx = pickFastestRouteIndex(
              routes,
              requireMetroLeg: true,
            );
            if (bestIdx >= 0) {
              promoteRouteToFront(directions, bestIdx);
            } else {
              dev.log(
                'Metro mode: fallback still has no metro leg; using fastest available route',
                name: 'DirectionService',
              );
              final anyIdx = pickFastestRouteIndex(
                routes,
                requireMetroLeg: false,
              );
              if (anyIdx >= 0) {
                promoteRouteToFront(directions, anyIdx);
              }
            }
          }
        }
      }

      if (directions['status'] != 'OK' ||
          (directions['routes'] as List).isEmpty) {
        throw Exception(
          "No feasible route found: ${directions['error_message'] ?? directions['status']}",
        );
      }

      // --- Simplify & compress the overview polyline ---
      String? simplifiedCompressed;
      if (directions['routes'] != null && directions['routes'].isNotEmpty) {
        final route = directions['routes'][0];
        if (route['overview_polyline'] != null &&
            route['overview_polyline']['points'] != null) {
          final String encodedPolyline =
              route['overview_polyline']['points'] as String;
          // Decode + simplify with small in-memory cache
          final simplifiedPoints = _decodeAndProcessCached(
            encodedPolyline,
            10.0,
          );
          // Compress the simplified polyline.
          String compressedPolyline = PolylineSimplifier.compressPolyline(
            simplifiedPoints,
          );
          // Add the simplified compressed polyline to the response.
          route['simplified_polyline'] = compressedPolyline;
          simplifiedCompressed = compressedPolyline;
        }
      }

      _cachedDirections = directions;
      _lastFetchTime = DateTime.now();
      // Note: requestKey is used only for the in-memory fast path. The fallback path is
      // time-anchored, so we intentionally avoid returning it from the in-memory cache
      // for a non-time-anchored request.
      // Key in-memory cache by the actual request params used (time-anchored routes
      // must not be served for non-time-anchored requests).
      _cachedDirectionsKey = _makeRequestKey(
        origin: origin,
        destination: dest,
        mode: mode,
        transitVariant: transitVariant,
        departureTime: departureTime,
      );

      // Persist to RouteCache (L2)
      try {
        final key = RouteCache.makeKey(
          origin: origin,
          destination: dest,
          mode: mode,
          transitVariant: transitVariant,
          departureTime: departureTime,
        );
        final planned = _extractPlannedWindowEpochs(directions);
        await RouteCache.put(
          RouteCacheEntry(
            key: key,
            directions: directions,
            timestamp: _lastFetchTime!,
            origin: origin,
            destination: dest,
            mode: mode,
            simplifiedCompressedPolyline: simplifiedCompressed,
            plannedDepartureEpoch: planned.$1,
            plannedArrivalEpoch: planned.$2,
            schemaVersion: RouteCache.schemaVersion,
          ),
        );
      } catch (e) {
        dev.log('Failed to persist route cache: $e', name: 'DirectionService');
      }

      // Log route for reconstruction (when enabled)
      try {
        await RouteLogger.instance.logRoute(
          directions: directions,
          origin: origin,
          destination: dest,
          transitMode: transitMode,
          metadata: {
            'transitVariant': transitVariant,
            'departureTime': departureTime,
            'isDistanceMode': isDistanceMode,
            'threshold': threshold,
          },
        );
      } catch (e) {
        dev.log('Failed to log route: $e', name: 'DirectionService');
      }

      return directions;
    } catch (e) {
      final msg = e.toString();
      // COST LEAK #3: do NOT retry on ZERO_RESULTS or NO_FEASIBLE_ROUTE — these
      // are legitimate "no route" responses, not transient errors. Retrying
      // doubles the API cost for every unroutable destination.
      final isNoRoute = msg.contains('No feasible route') ||
          msg.contains('ZERO_RESULTS') ||
          msg.contains('NO_FEASIBLE_ROUTE');
      dev.log(
        "Error fetching directions via API client: $e",
        name: "DirectionService",
      );
      if (!forceRefresh && !isNoRoute) {
        dev.log("Retrying directions fetch...", name: "DirectionService");
        return getDirections(
          startLat,
          startLng,
          endLat,
          endLng,
          isDistanceMode: isDistanceMode,
          threshold: threshold,
          transitMode: transitMode,
          forceRefresh: true,
        );
      }
      rethrow;
    }
  }

  List<Map<String, dynamic>> buildRawSegments(
    Map<String, dynamic> directions,
    bool transitMode, {
    bool simplify = false,
  }) {
    List<Map<String, dynamic>> segments = [];
    var nextSegmentId = 0;
    if (directions['routes'] == null || directions['routes'].isEmpty) {
      return segments;
    }

    for (var leg in directions['routes'][0]['legs']) {
      List<dynamic> steps = leg['steps'];
      if (steps.isEmpty) continue;

      List<LatLng> groupPoints = [];
      String currentGroupType;
      // non_transit subtype to distinguish DRIVING vs WALKING for styling
      String?
      currentNonTransitMode; // 'DRIVING' | 'WALKING' | null when transit
      String? currentTransitLine;
      String? currentTransitLineId;
      Color? currentTransitLineColor;
      String? currentVehicleType;

      // Helper to process a step's mode info
      ModeInfo getModeInfo(dynamic s) {
        String mode = s['travel_mode'] as String? ?? 'DRIVING';
        bool isMetro = false;
        String? tLine;
        String? tLineId;
        Color? tLineColor;
        String? vType;
        if (mode == 'TRANSIT' && transitMode) {
          if (s.containsKey('transit_details') &&
              s['transit_details'] != null) {
            final td = (s['transit_details'] as Map).cast<String, dynamic>();
            final line = (td['line'] as Map?)?.cast<String, dynamic>();
            final vehicle =
                (line?['vehicle'] as Map?)?.cast<String, dynamic>();
            vType = vehicle?['type'] as String?;
            isMetro = const {
              'SUBWAY',
              'HEAVY_RAIL',
              'RAIL',
              'LIGHT_RAIL',
              'COMMUTER_TRAIN',
              'TRAM',
            }.contains(vType);
            if (isMetro) {
              tLine =
                  line?['short_name'] as String? ?? line?['name'] as String?;
              tLineId = line?['id'] as String?;
              final agency = (line?['agencies'] as List?)?.first;
              final agencyId =
                  agency is Map ? agency['id'] as String? : null;
              if (tLineId == null && (agencyId != null || tLine != null)) {
                tLineId = [if (agencyId != null) agencyId, tLine]
                    .whereType<String>()
                    .join(':');
              }
              tLineColor = _parseProviderColor(line?['color']);
            }
          }
        }
        return ModeInfo(mode, isMetro, tLine, vType, tLineId, tLineColor);
      }

      // Initialize first step
      var firstStep = steps[0];
      var firstInfo = getModeInfo(firstStep);

      if (firstInfo.isMetro) {
        currentGroupType = "transit";
        currentTransitLine = firstInfo.line;
        currentTransitLineId = firstInfo.lineId;
        currentTransitLineColor = firstInfo.lineColor;
      } else {
        currentGroupType = "non_transit";
        currentTransitLine = null;
        currentTransitLineId = null;
        currentTransitLineColor = null;
      }
      currentNonTransitMode = firstInfo.isMetro ? null : firstInfo.mode;
      currentVehicleType = firstInfo.vehicleType;

      // Decode, (maybe) simplify, then add first step points.
      List<LatLng> processedPoints = _decodeAndProcessCached(
        firstStep['polyline']['points'],
        simplify ? 10.0 : 0.0,
      );
      groupPoints.addAll(processedPoints);

      for (int i = 1; i < steps.length; i++) {
        var step = steps[i];
        var info = getModeInfo(step);

        String stepGroupType = info.isMetro ? "transit" : "non_transit";
        String? stepNonTransitMode = info.isMetro ? null : info.mode;

        bool sameGroup = false;
        if (currentGroupType == "non_transit" &&
            stepGroupType == "non_transit") {
          // keep grouping only if same non-transit mode
          sameGroup = (currentNonTransitMode == stepNonTransitMode);
        } else if (currentGroupType == "transit" &&
            stepGroupType == "transit") {
          sameGroup =
              currentTransitLineId != null && info.lineId != null
                  ? currentTransitLineId == info.lineId
                  : currentTransitLine == info.line;
        }

        if (sameGroup) {
          List<LatLng> stepPoints = _decodeAndProcessCached(
            step['polyline']['points'],
            simplify ? 10.0 : 0.0,
          );
          groupPoints.addAll(stepPoints);
        } else {
          // Finalize current segment
          segments.add({
            'segment_id': nextSegmentId++,
            'mode':
                currentGroupType == 'transit'
                    ? 'transit'
                    : currentNonTransitMode?.toLowerCase() ?? 'driving',
            'points':
                groupPoints
                    .map((p) => {'lat': p.latitude, 'lng': p.longitude})
                    .toList(),
            'transit_line': currentTransitLine,
            'transit_line_id': currentTransitLineId,
            'transit_line_color': currentTransitLineColor?.value,
            'vehicle_type': currentVehicleType,
          });

          // Start new segment
          groupPoints = [];
          currentGroupType = stepGroupType;
          currentTransitLine = info.line;
          currentTransitLineId = info.lineId;
          currentTransitLineColor = info.lineColor;
          currentNonTransitMode = stepNonTransitMode;
          currentVehicleType = info.vehicleType;

          List<LatLng> stepPoints = _decodeAndProcessCached(
            step['polyline']['points'],
            simplify ? 10.0 : 0.0,
          );
          groupPoints.addAll(stepPoints);
        }
      }

      if (groupPoints.isNotEmpty) {
        segments.add({
          'segment_id': nextSegmentId++,
          'mode':
              currentGroupType == 'transit'
                  ? 'transit'
                  : currentNonTransitMode?.toLowerCase() ?? 'driving',
          'points':
              groupPoints
                  .map((p) => {'lat': p.latitude, 'lng': p.longitude})
                  .toList(),
          'transit_line': currentTransitLine,
          'transit_line_id': currentTransitLineId,
          'transit_line_color': currentTransitLineColor?.value,
          'vehicle_type': currentVehicleType,
        });
      }
    }
    return segments;
  }

  List<Polyline> buildSegmentedPolylines(
    Map<String, dynamic> directions,
    bool transitMode, {
    bool simplify = false,
  }) {
    final rawSegments = buildRawSegments(
      directions,
      transitMode,
      simplify: simplify,
    );
    return buildSegmentedPolylinesFromRawSegments(rawSegments);
  }

  /// Build polylines from already-prepared raw segments.
  ///
  /// This is used by the simulation dashboard so it can render the exact same
  /// route styling as MapTrackingScreen without re-implementing the logic.
  List<Polyline> buildSegmentedPolylinesFromRawSegments(
    List<Map<String, dynamic>> rawSegments,
  ) {
    final polylines = <Polyline>[];

    for (int i = 0; i < rawSegments.length; i++) {
      final seg = rawSegments[i];
      final mode = seg['mode'] as String? ?? 'driving';
      final pointsData = (seg['points'] as List?) ?? const [];
      final points = pointsData.map((p) => LatLng(p['lat'], p['lng'])).toList();
      final transitLine = seg['transit_line'] as String?;
      final providerColorValue = seg['transit_line_color'];

      Color color;
      List<PatternItem> patterns = [];
      int zIndex = 2;

      if (mode == 'transit') {
        zIndex = 3;
        final providerColor = providerColorValue is num
              ? Color(providerColorValue.toInt())
              : null;
        if (providerColor != null) {
          // Google Transit's line color is authoritative for this route and
          // avoids ambiguous generic names such as "Blue Line" across cities.
          color = providerColor;
        } else if (transitLine != null) {
          // Attempt fast O(1) lookup
          Color? realColor;
          try {
            final c = _getLineColor(transitLine);
            if (c != Colors.indigo) realColor = c;
          } catch (_) {}

          if (realColor != null) {
            color = realColor;
          } else {
            // Never invent a line identity by cycling colours.  A generic
            // "Blue Line" is ambiguous across cities; neutral styling makes
            // that uncertainty visible instead of misleading the rider.
            color = Colors.blueGrey;
          }
        } else {
          // Safe fallback
          color = Colors.blueGrey;
        }
      } else {
        color = Colors.blue;
        if (mode == 'walking') {
          patterns = [PatternItem.dash(20), PatternItem.gap(12)];
        }
      }

      polylines.add(
        Polyline(
          polylineId: PolylineId('seg_${seg['segment_id'] ?? i}'),
          points: points,
          color: color,
          width: 5,
          patterns: patterns,
          zIndex: zIndex,
        ),
      );
    }

    return polylines;
  }

  String _normalizeLineName(String input) {
    try {
      var s = input.toLowerCase();
      s = s.replaceAll(RegExp(r'[^a-z0-9]'), '');
      return s;
    } catch (_) {
      return '';
    }
  }

  Color _getLineColor(String lineName) {
    try {
      final normalized = _normalizeLineName(lineName);

      // A bare "Blue Line" (or "Purple Line") is not a city identity.  Do
      // not silently apply the Delhi palette to a Mumbai/Chennai cached route
      // when the provider omitted its authoritative colour.  Only qualified
      // keys (city/operator/numbered metro) and genuinely unique names are
      // safe for an offline static fallback; otherwise the renderer uses the
      // neutral unknown-line colour.
      bool isSafeStaticKey(String key) {
        final lower = key.toLowerCase();
        return lower.contains('(') ||
            lower.contains('metro line') ||
            lower == 'rapid metro' ||
            lower == 'airport express';
      }

      // 1. Direct normalized match check
      for (final key in metroLineColors.keys) {
        if (!isSafeStaticKey(key)) continue;
        if (_normalizeLineName(key) == normalized) {
          return metroLineColors[key]!;
        }
      }

      // A generic input must not fuzzy-match a city-qualified key.
      if (!isSafeStaticKey(lineName)) return Colors.indigo;

      // 2. Fuzzy match (if input is substring of key or vice versa)
      for (final key in metroLineColors.keys) {
        if (!isSafeStaticKey(key)) continue;
        final normKey = _normalizeLineName(key);
        if (normKey.isNotEmpty &&
            (normKey.contains(normalized) || normalized.contains(normKey))) {
          return metroLineColors[key]!;
        }
      }

      return Colors.indigo;
    } catch (e) {
      return Colors.indigo;
    }
  }

  static Color? _parseProviderColor(Object? value) {
    if (value is! String) return null;
    var hex = value.trim().replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  // Decode an encoded polyline and optionally simplify it.
  // Cached keyed by md5 of input+tol.
  // If toleranceMeters <= 0, simplification is skipped.
  List<LatLng> _decodeAndProcessCached(String encoded, double toleranceMeters) {
    final key = _polyKey(encoded, toleranceMeters);
    final cached = _polylineSimplifyCache[key];
    if (cached != null) return cached;
    final decoded = decodePolyline(encoded);

    List<LatLng> result;
    if (toleranceMeters > 0) {
      result = PolylineSimplifier.simplifyPolyline(decoded, toleranceMeters);
    } else {
      result = decoded;
    }
    _polylineSimplifyCache[key] = result;
    return result;
  }

  String _polyKey(String encoded, double tol) {
    final bytes = utf8.encode('$tol|$encoded');
    final digest = crypto.md5.convert(bytes).toString();
    return '${encoded.length}:$digest';
  }

  /// G17: Extract the planned departure/arrival window (unix epoch seconds) from
  /// the first route's legs when the provider supplies scheduled transit times.
  /// Returns (departureEpoch, arrivalEpoch); either may be null for scheduleless
  /// or driving routes. Departure is the earliest leg's departure_time; arrival
  /// is the final leg's arrival_time.
  (int?, int?) _extractPlannedWindowEpochs(Map<String, dynamic> directions) {
    try {
      final legs = ((directions['routes'] as List).first
          as Map<String, dynamic>)['legs'] as List;
      int? departure;
      int? arrival;
      for (final legAny in legs) {
        final leg = legAny as Map<String, dynamic>;
        final dep =
            (leg['departure_time'] as Map<String, dynamic>?)?['value'] as num?;
        final arr =
            (leg['arrival_time'] as Map<String, dynamic>?)?['value'] as num?;
        if (dep != null) departure ??= dep.toInt();
        if (arr != null) arrival = arr.toInt();
      }
      return (departure, arrival);
    } catch (_) {
      return (null, null);
    }
  }
}

class ModeInfo {
  final String mode;
  final bool isMetro;
  final String? line;
  final String? vehicleType;
  final String? lineId;
  final Color? lineColor;

  ModeInfo(
    this.mode,
    this.isMetro,
    this.line,
    this.vehicleType,
    this.lineId,
    this.lineColor,
  );
}
