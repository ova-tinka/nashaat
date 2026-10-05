import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/app-colors.dart';

/// A compact circular progress treatment for focused, time-based flows.
///
/// The ring intentionally owns only presentation. The caller supplies the
/// progress value and the content shown in the middle, so it can be reused by
/// workout sessions, focus timers, and future reward moments.
class AppTimerRing extends StatelessWidget {
  final double progress;
  final Widget child;
  final double size;
  final double strokeWidth;
  final Color? activeColor;
  final Color? trackColor;

  const AppTimerRing({
    super.key,
    required this.progress,
    required this.child,
    this.size = 208,
    this.strokeWidth = 12,
    this.activeColor,
    this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return Semantics(
      label: 'Timer progress',
      value: '${(progress.clamp(0.0, 1.0) * 100).round()}%',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _AppTimerRingPainter(
            progress: progress.clamp(0.0, 1.0),
            activeColor: activeColor ?? palette.accent,
            trackColor: trackColor ?? palette.raised,
            strokeWidth: strokeWidth,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _AppTimerRingPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color trackColor;
  final double strokeWidth;

  const _AppTimerRingPainter({
    required this.progress,
    required this.activeColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    final bounds = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;

    final active = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;
    canvas.drawArc(bounds, -math.pi / 2, math.pi * 2 * progress, false, active);
  }

  @override
  bool shouldRepaint(covariant _AppTimerRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
