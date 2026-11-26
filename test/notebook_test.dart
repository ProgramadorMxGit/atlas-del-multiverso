import 'dart:io';
import 'dart:typed_data';
import 'package:atlas/atlas_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test(
    'Recupera una ficha tras reiniciar y aísla dos cuadernos con el mismo personaje',
    () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('atlas_test');
      final path = '${dir.path}/atlas.sqlite';
      Future<Notebook> open() async => Notebook(
        await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(version: 1, onCreate: Notebook.schema),
        ),
      );
      var book = await open();
      addTearDown(() async {
        await book.db.close();
        await dir.delete(recursive: true);
      });
      const first = '528331111111', second = '528332222222';
      const person = Specimen({'id': 1, 'name': 'Rick'});
      await book.enter(first);
      await book.keep(first, person, null);
      expect((await book.missingPortraits(first, 0)).single.id, 1);
      expect(await book.missingPortraits(second, 0), isEmpty);
      await book.attach(first, 1, Uint8List.fromList([1, 2, 3]));
      await book.keep(first, person, null);
      await book.remember(first, 1, 'rick');
      await book.markDetail(first, person);
      await book.db.close();
      book = await open();
      expect(await book.active(), first);
      expect((await book.saved(first)).single.name, 'Rick');
      expect(await book.photo(first, 1), [1, 2, 3]);
      expect(await book.missingPortraits(first, 0), isEmpty);
      expect((await book.state(first))['query'], 'rick');
      expect((await book.state(first))['last_detail'], contains('Rick'));
      await book.leave();
      expect(await book.active(), isNull);
      await book.enter(second);
      expect(await book.saved(second), isEmpty);
      expect((await book.state(second))['last_detail'], isNull);
      await book.keep(second, person, null);
      await book.forget(second, 1);
      expect((await book.saved(first)).single.id, 1);
    },
  );
}
