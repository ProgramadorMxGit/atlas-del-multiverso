import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'appearance.dart';
import 'catalog.dart';
import 'motion.dart';
import 'package:flutter/services.dart';
import 'atlas_data.dart';
import 'details.dart';

class FieldDesk extends StatefulWidget {
  const FieldDesk({
    super.key,
    required this.book,
    required this.phone,
    required this.onLeave,
    this.createApi = AtlasApi.new,
    this.networkEvents,
  });
  final AtlasApi Function() createApi;
  final Stream<bool>? networkEvents;
  final Notebook book;
  final String phone;
  final Future<void> Function() onLeave;
  @override
  State<FieldDesk> createState() => _DeskState();
}

class _DeskState extends State<FieldDesk> with WidgetsBindingObserver {
  late final api = widget.createApi();
  final query = TextEditingController();
  List<Specimen> results = [], saved = [];
  final images = <int, Future<Uint8List?>>{};
  Set<int> keptIds = {};
  void setSaved(List<Specimen> people) {
    saved = people;
    keptIds = people.map((p) => p.id).toSet();
  }

  int tab = 0, page = 1, generation = 0;
  bool more = false,
      loading = false,
      failed = false,
      ready = false,
      localError = false;
  Timer? timer;
  bool detailOpen = false;
  final revealed = <int>{};
  bool playTiles = false;
  void revealTiles() {
    playTiles = revealed.add(tab);
  }

  StreamSubscription<bool>? network;
  bool? online;
  int networkRevision = 0;
  void recover() {
    if (!mounted || !ready) return;
    if (tab == 0 && failed && !loading) {
      search(next: results.isNotEmpty);
    } else {
      setState(() {});
      unawaited(restorePortraits());
    }
  }

