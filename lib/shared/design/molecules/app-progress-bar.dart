import 'package:flutter/material.dart';
import '../tokens/app-colors.dart';

class AppProgressBar extends StatelessWidget {
  final double value; // 0.0 to 1.0
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
    return SizedBox(
      height: height,
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        backgroundColor: trackColor ?? AppColors.paperBorder,
        color: activeColor ?? AppColors.ink,
        borderRadius: BorderRadius.zero,
        minHeight: height,
      ),
    );
  }
}

class AppStepProgressBar extends StatelessWidget {
  final int totalSteps;
  final int currentStep; // 0-indexed
  final double height;

  const AppStepProgressBar({
    super.key,
    required this.totalSteps,
    required this.currentStep,
    this.height = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (i) {
        final active = i <= currentStep;
        return Expanded(
          child: Container(
            height: height,
            margin: EdgeInsets.only(right: i < totalSteps - 1 ? 4 : 0),
            color: active ? AppColors.ink : AppColors.paperBorder,
          ),
        );
      }),
    );
  }
}
