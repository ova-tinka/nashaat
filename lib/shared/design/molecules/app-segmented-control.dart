import 'package:flutter/material.dart';

import '../tokens/app-colors.dart';
import '../tokens/app-radii.dart';

class AppSegmentOption<T> {
  final T value;
  final String label;
  final IconData? icon;

  const AppSegmentOption({required this.value, required this.label, this.icon});
}

class AppSegmentedControl<T> extends StatelessWidget {
  final List<AppSegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  const AppSegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.well,
        border: Border.all(color: palette.border),
        borderRadius: AppRadii.control,
      ),
      child: Row(
        children: options.map((option) {
          final isSelected = option.value == selected;
          return Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              label: option.label,
              child: GestureDetector(
                onTap: () => onChanged(option.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? palette.card : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(
                            color: palette.border.withValues(alpha: 0.4),
                            width: 0.8,
                          )
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (option.icon != null) ...[
                        Icon(
                          option.icon,
                          size: 15,
                          color: isSelected
                              ? palette.textPrimary
                              : palette.textMuted,
                        ),
                        const SizedBox(width: 5),
                      ],
                      Flexible(
                        child: Text(
                          option.label,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: textTheme.labelMedium?.copyWith(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? palette.textPrimary
                                : palette.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
