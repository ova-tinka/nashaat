import 'package:flutter/material.dart';
import '../tokens/app-colors.dart';
import '../tokens/app-typography.dart';

class AppBadge extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const AppBadge(
    this.label, {
    super.key,
    this.background = AppColors.ink,
    this.foreground = AppColors.paper,
  });

  const AppBadge.acid(String label, {Key? key})
      : this(label, key: key, background: AppColors.acid, foreground: AppColors.ink);

  const AppBadge.signal(String label, {Key? key})
      : this(label, key: key, background: AppColors.signal, foreground: AppColors.ink);

  const AppBadge.error(String label, {Key? key})
      : this(label, key: key, background: AppColors.error, foreground: AppColors.paper);

  const AppBadge.muted(String label, {Key? key})
      : this(label, key: key, background: AppColors.paperAlt, foreground: AppColors.inkMuted);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      color: background,
      child: Text(
        label,
        style: AppTypography.sectionHeader.copyWith(color: foreground, letterSpacing: 0.8),
      ),
    );
  }
}
