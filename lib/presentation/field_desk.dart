import 'dart:async';

import 'package:flutter/material.dart';

import '../application/desk_controller.dart';
import '../domain/notebook_repository.dart';
import '../domain/specimen.dart';
import 'appearance.dart';
import 'catalog.dart';
import 'details.dart';
import 'motion.dart';

class FieldDesk extends StatefulWidget {
  const FieldDesk({super.key, required this.createDesk, required this.onLeave});

  final DeskController Function() createDesk;
  final Future<void> Function() onLeave;

  @override
  State<FieldDesk> createState() => _DeskState();
}

class _DeskState extends State<FieldDesk> with WidgetsBindingObserver {
  late final desk = widget.createDesk();
  final query = TextEditingController();
  final revealed = <DeskTab>{};
  late final StreamSubscription<void> changes, writeErrors;
  DeskTab? displayedTab;
  bool playTiles = false;
  bool detailOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    changes = desk.changes.listen((_) {
      if (!mounted) return;
      if (query.text != desk.query) query.text = desk.query;
      setState(() {
        if (displayedTab != desk.tab) {
          displayedTab = desk.tab;
          playTiles = false;
        }
        if (desk.items.isNotEmpty && revealed.add(desk.tab)) playTiles = true;
      });
    });
    writeErrors = desk.writeErrors.listen(
      (_) => notice('No se pudo guardar la vista actual.'),
    );
    unawaited(restore());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(changes.cancel());
    unawaited(writeErrors.cancel());
    desk.close();
    query.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) desk.recover();
  }

  Future<void> restore() async {
    final last = await desk.restore();
    if (mounted && last != null) await detail(last);
  }

  void notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> detail(Specimen person) async {
    if (detailOpen) return;
    detailOpen = true;
    try {
      await desk.markDetail(person);
    } catch (_) {
      notice('No se pudo recordar la ficha actual.');
    }
    if (!mounted) return;
    final image = desk.picture(person);
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
          kept: desk.kept.contains(person.id),
          toggle: (keep) => desk.toggleSaved(person, keep),
        ),
      ),
    );
    if (mounted) {
      try {
        await desk.markDetail(null);
      } catch (_) {
        notice('No se pudo actualizar la vista guardada.');
      }
    }
    detailOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final tab = desk.tab;
    final exploring = tab == DeskTab.explore;
    final items = desk.items;
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
                    'El cuaderno de +${desk.phone} quedará guardado en este dispositivo.',
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
        selectedIndex: tab.index,
        onDestinationSelected: desk.ready
            ? (index) => desk.changeTab(DeskTab.values[index])
            : null,
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
      body: !desk.ready
          ? Center(
              child: desk.localError
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
                                exploring ? 'Personajes' : 'Mis guardados',
                                style: const TextStyle(
                                  fontSize: 38,
                                  height: 1.1,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -1.7,
                                ),
                              ),
                            ),
                            if (exploring) ...[
                              const SizedBox(height: 16),
                              TextField(
                                controller: query,
                                textInputAction: TextInputAction.search,
                                onChanged: desk.updateQuery,
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
                                            desk.updateQuery('');
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
                    if (exploring && desk.failed)
                      SliverToBoxAdapter(
                        child: ListTile(
                          leading: const Icon(Icons.cloud_off_outlined),
                          title: Text(
                            !desk.hasResults
                                ? 'Catálogo no disponible. Se muestran fichas guardadas.'
                                : 'No se pudo cargar la siguiente página.',
                          ),
                          trailing: IconButton(
                            tooltip: 'Reintentar',
                            onPressed: desk.retry,
                            icon: const Icon(Icons.refresh),
                          ),
                        ),
                      ),
                    if (exploring && desk.loading)
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
                              !exploring
                                  ? 'Los personajes que guardes aparecerán aquí.'
                                  : desk.loading
                                  ? 'Buscando personajes…'
                                  : desk.failed
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
                          kept: desk.kept,
                          animate: playTiles,
                          picture: desk.picture,
                          onOpen: detail,
                        ),
                      ),
                    if (exploring && desk.more && !desk.failed)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: OutlinedButton(
                            onPressed: desk.loading ? null : desk.loadMore,
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
}
