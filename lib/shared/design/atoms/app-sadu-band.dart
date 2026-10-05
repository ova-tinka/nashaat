import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/app-colors.dart';

enum AppSaduMotif {
  diamonds,
  chevrons,
  steps,
  crosses,
  waves,
  stars,
  lattice,
  combs,
}

class AppSaduBand extends StatelessWidget {
  final AppSaduMotif motif;
  final double progress;
  final double height;
  final double? width;
  final bool ghost;
  final bool isTarget;
  final double borderRadius;

  const AppSaduBand({
    super.key,
    this.motif = AppSaduMotif.diamonds,
    this.progress = 1,
    this.height = 16,
    this.width,
    this.ghost = false,
    this.isTarget = false,
    this.borderRadius = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return Semantics(
      label: 'Sadu band',
      child: SizedBox(
        width: width ?? double.infinity,
        height: height,
        child: CustomPaint(
          painter: _AppSaduBandPainter(
            palette: palette,
            motif: motif,
            progress: progress.clamp(0, 1),
            ghost: ghost,
            isTarget: isTarget,
            borderRadius: borderRadius,
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
  final bool isTarget;
  final double borderRadius;

  const _AppSaduBandPainter({
    required this.palette,
    required this.motif,
    required this.progress,
    required this.ghost,
    required this.isTarget,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // Base background
    final baseColor = ghost
        ? const Color(0xFF221A15)
        : (progress > 0 ? palette.saduRed : const Color(0xFF211A15));
    final basePaint = Paint()..color = baseColor;
    canvas.drawRRect(rrect, basePaint);

    canvas.save();
    canvas.clipRRect(rrect);

    if (ghost || progress == 0) {
      // Locked state: subtle low-contrast dark geometric weave
      _drawLockedPattern(canvas, rect);
    } else {
      // Unlocked or Active state: rich Sadu woven textile
      _drawActiveTextile(canvas, rect);
    }

    canvas.restore();

    // Saffron highlight border for target milestone
    if (isTarget) {
      final borderPaint = Paint()
        ..color = palette.reward
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(0.8),
          Radius.circular(math.max(0, borderRadius - 0.8)),
        ),
        borderPaint,
      );
    }
  }

  void _drawLockedPattern(Canvas canvas, Rect rect) {
    final stroke = Paint()
      ..color = const Color(0xFF382D24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final fill = Paint()
      ..color = const Color(0xFF382D24)
      ..style = PaintingStyle.fill;

    final center = rect.center;
    final w = rect.width;
    final h = rect.height;

    switch (motif) {
      case AppSaduMotif.steps:
        // Stepped pyramid / chevron
        final path = Path()
          ..moveTo(center.dx - w * 0.3, center.dy + h * 0.25)
          ..lineTo(center.dx, center.dy - h * 0.25)
          ..lineTo(center.dx + w * 0.3, center.dy + h * 0.25)
          ..moveTo(center.dx - w * 0.2, center.dy + h * 0.32)
          ..lineTo(center.dx, center.dy - h * 0.12)
          ..lineTo(center.dx + w * 0.2, center.dy + h * 0.32);
        canvas.drawPath(path, stroke);
      case AppSaduMotif.crosses:
        // Checker / cross grid
        final step = w / 4;
        for (var i = 0; i < 4; i++) {
          for (var j = 0; j < 4; j++) {
            if ((i + j) % 2 == 0) {
              canvas.drawRect(
                Rect.fromLTWH(
                  rect.left + i * step,
                  rect.top + j * (h / 4),
                  step,
                  h / 4,
                ),
                fill,
              );
            }
          }
        }
      case AppSaduMotif.waves || AppSaduMotif.combs:
        // Chandelier / Comb column lattice
        for (var i = -1; i <= 1; i++) {
          final x = center.dx + i * (w * 0.24);
          canvas.drawLine(
            Offset(x, rect.top + h * 0.2),
            Offset(x, rect.bottom - h * 0.2),
            stroke,
          );
          canvas.drawCircle(Offset(x, rect.top + h * 0.2), 1.5, fill);
        }
        canvas.drawLine(
          Offset(center.dx - w * 0.3, center.dy),
          Offset(center.dx + w * 0.3, center.dy),
          stroke,
        );
      case AppSaduMotif.lattice:
        // M / Arch pattern
        final path = Path()
          ..moveTo(rect.left + w * 0.2, rect.bottom - h * 0.2)
          ..lineTo(rect.left + w * 0.2, rect.top + h * 0.2)
          ..lineTo(center.dx, center.dy)
          ..lineTo(rect.right - w * 0.2, rect.top + h * 0.2)
          ..lineTo(rect.right - w * 0.2, rect.bottom - h * 0.2);
        canvas.drawPath(path, stroke);
      default:
        // Star diamond outline
        final path = Path()
          ..moveTo(center.dx, rect.top + h * 0.2)
          ..lineTo(rect.right - w * 0.2, center.dy)
          ..lineTo(center.dx, rect.bottom - h * 0.2)
          ..lineTo(rect.left + w * 0.2, center.dy)
          ..close();
        canvas.drawPath(path, stroke);
        canvas.drawCircle(center, 1.5, fill);
    }
  }

  void _drawActiveTextile(Canvas canvas, Rect rect) {
    // Top and bottom woven serration teeth
    final toothPaint = Paint()..color = const Color(0xFFF5EDE0);
    final darkTooth = Paint()..color = const Color(0xFF15110E);
    final teethCount = 7;
    final toothW = rect.width / teethCount;

    for (var i = 0; i < teethCount; i++) {
      final p = (i % 2 == 0) ? toothPaint : darkTooth;
      canvas.drawRect(
        Rect.fromLTWH(rect.left + i * toothW, rect.top, toothW, 2.0),
        p,
      );
      canvas.drawRect(
        Rect.fromLTWH(rect.left + i * toothW, rect.bottom - 2.0, toothW, 2.0),
        p,
      );
    }

    final center = rect.center;
    final w = rect.width;
    final h = rect.height;

    final white = Paint()..color = const Color(0xFFF5EDE0);
    final gold = Paint()..color = palette.reward;
    final whiteStroke = Paint()
      ..color = const Color(0xFFF5EDE0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final goldStroke = Paint()
      ..color = palette.reward
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (motif) {
      case AppSaduMotif.stars:
        // Star 3-day motif: Central 8-point star and micro side dots
        canvas.drawCircle(center, 2.2, white);
        for (var i = 0; i < 4; i++) {
          final rad = 4.5;
          final angle = i * math.pi / 2;
          canvas.drawCircle(
            Offset(
              center.dx + math.cos(angle) * rad,
              center.dy + math.sin(angle) * rad,
            ),
            1.4,
            gold,
          );
        }
        // Four corner dot clusters
        for (var dx in [-0.28, 0.28]) {
          for (var dy in [-0.22, 0.22]) {
            canvas.drawCircle(
              Offset(center.dx + w * dx, center.dy + h * dy),
              1.2,
              white,
            );
          }
        }
      case AppSaduMotif.chevrons:
        // Double chevron arrows >>>
        final leftX = center.dx - w * 0.18;
        final midX = center.dx;
        final rightX = center.dx + w * 0.18;
        final spread = h * 0.24;

        final path1 = Path()
          ..moveTo(leftX - 3, center.dy - spread)
          ..lineTo(leftX + 2, center.dy)
          ..lineTo(leftX - 3, center.dy + spread);
        canvas.drawPath(path1, goldStroke);

        final path2 = Path()
          ..moveTo(midX - 3, center.dy - spread)
          ..lineTo(midX + 2, center.dy)
          ..lineTo(midX - 3, center.dy + spread);
        canvas.drawPath(path2, whiteStroke);

        final path3 = Path()
          ..moveTo(rightX - 3, center.dy - spread)
          ..lineTo(rightX + 2, center.dy)
          ..lineTo(rightX - 3, center.dy + spread);
        canvas.drawPath(path3, goldStroke);
      case AppSaduMotif.diamonds:
        // Eein (Eye) diamond motif: Center diamond with surrounding dots
        final diamond = Path()
          ..moveTo(center.dx, center.dy - h * 0.24)
          ..lineTo(center.dx + w * 0.22, center.dy)
          ..lineTo(center.dx, center.dy + h * 0.24)
          ..lineTo(center.dx - w * 0.22, center.dy)
          ..close();
        canvas.drawPath(diamond, whiteStroke);
        canvas.drawCircle(center, 1.8, gold);

        // Side diamond dots
        canvas.drawCircle(Offset(center.dx - w * 0.32, center.dy), 1.4, white);
        canvas.drawCircle(Offset(center.dx + w * 0.32, center.dy), 1.4, white);
      default:
        // General woven diamond/star
        final diamond = Path()
          ..moveTo(center.dx, center.dy - h * 0.22)
          ..lineTo(center.dx + w * 0.2, center.dy)
          ..lineTo(center.dx, center.dy + h * 0.22)
          ..lineTo(center.dx - w * 0.2, center.dy)
          ..close();
        canvas.drawPath(diamond, white);
        canvas.drawCircle(center, 1.5, gold);
    }
  }

  @override
  bool shouldRepaint(covariant _AppSaduBandPainter oldDelegate) {
    return palette != oldDelegate.palette ||
        motif != oldDelegate.motif ||
        progress != oldDelegate.progress ||
        ghost != oldDelegate.ghost ||
        isTarget != oldDelegate.isTarget ||
        borderRadius != oldDelegate.borderRadius;
  }
}
