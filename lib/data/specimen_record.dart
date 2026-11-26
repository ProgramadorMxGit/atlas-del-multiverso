import '../domain/specimen.dart';

abstract final class SpecimenRecord {
  static Specimen decode(Map<String, dynamic> json) {
    final image = json['image'] as String? ?? '';
    return Specimen(
      id: json['id'] as int,
      name: json['name'] as String,
      species: json['species'] as String? ?? '',
      status: switch (json['status']) {
        'Alive' => SpecimenStatus.alive,
        'Dead' => SpecimenStatus.dead,
        _ => SpecimenStatus.unknown,
      },
      portraitUrl: image.isEmpty ? null : Uri.tryParse(image),
      origin: json['origin']?['name'] as String? ?? '',
      location: json['location']?['name'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      type: json['type'] as String? ?? '',
      episodeReferences: List.unmodifiable(
        (json['episode'] as List? ?? const []).cast<String>(),
      ),
    );
  }

  // Conserva las claves de las fichas que ya existen en SQLite.
  static Map<String, Object?> encode(Specimen person) => {
    'id': person.id,
    'name': person.name,
    'species': person.species,
    'status': switch (person.status) {
      SpecimenStatus.alive => 'Alive',
      SpecimenStatus.dead => 'Dead',
      SpecimenStatus.unknown => 'unknown',
    },
    'image': person.portraitUrl?.toString() ?? '',
    'origin': {'name': person.origin},
    'location': {'name': person.location},
    'gender': person.gender,
    'type': person.type,
    'episode': person.episodeReferences,
  };
}
