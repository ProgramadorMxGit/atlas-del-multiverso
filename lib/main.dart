import 'package:flutter/material.dart';

import 'application/session_controller.dart';
import 'data/android_connectivity.dart';
import 'data/atlas_api.dart';
import 'data/sqlite_notebook.dart';
import 'presentation/appearance.dart';
import 'presentation/gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Atlas());
}

class Atlas extends StatelessWidget {
  const Atlas({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Atlas Multiverso',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: mint,
        brightness: Brightness.dark,
      ).copyWith(primary: mint, surface: ink),
      scaffoldBackgroundColor: ink,
      useMaterial3: true,
    ),
    home: const Gate(openSession: openAtlasSession),
  );
}

Future<SessionController> openAtlasSession() async => SessionController(
  book: await SqliteNotebook.open(),
  createCatalog: AtlasApi.new,
  connectivity: androidConnectivity,
);
