import 'package:flutter/material.dart';

import '../atoms/app-sadu-band.dart';
import '../tokens/app-colors.dart';
import '../tokens/app-radii.dart';

class AppDialog extends StatelessWidget {
  final Widget? title;
  final Widget content;
  final List<Widget> actions;

  const AppDialog({
    super.key,
    this.title,
    required this.content,
    this.actions = const [],
  });

  static Future<T?> show<T>({
    required BuildContext context,
    Widget? title,
    required Widget content,
    List<Widget> actions = const [],
  }) {
    final palette = context.nashaatPalette;
    return showDialog<T>(
      context: context,
      barrierColor: palette.scrim,
      builder: (_) =>
          AppDialog(title: title, content: content, actions: actions),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: AppRadii.card,
          border: palette.cardEdge == Colors.transparent
              ? null
              : Border.all(color: palette.cardEdge),
        ),
        child: ClipRRect(
          borderRadius: AppRadii.card,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppSaduBand(motif: AppSaduMotif.diamonds, height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null) ...[
                      DefaultTextStyle(
                        style: Theme.of(context).textTheme.titleMedium!,
                        child: title!,
                      ),
                      const SizedBox(height: 10),
                    ],
                    DefaultTextStyle(
                      style: Theme.of(context).textTheme.bodyMedium!,
                      child: content,
                    ),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: actions,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
