import 'package:flutter/material.dart';

class AppDashedBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final BorderRadius radius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  const AppDashedBorder({
    super.key,
    required this.child,
    required this.color,
    this.radius = BorderRadius.zero,
    this.strokeWidth = 1.25,
    this.dashLength = 4,
    this.gapLength = 3,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _AppDashedBorderPainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
        dashLength: dashLength,
        gapLength: gapLength,
      ),
      child: child,
    );
  }
}

class _AppDashedBorderPainter extends CustomPainter {
  final Color color;
  final BorderRadius radius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  const _AppDashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rrect = radius.resolve(TextDirection.ltr).toRRect(Offset.zero & size);
    final path = Path()..addRRect(rrect.deflate(strokeWidth / 2));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AppDashedBorderPainter oldDelegate) {
    return color != oldDelegate.color ||
        radius != oldDelegate.radius ||
        strokeWidth != oldDelegate.strokeWidth ||
        dashLength != oldDelegate.dashLength ||
        gapLength != oldDelegate.gapLength;
  }
}
