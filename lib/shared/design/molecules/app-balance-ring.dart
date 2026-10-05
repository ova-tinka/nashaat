import 'package:flutter/material.dart';

import '../atoms/app-nav-icon.dart';
import '../tokens/app-colors.dart';
import 'app-timer-ring.dart';

/// The fanar-led balance treatment used by Focus and other screen-time views.
class AppBalanceRing extends StatelessWidget {
  final double progress;
  final String balanceLabel;
  final String caption;
  final double size;
  final Widget? icon;

  const AppBalanceRing({
    super.key,
    required this.progress,
    required this.balanceLabel,
    required this.caption,
    this.size = 320,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return Semantics(
      label: 'Screen-time balance',
      value: balanceLabel,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _FanarWellPainter(palette: palette)),
            ),
            AppTimerRing(
              progress: progress,
              size: size,
              strokeWidth: size * 0.035,
              activeColor: palette.accent,
              trackColor: palette.saduDark,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon ??
                      AppNavIcon(
                        glyph: AppNavGlyph.fanar,
                        selected: true,
                        size: size * 0.14,
                      ),
                  SizedBox(height: size * 0.02),
                  Text(
                    balanceLabel,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: size * 0.135,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: size * 0.018),
                  Text(
                    caption,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: palette.textMuted,
                      fontSize: size * 0.055,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FanarWellPainter extends CustomPainter {
  final NashaatPalette palette;

  const _FanarWellPainter({required this.palette});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.39;
    final paint = Paint()
      ..color = palette.raised.withValues(alpha: 0.32)
      ..style = PaintingStyle.fill;

    for (var row = -7; row <= 7; row++) {
      for (var column = -7; column <= 7; column++) {
        final offset = Offset(
          center.dx + column * size.shortestSide * 0.055,
          center.dy + row * size.shortestSide * 0.055,
        );
        if ((offset - center).distance > radius) continue;
        final path = Path()
          ..moveTo(offset.dx, offset.dy - 4)
          ..lineTo(offset.dx - 4, offset.dy + 3)
          ..lineTo(offset.dx + 4, offset.dy + 3)
          ..close();
        canvas.drawPath(path, paint);
      }
    }

    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              palette.accent.withValues(alpha: 0.22),
              palette.accent.withValues(alpha: 0.07),
              palette.accent.withValues(alpha: 0),
            ],
            stops: const [0, 0.44, 1],
          ).createShader(
            Rect.fromCircle(center: center, radius: size.width * 0.58),
          );
    canvas.drawCircle(center, size.width * 0.58, glow);
  }

  @override
  bool shouldRepaint(covariant _FanarWellPainter oldDelegate) {
    return palette != oldDelegate.palette;
  }
}
