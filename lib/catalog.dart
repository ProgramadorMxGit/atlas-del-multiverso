import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'appearance.dart';
import 'atlas_data.dart';
import 'details.dart';

class CatalogTiles extends StatefulWidget {
  const CatalogTiles({
    super.key,
    required this.people,
    required this.kept,
    required this.picture,
    required this.onOpen,
    required this.animate,
  });
  final List<Specimen> people;
  final Set<int> kept;
  final Future<Uint8List?> Function(Specimen) picture;
  final ValueChanged<Specimen> onOpen;
  final bool animate;
  @override
  State<CatalogTiles> createState() => _CatalogTilesState();
}

class _CatalogTilesState extends State<CatalogTiles>
    with SingleTickerProviderStateMixin {
  late final entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      entrance.value = 1;
    } else if (entrance.isDismissed) {
      entrance.forward();
    }
  }

  @override
  void didUpdateWidget(CatalogTiles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.animate && !entrance.isCompleted) entrance.value = 1;
  }

  @override
  void dispose() {
    entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final columns = (width / math.max(146, scaler.scale(104)))
            .floor()
            .clamp(1, 5);
        final tileWidth = (width - 12 * (columns - 1)) / columns;
        final extent =
            math.min(tileWidth * .86, 222.0) +
            33 +
            scaler.scale(19) * 2.35 +
            scaler.scale(13) * 1.5;
        return SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: extent,
          ),
          itemCount: widget.people.length,
          itemBuilder: (context, i) {
            final person = widget.people[i];
            final card = _SpecimenCard(
              person: person,
              kept: widget.kept.contains(person.id),
              image: widget.picture(person),
              onTap: () => widget.onOpen(person),
            );
            if (i >= 6 || entrance.isCompleted) return card;
            final start = i * 32 / 380;
            final progress = entrance.drive(
              CurveTween(
                curve: Interval(
                  start,
                  ((i * 32 + 220) / 380),
                  curve: Curves.easeOutCubic,
                ),
              ),
            );
            return FadeTransition(
              key: ValueKey('reveal-${person.id}'),
              opacity: progress,
              child: SlideTransition(
                position: Tween(
                  begin: Offset(0, 8 / extent),
                  end: Offset.zero,
                ).animate(progress),
                child: card,
              ),
            );
          },
        );
      },
    );
  }
}

class _SpecimenCard extends StatelessWidget {
  const _SpecimenCard({
    required this.person,
    required this.kept,
    required this.image,
    required this.onTap,
  });
  final Specimen person;
  final bool kept;
  final Future<Uint8List?> image;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    const badge = Color(0xed15242d);
    final dot = switch (person.data['status']) {
      'Alive' => mint,
      'Dead' => const Color(0xffe4aa93),
      _ => muted,
    };
    return Semantics(
      button: true,
      onTap: onTap,
      label:
          '${person.name}, ${person.species}, ${person.status}${kept ? ', guardado' : ''}',
      child: ExcludeSemantics(
        child: Material(
          color: panel,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xff32444e)),
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Portrait(id: person.id, future: image, size: 180),
                        Positioned(
                          left: 10,
                          top: 10,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: badge,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              child: Text(
                                '#${person.id.toString().padLeft(3, '0')}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (kept)
                          const Positioned(
                            right: 10,
                            top: 10,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: badge,
                              child: Icon(
                                Icons.bookmark_rounded,
                                size: 16,
                                color: mint,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 19,
                            height: 1.12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: dot,
                              ),
                              child: const SizedBox.square(dimension: 6),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${person.species} · ${person.status}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