  bool restoringPortraits = false;
  int portraitCursor = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final events =
        widget.networkEvents ??
        const EventChannel(
          'dev.cartografia.atlas/network',
        ).receiveBroadcastStream().cast<bool>();
    network = events.listen((online) {
      if (this.online == online) return;
      this.online = online;
      networkRevision++;
      if (online) recover();
    }, onError: (Object _) {});
    restore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    network?.cancel();
    api.close();
    timer?.cancel();
    query.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) recover();
  }

  Future<void> restore() async {
    try {
      final state = await widget.book.state(widget.phone);
      final kept = await widget.book.saved(widget.phone);
      if (!mounted) return;
      setState(() {
        setSaved(kept);
        tab = state['tab'] as int;
        query.text = state['query'] as String;
        if (tab == 1 && saved.isNotEmpty) revealTiles();
        ready = true;
        localError = false;
      });
      final last = state['last_detail'] as String?;
      if (tab == 0) {
        unawaited(search());
      } else {
        unawaited(restorePortraits());
      }
      if (last != null) await detail(Specimen(jsonDecode(last)));
    } catch (_) {
      if (mounted) setState(() => localError = true);
    }
  }

  void remember() {
    widget.book.remember(widget.phone, tab, query.text).catchError((Object e) {
      notice('No se pudo guardar la vista actual.');
    });
  }

  void notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> search({bool next = false, bool manual = false}) async {
    if (next && loading) return;
    final token = ++generation;
    final revision = networkRevision;
    final target = next ? page + 1 : 1;
    setState(() {
      loading = true;
      failed = false;
      if (!next) {
        results = [];
        more = false;
      }
    });
    try {
      if (online == false && !manual) throw StateError("Sin conexión");
      final batch = await api.search(query.text.trim(), target);
      if (!mounted || token != generation) return;
      setState(() {
        if (revision == networkRevision) online = true;
        if (!next && batch.items.isNotEmpty) revealTiles();
        results = [...results, ...batch.items];
        page = target;
        more = batch.more;
        loading = false;
      });
      unawaited(restorePortraits());
    } catch (_) {
      if (mounted && token == generation) {
        setState(() {
          loading = false;
          if (results.isEmpty && saved.isNotEmpty) revealTiles();
          failed = true;
        });
        if (revision != networkRevision && online == true) {
          unawaited(search(next: next));
        }
      }
    }
  }

  Future<void> restorePortraits() async {
    if (restoringPortraits) return;
    restoringPortraits = true;
    try {
      while (mounted && online != false) {
        final batch = await widget.book.missingPortraits(
          widget.phone,
          portraitCursor,
        );
        if (batch.isEmpty) {
          portraitCursor = 0;
          return;
        }
        for (final person in batch) {
          if (!mounted || online == false) return;
          final bytes = await picture(person);
          portraitCursor = person.id;
          if (bytes == null) continue;
          await widget.book.attach(widget.phone, person.id, bytes);
          if (mounted && tab == 1) setState(() {});
        }
      }
    } catch (_) {
      // La fila sin retrato sigue pendiente si se interrumpe la lectura o la escritura.
    } finally {
      restoringPortraits = false;
    }
  }

  Future<Uint8List?> picture(Specimen person) {
    if (images.length >= 60 && !images.containsKey(person.id)) {
      images.remove(images.keys.first);
    }
    final cached = images[person.id];
    if (cached != null) return cached;
    final pending = loadPicture(person);
    images[person.id] = pending;
    pending.then((bytes) {
      if (bytes == null && identical(images[person.id], pending)) {
        images.remove(person.id);
      }
    });
    return pending;
  }

  Future<Uint8List?> loadPicture(Specimen person) async {
    try {
      if (keptIds.contains(person.id)) {
        final local = await widget.book.photo(widget.phone, person.id);
        if (local != null) return local;
      }
      if (!mounted || online == false) return null;
      return await api.portrait(person);
    } catch (_) {
      return null;
    }
  }

  Future<void> detail(Specimen person) async {
    if (detailOpen) return;
    detailOpen = true;
    try {
      await widget.book.markDetail(widget.phone, person);
    } catch (_) {
      notice('No se pudo recordar la ficha actual.');
    }
    if (!mounted) return;
    final image = picture(person);
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 310),
        reverseTransitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 210),
        transitionsBuilder: (_, animation, secondary, child) => FadeTransition(
          opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
          child: child,
        ),
        pageBuilder: (_, animation, secondary) => Details(
          person: person,
          image: image,
          kept: keptIds.contains(person.id),
          toggle: (keep) async {
            final book = widget.book, phone = widget.phone;
            if (keep) {
              await book.keep(phone, person, null);
              unawaited(
                image
                    .then((b) async {
                      if (b != null) {
                        await book.attach(phone, person.id, b);
                      }
                    })
                    .catchError((Object e) {}),
              );
            } else {
              await book.forget(phone, person.id);
            }
            final updated = await book.saved(phone);
            if (mounted) setState(() => setSaved(updated));
          },
        ),
      ),
    );
    if (mounted) {
      try {
        await widget.book.markDetail(widget.phone, null);
      } catch (_) {
        notice('No se pudo actualizar la vista guardada.');
      }
    }
    detailOpen = false;
  }

  void changeTab(int value) {
    if (value == tab) return;
    timer?.cancel();
    generation++;
    setState(() {
      tab = value;
      playTiles = false;
      if ((tab == 1 ? saved : results).isNotEmpty) revealTiles();
      loading = false;
    });
    remember();
    if (value == 0 && (results.isEmpty || failed)) {
      search(next: results.isNotEmpty);
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = saved
        .where(
          (p) => p.name.toLowerCase().contains(query.text.trim().toLowerCase()),
        )
        .toList();
    final items = tab == 1
        ? saved
        : failed && results.isEmpty
        ? local
        : results;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text(
          'Atlas del multiverso',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        leading: const Padding(padding: EdgeInsets.all(10), child: Mark()),
        actions: [
          IconButton(
            tooltip: 'Cambiar investigador',
            icon: const Icon(Icons.switch_account_outlined),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Cambiar investigador'),
                  content: Text(
                    'El cuaderno de +${widget.phone} quedará guardado en este dispositivo.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Cambiar'),
                    ),
                  ],
                ),
              );
              if (confirm == true && mounted) {
                try {
                  await widget.onLeave();
                } catch (_) {
                  notice('No se pudo cerrar el cuaderno.');
                }
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 68,
        animationDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 230),
        selectedIndex: tab,
        onDestinationSelected: ready ? changeTab : null,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.travel_explore),
            label: 'Explorar',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmarks_outlined),
            label: 'Guardados',
          ),
        ],
      ),
      body: !ready
          ? Center(
              child: localError
                  ? TextButton(
                      onPressed: restore,
                      child: const Text('Reintentar lectura local'),
                    )
                  : const CircularProgressIndicator(),
            )
          : SafeArea(
              child: NotificationListener<ScrollStartNotification>(
                onNotification: (event) {
                  if (playTiles && event.dragDetails != null) {
                    setState(() => playTiles = false);
                  }
                  return false;
                },
                child: CustomScrollView(
                  key: PageStorageKey('desk-$tab'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Entrance(
                              key: ValueKey(tab),
                              distance: 5,
                              child: Text(
                                tab == 0 ? 'Personajes' : 'Mis guardados',
                                style: const TextStyle(
                                  fontSize: 38,
                                  height: 1.1,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -1.7,
                                ),
                              ),
                            ),
                            if (tab == 0) ...[
                              const SizedBox(height: 16),
                              TextField(
                                controller: query,
                                textInputAction: TextInputAction.search,
                                onChanged: updateQuery,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    color: mint,
                                  ),
                                  suffixIcon: query.text.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Borrar búsqueda',
                                          icon: const Icon(Icons.close),
                                          onPressed: () {
                                            query.clear();
                                            updateQuery('');
                                          },
                                        ),
                                  hintText: 'Buscar por nombre',
                                  filled: true,
                                  fillColor: panel,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (tab == 0 && failed)
                      SliverToBoxAdapter(
                        child: ListTile(
                          leading: const Icon(Icons.cloud_off_outlined),
                          title: Text(
                            results.isEmpty
                                ? 'Catálogo no disponible. Se muestran fichas guardadas.'
                                : 'No se pudo cargar la siguiente página.',
                          ),
                          trailing: IconButton(
                            tooltip: 'Reintentar',
                            onPressed: () =>
                                search(next: results.isNotEmpty, manual: true),
                            icon: const Icon(Icons.refresh),
                          ),
                        ),
                      ),
                    if (tab == 0 && loading)
                      const SliverToBoxAdapter(
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    if (items.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              tab == 1
                                  ? 'Los personajes que guardes aparecerán aquí.'
                                  : loading
                                  ? 'Buscando personajes…'
                                  : failed
                                  ? 'Sin coincidencias en este cuaderno.'
                                  : 'No se encontraron personajes con ese nombre.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        sliver: CatalogTiles(
                          key: ValueKey(tab),
                          people: items,
                          kept: keptIds,
                          animate: playTiles,
                          picture: picture,
                          onOpen: detail,
                        ),
                      ),
                    if (tab == 0 && more && !failed)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: OutlinedButton(
                            onPressed: loading
                                ? null
                                : () => search(next: true),
                            child: const Text('Cargar más'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  void updateQuery(String value) {
    timer?.cancel();
    generation++;
    setState(() {
      results = [];
      loading = true;
      failed = false;
      more = false;
    });
    remember();
    timer = Timer(const Duration(milliseconds: 350), search);
  }
}
