import 'package:flutter/material.dart';
import 'appearance.dart';
import 'atlas_data.dart';
import 'entry.dart';
import 'motion.dart';
import 'field_desk.dart';

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
    home: const Gate(),
  );
}

class Gate extends StatefulWidget {
  const Gate({super.key, this.openBook = Notebook.open});
  final Future<Notebook> Function() openBook;
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  Notebook? store;
  String? phone;
  bool failed = false, introFinished = false;
  @override
  void initState() {
    super.initState();
    boot();
  }

  Future<void> boot() async {
    try {
      final book = await widget.openBook();
      final current = await book.active();
      if (mounted) {
        setState(() {
          store = book;
          phone = current;
        });
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!introFinished || store == null && !failed) {
      return transition(
        LaunchCover(
          emblem: const Mark(size: 86),
          onFinished: () {
            if (!introFinished) setState(() => introFinished = true);
          },
        ),
      );
    }
    if (failed) {
      return Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () {
              setState(() => failed = false);
              boot();
            },
            child: const Text('Reintentar apertura del cuaderno'),
          ),
        ),
      );
    }
    final screen = phone == null
        ? Entry(
            onEnter: (number) async {
              await store!.enter(number);
              if (mounted) setState(() => phone = number);
            },
          )
        : FieldDesk(
            key: ValueKey(phone),
            book: store!,
            phone: phone!,
            onLeave: () async {
              await store!.leave();
              if (mounted) setState(() => phone = null);
            },
          );
    return transition(KeyedSubtree(key: const ValueKey('app'), child: screen));
  }

  Widget transition(Widget child) => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240),
    switchInCurve: Curves.easeOut,
    switchOutCurve: Curves.easeIn,
    layoutBuilder: (current, previous) => Stack(
      fit: StackFit.expand,
      children: [...previous, if (current != null) current],
    ),
    child: child,
  );
}
