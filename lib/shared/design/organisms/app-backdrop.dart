import 'package:flutter/material.dart';

import '../tokens/app-colors.dart';

/// A quiet atmospheric layer shared by the redesigned screens.
///
/// The prototype uses light from the palette rather than flat, untextured
/// surfaces. Keeping that treatment here makes every feature feel like the
/// same Nashaat space without coupling screens to decorative code.
class AppBackdrop extends StatelessWidget {
  final bool showBottomWaves;

  const AppBackdrop({super.key, this.showBottomWaves = true});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AppBackdropPainter(
        palette: context.nashaatPalette,
        showBottomWaves: showBottomWaves,
      ),
    );
  }
}

class _AppBackdropPainter extends CustomPainter {
  final NashaatPalette palette;
  final bool showBottomWaves;

  const _AppBackdropPainter({
    required this.palette,
    required this.showBottomWaves,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final background = Paint()..color = palette.background;
    canvas.drawRect(Offset.zero & size, background);

    final glow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.78),
        radius: 1.05,
        colors: [
          palette.accent.withValues(alpha: 0.10),
          palette.reward.withValues(alpha: 0.045),
          Colors.transparent,
        ],
        stops: const [0, 0.42, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glow);

    if (!showBottomWaves) return;

    final leftWave = Path()
      ..moveTo(0, size.height * 0.935)
      ..quadraticBezierTo(
        size.width * 0.22,
        size.height * 0.905,
        size.width * 0.52,
        size.height * 0.965,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 1.02,
        size.width,
        size.height * 0.955,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      leftWave,
      Paint()..color = palette.calm.withValues(alpha: 0.065),
    );

    final rightWave = Path()
      ..moveTo(0, size.height * 0.98)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.90,
        size.width * 0.64,
        size.height * 0.965,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 1.0,
        size.width,
        size.height * 0.93,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      rightWave,
      Paint()..color = palette.reward.withValues(alpha: 0.045),
    );
  }

  @override
  bool shouldRepaint(covariant _AppBackdropPainter oldDelegate) =>
      oldDelegate.palette != palette ||
      oldDelegate.showBottomWaves != showBottomWaves;
}
