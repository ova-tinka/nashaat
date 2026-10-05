import 'package:flutter/material.dart';

import '../atoms/app-sadu-band.dart';

class AppStreakLoom extends StatelessWidget {
  final int completedBands;
  final double currentProgress;
  final double gap;
  final double bandHeight;
  final Axis axis;

  const AppStreakLoom({
    super.key,
    this.completedBands = 0,
    this.currentProgress = 0,
    this.gap = 4,
    this.bandHeight = 12,
    this.axis = Axis.horizontal,
  }) : assert(completedBands >= 0 && completedBands <= 8);

  @override
  Widget build(BuildContext context) {
    final motifs = AppSaduMotif.values;
    final bands = List.generate(8, (index) {
      final completed = index < completedBands;
      final current = index == completedBands;
      final band = AppSaduBand(
        motif: motifs[index % motifs.length],
        progress: completed
            ? 1
            : current
            ? currentProgress
            : 0,
        height: bandHeight,
        ghost: !completed && !current,
      );

      if (axis == Axis.horizontal) {
        return Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.only(end: index == 7 ? 0 : gap),
            child: band,
          ),
        );
      }

      return Padding(
        padding: EdgeInsets.only(bottom: index == 7 ? 0 : gap),
        child: band,
      );
    });

    return axis == Axis.horizontal
        ? Row(children: bands)
        : Column(children: bands);
  }
}
