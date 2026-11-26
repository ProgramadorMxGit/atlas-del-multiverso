import 'dart:convert';
import 'dart:io';
import 'package:atlas/data/atlas_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Codifica el filtro, pagina y distingue 404 de una caída', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final api = AtlasApi(
      endpoint: Uri.http('127.0.0.1:${server.port}', '/api/character/'),
    );
    addTearDown(() async {
      api.close();
      await server.close(force: true);
    });
    final requests = <Uri>[];
    server.listen((req) async {
      requests.add(req.uri);
      switch (req.uri.queryParameters['name']) {
        case 'Nadie':
          req.response.statusCode = 404;
        case 'error':
          req.response.statusCode = 503;
        default:
          req.response.write(
            jsonEncode({
              'info': {'next': 'page=3'},
              'results': [
                {'id': 1, 'name': 'Rick'},
              ],
            }),
          );
      }
      await req.response.close();
    });
    final result = await api.search('Rick & Morty', 2);
    expect(result.items.single.name, 'Rick');
    expect(result.more, true);
    expect(requests.single.queryParameters, {
      'name': 'Rick & Morty',
      'page': '2',
    });
    expect((await api.search('Nadie', 1)).items, isEmpty);
    await expectLater(api.search('error', 1), throwsA(isA<HttpException>()));
  });
}
