import 'package:flutter/material.dart';

import '../tokens/app-colors.dart';

class AppBottomSheet extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppBottomSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 24),
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(20, 16, 20, 24),
    bool isScrollControlled = false,
  }) {
    final palette = context.nashaatPalette;
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: palette.card,
      barrierColor: palette.scrim,
      isScrollControlled: isScrollControlled,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => AppBottomSheet(padding: padding, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(padding: padding, child: child),
    );
  }
}
