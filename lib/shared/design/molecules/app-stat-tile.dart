import 'package:flutter/material.dart';
import '../tokens/app-colors.dart';
import '../tokens/app-typography.dart';

class AppStatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final Color? accentColor;

  const AppStatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.paperAlt,
        border: Border.all(color: AppColors.paperBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: accentColor ?? AppColors.inkMuted),
            const SizedBox(height: 6),
          ],
          Text(
            value,
            style: AppTypography.monoStrong.copyWith(
              fontSize: 18,
              color: accentColor ?? AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.labelMuted,
          ),
        ],
      ),
    );
  }
}
