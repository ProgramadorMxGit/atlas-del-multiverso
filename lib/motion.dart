import 'package:flutter/material.dart';

class Entrance extends StatelessWidget {
  const Entrance({
    super.key,
    required this.child,
    this.start = 0,
    this.distance = 12,
  });
  final Widget child;
  final double start;
  final double distance;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 420),
      tween: Tween(begin: 0, end: 1),
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, distance * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

class LaunchCover extends StatefulWidget {
  const LaunchCover({
    super.key,
    required this.onFinished,
    required this.emblem,
  });
  final VoidCallback onFinished;
  final Widget emblem;
  @override
  State<LaunchCover> createState() => _LaunchCoverState();
}

class _LaunchCoverState extends State<LaunchCover>
    with SingleTickerProviderStateMixin {
  late final controller =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1250),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onFinished();
      });
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.stop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFinished();
      });
    } else if (controller.isDismissed) {
      controller.forward();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: controller,
              child: widget.emblem,
              builder: (_, child) {
                final t = reduced
                    ? 1.0
                    : const Interval(
                        0,
                        .62,
                        curve: Curves.easeOutCubic,
                      ).transform(controller.value);
                return Transform.translate(
                  offset: Offset(0, -22 * t),
                  child: Transform.rotate(angle: -.18 * (1 - t), child: child),
                );
              },
            ),
            Transform.translate(
              offset: const Offset(0, 52),
              child: AnimatedBuilder(
                animation: controller,
                child: const Text(
                  'Atlas del multiverso',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.7,
                  ),
                ),
                builder: (_, child) {
                  final t = reduced
                      ? 1.0
                      : const Interval(
                          .18,
                          .70,
                          curve: Curves.easeOutCubic,
                        ).transform(controller.value);
                  return Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, 8 * (1 - t)),
                      child: child,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
