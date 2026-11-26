import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:atlas/data/sqlite_notebook.dart';
import 'package:atlas/domain/notebook_repository.dart';
import 'package:atlas/domain/specimen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test(
    'Recupera una ficha tras reiniciar y aísla dos cuadernos con el mismo personaje',
    () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('atlas_test');
      final path = '${dir.path}/atlas.sqlite';
      Future<Database> open() => databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: SqliteNotebook.schema,
        ),
      );
      var db = await open();
      var book = SqliteNotebook(db);
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      const first = '528331111111', second = '528332222222';
      const person = Specimen(id: 1, name: 'Rick');
      await book.enter(first);
      await book.keep(first, person, null);
      expect((await book.missingPortraits(first, 0)).single.id, 1);
      expect(await book.missingPortraits(second, 0), isEmpty);
      await book.attach(first, 1, Uint8List.fromList([1, 2, 3]));
      await book.keep(first, person, null);
      await book.remember(first, DeskTab.saved, 'rick');
      await book.markDetail(first, person);
      await db.close();
      db = await open();
      book = SqliteNotebook(db);
      expect(await book.active(), first);
      expect((await book.saved(first)).single.name, 'Rick');
      expect(await book.photo(first, 1), [1, 2, 3]);
      expect(await book.missingPortraits(first, 0), isEmpty);
      expect((await book.workspace(first)).query, 'rick');
      expect(
        (await book.workspace(first)).lastDetail,
        isA<Specimen>().having((person) => person.name, 'name', 'Rick'),
      );
      await book.leave();
      expect(await book.active(), isNull);
      await book.enter(second);
      expect(await book.saved(second), isEmpty);
      expect((await book.workspace(second)).lastDetail, isNull);
      await book.keep(second, person, null);
      await book.forget(second, 1);
      expect((await book.saved(first)).single.id, 1);
    },
  );

  test(
    'Lee y vuelve a guardar fichas con el JSON de la versión anterior',
    () async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: SqliteNotebook.schema,
        ),
      );
      addTearDown(db.close);
      final book = SqliteNotebook(db);
      const phone = '528331111111';
      const url = 'https://example.org/avatar/1.jpeg';
      final legacy = jsonEncode({
        'id': 1,
        'name': 'Rick',
        'species': 'Human',
        'status': 'Alive',
        'image': url,
        'origin': {'name': 'Earth'},
        'location': {'name': 'Citadel'},
        'gender': 'Male',
        'type': 'Scientist',
        'episode': ['https://example.org/episode/9'],
      });
      await book.enter(phone);
      await db.update('workspace', {
        'tab': 1,
        'query': 'rick',
        'last_detail': legacy,
      });
      await db.insert('saved', {
        'phone': phone,
        'id': 1,
        'payload': legacy,
        'portrait': Uint8List.fromList([1]),
      });

      final workspace = await book.workspace(phone);
      final saved = (await book.saved(phone)).single;
      expect(workspace.tab, DeskTab.saved);
      expect(workspace.query, 'rick');
      expect(workspace.lastDetail?.episodeReferences, saved.episodeReferences);
      expect(saved.status, SpecimenStatus.alive);
      expect(saved.origin, 'Earth');
      expect(saved.location, 'Citadel');
      expect(saved.species, 'Human');
      expect(saved.gender, 'Male');
      expect(saved.type, 'Scientist');
      expect(saved.portraitUrl.toString(), url);
      expect(saved.episodes, ['9']);
      expect(await book.photo(phone, 1), [1]);

      await book.markDetail(phone, saved);
      final row = (await db.query('workspace')).single;
      final payload =
          jsonDecode(row['last_detail'] as String) as Map<String, dynamic>;
      expect(payload, jsonDecode(legacy));
    },
  );
}
