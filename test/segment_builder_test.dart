import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:geowake2/services/direction_service.dart';

void main() {
  group('DirectionService Segment Builder', () {
    test('Should merge adjacent walking steps', () {
      final service = DirectionService();
      // Mock directions with 2 adjacent walking steps
      final directions = {
        'routes': [
          {
            'legs': [
              {
                'steps': [
                  {
                    'travel_mode': 'WALKING',
                    'html_instructions': 'Walk to A',
                    'polyline': {
                      'points': '}~gvH_~wW??_ibE_ibE',
                    }, // (0,0) to (0.01, 0.01)
                  },
                  {
                    'travel_mode': 'WALKING',
                    'html_instructions': 'Walk to B',
                    'polyline': {
                      'points': '_ibE_ibE??_ibE_ibE',
                    }, // (0.01, 0.01) to (0.02, 0.02)
                  },
                ],
              },
            ],
          },
        ],
      };

      final segments = service.buildRawSegments(directions, false);

      // Expect 1 merged segment
      expect(segments.length, 1);
      expect(segments[0]['mode'], 'walking');
      // Points should be roughly start, mid, end (simplification might reduce specific count but should be > 2 if simplified properly or just joined)
      // Note: Using a very short mock polyline might result in simplification to start/end only.
      // But critical check is segments.length == 1
    });

    test('Should separate transit steps correctly', () {
      final service = DirectionService();
      final directions = {
        'routes': [
          {
            'legs': [
              {
                'steps': [
                  {
                    'travel_mode': 'WALKING',
                    'html_instructions': 'Walk to Station',
                    'polyline': {'points': '}~gvH_~wW??_ibE_ibE'},
                  },
                  {
                    'travel_mode': 'TRANSIT',
                    'html_instructions': 'Take Subway',
                    'polyline': {'points': '_ibE_ibE??_{bP_{bP'},
                    'transit_details': {
                      'line': {
                        'short_name': 'L1',
                        'vehicle': {'type': 'SUBWAY'},
                      },
                    },
                  },
                  {
                    'travel_mode': 'WALKING',
                    'html_instructions': 'Walk to Dest',
                    'polyline': {'points': '_{bP_{bP??_{bP_{bP'},
                  },
                ],
              },
            ],
          },
        ],
      };

      final segments = service.buildRawSegments(directions, true);

      expect(segments.length, 3);
      expect(segments[0]['mode'], 'walking');
      expect(segments[1]['mode'], 'transit');
      expect(segments[1]['vehicle_type'], 'SUBWAY');
      expect(segments[1]['transit_line'], 'L1');
      expect(segments[2]['mode'], 'walking');
    });

    test('provider line color and stable segment id win over generic name', () {
      final service = DirectionService();
      final polylines = service.buildSegmentedPolylinesFromRawSegments([
        {
          'segment_id': 7,
          'mode': 'transit',
          'transit_line': 'Blue Line',
          'transit_line_color': 0xFF123456,
          'points': [
            {'lat': 12.0, 'lng': 77.0},
            {'lat': 12.001, 'lng': 77.0},
          ],
        },
      ]);

      expect(polylines.single.polylineId.value, 'seg_7');
      expect(polylines.single.color.value, 0xFF123456);
    });

    test('generic offline line names never borrow another city palette', () {
      final service = DirectionService();
      final polylines = service.buildSegmentedPolylinesFromRawSegments([
        {
          'segment_id': 8,
          'mode': 'transit',
          'transit_line': 'Blue Line',
          'points': [
            {'lat': 19.0, 'lng': 72.0},
            {'lat': 19.001, 'lng': 72.0},
          ],
        },
      ]);

      expect(polylines.single.color, Colors.blueGrey);
    });
  });
}
