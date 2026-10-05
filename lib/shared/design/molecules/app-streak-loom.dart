import 'package:flutter/material.dart';

import '../atoms/app-sadu-band.dart';

const _milestoneMotifs = <AppSaduMotif>[
  AppSaduMotif.stars,
  AppSaduMotif.chevrons,
  AppSaduMotif.diamonds,
  AppSaduMotif.steps,
  AppSaduMotif.crosses,
  AppSaduMotif.combs,
  AppSaduMotif.lattice,
  AppSaduMotif.diamonds,
];

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
    this.gap = 6,
    this.bandHeight = 34,
    this.axis = Axis.horizontal,
  }) : assert(completedBands >= 0 && completedBands <= 8);

  @override
  Widget build(BuildContext context) {
    final bands = List.generate(8, (index) {
      final completed = index < completedBands;
      final isTarget = index == completedBands && completedBands < 8;
      final motif = _milestoneMotifs[index % _milestoneMotifs.length];

      final band = AspectRatio(
        aspectRatio: 1.0,
        child: AppSaduBand(
          motif: motif,
          progress: completed || isTarget ? 1.0 : 0.0,
          height: bandHeight,
          ghost: !completed && !isTarget,
          isTarget: isTarget,
          borderRadius: 6.0,
        ),
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
