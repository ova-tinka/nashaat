import 'package:flutter/material.dart';

import '../atoms/app-nav-icon.dart';
import '../atoms/app-sadu-band.dart';
import '../tokens/app-colors.dart';

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
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.background.withValues(alpha: 0.0),
            palette.background.withValues(alpha: 0.85),
            palette.background,
          ],
          stops: const [0.0, 0.40, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
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
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 2,
                            vertical: 3,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ExcludeSemantics(
                                child: AppNavIcon(
                                  glyph: item.glyph,
                                  selected: selected,
                                  wasmLabel: item.wasmLabel,
                                  size: item.glyph == AppNavGlyph.wasm
                                      ? 26
                                      : 26,
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
                                      fontSize: 10.5,
                                      height: 1.1,
                                      color: selected
                                          ? palette.textPrimary
                                          : palette.textMuted,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              SizedBox(
                                height: 3,
                                child: selected
                                    ? ExcludeSemantics(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: List.generate(
                                            3,
                                            (_) => Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 1.5,
                                                  ),
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  color: palette.reward,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const SizedBox.square(
                                                  dimension: 2.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
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
      ),
    );
  }
}
