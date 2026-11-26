import 'dart:typed_data';

import 'specimen.dart';

enum DeskTab { explore, saved }

class Workspace {
  const Workspace({
    this.tab = DeskTab.explore,
    this.query = '',
    this.lastDetail,
  });

  final DeskTab tab;
  final String query;
  final Specimen? lastDetail;
}

abstract interface class NotebookRepository {
  Future<String?> active();
  Future<void> enter(String phone);
  Future<void> leave();
  Future<Workspace> workspace(String phone);
  Future<void> remember(String phone, DeskTab tab, String query);
  Future<void> markDetail(String phone, Specimen? person);
  Future<List<Specimen>> saved(String phone);
  Future<List<Specimen>> missingPortraits(String phone, int afterId);
  Future<void> keep(String phone, Specimen person, Uint8List? image);
  Future<void> forget(String phone, int id);
  Future<Uint8List?> photo(String phone, int id);
  Future<void> attach(String phone, int id, Uint8List bytes);
}
