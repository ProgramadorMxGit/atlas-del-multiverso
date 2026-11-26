import 'package:flutter/material.dart';
import 'appearance.dart';
import 'atlas_data.dart';
import 'entry.dart';
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
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  Notebook? store;
  String? phone;
  bool failed = false;
  @override
  void initState() {
    super.initState();
    boot();
  }

  Future<void> boot() async {
    try {
      final book = await Notebook.open();
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
    if (store == null) {
      return Scaffold(
        body: Center(
          child: failed
              ? TextButton(
                  onPressed: boot,
                  child: const Text('Reintentar apertura del cuaderno'),
                )
              : const Mark(size: 84),
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
    return TweenAnimationBuilder<double>(
      key: ValueKey(phone),
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: screen,
      builder: (_, value, child) => Transform.translate(
        offset: Offset(0, 8 * (1 - value)),
        child: Opacity(opacity: 0.75 + 0.25 * value, child: child),
      ),
    );
  }
}
