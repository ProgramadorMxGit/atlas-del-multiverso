import 'dart:io';
import 'dart:typed_data';
import 'package:atlas/atlas_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('Celulares nacionales e internacionales se identifican sin red', () {
    for (final input in [
      '8338498692',
      '+528338498692',
      '52 (833) 849-8692',
      ' 833 849 8692 ',
    ]) {
      expect(phoneKey(input), '528338498692', reason: input);
    }
    for (final input in ['5512345678', '3312345678', '8112345678']) {
      expect(phoneKey(phoneKey(input)!), '52$input');
    }
    for (final input in [
      '1111234567',
      '0000000000',
      '833849869',
      '+1 8338498692',
      '+52 52 8338498692',
      '+5218338498692',
      '8338498692 ext 1',
      '833849869A',
      '+8338498692',
      '52+8338498692',
      '+52',
      '8001234567',
    ]) {
      expect(phoneKey(input), isNull, reason: input);
    }
  });

  for (final active in ['8338498692', '528338498692', '12345678']) {
    test('Actualiza cuadernos v1 con sesión $active', () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('atlas_upgrade');
      final file = '${dir.path}/atlas.sqlite';
      var db = await databaseFactoryFfi.openDatabase(
        file,
        options: OpenDatabaseOptions(version: 1, onCreate: Notebook.schema),
      );
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      const national = '8338498692',
          key = '528338498692',
          other = '528112345678';
      for (final id in [national, key, other, '12345678']) {
        await db.insert('workspace', {'phone': id, 'query': id});
      }
      await db.insert('session', {'phone': active, 'slot': 1});
      var book = Notebook(db);
      for (final id in [1, 2]) {
        await book.keep(
          national,
          Specimen({'id': id, 'name': 'N$id'}),
          Uint8List.fromList([id]),
        );
      }
      for (final id in [2, 3]) {
        await book.keep(key, Specimen({'id': id, 'name': 'I$id'}), null);
      }
      await book.keep(other, const Specimen({'id': 9, 'name': 'Otro'}), null);
      await db.close();
      db = await databaseFactoryFfi.openDatabase(
        file,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: Notebook.schema,
          onUpgrade: Notebook.upgrade,
        ),
      );
      book = Notebook(db);
      expect(await db.getVersion(), 2);
      expect(await book.active(), active == '12345678' ? null : key);
      expect(
        (await book.state(key))['query'],
        active == national ? national : key,
      );
      expect((await book.saved(key)).map((p) => p.id).toSet(), {1, 2, 3});
      expect(await book.photo(key, 2), [2]);
      expect(await book.saved(national), isEmpty);
      expect((await book.saved(other)).single.id, 9);
      expect((await book.state('12345678'))['query'], '12345678');
      await book.enter(national);
      expect(await book.active(), key);
    });
  }
}
