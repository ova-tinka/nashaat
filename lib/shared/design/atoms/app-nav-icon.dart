import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app-wasm-badge.dart';
import '../tokens/app-colors.dart';

enum AppNavGlyph { qasr, crossedOars, fanar, tent, wasm }

class AppNavIcon extends StatelessWidget {
  final AppNavGlyph glyph;
  final bool selected;
  final String wasmLabel;
  final double size;

  const AppNavIcon({
    super.key,
    required this.glyph,
    this.selected = false,
    this.wasmLabel = 'N',
    this.size = 26,
  });

  @override
  Widget build(BuildContext context) {
    if (glyph == AppNavGlyph.wasm) {
      return AppWasmBadge(label: wasmLabel, size: selected ? size + 2 : size);
    }

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _AppNavGlyphPainter(
          glyph: glyph,
          color: selected
              ? context.nashaatPalette.accentText
              : context.nashaatPalette.textMuted,
        ),
      ),
    );
  }
}

class _AppNavGlyphPainter extends CustomPainter {
  final AppNavGlyph glyph;
  final Color color;

  const _AppNavGlyphPainter({required this.glyph, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, size.shortestSide * 0.075)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    final bounds = Offset.zero & size;

    switch (glyph) {
      case AppNavGlyph.qasr:
        _paintQasr(canvas, bounds, stroke, fill);
      case AppNavGlyph.crossedOars:
        _paintCrossedOars(canvas, bounds, stroke, fill);
      case AppNavGlyph.fanar:
        _paintFanar(canvas, bounds, stroke, fill);
      case AppNavGlyph.tent:
        _paintTent(canvas, bounds, stroke, fill);
      case AppNavGlyph.wasm:
        break;
    }
  }

  void _paintQasr(Canvas canvas, Rect bounds, Paint stroke, Paint fill) {
    final left = bounds.left + bounds.width * 0.12;
    final right = bounds.right - bounds.width * 0.12;
    final baseline = bounds.bottom - bounds.height * 0.13;
    final towerTop = bounds.top + bounds.height * 0.25;
    final bodyTop = bounds.top + bounds.height * 0.43;

    canvas.drawLine(Offset(left, baseline), Offset(right, baseline), stroke);
    canvas.drawRect(Rect.fromLTRB(left, bodyTop, right, baseline), stroke);
    canvas.drawRect(
      Rect.fromLTRB(
        bounds.left + bounds.width * 0.34,
        towerTop,
        bounds.left + bounds.width * 0.66,
        baseline,
      ),
      stroke,
    );

    final crenellations = Path()
      ..moveTo(bounds.left + bounds.width * 0.29, towerTop)
      ..lineTo(
        bounds.left + bounds.width * 0.29,
        bounds.top + bounds.height * 0.16,
      )
      ..lineTo(
        bounds.left + bounds.width * 0.39,
        bounds.top + bounds.height * 0.16,
      )
      ..lineTo(bounds.left + bounds.width * 0.39, towerTop)
      ..moveTo(bounds.left + bounds.width * 0.61, towerTop)
      ..lineTo(
        bounds.left + bounds.width * 0.61,
        bounds.top + bounds.height * 0.16,
      )
      ..lineTo(
        bounds.left + bounds.width * 0.71,
        bounds.top + bounds.height * 0.16,
      )
      ..lineTo(bounds.left + bounds.width * 0.71, towerTop);
    canvas.drawPath(crenellations, stroke);

    final arch = Path()
      ..moveTo(bounds.center.dx - bounds.width * 0.08, baseline)
      ..lineTo(
        bounds.center.dx - bounds.width * 0.08,
        bounds.top + bounds.height * 0.68,
      )
      ..quadraticBezierTo(
        bounds.center.dx,
        bounds.top + bounds.height * 0.55,
        bounds.center.dx + bounds.width * 0.08,
        bounds.top + bounds.height * 0.68,
      )
      ..lineTo(bounds.center.dx + bounds.width * 0.08, baseline);
    canvas.drawPath(arch, stroke);
    canvas.drawCircle(
      Offset(bounds.center.dx, bounds.top + bounds.height * 0.33),
      bounds.width * 0.035,
      fill,
    );
  }

