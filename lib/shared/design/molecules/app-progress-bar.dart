import 'package:flutter/material.dart';

import '../tokens/app-colors.dart';
import '../tokens/app-radii.dart';

class AppProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final Color? activeColor;
  final Color? trackColor;

  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 6,
    this.activeColor,
    this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return ClipRRect(
      borderRadius: AppRadii.sm,
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          backgroundColor: trackColor ?? palette.raised,
          color: activeColor ?? palette.accent,
          minHeight: height,
        ),
      ),
    );
  }
}

class AppStepProgressBar extends StatelessWidget {
  final int totalSteps;
  final int currentStep;
  final double height;

  const AppStepProgressBar({
    super.key,
    required this.totalSteps,
    required this.currentStep,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return Row(
      children: List.generate(totalSteps, (index) {
        final active = index <= currentStep;
        return Expanded(
          child: Container(
            height: height,
            margin: EdgeInsetsDirectional.only(
              end: index < totalSteps - 1 ? 4 : 0,
            ),
            decoration: BoxDecoration(
              color: active ? palette.calm : palette.raised,
              borderRadius: AppRadii.xs,
            ),
          ),
        );
      }),
    );
  }
}
