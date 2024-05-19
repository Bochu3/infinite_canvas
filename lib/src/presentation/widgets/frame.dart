import 'package:flutter/material.dart';

import 'inline_painter.dart';

/// A marquee widget that allows you to select multiple nodes.
class Frame extends StatelessWidget {
  const Frame({
    super.key,
    required this.start,
    required this.end,
  });

  final Offset start, end;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: InlinePainter(
        brush: Paint()
          ..strokeWidth = 4
          ..color = Colors.amber.withOpacity(0.5)
          ..style = PaintingStyle.stroke,
        builder: (brush, canvas, rect) {
          final marqueeRect = Rect.fromPoints(start, end);
          canvas.drawRect(marqueeRect, brush);
        },
      ),
    );
  }
}
