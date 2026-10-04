import 'package:flutter/material.dart';

import '../tokens/app-colors.dart';
import '../tokens/app-radii.dart';
import '../tokens/app-shadows.dart';

enum _AppCardVariant {
  standard,
  flat,
  reward,
  attention,
  legacyAccent,
  legacySignal,
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final bool shadow;
  final Border? border;
  final VoidCallback? onTap;
  final _AppCardVariant _variant;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.shadow = false,
    this.border,
    this.onTap,
  }) : _variant = _AppCardVariant.standard;

  const AppCard.standard({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry? padding,
    Color? backgroundColor,
    bool shadow = false,
    Border? border,
    VoidCallback? onTap,
  }) : this(
         key: key,
         child: child,
         padding: padding,
         backgroundColor: backgroundColor,
         shadow: shadow,
         border: border,
         onTap: onTap,
       );

  const AppCard.flat({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry? padding,
    Color? backgroundColor,
    bool shadow = false,
    Border? border,
    VoidCallback? onTap,
  }) : this._variant(
         key: key,
         child: child,
         padding: padding,
         backgroundColor: backgroundColor,
         shadow: shadow,
         border: border,
         onTap: onTap,
         variant: _AppCardVariant.flat,
       );

  const AppCard.reward({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry? padding,
    bool shadow = false,
    VoidCallback? onTap,
  }) : this._variant(
         key: key,
         child: child,
         padding: padding,
         shadow: shadow,
         onTap: onTap,
         variant: _AppCardVariant.reward,
       );

  const AppCard.attention({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry? padding,
    bool shadow = false,
    VoidCallback? onTap,
  }) : this._variant(
         key: key,
         child: child,
         padding: padding,
         shadow: shadow,
         onTap: onTap,
         variant: _AppCardVariant.attention,
       );

  /// Transitional alias for the old accent-stripe card.
  const AppCard.accent({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry? padding,
    bool shadow = false,
    VoidCallback? onTap,
  }) : this._variant(
         key: key,
         child: child,
         padding: padding,
         shadow: shadow,
         onTap: onTap,
         variant: _AppCardVariant.legacyAccent,
       );

  /// Transitional alias for the old signal-stripe card.
  const AppCard.signal({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry? padding,
    bool shadow = false,
    VoidCallback? onTap,
  }) : this._variant(
         key: key,
         child: child,
         padding: padding,
         shadow: shadow,
         onTap: onTap,
         variant: _AppCardVariant.legacySignal,
       );

  const AppCard._variant({
    super.key,
    required this.child,
    required _AppCardVariant variant,
    this.padding,
    this.backgroundColor,
    this.shadow = false,
    this.border,
    this.onTap,
  }) : _variant = variant;

  Color _background(NashaatPalette palette) => switch (_variant) {
    _AppCardVariant.standard => backgroundColor ?? palette.card,
    _AppCardVariant.flat => backgroundColor ?? palette.background,
    _AppCardVariant.reward =>
      backgroundColor ?? palette.reward.withValues(alpha: 0.14),
    _AppCardVariant.attention =>
      backgroundColor ?? palette.danger.withValues(alpha: 0.10),
    _AppCardVariant.legacyAccent =>
      backgroundColor ?? palette.accent.withValues(alpha: 0.10),
    _AppCardVariant.legacySignal =>
      backgroundColor ?? palette.reward.withValues(alpha: 0.12),
  };

  Border? _border(NashaatPalette palette) {
    if (border != null) return border;
    return switch (_variant) {
      _AppCardVariant.standard || _AppCardVariant.flat =>
        palette.cardEdge == Colors.transparent
            ? null
            : Border.all(color: palette.cardEdge),
      _AppCardVariant.reward => Border.all(color: palette.rewardText),
      _AppCardVariant.attention => Border.all(color: palette.dangerText),
      _AppCardVariant.legacyAccent => Border.all(color: palette.accentText),
      _AppCardVariant.legacySignal => Border.all(color: palette.rewardText),
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    final decoration = BoxDecoration(
      color: _background(palette),
      border: _border(palette),
      borderRadius: AppRadii.card,
      boxShadow: shadow ? AppShadows.subtle : AppShadows.none,
    );
    final content = Padding(padding: padding ?? EdgeInsets.zero, child: child);
    final decorated = DecoratedBox(decoration: decoration, child: content);

    if (onTap == null) return decorated;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadii.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.card,
        child: decorated,
      ),
    );
  }
}
