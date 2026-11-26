import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../domain/mexico_phone.dart';
import '../domain/notebook_repository.dart';
import '../domain/specimen.dart';
import 'specimen_record.dart';

class SqliteNotebook implements NotebookRepository {
  SqliteNotebook(this._db);
  final Database _db;

  static Future<SqliteNotebook> open() async {
    final path = '${await getDatabasesPath()}/atlas.sqlite';
    return SqliteNotebook(
      await openDatabase(
        path,
        version: 2,
        onCreate: schema,
        onUpgrade: upgrade,
      ),
    );
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

  static Future<void> upgrade(Database db, int from, int to) async {
    if (from >= 2) return;
    final session = await db.query('session');
    final active = session.firstOrNull?['phone'];
    final workspaces = await db.query('workspace');
    for (final workspace in workspaces) {
      final old = workspace['phone'] as String;
      final key = phoneKey(old);
      if (key == null || key == old) continue;
      await db.insert(
        'workspace',
        {...workspace, 'phone': key},
        conflictAlgorithm: old == active
            ? ConflictAlgorithm.replace
            : ConflictAlgorithm.ignore,
      );
      // Dos cuadernos antiguos pueden compartir la ficha y solo uno tener el retrato.
      await db.rawInsert(
        'INSERT OR IGNORE INTO saved(phone,id,payload,portrait) '
        'SELECT ?,id,payload,portrait FROM saved WHERE phone=? ORDER BY rowid',
        [key, old],
      );
      await db.rawUpdate(
        'UPDATE saved SET portrait=(SELECT alias.portrait FROM saved AS alias '
        'WHERE alias.phone=? AND alias.id=saved.id) WHERE phone=? AND portrait IS NULL',
        [old, key],
      );
      await db.delete('saved', where: 'phone=?', whereArgs: [old]);
      await db.delete('workspace', where: 'phone=?', whereArgs: [old]);
    }
    if (active is String) {
      final key = phoneKey(active);
      if (key == null) {
        await db.delete('session');
      } else {
        await db.update('session', {'phone': key});
      }
    }
  }

  @override
  Future<String?> active() async {
    final rows = await _db.query('session');
    return rows.isEmpty ? null : rows.first['phone'] as String;
  }

  @override
  Future<void> enter(String phone) => _db.transaction((txn) async {
    await txn.insert('workspace', {
      'phone': phone,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await txn.insert('session', {
      'slot': 1,
      'phone': phone,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });

  @override
  Future<void> markDetail(String phone, Specimen? person) async {
    await _db.update(
      'workspace',
      {
        'last_detail': person == null
            ? null
            : jsonEncode(SpecimenRecord.encode(person)),
      },
      where: 'phone=?',
      whereArgs: [phone],
    );
  }

  @override
  Future<void> leave() async {
    await _db.delete('session');
  }

  @override
  Future<Workspace> workspace(String phone) async {
    final row = (await _db.query(
      'workspace',
      where: 'phone=?',
      whereArgs: [phone],
    )).single;
    final detail = row['last_detail'] as String?;
    return Workspace(
      tab: row['tab'] == 1 ? DeskTab.saved : DeskTab.explore,
      query: row['query'] as String? ?? '',
      lastDetail: detail == null
          ? null
          : SpecimenRecord.decode(jsonDecode(detail)),
    );
  }

  @override
  Future<void> remember(String phone, DeskTab tab, String query) async {
    await _db.update(
      'workspace',
      {'tab': tab == DeskTab.saved ? 1 : 0, 'query': query},
      where: 'phone=?',
      whereArgs: [phone],
    );
  }

  @override
  Future<List<Specimen>> saved(String phone) async =>
      (await _db.query(
            'saved',
            columns: ['payload'],
            where: 'phone=?',
            whereArgs: [phone],
            orderBy: 'rowid DESC',
          ))
          .map((r) => SpecimenRecord.decode(jsonDecode(r['payload'] as String)))
          .toList();

  @override
  Future<List<Specimen>> missingPortraits(String phone, int afterId) async {
    final rows = await _db.query(
      'saved',
      columns: ['payload'],
      where: 'phone=? AND portrait IS NULL AND id>?',
      whereArgs: [phone, afterId],
      orderBy: 'id',
      limit: 8,
    );
    return rows
        .map(
          (row) => SpecimenRecord.decode(jsonDecode(row['payload'] as String)),
        )
        .toList();
  }

  @override
  Future<void> keep(String phone, Specimen person, Uint8List? image) async {
    await _db.insert('saved', {
      'phone': phone,
      'id': person.id,
      'payload': jsonEncode(SpecimenRecord.encode(person)),
      'portrait': image,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<void> forget(String phone, int id) async {
    await _db.delete(
      'saved',
      where: 'phone=? AND id=?',
      whereArgs: [phone, id],
    );
  }

  @override
  Future<Uint8List?> photo(String phone, int id) async {
    final rows = await _db.query(
      'saved',
      columns: ['portrait'],
      where: 'phone=? AND id=?',
      whereArgs: [phone, id],
    );
    return rows.isEmpty ? null : rows.first['portrait'] as Uint8List?;
  }

  @override
  Future<void> attach(String phone, int id, Uint8List bytes) async {
    await _db.update(
      'saved',
      {'portrait': bytes},
      where: 'phone=? AND id=? AND portrait IS NULL',
      whereArgs: [phone, id],
    );
  }
}
