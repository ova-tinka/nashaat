import 'package:flutter/material.dart';

import '../tokens/app-colors.dart';
import '../tokens/app-radii.dart';

enum _AppButtonVariant {
  primary,
  secondary,
  ghost,
  reward,
  destructive,
  locked,
}

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final IconData? icon;
  final _AppButtonVariant _variant;

  const AppButton.primary(
    this.label, {
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.icon,
  }) : _variant = _AppButtonVariant.primary;

  const AppButton.secondary(
    this.label, {
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.icon,
  }) : _variant = _AppButtonVariant.secondary;

  const AppButton.ghost(
    this.label, {
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.icon,
  }) : _variant = _AppButtonVariant.ghost;

  const AppButton.reward(
    this.label, {
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.icon,
  }) : _variant = _AppButtonVariant.reward;

  const AppButton.destructive(
    this.label, {
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.icon,
  }) : _variant = _AppButtonVariant.destructive;

  const AppButton.locked(
    this.label, {
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.icon,
  }) : _variant = _AppButtonVariant.locked;

  /// Transitional alias for the former acid action.
  const AppButton.acid(
    this.label, {
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.icon,
  }) : _variant = _AppButtonVariant.primary;

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    final textTheme = Theme.of(context).textTheme;
    final enabled = onPressed != null && !isLoading;

    final (background, foreground, border) = switch (_variant) {
      _AppButtonVariant.primary => (
        palette.accent,
        palette.accentInk,
        BorderSide.none,
      ),
      _AppButtonVariant.secondary => (
        palette.card,
        palette.textPrimary,
        BorderSide(color: palette.border),
      ),
      _AppButtonVariant.ghost => (
        Colors.transparent,
        palette.textPrimary,
        BorderSide(color: palette.border),
      ),
      _AppButtonVariant.reward => (
        palette.reward,
        palette.rewardInk,
        BorderSide.none,
      ),
      _AppButtonVariant.destructive => (
        palette.danger,
        palette.dangerInk,
        BorderSide.none,
      ),
      _AppButtonVariant.locked => (
        palette.locked,
        Colors.white,
        BorderSide.none,
      ),
    };

    final effectiveBackground = enabled ? background : palette.raised;
    final effectiveForeground = enabled ? foreground : palette.textMuted;
    final labelChild = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: textTheme.titleSmall?.copyWith(
        color: effectiveForeground,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );

    final child = isLoading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: effectiveForeground,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: effectiveForeground),
                const SizedBox(width: 8),
              ],
              if (width != null) Flexible(child: labelChild) else labelChild,
            ],
          );

    return SizedBox(
      width: width,
      height: 52,
      child: TextButton(
        onPressed: enabled ? onPressed : null,
        style: TextButton.styleFrom(
          backgroundColor: effectiveBackground,
          foregroundColor: effectiveForeground,
          disabledBackgroundColor: palette.raised,
          disabledForegroundColor: palette.textMuted,
          shape: RoundedRectangleBorder(borderRadius: AppRadii.button),
          side: enabled ? border : BorderSide(color: palette.border),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          minimumSize: const Size(64, 52),
        ),
        child: child,
      ),
    );
  }
}
