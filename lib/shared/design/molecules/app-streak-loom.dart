import 'package:flutter/material.dart';

import '../atoms/app-sadu-band.dart';

class AppStreakLoom extends StatelessWidget {
  final int completedBands;
  final double currentProgress;
  final double gap;
  final double bandHeight;

  const AppStreakLoom({
    super.key,
    this.completedBands = 0,
    this.currentProgress = 0,
    this.gap = 4,
    this.bandHeight = 12,
  }) : assert(completedBands >= 0 && completedBands <= 8);

  @override
  Widget build(BuildContext context) {
    final motifs = AppSaduMotif.values;
    return Column(
      children: List.generate(8, (index) {
        final completed = index < completedBands;
        final current = index == completedBands;
        return Padding(
          padding: EdgeInsets.only(bottom: index == 7 ? 0 : gap),
          child: AppSaduBand(
            motif: motifs[index % motifs.length],
            progress: completed
                ? 1
                : current
                ? currentProgress
                : 0,
            height: bandHeight,
            ghost: !completed && !current,
          ),
        );
      }),
    );
  }
}
