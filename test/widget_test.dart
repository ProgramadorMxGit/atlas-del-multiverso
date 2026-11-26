import 'package:atlas/atlas_data.dart';
import 'package:atlas/entry.dart';
import 'package:atlas/details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Normaliza un celular y rechaza extensiones o texto', () {
    expect(phoneKey('+52 (833) 123-4567'), '528331234567');
    expect(phoneKey('528331234567'), '528331234567');
    expect(phoneKey('833 xy'), isNull);
    expect(phoneKey(''), isNull);
  });
  testWidgets('El acceso mantiene el formulario ante un número incompleto', (
    tester,
  ) async {
    String? received;
    await tester.pumpWidget(
      MaterialApp(
        home: Entry(
          onEnter: (p) async {
            received = p;
          },
        ),
      ),
    );
    await tester.tap(find.text('Abrir cuaderno'));
    await tester.pump();
    expect(received, isNull);
    expect(find.textContaining('8 y 15'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '+52 833 123 4567');
    await tester.tap(find.text('Abrir cuaderno'));
    expect(received, '528331234567');
  });
  testWidgets('Guarda una ficha aunque falte su retrato', (tester) async {
    bool? value;
    const person = Specimen({
      'id': 1,
      'name': 'Rick Sánchez',
      'species': 'Human',
      'status': 'Alive',
      'type': '',
      'gender': 'Male',
      'origin': {'name': 'Earth'},
      'location': {'name': 'Citadel'},
      'episode': ['https://example.org/episode/1'],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Details(
          person: person,
          image: Future.value(null),
          kept: false,
          toggle: (v) async {
            value = v;
          },
        ),
      ),
    );
    await tester.tap(find.text('Guardar en mi cuaderno'));
    await tester.pumpAndSettle();
    expect(value, true);
    expect(find.text('Quitar de guardados'), findsOneWidget);
  });
}
