import 'package:flutter/material.dart';
import '../tokens/app-colors.dart';
import '../tokens/app-shadows.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final bool shadow;
  final Border? border;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.shadow = false,
    this.border,
    this.onTap,
  });

  const AppCard.accent({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry? padding,
    bool shadow = false,
  }) : this(
          key: key,
          child: child,
          padding: padding,
          shadow: shadow,
          border: const Border(left: BorderSide(color: AppColors.acid, width: 3)),
        );

  const AppCard.signal({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry? padding,
    bool shadow = false,
  }) : this(
          key: key,
          child: child,
          padding: padding,
          shadow: shadow,
          border: const Border(left: BorderSide(color: AppColors.signal, width: 3)),
        );

  @override
  Widget build(BuildContext context) {
    final effectiveBorder =
        border ?? Border.all(color: AppColors.paperBorder, width: 1);
    final bg = backgroundColor ?? AppColors.paper;

    Widget content = Container(
      decoration: BoxDecoration(
        color: bg,
        border: effectiveBorder,
        boxShadow: shadow ? AppShadows.subtle : AppShadows.none,
      ),
      child: padding != null
          ? Padding(padding: padding!, child: child)
          : child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        child: content,
      );
    }
    return content;
  }
}
