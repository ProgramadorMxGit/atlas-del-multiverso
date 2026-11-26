import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../domain/catalog_repository.dart';
import '../domain/specimen.dart';
import 'specimen_record.dart';

class AtlasApi implements CatalogRepository {
  AtlasApi({Uri? endpoint})
    : endpoint =
          endpoint ?? Uri.https('rickandmortyapi.com', '/api/character/');
  final Uri endpoint;
  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 5);

  @override
  void close() => _client.close(force: true);

  Future<Uint8List> _get(Uri uri) async {
    final request = await _client
        .getUrl(uri)
        .timeout(const Duration(seconds: 6));
    try {
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      if (response.statusCode != 200) {
        await response.drain<void>().timeout(const Duration(seconds: 3));
        throw HttpException('${response.statusCode}', uri: uri);
      }
      final bytes = BytesBuilder(copy: false);
      await response.forEach(bytes.add).timeout(const Duration(seconds: 10));
      return bytes.takeBytes();
    } catch (_) {
      request.abort();
      rethrow;
    }
  }

  @override
  Future<CatalogPage> search(String name, int page) async {
    final uri = endpoint.replace(
      queryParameters: {
        if (name.isNotEmpty) 'name': name,
        'page': page.toString(),
      },
    );
    try {
      final json = jsonDecode(utf8.decode(await _get(uri)));
      return (
        items: (json['results'] as List)
            .map((v) => SpecimenRecord.decode(v as Map<String, dynamic>))
            .toList(),
        more: json['info']['next'] != null,
      );
    } on HttpException catch (e) {
      if (e.message == '404') return (items: <Specimen>[], more: false);
      rethrow;
    }
  }

  @override
  Future<Uint8List?> portrait(Specimen person) async {
    final uri = person.portraitUrl;
    return uri == null ? null : _get(uri);
  }
}
