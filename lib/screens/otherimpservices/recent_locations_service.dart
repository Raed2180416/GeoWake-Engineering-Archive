import 'dart:developer' as dev;

import 'package:hive_flutter/hive_flutter.dart';

/// Destination-only recent history.
///
/// No origin, route geometry, travel mode, alarm threshold, or frequency data
/// crosses this storage boundary. Routes are always resolved for the rider's
/// current position when they arm a new journey.
class RecentLocationsService {
  static const String boxName = 'recent_locations';
  static const String legacyRouteMemoryBoxName = 'route_memory_v1';
  static const int maxItems = 10;

  static Box? _box;
  static Future<void>? _opening;

  static String destinationId(Map<String, dynamic> location) {
    final placeId = location['place_id'] ?? location['placeId'];
    if (placeId != null && placeId.toString().trim().isNotEmpty) {
      return placeId.toString().trim();
    }
    return '${location['lat']},${location['lng']}';
  }

  static Map<String, dynamic> _destinationOnly(Map<dynamic, dynamic> input) {
    final location = Map<String, dynamic>.from(input);
    final result = <String, dynamic>{
      'description': (location['description'] ?? '').toString(),
      'lat': location['lat'],
      'lng': location['lng'],
    };
    final placeId = location['place_id'] ?? location['placeId'];
    if (placeId != null && placeId.toString().trim().isNotEmpty) {
      result['place_id'] = placeId.toString().trim();
    }
    return result;
  }

  static Future<void> _ensureBoxIsOpen() async {
    if (_box != null && _box!.isOpen) return;
    if (_opening != null) return _opening;
    _opening = () async {
      try {
        _box = await Hive.openBox(boxName);
      } catch (e) {
        dev.log(
          'Error opening recent destinations; recreating: $e',
          name: 'RecentLocationsService',
        );
        await Hive.deleteBoxFromDisk(boxName);
        _box = await Hive.openBox(boxName);
      }
    }();
    try {
      await _opening;
    } finally {
      _opening = null;
    }
  }

  static Future<List<Map<String, dynamic>>> getRecentLocations() async {
    try {
      await _ensureBoxIsOpen();
      final storedData = _box!.get('locations');
      if (storedData is! List) return [];

      final seen = <String>{};
      final result = <Map<String, dynamic>>[];
      for (final raw in storedData.whereType<Map>()) {
        final destination = _destinationOnly(raw);
        if (destination['lat'] == null || destination['lng'] == null) continue;
        if (seen.add(destinationId(destination))) result.add(destination);
        if (result.length == maxItems) break;
      }

      // Rewrite through the whitelist so legacy extra fields are removed from
      // disk, not merely hidden from callers.
      await _box!.put('locations', result);
      return result;
    } catch (e) {
      dev.log(
        'Error getting recent destinations: $e',
        name: 'RecentLocationsService',
      );
      return [];
    }
  }

  static Future<void> saveRecentLocations(
    List<Map<String, dynamic>> locations,
  ) async {
    try {
      await _ensureBoxIsOpen();
      final seen = <String>{};
      final destinations = <Map<String, dynamic>>[];
      for (final raw in locations) {
        final destination = _destinationOnly(raw);
        if (destination['lat'] == null || destination['lng'] == null) continue;
        if (seen.add(destinationId(destination))) destinations.add(destination);
        if (destinations.length == maxItems) break;
      }
      await _box!.put('locations', destinations);
    } catch (e) {
      dev.log(
        'Error saving recent destinations: $e',
        name: 'RecentLocationsService',
      );
    }
  }

  /// Earlier builds recorded automatic trip metadata in a separate Hive box.
  /// Purge it during home initialization now that the product remembers only
  /// destinations.
  static Future<void> purgeLegacyRouteMemory() async {
    try {
      if (Hive.isBoxOpen(legacyRouteMemoryBoxName)) {
        await Hive.box(legacyRouteMemoryBoxName).close();
      }
      await Hive.deleteBoxFromDisk(legacyRouteMemoryBoxName);
    } catch (e) {
      dev.log(
        'Could not purge legacy route memory: $e',
        name: 'RecentLocationsService',
      );
    }
  }
}
