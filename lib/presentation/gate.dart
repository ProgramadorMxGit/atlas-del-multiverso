import 'package:flutter/material.dart';

import '../application/session_controller.dart';
import 'appearance.dart';
import 'entry.dart';
import 'field_desk.dart';
import 'motion.dart';

class Gate extends StatefulWidget {
  const Gate({super.key, required this.openSession});
  final Future<SessionController> Function() openSession;
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  SessionController? session;
  bool failed = false, introFinished = false;
  @override
  void initState() {
    super.initState();
    boot();
  }

  Future<void> boot() async {
    try {
      final controller = await widget.openSession();
      await controller.restore();
      if (mounted) setState(() => session = controller);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!introFinished || session == null && !failed) {
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
    final controller = session!;
    final phone = controller.phone;
    final screen = phone == null
        ? Entry(
            onEnter: (number) async {
              await controller.enter(number);
              if (mounted) setState(() {});
            },
          )
        : FieldDesk(
            key: ValueKey(phone),
            createDesk: () => controller.deskFor(phone),
            onLeave: () async {
              await controller.leave();
              if (mounted) setState(() {});
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
