import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/screens/otherimpservices/recent_locations_service.dart';
import 'package:hive/hive.dart';

void main() {
  setUp(() async {
    if (Hive.isBoxOpen(RecentLocationsService.boxName)) {
      await Hive.box(RecentLocationsService.boxName).clear();
    } else {
      await Hive.deleteBoxFromDisk(RecentLocationsService.boxName);
    }
    await Hive.deleteBoxFromDisk(
      RecentLocationsService.legacyRouteMemoryBoxName,
    );
  });

  test('persists destination fields only and strips route metadata', () async {
    await RecentLocationsService.saveRecentLocations([
      {
        'description': 'Museum',
        'place_id': 'museum-1',
        'lat': 12.97,
        'lng': 77.59,
        'originLat': 12.90,
        'originLng': 77.50,
        'alarmMode': 'stops',
        'alarmValue': 4,
        'metroMode': true,
        'directions': {'routes': []},
      },
    ]);

    final stored = await RecentLocationsService.getRecentLocations();
    expect(stored, hasLength(1));
    expect(stored.single.keys.toSet(), {
      'description',
      'place_id',
      'lat',
      'lng',
    });
  });

  test('deduplicates and caps destination history at ten', () async {
    final destinations = List.generate(
      12,
      (i) => <String, dynamic>{
        'description': 'Destination $i',
        'place_id': 'place-$i',
        'lat': 12.0 + i,
        'lng': 77.0 + i,
      },
    );
    destinations.insert(1, Map<String, dynamic>.from(destinations.first));

    await RecentLocationsService.saveRecentLocations(destinations);
    final stored = await RecentLocationsService.getRecentLocations();

    expect(stored, hasLength(RecentLocationsService.maxItems));
    expect(
      stored.map(RecentLocationsService.destinationId).toSet(),
      hasLength(RecentLocationsService.maxItems),
    );
  });

  test('purges the obsolete automatic route-memory box', () async {
    final legacy = await Hive.openBox<String>(
      RecentLocationsService.legacyRouteMemoryBoxName,
    );
    await legacy.put('routes', 'sensitive old route state');
    await legacy.close();

    await RecentLocationsService.purgeLegacyRouteMemory();

    expect(
      await Hive.boxExists(RecentLocationsService.legacyRouteMemoryBoxName),
      isFalse,
    );
  });
}
