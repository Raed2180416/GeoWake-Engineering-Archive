import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:geowake2/services/share/journey_share_models.dart';
import 'package:geowake2/services/share/live_share_backend.dart';

void main() {
  test('HTTP transport keeps read and write capabilities separated', () async {
    final requests = <http.BaseRequest>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'POST' && request.url.path == '/v1/share') {
        return http.Response(jsonEncode({'serverId': 'server-1'}), 200);
      }
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'id': 'server-1',
            'status': 'enRoute',
            'destLabel': 'MG Road',
            'gone': false,
          }),
          200,
        );
      }
      return http.Response('', 204);
    });
    final backend = HttpShareBackend(
      baseUrl: 'https://share.example',
      client: client,
    );
    const session = ShareSession(
      id: 'ride-1',
      mode: ShareMode.guardian,
      status: ShareStatus.enRoute,
      createdAtMs: 1,
      expiresAtMs: 9999999999999,
      readToken: 'read_capability_abcdefghijklmnopqrstuvwxyz123456',
      writeToken: 'write_capability_abcdefghijklmnopqrstuvwxyz12345',
    );

    expect(await backend.createShare(session), 'server-1');
    await backend.pushLocation(
      'server-1',
      ShareSnapshot(lat: 12.97, lng: 77.59, atMs: 2),
      writeToken: session.writeToken,
    );
    final view = await backend.getStatus(
      'server-1',
      readToken: session.readToken,
    );

    final create = requests[0] as http.Request;
    final createBody = jsonDecode(create.body) as Map<String, dynamic>;
    expect(create.headers.containsKey('authorization'), isFalse);
    expect(createBody['readToken'], session.readToken);
    expect(createBody['writeToken'], session.writeToken);

    final ping = requests[1] as http.Request;
    expect(ping.headers['authorization'], 'Bearer ${session.writeToken}');
    expect(
      ping.url.queryParameters,
      isEmpty,
      reason: 'write capabilities must never enter URLs',
    );

    final status = requests[2];
    expect(status.headers.containsKey('authorization'), isFalse);
    expect(status.url.queryParameters['t'], session.readToken);
    expect(view?.destLabel, 'MG Road');
  });
}
