import 'dart:async';
import 'dart:typed_data';

import '../domain/catalog_repository.dart';
import '../domain/notebook_repository.dart';
import '../domain/specimen.dart';
import 'portrait_queue.dart';

class DeskController {
  DeskController({
    required NotebookRepository book,
    required CatalogRepository catalog,
    required this.phone,
    required Stream<bool> connectivity,
  }) : _book = book,
       _catalog = catalog,
       _connectivity = connectivity;

  final NotebookRepository _book;
  final CatalogRepository _catalog;
  final Stream<bool> _connectivity;
  final String phone;
  final _changes = StreamController<void>.broadcast(sync: true);
  final _writeErrors = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  Stream<void> get writeErrors => _writeErrors.stream;
  StreamSubscription<bool>? _network;
  Timer? _debounce;
  bool _closed = false;
  bool? _online;
  int _generation = 0, _networkRevision = 0, _page = 1;
  late final _portraits = PortraitQueue(
    book: _book,
    catalog: _catalog,
    phone: phone,
    canDownload: () => !_closed && _online != false,
    onStored: () {
      if (_tab == DeskTab.saved) _notify();
    },
  );

  DeskTab _tab = DeskTab.explore;
  DeskTab get tab => _tab;
  String _query = '';
  String get query => _query;
  List<Specimen> _results = const [], _saved = const [];
  Set<int> _kept = const {};
  Set<int> get kept => _kept;
  bool _ready = false,
      _localError = false,
      _loading = false,
      _failed = false,
      _more = false;
  bool get ready => _ready;
  bool get localError => _localError;
  bool get loading => _loading;
  bool get failed => _failed;
  bool get more => _more;
  bool get hasResults => _results.isNotEmpty;
  List<Specimen> get items {
    if (_tab == DeskTab.saved) return _saved;
    if (!_failed || hasResults) return _results;
    final term = _query.trim().toLowerCase();
    return _saved
        .where((person) => person.name.toLowerCase().contains(term))
        .toList();
  }

  Future<Specimen?> restore() async {
    _network ??= _connectivity.listen((online) {
      if (_online == online) return;
      _online = online;
      _networkRevision++;
      if (online) recover();
    }, onError: (Object _) {});
    try {
      final workspace = await _book.workspace(phone);
      final people = await _book.saved(phone);
      if (_closed) return null;
      _tab = workspace.tab;
      _query = workspace.query;
      _setSaved(people);
      _ready = true;
      _localError = false;
      if (_tab == DeskTab.explore) {
        unawaited(_search());
      } else {
        _notify();
        unawaited(_portraits.drain());
      }
      return workspace.lastDetail;
    } catch (_) {
      _localError = true;
      _notify();
      return null;
    }
  }

  void recover() {
    if (_closed || !_ready) return;
    if (_tab == DeskTab.explore && _failed && !_loading) {
      unawaited(_search(next: hasResults));
    } else {
      _notify();
      unawaited(_portraits.drain());
    }
  }

  void updateQuery(String value) {
    _debounce?.cancel();
    _generation++;
    _query = value;
    _results = const [];
    _loading = true;
    _failed = false;
    _more = false;
    _notify();
    _remember();
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  void changeTab(DeskTab value) {
    if (value == _tab) return;
    _debounce?.cancel();
    _generation++;
    _tab = value;
    _loading = false;
    _remember();
    if (value == DeskTab.explore && (!hasResults || _failed)) {
      unawaited(_search(next: hasResults));
    } else {
      _notify();
    }
  }

  Future<void> loadMore() async {
    if (_tab == DeskTab.explore && _more && !_failed) await _search(next: true);
  }

  Future<void> retry() => _search(next: hasResults, manual: true);

  Future<void> _search({bool next = false, bool manual = false}) async {
    if (_closed || (next && _loading)) return;
    final token = ++_generation;
    final revision = _networkRevision;
    final target = next ? _page + 1 : 1;
    _loading = true;
    _failed = false;
    if (!next) {
      _results = const [];
      _more = false;
    }
    _notify();
    try {
      if (_online == false && !manual) throw StateError('Sin conexión');
      final batch = await _catalog.search(_query.trim(), target);
      if (_closed || token != _generation) return;
      if (revision == _networkRevision) _online = true;
      _results = List.unmodifiable([..._results, ...batch.items]);
      _page = target;
      _more = batch.more;
      _loading = false;
      _notify();
      unawaited(_portraits.drain());
    } catch (_) {
      if (_closed || token != _generation) return;
      _loading = false;
      _failed = true;
      _notify();
      if (revision != _networkRevision && _online == true) {
        unawaited(_search(next: next));
      }
    }
  }

  Future<Uint8List?> picture(Specimen person) =>
      _portraits.picture(person, kept: _kept.contains(person.id));

  Future<void> markDetail(Specimen? person) => _book.markDetail(phone, person);

  Future<void> toggleSaved(Specimen person, bool keep) async {
    if (keep) {
      await _book.keep(phone, person, null);
      unawaited(_portraits.storeWhenReady(person.id, picture(person)));
    } else {
      await _book.forget(phone, person.id);
    }
    if (_closed) return;
    if (keep && !_kept.contains(person.id)) {
      _setSaved([person, ..._saved]);
    } else if (!keep) {
      _setSaved(_saved.where((item) => item.id != person.id).toList());
    }
    _notify();
  }

  void _setSaved(List<Specimen> people) {
    _saved = List.unmodifiable(people);
    _kept = Set.unmodifiable(people.map((person) => person.id));
  }

  void _remember() {
    unawaited(
      _book.remember(phone, _tab, _query).catchError((Object _) {
        if (!_closed) _writeErrors.add(null);
      }),
    );
  }

  void _notify() {
    if (!_closed) _changes.add(null);
  }

  void close() {
    _closed = true;
    _debounce?.cancel();
    unawaited(_network?.cancel());
    _catalog.close();
    unawaited(_changes.close());
    unawaited(_writeErrors.close());
  }
}
