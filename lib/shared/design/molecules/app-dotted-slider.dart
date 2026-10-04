import 'package:flutter/material.dart';

import '../tokens/app-colors.dart';

class AppDottedSlider extends StatelessWidget {
  final List<int> values;
  final int value;
  final ValueChanged<int> onChanged;
  final bool useAccent;
  final String? semanticLabel;

  const AppDottedSlider({
    super.key,
    required this.values,
    required this.value,
    required this.onChanged,
    this.useAccent = false,
    this.semanticLabel,
  }) : assert(values.length > 0);

  int get _currentIndex {
    final index = values.indexOf(value);
    if (index >= 0) return index;
    return 0;
  }

  void _selectAt({
    required double position,
    required double width,
    required TextDirection textDirection,
  }) {
    if (values.length == 1 || width <= 0) {
      onChanged(values.first);
      return;
    }

    final normalized = (position / width).clamp(0.0, 1.0);
    final logical = textDirection == TextDirection.rtl
        ? 1 - normalized
        : normalized;
    final index = (logical * (values.length - 1)).round();
    onChanged(values[index]);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    final currentIndex = _currentIndex;
    final active = useAccent ? palette.accent : palette.calm;
    final thumb = palette.textPrimary;
    final direction = Directionality.of(context);

    return Semantics(
      label: semanticLabel,
      value: '$value',
      increasedValue: currentIndex < values.length - 1
          ? '${values[currentIndex + 1]}'
          : null,
      decreasedValue: currentIndex > 0 ? '${values[currentIndex - 1]}' : null,
      onIncrease: currentIndex < values.length - 1
          ? () => onChanged(values[currentIndex + 1])
          : null,
      onDecrease: currentIndex > 0
          ? () => onChanged(values[currentIndex - 1])
          : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _selectAt(
              position: details.localPosition.dx,
              width: width,
              textDirection: direction,
            ),
            onHorizontalDragUpdate: (details) => _selectAt(
              position: details.localPosition.dx,
              width: width,
              textDirection: direction,
            ),
            child: SizedBox(
              height: 36,
              child: Row(
                children: List.generate(values.length, (index) {
                  final isCurrent = index == currentIndex;
                  final isActive = index <= currentIndex;
                  return Expanded(
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: isCurrent ? 22 : 7,
                        height: isCurrent ? 22 : 7,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? thumb
                              : isActive
                              ? active
                              : palette.raised,
                          shape: BoxShape.circle,
                          border: isCurrent
                              ? Border.all(color: active, width: 5)
                              : Border.all(color: palette.border),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          );
        },
      ),
    );
  }
}
