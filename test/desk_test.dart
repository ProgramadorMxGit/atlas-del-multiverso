import 'dart:async';
import 'dart:typed_data';
import 'package:atlas/application/desk_controller.dart';
import 'package:atlas/application/session_controller.dart';
import 'package:atlas/domain/catalog_repository.dart';
import 'package:atlas/domain/notebook_repository.dart';
import 'package:atlas/domain/specimen.dart';
import 'package:atlas/presentation/entry.dart';
import 'package:atlas/presentation/catalog.dart';
import 'package:atlas/presentation/details.dart';
import 'package:atlas/presentation/field_desk.dart';
import 'package:atlas/presentation/gate.dart';
import 'package:atlas/presentation/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Specimen record(int id, String name) => Specimen(
  id: id,
  name: name,
  species: 'Human',
  status: SpecimenStatus.alive,
  gender: 'Male',
  origin: 'Tierra',
  location: 'Tierra',
);

class MemoryBook extends Fake implements NotebookRepository {
  String? activePhone;
  final kept = <Specimen>[];
  final attached = <(String, int)>[];
  @override
  Future<void> keep(String phone, Specimen person, Uint8List? image) async {
    kept.add(person);
  }

  @override
  Future<String?> active() async => activePhone;

  @override
  Future<void> enter(String phone) async => activePhone = phone;

  @override
  Future<void> leave() async => activePhone = null;
  @override
  Future<Workspace> workspace(String phone) async => const Workspace();
  @override
  Future<List<Specimen>> saved(String phone) async => [...kept];
  @override
  Future<List<Specimen>> missingPortraits(String phone, int afterId) async =>
      [];
  @override
  Future<Uint8List?> photo(String phone, int id) async => null;
  @override
  Future<void> attach(String phone, int id, Uint8List bytes) async {
    attached.add((phone, id));
  }

  @override
  Future<void> remember(String phone, DeskTab tab, String query) async {}
  @override
  Future<void> markDetail(String phone, Specimen? person) async {}
}

class LocalApi extends Fake implements CatalogRepository {
  final calls = <(String, int, Completer<CatalogPage>)>[];
  @override
  Future<CatalogPage> search(String name, int page) {
    final done = Completer<CatalogPage>();
    calls.add((name, page, done));
    return done.future;
  }

  @override
  Future<Uint8List> portrait(Specimen p) async =>
      throw StateError('Sin retrato');
  @override
  void close() {}
}

