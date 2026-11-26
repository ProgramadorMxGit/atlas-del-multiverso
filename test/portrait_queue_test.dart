import 'dart:async';
import 'dart:typed_data';

import 'package:atlas/application/portrait_queue.dart';
import 'package:atlas/domain/catalog_repository.dart';
import 'package:atlas/domain/notebook_repository.dart';
import 'package:atlas/domain/specimen.dart';
import 'package:flutter_test/flutter_test.dart';

class PendingBook extends Fake implements NotebookRepository {
  final pending = const [
    Specimen(id: 1, name: 'Rick'),
    Specimen(id: 2, name: 'Morty'),
  ];
  final stored = <int>{};

  @override
  Future<List<Specimen>> missingPortraits(String phone, int afterId) async =>
      pending
          .where((person) => person.id > afterId && !stored.contains(person.id))
          .toList();

  @override
  Future<Uint8List?> photo(String phone, int id) async => null;

  @override
  Future<void> attach(String phone, int id, Uint8List bytes) async =>
      stored.add(id);
}

class PortraitSource extends Fake implements CatalogRepository {
  final firstAttempt = Completer<Uint8List?>();
  final requests = <int>[];

  @override
  Future<Uint8List?> portrait(Specimen person) async {
    requests.add(person.id);
    if (person.id == 1 && requests.length == 1) return firstAttempt.future;
    return Uint8List.fromList([person.id]);
  }
}

void main() {
  test(
    'Comparte la descarga activa y vuelve a intentar un retrato fallido',
    () async {
      final book = PendingBook();
      final catalog = PortraitSource();
      var online = false;
      final queue = PortraitQueue(
        book: book,
        catalog: catalog,
        phone: '528331111111',
        canDownload: () => online,
        onStored: () {},
      );

      await queue.drain();
      expect(catalog.requests, isEmpty);

      online = true;
      final first = queue.picture(book.pending.first, kept: true);
      expect(queue.picture(book.pending.first, kept: true), same(first));

      final drain = queue.drain();
      catalog.firstAttempt.complete(null);
      await drain;
      expect(catalog.requests, [1, 2]);
      expect(book.stored, {2});

      await queue.drain();
      expect(book.stored, {1, 2});
      expect(catalog.requests, [1, 2, 1]);
    },
  );
}
