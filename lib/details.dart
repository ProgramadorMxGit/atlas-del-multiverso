import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'appearance.dart';
import 'atlas_data.dart';
import 'motion.dart';

class Portrait extends StatelessWidget {
  const Portrait({
    super.key,
    required this.id,
    required this.future,
    required this.size,
  });
  final int id;
  final Future<Uint8List?> future;
  final double size;
  @override
  Widget build(BuildContext context) => Hero(
    tag: 'portrait-$id',
    child: SizedBox.square(
      dimension: size,
      child: FutureBuilder<Uint8List?>(
        future: future,
        builder: (c, s) {
          final data = s.data;
          final blank = ColoredBox(
            color: const Color(0xff293e49),
            child: Center(
              child: Icon(Icons.person_outline, color: mint, size: size * .4),
            ),
          );
          return data == null
              ? blank
              : Image.memory(
                  data,
                  fit: BoxFit.cover,
                  frameBuilder: (context, child, frame, sync) {
                    if (sync || MediaQuery.disableAnimationsOf(context)) {
                      return child;
                    }
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        blank,
                        AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration: const Duration(milliseconds: 160),
                          child: child,
                        ),
                      ],
                    );
                  },
                  cacheWidth: 300,
                  errorBuilder: (_, __, ___) => blank,
                );
        },
      ),
    ),
  );
}

class Details extends StatefulWidget {
  const Details({
    super.key,
    required this.person,
    required this.image,
    required this.kept,
    required this.toggle,
  });
  final Specimen person;
  final Future<Uint8List?> image;
  final bool kept;
  final Future<void> Function(bool) toggle;
  @override
  State<Details> createState() => _DetailsState();
}

class _DetailsState extends State<Details> {
  late bool kept = widget.kept;
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final p = widget.person;
    return Scaffold(
      appBar: AppBar(title: Text('Ficha #${p.id}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Portrait(id: p.id, future: widget.image, size: 180),
              ),
            ),
            const SizedBox(height: 24),
            Entrance(
              child: Text(
                p.name,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      try {
                        await widget.toggle(!kept);
                        if (mounted) setState(() => kept = !kept);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'No se pudo actualizar el cuaderno.',
                              ),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              icon: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 170),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  kept ? Icons.bookmark : Icons.bookmark_add_outlined,
                  key: ValueKey(kept),
                ),
              ),
              label: Text(
                kept ? 'Quitar de guardados' : 'Guardar en mi cuaderno',
              ),
            ),
            const SizedBox(height: 18),
            Entrance(
              start: .2,
              child: Material(
                color: panel,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Column(
                    children: [
                      for (final field in {
                        'Estado': p.status,
                        'Especie': p.species,
                        'Origen': p.data['origin']['name'],
                        'Ubicación': p.data['location']['name'],
                        'Género': p.data['gender'],
                        if ((p.data['type'] as String).isNotEmpty)
                          'Tipo': p.data['type'],
                      }.entries)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            field.key,
                            style: const TextStyle(color: muted, fontSize: 13),
                          ),
                          subtitle: Text(
                            field.value.toString(),
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Episodios · ${p.episodes.length}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [for (final n in p.episodes) Chip(label: Text('#$n'))],
            ),
          ],
        ),
      ),
    );
  }
}
