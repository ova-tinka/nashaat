import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/app-colors.dart';

class AppWasmBadge extends StatelessWidget {
  final String label;
  final double size;

  const AppWasmBadge({super.key, required this.label, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return Semantics(
      label: 'Wasm $label',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _AppWasmPainter(palette: palette),
          child: Center(
            child: Container(
              width: size * 0.72,
              height: size * 0.72,
              decoration: BoxDecoration(
                color: palette.card,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: palette.textPrimary,
                  fontSize: size * 0.27,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppWasmPainter extends CustomPainter {
  final NashaatPalette palette;

  const _AppWasmPainter({required this.palette});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final background = Paint()..color = palette.saduRed;
    canvas.drawCircle(center, radius, background);

    final pattern = Paint()
      ..color = palette.saduYellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );
    for (var i = -2; i < 8; i++) {
      final offset = i * size.width * 0.22;
      canvas.drawLine(
        Offset(offset, size.height),
        Offset(offset + size.height, 0),
        pattern,
      );
    }
    final star = Path();
    for (var i = 0; i < 8; i++) {
      final pointRadius = i.isEven ? radius * 0.68 : radius * 0.34;
      final angle = -math.pi / 2 + i * math.pi / 4;
      final point = Offset(
        center.dx + math.cos(angle) * pointRadius,
        center.dy + math.sin(angle) * pointRadius,
      );
      if (i == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas.drawPath(star, pattern);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AppWasmPainter oldDelegate) {
    return oldDelegate.palette != palette;
  }
}
