enum SpecimenStatus { alive, dead, unknown }

class Specimen {
  const Specimen({
    required this.id,
    required this.name,
    this.species = '',
    this.status = SpecimenStatus.unknown,
    this.portraitUrl,
    this.origin = '',
    this.location = '',
    this.gender = '',
    this.type = '',
    this.episodeReferences = const [],
  });

  final int id;
  final String name, species, origin, location, gender, type;
  final SpecimenStatus status;
  final Uri? portraitUrl;
  final List<String> episodeReferences;

  Iterable<String> get episodes =>
      episodeReferences.map((reference) => reference.split('/').last);
}
