import '../domain/mexico_phone.dart';
import '../domain/catalog_repository.dart';
import '../domain/notebook_repository.dart';
import 'desk_controller.dart';

class SessionController {
  SessionController({
    required NotebookRepository book,
    required CatalogRepository Function() createCatalog,
    required Stream<bool> Function() connectivity,
  }) : _book = book,
       _createCatalog = createCatalog,
       _connectivity = connectivity;

  final NotebookRepository _book;
  final CatalogRepository Function() _createCatalog;
  final Stream<bool> Function() _connectivity;
  String? _phone;
  String? get phone => _phone;

  Future<void> restore() async {
    _phone = await _book.active();
  }

  Future<void> enter(String input) async {
    final phone = phoneKey(input);
    if (phone == null) throw const FormatException('Celular mexicano inválido');
    await _book.enter(phone);
    _phone = phone;
  }

  Future<void> leave() async {
    await _book.leave();
    _phone = null;
  }

  DeskController deskFor(String phone) => DeskController(
    book: _book,
    catalog: _createCatalog(),
    phone: phone,
    connectivity: _connectivity(),
  );
}
