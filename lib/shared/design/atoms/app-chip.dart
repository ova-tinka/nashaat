import 'package:flutter/material.dart';
import '../tokens/app-colors.dart';
import '../tokens/app-typography.dart';

class AppSelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const AppSelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.paper,
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.paperBorder,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.label.copyWith(
            color: selected ? AppColors.paper : AppColors.ink,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class AppDayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const AppDayChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.paperAlt,
          border: Border.all(color: AppColors.ink, width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.monoStrong.copyWith(
            color: selected ? AppColors.paper : AppColors.ink,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
