import 'dart:typed_data';

import 'specimen.dart';

typedef CatalogPage = ({List<Specimen> items, bool more});

abstract interface class CatalogRepository {
  Future<CatalogPage> search(String name, int page);
  Future<Uint8List?> portrait(Specimen person);
  void close();
}