  void _paintCrossedOars(Canvas canvas, Rect bounds, Paint stroke, Paint fill) {
    final center = bounds.center;
    final inset = bounds.shortestSide * 0.16;
    final topLeft = Offset(bounds.left + inset, bounds.top + inset);
    final topRight = Offset(bounds.right - inset, bounds.top + inset);
    final bottomLeft = Offset(bounds.left + inset, bounds.bottom - inset);
    final bottomRight = Offset(bounds.right - inset, bounds.bottom - inset);

    canvas.drawLine(topLeft, bottomRight, stroke);
    canvas.drawLine(topRight, bottomLeft, stroke);
    canvas.drawCircle(center, bounds.shortestSide * 0.1, fill);

    _drawOarBlade(
      canvas,
      topLeft,
      topLeft - Offset(inset * 0.42, inset * 0.58),
      fill,
    );
    _drawOarBlade(
      canvas,
      bottomRight,
      bottomRight + Offset(inset * 0.42, inset * 0.58),
      fill,
    );
    _drawOarBlade(
      canvas,
      topRight,
      topRight + Offset(inset * 0.42, -inset * 0.58),
      fill,
    );
    _drawOarBlade(
      canvas,
      bottomLeft,
      bottomLeft - Offset(inset * 0.42, -inset * 0.58),
      fill,
    );
  }

  void _drawOarBlade(Canvas canvas, Offset handle, Offset tip, Paint fill) {
    final direction = tip - handle;
    final length = direction.distance;
    if (length == 0) return;
    final unit = direction / length;
    final perpendicular = Offset(-unit.dy, unit.dx);
    final bladeStart = handle + unit * length * 0.22;
    final bladeEnd = handle + unit * length;
    final blade = Path()
      ..moveTo(bladeStart.dx, bladeStart.dy)
      ..lineTo(
        (bladeEnd + perpendicular * 2.8).dx,
        (bladeEnd + perpendicular * 2.8).dy,
      )
      ..lineTo(
        (bladeEnd - perpendicular * 2.8).dx,
        (bladeEnd - perpendicular * 2.8).dy,
      )
      ..close();
    canvas.drawPath(blade, fill);
  }

  void _paintFanar(Canvas canvas, Rect bounds, Paint stroke, Paint fill) {
    final center = bounds.center;
    final glow = Paint()..color = color.withValues(alpha: 0.18);
    canvas.drawCircle(
      center.translate(0, -bounds.height * 0.08),
      bounds.width * 0.29,
      glow,
    );

    final body = Rect.fromLTRB(
      bounds.left + bounds.width * 0.29,
      bounds.top + bounds.height * 0.35,
      bounds.right - bounds.width * 0.29,
      bounds.bottom - bounds.height * 0.16,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(bounds.width * 0.08)),
      stroke,
    );
    canvas.drawLine(
      Offset(
        bounds.left + bounds.width * 0.23,
        bounds.bottom - bounds.height * 0.1,
      ),
      Offset(
        bounds.right - bounds.width * 0.23,
        bounds.bottom - bounds.height * 0.1,
      ),
      stroke,
    );
    canvas.drawLine(
      Offset(
        bounds.left + bounds.width * 0.4,
        bounds.top + bounds.height * 0.25,
      ),
      Offset(
        bounds.right - bounds.width * 0.4,
        bounds.top + bounds.height * 0.25,
      ),
      stroke,
    );
    canvas.drawLine(
      Offset(center.dx, bounds.top + bounds.height * 0.12),
      Offset(center.dx, bounds.top + bounds.height * 0.25),
      stroke,
    );
    canvas.drawCircle(
      Offset(center.dx, bounds.top + bounds.height * 0.16),
      bounds.width * 0.045,
      fill,
    );
  }

  void _paintTent(Canvas canvas, Rect bounds, Paint stroke, Paint fill) {
    final apex = Offset(bounds.center.dx, bounds.top + bounds.height * 0.13);
    final left = Offset(
      bounds.left + bounds.width * 0.12,
      bounds.bottom - bounds.height * 0.14,
    );
    final right = Offset(
      bounds.right - bounds.width * 0.12,
      bounds.bottom - bounds.height * 0.14,
    );
    final base = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(base, stroke);
    canvas.drawLine(apex, Offset(bounds.center.dx, right.dy), stroke);
    canvas.drawLine(
      Offset(bounds.center.dx, bounds.top + bounds.height * 0.63),
      Offset(bounds.center.dx, right.dy),
      stroke,
    );
    canvas.drawCircle(
      Offset(bounds.center.dx, bounds.top + bounds.height * 0.42),
      bounds.width * 0.045,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _AppNavGlyphPainter oldDelegate) {
    return glyph != oldDelegate.glyph || color != oldDelegate.color;
  }
}
