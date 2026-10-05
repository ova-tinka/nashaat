import 'package:flutter/material.dart';

import 'app-wasm-badge.dart';

import '../tokens/app-colors.dart';

enum AppNavGlyph { qasr, crossedOars, fanar, tent, wasm }

class AppNavIcon extends StatelessWidget {
  final AppNavGlyph glyph;
  final bool selected;
  final String wasmLabel;
  final double size;
  final Color? color;

  const AppNavIcon({
    super.key,
    required this.glyph,
    this.selected = false,
    this.wasmLabel = 'N',
    this.size = 26,
    this.color,
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
          color:
              color ??
              (selected
                  ? context.nashaatPalette.accentText
                  : context.nashaatPalette.textMuted),
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
      ..strokeWidth = 1.4
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
    final w = bounds.width;
    final h = bounds.height;
    final baseline = bounds.bottom - h * 0.12;

    // Main base line
    canvas.drawLine(
      Offset(bounds.left + w * 0.1, baseline),
      Offset(bounds.right - w * 0.1, baseline),
      stroke,
    );

    // Main castle outline with crenellated turrets
    final path = Path()
      // Left turret base
      ..moveTo(bounds.left + w * 0.15, baseline)
      ..lineTo(bounds.left + w * 0.15, bounds.top + h * 0.28)
      // Left turret crenellation
      ..lineTo(bounds.left + w * 0.15, bounds.top + h * 0.15)
      ..lineTo(bounds.left + w * 0.25, bounds.top + h * 0.15)
      ..lineTo(bounds.left + w * 0.25, bounds.top + h * 0.22)
      ..lineTo(bounds.left + w * 0.35, bounds.top + h * 0.22)
      ..lineTo(bounds.left + w * 0.35, bounds.top + h * 0.15)
      ..lineTo(bounds.left + w * 0.42, bounds.top + h * 0.15)
      ..lineTo(bounds.left + w * 0.42, bounds.top + h * 0.30)
      // Center wall & crenellation
      ..lineTo(bounds.left + w * 0.48, bounds.top + h * 0.30)
      ..lineTo(bounds.left + w * 0.48, bounds.top + h * 0.22)
      ..lineTo(bounds.left + w * 0.52, bounds.top + h * 0.22)
      ..lineTo(bounds.left + w * 0.52, bounds.top + h * 0.30)
      ..lineTo(bounds.left + w * 0.58, bounds.top + h * 0.30)
      // Right turret crenellation
      ..lineTo(bounds.left + w * 0.58, bounds.top + h * 0.15)
      ..lineTo(bounds.left + w * 0.65, bounds.top + h * 0.15)
      ..lineTo(bounds.left + w * 0.65, bounds.top + h * 0.22)
      ..lineTo(bounds.left + w * 0.75, bounds.top + h * 0.22)
      ..lineTo(bounds.left + w * 0.75, bounds.top + h * 0.15)
      ..lineTo(bounds.left + w * 0.85, bounds.top + h * 0.15)
      ..lineTo(bounds.left + w * 0.85, baseline);

    canvas.drawPath(path, stroke);

    // Central Arch Doorway
    final arch = Path()
      ..moveTo(bounds.center.dx - w * 0.10, baseline)
      ..lineTo(bounds.center.dx - w * 0.10, bounds.top + h * 0.62)
      ..quadraticBezierTo(
        bounds.center.dx,
        bounds.top + h * 0.48,
        bounds.center.dx + w * 0.10,
        bounds.top + h * 0.62,
      )
      ..lineTo(bounds.center.dx + w * 0.10, baseline);
    canvas.drawPath(arch, stroke);

    // Small castle window dot
    canvas.drawCircle(
      Offset(bounds.center.dx, bounds.top + h * 0.40),
      1.2,
      fill,
    );
  }

  void _paintCrossedOars(Canvas canvas, Rect bounds, Paint stroke, Paint fill) {
    final center = bounds.center;
    final w = bounds.width;
    final h = bounds.height;

    // Cross shafts
    final p1 = Offset(bounds.left + w * 0.2, bounds.top + h * 0.2);
    final p2 = Offset(bounds.right - w * 0.2, bounds.bottom - h * 0.2);
    final p3 = Offset(bounds.right - w * 0.2, bounds.top + h * 0.2);
    final p4 = Offset(bounds.left + w * 0.2, bounds.bottom - h * 0.2);

    canvas.drawLine(p1, p2, stroke);
    canvas.drawLine(p3, p4, stroke);

    // Blades/Tips
    _drawBlade(canvas, p1, Offset(-w * 0.10, -h * 0.10), stroke, fill);
    _drawBlade(canvas, p2, Offset(w * 0.10, h * 0.10), stroke, fill);
    _drawBlade(canvas, p3, Offset(w * 0.10, -h * 0.10), stroke, fill);
    _drawBlade(canvas, p4, Offset(-w * 0.10, h * 0.10), stroke, fill);

    // Center joint ring
    canvas.drawCircle(center, 2.2, stroke);
  }

  void _drawBlade(
    Canvas canvas,
    Offset origin,
    Offset delta,
    Paint stroke,
    Paint fill,
  ) {
    final tip = origin + delta;
    final perp = Offset(-delta.dy, delta.dx) * 0.35;
    final path = Path()
      ..moveTo(origin.dx, origin.dy)
      ..lineTo(tip.dx + perp.dx, tip.dy + perp.dy)
      ..lineTo(tip.dx - perp.dx, tip.dy - perp.dy)
      ..close();
    canvas.drawPath(path, fill);
  }

  void _paintFanar(Canvas canvas, Rect bounds, Paint stroke, Paint fill) {
    final center = bounds.center;
    final w = bounds.width;
    final h = bounds.height;

    // Top loop ring
    canvas.drawCircle(
      Offset(center.dx, bounds.top + h * 0.16),
      w * 0.08,
      stroke,
    );

    // Dome cap
    final cap = Path()
      ..moveTo(bounds.left + w * 0.32, bounds.top + h * 0.32)
      ..quadraticBezierTo(
        center.dx,
        bounds.top + h * 0.24,
        bounds.right - w * 0.32,
        bounds.top + h * 0.32,
      )
      ..close();
    canvas.drawPath(cap, fill);

    // Glass cylinder cage
    final body = Rect.fromLTRB(
      bounds.left + w * 0.30,
      bounds.top + h * 0.34,
      bounds.right - w * 0.30,
      bounds.bottom - h * 0.24,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(3)),
      stroke,
    );

    // Inner flame
    canvas.drawCircle(center.translate(0, 1), 2.0, fill);

    // Base
    canvas.drawLine(
      Offset(bounds.left + w * 0.24, bounds.bottom - h * 0.16),
      Offset(bounds.right - w * 0.24, bounds.bottom - h * 0.16),
      stroke,
    );
  }

