import '../domain/specimen.dart';

extension StatusLabel on SpecimenStatus {
  String get label => switch (this) {
    SpecimenStatus.alive => 'Con vida',
    SpecimenStatus.dead => 'Sin vida',
    SpecimenStatus.unknown => 'Desconocido',
  };
}
