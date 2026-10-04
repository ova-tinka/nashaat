import 'package:flutter/material.dart';

import '../atoms/app-nav-icon.dart';
import '../atoms/app-sadu-band.dart';
import '../tokens/app-colors.dart';
import '../tokens/app-spacing.dart';

class AppBottomNavItem {
  final String label;
  final AppNavGlyph glyph;
  final AppSaduMotif motif;
  final String wasmLabel;

  const AppBottomNavItem({
    required this.label,
    required this.glyph,
    this.motif = AppSaduMotif.diamonds,
    this.wasmLabel = 'N',
  });
}

class AppBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final List<AppBottomNavItem> items;

  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    required this.items,
  }) : assert(items.length > 0);

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    final safeIndex = selectedIndex.clamp(0, items.length - 1).toInt();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.background,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 74,
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final selected = index == safeIndex;
              return Expanded(
                child: Semantics(
                  key: ValueKey<String>('app-tab-${item.label}'),
                  container: true,
                  button: true,
                  selected: selected,
                  label: item.label,
                  onTap: () => onTap(index),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onTap(index),
                      splashColor: Colors.transparent,
                      highlightColor: palette.selection,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          AppSpacing.xs,
                          0,
                          AppSpacing.xs,
                          AppSpacing.xs,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 5,
                              width: double.infinity,
                              child: selected
                                  ? ExcludeSemantics(
                                      child: AppSaduBand(
                                        motif: item.motif,
                                        height: 4,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            const Spacer(),
                            ExcludeSemantics(
                              child: AppNavIcon(
                                glyph: item.glyph,
                                selected: selected,
                                wasmLabel: item.wasmLabel,
                                size: 26,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: selected
                                        ? palette.textPrimary
                                        : palette.textMuted,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
