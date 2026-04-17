import 'package:flutter/material.dart';
import '../tokens/app-colors.dart';
import '../tokens/app-typography.dart';

enum _Variant { primary, secondary, ghost, destructive, acid }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final IconData? icon;
  final _Variant _variant;

  const AppButton.primary(
    this.label, {
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.icon,
  }) : _variant = _Variant.primary;

  const AppButton.secondary(
    this.label, {
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.icon,
  }) : _variant = _Variant.secondary;

  const AppButton.ghost(
    this.label, {
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.icon,
  }) : _variant = _Variant.ghost;

  const AppButton.destructive(
    this.label, {
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.icon,
  }) : _variant = _Variant.destructive;

  const AppButton.acid(
    this.label, {
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.icon,
  }) : _variant = _Variant.acid;

  @override
  Widget build(BuildContext context) {
    final bg = switch (_variant) {
      _Variant.primary => AppColors.ink,
      _Variant.secondary => AppColors.paper,
      _Variant.ghost => Colors.transparent,
      _Variant.destructive => AppColors.error,
      _Variant.acid => AppColors.acid,
    };
    final fg = switch (_variant) {
      _Variant.primary => AppColors.paper,
      _Variant.secondary => AppColors.ink,
      _Variant.ghost => AppColors.ink,
      _Variant.destructive => AppColors.paper,
      _Variant.acid => AppColors.ink,
    };
    final side = switch (_variant) {
      _Variant.secondary => const BorderSide(color: AppColors.ink, width: 1),
      _Variant.ghost => const BorderSide(color: AppColors.paperBorder, width: 1),
      _ => BorderSide.none,
    };

    Widget child = isLoading
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: 6),
                  Text(label, style: AppTypography.label.copyWith(color: fg, fontSize: 14)),
                ],
              )
            : Text(label, style: AppTypography.label.copyWith(color: fg, fontSize: 14));

    return SizedBox(
      width: width,
      height: 48,
      child: TextButton(
        onPressed: isLoading ? null : onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          shape: const RoundedRectangleBorder(),
          side: side,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          minimumSize: const Size(64, 48),
        ),
        child: child,
      ),
    );
  }
}
