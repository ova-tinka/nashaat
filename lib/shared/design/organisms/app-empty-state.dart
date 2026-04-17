import 'package:flutter/material.dart';
import '../atoms/app-button.dart';
import '../tokens/app-colors.dart';
import '../tokens/app-typography.dart';

class AppEmptyState extends StatelessWidget {
  final String title;
  final String body;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final IconData? icon;
  final bool accentBorder;

  const AppEmptyState({
    super.key,
    required this.title,
    required this.body,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.icon,
    this.accentBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 48, color: AppColors.inkMuted),
              const SizedBox(height: 20),
            ],
            Text(
              title.toUpperCase(),
              style: AppTypography.sectionHeader.copyWith(
                fontSize: 13,
                letterSpacing: 1.5,
                color: AppColors.ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: AppTypography.bodyMuted,
              textAlign: TextAlign.center,
            ),
            if (primaryLabel != null) ...[
              const SizedBox(height: 24),
              AppButton.primary(
                primaryLabel!,
                onPressed: onPrimary,
                width: double.infinity,
              ),
            ],
            if (secondaryLabel != null) ...[
              const SizedBox(height: 8),
              AppButton.ghost(
                secondaryLabel!,
                onPressed: onSecondary,
                width: double.infinity,
              ),
            ],
          ],
        ),
      ),
    );

    if (accentBorder) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: AppColors.acid, width: 3)),
          ),
          child: content,
        ),
      );
    }
    return content;
  }
}