class DelayedPortraitApi extends LocalApi {
  final image = Completer<Uint8List>();
  @override
  Future<Uint8List> portrait(Specimen person) => image.future;
}

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'Arranque frío y reanudación con movimiento reducido $reduced',
      (tester) async {
        final book = Completer<SessionController>();
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: Gate(openSession: () => book.future),
            ),
          ),
        );
        expect(find.byType(LaunchCover), findsOneWidget);
        final launchState = tester.state(find.byType(LaunchCover));
        await tester.pump(const Duration(milliseconds: 450));
        book.complete(
          SessionController(
            book: MemoryBook(),
            createCatalog: LocalApi.new,
            connectivity: () => const Stream.empty(),
          ),
        );
        await tester.pump();
        if (!reduced) {
          expect(find.byType(Entry), findsNothing);
          await tester.pump(const Duration(milliseconds: 850));
          await tester.pump();
          expect(tester.state(find.byType(LaunchCover)), same(launchState));
        }
        await tester.pumpAndSettle();
        expect(find.byType(Entry), findsOneWidget);
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pump();
        expect(find.byType(LaunchCover), findsNothing);
      },
    );
  }

  testWidgets('El acceso y el cambio de investigador usan la misma sesión', (
    tester,
  ) async {
    final book = MemoryBook();
    final api = LocalApi();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Gate(
            openSession: () async => SessionController(
              book: book,
              createCatalog: () => api,
              connectivity: () => const Stream.empty(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '+52 833 123 4567');
    await tester.tap(find.text('Abrir cuaderno'));
    await tester.pump();
    await tester.pump();
    api.calls.single.$3.complete((items: <Specimen>[], more: false));
    await tester.pumpAndSettle();
    expect(book.activePhone, '528331234567');
    expect(find.byType(FieldDesk), findsOneWidget);

    await tester.tap(find.byTooltip('Cambiar investigador'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cambiar'));
    await tester.pumpAndSettle();
    expect(book.activePhone, isNull);
    expect(find.byType(Entry), findsOneWidget);
  });

  testWidgets(
    'Las tarjetas entran en orden y un doble toque abre una sola ficha',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = LocalApi();
      await tester.pumpWidget(
        MaterialApp(
          home: FieldDesk(
            onLeave: () async {},
            createDesk: () => DeskController(
              book: MemoryBook(),
              phone: '528338498692',
              catalog: api,
              connectivity: const Stream.empty(),
            ),
          ),
        ),
      );
      await tester.pump();
      api.calls.first.$3.complete((
        items: List.generate(8, (i) => record(i + 1, 'Ficha ${i + 1}')),
        more: false,
      ));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      double alpha(int id) => tester
          .widget<FadeTransition>(find.byKey(ValueKey('reveal-$id')))
          .opacity
          .value;
      expect(alpha(1), greaterThan(alpha(2)));
      expect(alpha(4), 0);
      final tile = find.text('Ficha 1');
      await tester.tapAt(tester.getCenter(tile));
      await tester.tapAt(tester.getCenter(tile));
      await tester.pumpAndSettle();
      expect(find.byType(Details), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tile, findsOneWidget);
      expect(find.byType(Details), findsNothing);
    },
  );

  testWidgets(
    'Descarta resultados anteriores y recupera la página fallida al volver la red',
    (tester) async {
      final api = LocalApi(), book = MemoryBook();
      final network = StreamController<bool>.broadcast();
      addTearDown(network.close);
      await tester.pumpWidget(
        MaterialApp(
          home: FieldDesk(
            onLeave: () async {},
            createDesk: () => DeskController(
              book: book,
              phone: '528338498692',
              catalog: api,
              connectivity: network.stream,
            ),
          ),
        ),
      );
      await tester.pump();
      final initial = api.calls.single.$3;
      await tester.enterText(find.byType(TextField), 'Morty');
      await tester.pump(const Duration(milliseconds: 360));
      api.calls.last.$3.complete((
        items: [record(2, 'Morty Smith')],
        more: true,
      ));
      initial.complete((items: [record(1, 'Rick Sanchez')], more: false));
      await tester.pumpAndSettle();
      expect(find.text('Rick Sanchez'), findsNothing);
      final more = find.text('Cargar más');
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pump();
      expect(api.calls.last.$2, 2);
      api.calls.last.$3.completeError(StateError('Sin señal'));
      await tester.pumpAndSettle();
      expect(find.text('Morty Smith'), findsOneWidget);
      network.add(false);
      await tester.pump();
      network.add(true);
      await tester.pump();
      expect(api.calls.last.$2, 2);
      api.calls.last.$3.complete((
        items: [record(3, 'Morty Jr.')],
        more: false,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Morty Jr.'), findsOneWidget);
    },
  );

  testWidgets('Texto ampliado, nombres largos y movimiento reducido', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = LocalApi();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: FieldDesk(
            onLeave: () async {},
            createDesk: () => DeskController(
              book: MemoryBook(),
              phone: '528338498692',
              catalog: api,
              connectivity: const Stream.empty(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final person = record(7, 'Personaje con un nombre largo para el cuaderno');
    api.calls.first.$3.complete((
      items: [person, record(8, 'Otro personaje')],
      more: false,
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('reveal-7')), findsNothing);
    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    expect(
      (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      1,
    );
    final semantics = tester.getSemantics(
      find.bySemanticsLabel(RegExp('Personaje con un nombre largo')),
    );
    expect(semantics.label, contains(person.name));
  });

  testWidgets('Arrastrar termina el escalonamiento sin volver a iniciarlo', (
    tester,
  ) async {
    final api = LocalApi();
    await tester.pumpWidget(
      MaterialApp(
        home: FieldDesk(
          onLeave: () async {},
          createDesk: () => DeskController(
            book: MemoryBook(),
            phone: '528338498692',
            catalog: api,
            connectivity: const Stream.empty(),
          ),
        ),
      ),
    );
    await tester.pump();
    api.calls.first.$3.complete((
      items: List.generate(40, (i) => record(i + 1, 'Ficha ${i + 1}')),
      more: false,
    ));
    await tester.pump();
    await tester.pump();
    expect(
      tester.widget<CatalogTiles>(find.byType(CatalogTiles)).animate,
      isTrue,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CatalogTiles>(find.byType(CatalogTiles)).animate,
      isFalse,
    );
  });

  testWidgets(
    'Una descarga tardía conserva el cuaderno que inició el guardado',
    (tester) async {
      final first = MemoryBook(), second = MemoryBook();
      final api = DelayedPortraitApi(), nextApi = LocalApi();
      Widget desk(MemoryBook book, String phone, LocalApi source) =>
          MaterialApp(
            home: FieldDesk(
              key: ValueKey(phone),
              onLeave: () async {},
              createDesk: () => DeskController(
                book: book,
                phone: phone,
                catalog: source,
                connectivity: const Stream.empty(),
              ),
            ),
          );
      await tester.pumpWidget(desk(first, '528331234567', api));
      await tester.pump();
      api.calls.first.$3.complete((
        items: [record(1, 'Rick Sanchez')],
        more: false,
      ));
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.text('Rick Sanchez')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar en mi cuaderno'));
      await tester.pumpAndSettle();
      expect(first.kept.single.id, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pumpWidget(desk(second, '528112345678', nextApi));
      await tester.pump();
      nextApi.calls.first.$3.complete((items: <Specimen>[], more: false));
      api.image.complete(Uint8List.fromList([1]));
      await tester.pumpAndSettle();
      expect(first.attached, [('528331234567', 1)]);
      expect(second.attached, isEmpty);
      expect(second.kept, isEmpty);
    },
  );
}
