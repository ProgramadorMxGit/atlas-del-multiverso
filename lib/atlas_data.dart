import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

String? phoneKey(String raw) {
  final value = raw.trim().replaceAll(RegExp(r'[ ()-]'), '');
  return RegExp(r'^\+?[1-9]\d{7,14}$').hasMatch(value)
      ? value.replaceFirst('+', '')
      : null;
}

class Specimen {
  const Specimen(this.data);
  final Map<String, dynamic> data;
  int get id => data['id'] as int;
  String get name => data['name'] as String;
  String get species => data['species'] as String;
  String get status => switch (data['status']) {
    'Alive' => 'Con vida',
    'Dead' => 'Sin vida',
    _ => 'Desconocido',
  };
  String get image => data['image'] as String;
  List<String> get episodes => (data['episode'] as List)
      .map((e) => e.toString().split('/').last)
      .toList();
}

class AtlasApi {
  AtlasApi({Uri? endpoint})
    : endpoint =
          endpoint ?? Uri.https('rickandmortyapi.com', '/api/character/');
  final Uri endpoint;
  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 5);

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

  Future<({List<Specimen> items, bool more})> search(
    String name,
    int page,
  ) async {
    final uri = endpoint.replace(
      queryParameters: {
        if (name.isNotEmpty) 'name': name,
        'page': page.toString(),
      },
    );
    try {
      final json = jsonDecode(utf8.decode(await _get(uri)));
      return (
        items: (json['results'] as List).map((v) => Specimen(v)).toList(),
        more: json['info']['next'] != null,
      );
    } on HttpException catch (e) {
      if (e.message == '404') return (items: <Specimen>[], more: false);
      rethrow;
    }
  }

  Future<Uint8List> portrait(Specimen person) => _get(Uri.parse(person.image));
}

class Notebook {
  Notebook(this.db);
  final Database db;

  static Future<Notebook> open() async {
    final path = '${await getDatabasesPath()}/atlas.sqlite';
    return Notebook(await openDatabase(path, version: 1, onCreate: schema));
  }

  static Future<void> schema(Database db, int _) async {
    await db.execute(
      'CREATE TABLE session(slot INTEGER PRIMARY KEY CHECK(slot=1), phone TEXT NOT NULL)',
    );
    await db.execute(
      "CREATE TABLE workspace(phone TEXT PRIMARY KEY, tab INTEGER DEFAULT 0, query TEXT DEFAULT '', last_detail TEXT)",
    );
    await db.execute(
      'CREATE TABLE saved(phone TEXT NOT NULL, id INTEGER NOT NULL, payload TEXT NOT NULL, portrait BLOB, PRIMARY KEY(phone,id))',
    );
  }

  Future<String?> active() async {
    final rows = await db.query('session');
    return rows.isEmpty ? null : rows.first['phone'] as String;
  }

  Future<void> enter(String phone) => db.transaction((txn) async {
    await txn.insert('workspace', {
      'phone': phone,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await txn.insert('session', {
      'slot': 1,
      'phone': phone,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });

  Future<void> markDetail(String phone, Specimen? person) async {
    await db.update(
      'workspace',
      {'last_detail': person == null ? null : jsonEncode(person.data)},
      where: 'phone=?',
      whereArgs: [phone],
    );
  }

  Future<void> leave() async {
    await db.delete('session');
  }

  Future<Map<String, Object?>> state(String phone) async => (await db.query(
    'workspace',
    where: 'phone=?',
    whereArgs: [phone],
  )).single;
  Future<void> remember(String phone, int tab, String query) async {
    await db.update(
      'workspace',
      {'tab': tab, 'query': query},
      where: 'phone=?',
      whereArgs: [phone],
    );
  }

  Future<List<Specimen>> saved(String phone) async => (await db.query(
    'saved',
    columns: ['payload'],
    where: 'phone=?',
    whereArgs: [phone],
    orderBy: 'rowid DESC',
  )).map((r) => Specimen(jsonDecode(r['payload'] as String))).toList();

  Future<void> keep(String phone, Specimen person, Uint8List? image) async {
    await db.insert('saved', {
      'phone': phone,
      'id': person.id,
      'payload': jsonEncode(person.data),
      'portrait': image,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> forget(String phone, int id) async {
    await db.delete('saved', where: 'phone=? AND id=?', whereArgs: [phone, id]);
  }

  Future<Uint8List?> photo(String phone, int id) async {
    final rows = await db.query(
      'saved',
      columns: ['portrait'],
      where: 'phone=? AND id=?',
      whereArgs: [phone, id],
    );
    return rows.isEmpty ? null : rows.first['portrait'] as Uint8List?;
  }

  Future<void> attach(String phone, int id, Uint8List bytes) async {
    await db.update(
      'saved',
      {'portrait': bytes},
      where: 'phone=? AND id=? AND portrait IS NULL',
      whereArgs: [phone, id],
    );
  }
}
