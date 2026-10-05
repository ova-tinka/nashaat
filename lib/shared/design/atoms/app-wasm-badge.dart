import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/app-colors.dart';

class AppWasmBadge extends StatelessWidget {
  final String label;
  final double size;

  const AppWasmBadge({super.key, required this.label, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    final innerDiameter = size * 0.68;
    return Semantics(
      label: 'Wasm $label',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _AppWasmPainter(palette: palette),
          child: Center(
            child: Container(
              width: innerDiameter,
              height: innerDiameter,
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
                  fontSize: innerDiameter * 0.52,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
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
    if (size.isEmpty) return;

    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final innerRadius = radius * 0.68;

    // Outer base
    final basePaint = Paint()..color = palette.saduDark;
    canvas.drawCircle(center, radius, basePaint);

    // Sadu woven bead teeth around the perimeter
    const totalSegments = 24;
    final segmentAngle = (2 * math.pi) / totalSegments;
    final beadColors = [
      palette.saduRed,
      palette.saduLight,
      palette.saduRed,
      palette.saduYellow,
      palette.saduDark,
      palette.saduLight,
    ];

    final stroke = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (var i = 0; i < totalSegments; i++) {
      final startAngle = i * segmentAngle;
      final sweepAngle = segmentAngle * 0.82;
      stroke.color = beadColors[i % beadColors.length];

      final path = Path()
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          false,
        )
        ..arcTo(
          Rect.fromCircle(
            center: center,
            radius: innerRadius + (radius - innerRadius) * 0.15,
          ),
          startAngle + sweepAngle,
          -sweepAngle,
          false,
        )
        ..close();

      canvas.drawPath(path, stroke);
    }

    // Inner rim line
    final rimPaint = Paint()
      ..color = palette.saduDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, innerRadius, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _AppWasmPainter oldDelegate) {
    return oldDelegate.palette != palette;
  }
}
