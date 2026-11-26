import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'appearance.dart';
import 'atlas_data.dart';
import 'details.dart';

class FieldDesk extends StatefulWidget {
  const FieldDesk({
    super.key,
    required this.book,
    required this.phone,
    required this.onLeave,
  });
  final Notebook book;
  final String phone;
  final Future<void> Function() onLeave;
  @override
  State<FieldDesk> createState() => _DeskState();
}

class _DeskState extends State<FieldDesk> with WidgetsBindingObserver {
  final api = AtlasApi(), query = TextEditingController();
  List<Specimen> results = [], saved = [];
  final images = <int, Future<Uint8List?>>{};
  int tab = 0, page = 1, generation = 0;
  bool more = false,
      loading = false,
      failed = false,
      ready = false,
      localError = false;
  Timer? timer;
  bool restoringPortraits = false;
  int portraitCursor = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    restore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    api.close();
    timer?.cancel();
    query.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ready &&
        tab == 0 &&
        failed &&
        !loading) {
      images.clear();
      search(next: results.isNotEmpty);
    }
  }

  Future<void> restore() async {
    try {
      final state = await widget.book.state(widget.phone);
      final kept = await widget.book.saved(widget.phone);
      if (!mounted) return;
      setState(() {
        saved = kept;
        tab = state['tab'] as int;
        query.text = state['query'] as String;
        ready = true;
        localError = false;
      });
      final last = state['last_detail'] as String?;
      if (tab == 0) unawaited(search());
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

  Future<void> search({bool next = false}) async {
    if (next && loading) return;
    final token = ++generation;
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
      final batch = await api.search(query.text.trim(), target);
      if (!mounted || token != generation) return;
      setState(() {
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
          failed = true;
        });
      }
    }
  }

  Future<void> restorePortraits() async {
    if (restoringPortraits) return;
    restoringPortraits = true;
    try {
      while (mounted) {
        final batch = await widget.book.missingPortraits(
          widget.phone,
          portraitCursor,
        );
        if (batch.isEmpty) {
          portraitCursor = 0;
          return;
        }
        for (final person in batch) {
          if (!mounted) return;
          portraitCursor = person.id;
          final bytes = await picture(person);
          if (bytes == null) return;
          await widget.book.attach(widget.phone, person.id, bytes);
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
    return images.putIfAbsent(person.id, () async {
      try {
        final local = await widget.book.photo(widget.phone, person.id);
        if (local != null) return local;
        final bytes = await api.portrait(person);
        await widget.book.attach(widget.phone, person.id, bytes);
        return bytes;
      } catch (_) {
        images.remove(person.id);
        return null;
      }
    });
  }

  Future<void> detail(Specimen person) async {
    try {
      await widget.book.markDetail(widget.phone, person);
    } catch (_) {
      notice('No se pudo recordar la ficha actual.');
    }
    if (!mounted) return;
    final image = picture(person);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Details(
          person: person,
          image: image,
          kept: saved.any((e) => e.id == person.id),
          toggle: (keep) async {
            if (keep) {
              await widget.book.keep(widget.phone, person, null);
              unawaited(
                image
                    .then((b) async {
                      if (b != null) {
                        await widget.book.attach(widget.phone, person.id, b);
                      }
                    })
                    .catchError((Object e) {}),
              );
            } else {
              await widget.book.forget(widget.phone, person.id);
            }
            final updated = await widget.book.saved(widget.phone);
            if (mounted) setState(() => saved = updated);
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
  }

  void changeTab(int value) {
    if (value == tab) return;
    timer?.cancel();
    generation++;
    setState(() {
      tab = value;
      loading = false;
    });
    remember();
    if (value == 0) search();
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
        title: const Text('Atlas Multiverso'),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CUADERNO  /  +${widget.phone}',
                          style: const TextStyle(
                            color: mint,
                            letterSpacing: 1.5,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tab == 0 ? 'Personajes' : 'Mis guardados',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1.4,
                          ),
                        ),
                        if (tab == 0) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: query,
                            onChanged: (_) {
                              timer?.cancel();
                              generation++;
                              setState(() {
                                results = [];
                                loading = true;
                                failed = false;
                                more = false;
                              });
                              remember();
                              timer = Timer(
                                const Duration(milliseconds: 350),
                                search,
                              );
                            },
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Buscar por nombre',
                              filled: true,
                              border: OutlineInputBorder(
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (tab == 0 && failed)
                    ListTile(
                      leading: const Icon(Icons.cloud_off_outlined),
                      title: Text(
                        results.isEmpty
                            ? 'Catálogo no disponible. Se muestran coincidencias guardadas.'
                            : 'No se pudo cargar la siguiente página.',
                      ),
                      trailing: IconButton(
                        tooltip: 'Reintentar',
                        onPressed: () {
                          images.clear();
                          search(next: results.isNotEmpty);
                        },
                        icon: const Icon(Icons.refresh),
                      ),
                    ),
                  if (tab == 0 && loading)
                    const LinearProgressIndicator(minHeight: 2),
                  Expanded(
                    child: items.isEmpty
                        ? Center(
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
                          )
                        : ListView.builder(
                            key: ValueKey(tab),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount:
                                items.length +
                                (tab == 0 && more && !failed ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (i == items.length) {
                                return TextButton(
                                  onPressed: loading
                                      ? null
                                      : () => search(next: true),
                                  child: const Text('Cargar más'),
                                );
                              }
                              final p = items[i];
                              return Card(
                                color: panel,
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => detail(p),
                                  child: Row(
                                    children: [
                                      Portrait(
                                        id: p.id,
                                        future: picture(p),
                                        size: 78,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 18,
                                              ),
                                            ),
                                            Text(
                                              '${p.species} · ${p.status}',
                                              style: const TextStyle(
                                                color: muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, size: 20),
                                      const SizedBox(width: 10),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