  void _paintTent(Canvas canvas, Rect bounds, Paint stroke, Paint fill) {
    final w = bounds.width;
    final h = bounds.height;
    final apex = Offset(bounds.center.dx, bounds.top + h * 0.22);
    final leftBase = Offset(bounds.left + w * 0.14, bounds.bottom - h * 0.18);
    final rightBase = Offset(bounds.right - w * 0.14, bounds.bottom - h * 0.18);

    // Tent roof canopy
    final roof = Path()
      ..moveTo(leftBase.dx - 2, leftBase.dy)
      ..lineTo(apex.dx, apex.dy)
      ..lineTo(rightBase.dx + 2, rightBase.dy);
    canvas.drawPath(roof, stroke);

    // Ground baseline
    canvas.drawLine(leftBase, rightBase, stroke);

    // Front poles & entrance drape
    canvas.drawLine(apex, Offset(apex.dx, rightBase.dy), stroke);
    canvas.drawLine(
      Offset(bounds.center.dx - w * 0.14, bounds.top + h * 0.48),
      Offset(bounds.center.dx - w * 0.14, rightBase.dy),
      stroke,
    );
    canvas.drawLine(
      Offset(bounds.center.dx + w * 0.14, bounds.top + h * 0.48),
      Offset(bounds.center.dx + w * 0.14, rightBase.dy),
      stroke,
    );

    // Apex crown finial
    canvas.drawCircle(apex, 1.4, fill);
  }

  @override
  bool shouldRepaint(covariant _AppNavGlyphPainter oldDelegate) {
    return glyph != oldDelegate.glyph || color != oldDelegate.color;
  }
}
