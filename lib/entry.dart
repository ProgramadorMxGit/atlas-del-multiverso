import 'package:flutter/material.dart';
import 'appearance.dart';
import 'motion.dart';
import 'atlas_data.dart';

class Entry extends StatefulWidget {
  const Entry({super.key, required this.onEnter});
  final Future<void> Function(String) onEnter;
  @override
  State<Entry> createState() => _EntryState();
}

class _EntryState extends State<Entry> {
  final controller = TextEditingController();
  String? error;
  bool busy = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> enter() async {
    if (busy) return;
    final phone = phoneKey(controller.text);
    if (phone == null) {
      setState(
        () => error =
            'Escribe los 10 dígitos de un celular mexicano con su lada.',
      );
      return;
    }
    setState(() => busy = true);
    try {
      await widget.onEnter(phone);
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'No se pudo abrir el cuaderno.';
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Mark(size: 90),
                const SizedBox(height: 34),
                const Text(
                  'Atlas del\nmultiverso',
                  style: TextStyle(
                    fontSize: 48,
                    height: 1.04,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Abre tu cuaderno de campo con tu número de celular.',
                  style: TextStyle(color: muted, fontSize: 17),
                ),
                const SizedBox(height: 32),
                Entrance(
                  start: .15,
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      if (error != null) setState(() => error = null);
                    },
                    onSubmitted: (_) => enter(),
                    decoration: InputDecoration(
                      labelText: 'Celular de México',
                      helperText: '10 dígitos con lada',
                      errorMaxLines: 3,
                      hintText: '833 123 4567',
                      errorText: error,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Entrance(
                  start: .25,
                  child: FilledButton.icon(
                    onPressed: busy ? null : enter,
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(busy ? 'Abriendo…' : 'Abrir cuaderno'),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Identificación local de demostración, sin SMS.',
                  style: TextStyle(color: muted),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
