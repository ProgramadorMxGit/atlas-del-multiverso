import 'dart:async';
import 'dart:typed_data';

import '../domain/catalog_repository.dart';
import '../domain/notebook_repository.dart';
import '../domain/specimen.dart';

class PortraitQueue {
  PortraitQueue({
    required this.book,
    required this.catalog,
    required this.phone,
    required this.canDownload,
    required this.onStored,
  });

  final NotebookRepository book;
  final CatalogRepository catalog;
  final String phone;
  final bool Function() canDownload;
  final void Function() onStored;
  final _pictures = <int, Future<Uint8List?>>{};
  bool _draining = false;

  Future<Uint8List?> picture(Specimen person, {required bool kept}) {
    final cached = _pictures[person.id];
    if (cached != null) return cached;
    if (_pictures.length >= 60) _pictures.remove(_pictures.keys.first);
    final pending = _load(person, kept);
    _pictures[person.id] = pending;
    unawaited(
      pending.then((bytes) {
        if (bytes == null && identical(_pictures[person.id], pending)) {
          _pictures.remove(person.id);
        }
      }),
    );
    return pending;
  }

  Future<Uint8List?> _load(Specimen person, bool kept) async {
    try {
      if (kept) {
        final local = await book.photo(phone, person.id);
        if (local != null) return local;
      }
      return canDownload() ? await catalog.portrait(person) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> storeWhenReady(int id, Future<Uint8List?> picture) async {
    try {
      final bytes = await picture;
      if (bytes != null) await book.attach(phone, id, bytes);
    } catch (_) {
      // El retrato sigue en la cola si falla la descarga o la escritura.
    }
  }

  Future<void> drain() async {
    if (_draining) return;
    _draining = true;
    try {
      var afterId = 0;
      while (canDownload()) {
        final batch = await book.missingPortraits(phone, afterId);
        if (batch.isEmpty) return;
        for (final person in batch) {
          if (!canDownload()) return;
          afterId = person.id;
          final bytes = await picture(person, kept: true);
          if (bytes == null) continue;
          await book.attach(phone, person.id, bytes);
          onStored();
        }
      }
    } catch (_) {
      // SQLite conserva las filas pendientes para el siguiente intento.
    } finally {
      _draining = false;
    }
  }
}
