import 'package:flutter/material.dart';

const ink = Color(0xff101b24);
const panel = Color(0xff1c2c37);
const mint = Color(0xffa7ecd3);
const muted = Color(0xffb1c2ca);

class Mark extends StatelessWidget {
  const Mark({super.key, this.size = 44});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _Orbit()),
  );
}

class _Orbit extends CustomPainter {
  @override
  void paint(Canvas c, Size size) {
    c.scale(size.width / 100);
    c.translate(50, 50);
    c.rotate(-.52);
    final pen = Paint()
      ..color = mint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    c.drawCircle(Offset.zero, 28, pen);
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 92, height: 27),
      pen,
    );
    c.drawCircle(
      const Offset(34, -9),
      6,
      Paint()..color = const Color(0xffedbb70),
    );
  }

  @override
  bool shouldRepaint(_Orbit old) => false;
}
