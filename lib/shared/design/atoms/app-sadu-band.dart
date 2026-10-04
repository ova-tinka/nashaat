import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/app-colors.dart';
import '../tokens/app-radii.dart';

enum AppSaduMotif { diamonds, chevrons, steps, crosses, waves, stars }

class AppSaduBand extends StatelessWidget {
  final AppSaduMotif motif;
  final double progress;
  final double height;
  final bool ghost;

  const AppSaduBand({
    super.key,
    this.motif = AppSaduMotif.diamonds,
    this.progress = 1,
    this.height = 16,
    this.ghost = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return Semantics(
      label: 'Sadu band',
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: CustomPaint(
          painter: _AppSaduBandPainter(
            palette: palette,
            motif: motif,
            progress: progress.clamp(0, 1),
            ghost: ghost,
          ),
        ),
      ),
    );
  }
}

class _AppSaduBandPainter extends CustomPainter {
  final NashaatPalette palette;
  final AppSaduMotif motif;
  final double progress;
  final bool ghost;

  const _AppSaduBandPainter({
    required this.palette,
    required this.motif,
    required this.progress,
    required this.ghost,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final base = Paint()..color = palette.saduDark;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(AppRadii.xsValue / 2),
      ),
      base,
    );

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    final opacity = ghost ? 0.2 : 1.0;
    final colors = [
      palette.saduRed.withValues(alpha: opacity),
      palette.saduYellow.withValues(alpha: opacity),
      palette.saduLight.withValues(alpha: opacity),
      palette.saduBrown.withValues(alpha: opacity),
    ];
    const cellWidth = 14.0;
    var cell = 0;
    for (var x = 0.0; x < size.width + cellWidth; x += cellWidth) {
      _drawMotif(
        canvas,
        Rect.fromLTWH(x, 0, cellWidth, size.height),
        motif,
        colors,
        cell,
      );
      cell++;
    }
    canvas.restore();
  }

  void _drawMotif(
    Canvas canvas,
    Rect rect,
    AppSaduMotif motif,
    List<Color> colors,
    int index,
  ) {
    final color = colors[index % colors.length];
    final alternate = colors[(index + 1) % colors.length];
    final paint = Paint()..color = color;
    final linePaint = Paint()
      ..color = alternate
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final center = rect.center;

    switch (motif) {
      case AppSaduMotif.diamonds:
        final path = Path()
          ..moveTo(center.dx, rect.top + 1)
          ..lineTo(rect.right - 1, center.dy)
          ..lineTo(center.dx, rect.bottom - 1)
          ..lineTo(rect.left + 1, center.dy)
          ..close();
        canvas.drawPath(path, paint);
      case AppSaduMotif.chevrons:
        final path = Path()
          ..moveTo(rect.left + 2, rect.top + 2)
          ..lineTo(center.dx, center.dy)
          ..lineTo(rect.left + 2, rect.bottom - 2)
          ..moveTo(center.dx, rect.top + 2)
          ..lineTo(rect.right - 2, center.dy)
          ..lineTo(center.dx, rect.bottom - 2);
        canvas.drawPath(path, linePaint);
      case AppSaduMotif.steps:
        canvas.drawRect(
          Rect.fromLTWH(
            rect.left + 2,
            rect.top + 2,
            rect.width * 0.45,
            rect.height * 0.45,
          ),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(
            center.dx,
            center.dy,
            rect.width * 0.45,
            rect.height * 0.45,
          ),
          Paint()..color = alternate,
        );
      case AppSaduMotif.crosses:
        canvas.drawLine(
          Offset(rect.left + 3, rect.top + 3),
          Offset(rect.right - 3, rect.bottom - 3),
          linePaint,
        );
        canvas.drawLine(
          Offset(rect.right - 3, rect.top + 3),
          Offset(rect.left + 3, rect.bottom - 3),
          linePaint,
        );
      case AppSaduMotif.waves:
        final path = Path()..moveTo(rect.left, center.dy);
        for (var i = 0; i < 4; i++) {
          final start = rect.left + (rect.width / 4) * i;
          path.cubicTo(
            start + rect.width / 8,
            rect.top,
            start + rect.width * 3 / 8,
            rect.bottom,
            start + rect.width / 2,
            center.dy,
          );
        }
        canvas.drawPath(path, linePaint);
      case AppSaduMotif.stars:
        final path = Path();
        for (var i = 0; i < 8; i++) {
          final radius = i.isEven ? rect.height * 0.42 : rect.height * 0.18;
          final angle = -math.pi / 2 + i * math.pi / 4;
          final point = Offset(
            center.dx + math.cos(angle) * radius,
            center.dy + math.sin(angle) * radius,
          );
          if (i == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AppSaduBandPainter oldDelegate) {
    return palette != oldDelegate.palette ||
        motif != oldDelegate.motif ||
        progress != oldDelegate.progress ||
        ghost != oldDelegate.ghost;
  }
}
