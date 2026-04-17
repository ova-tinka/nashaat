import 'package:flutter/material.dart';
import '../tokens/app-colors.dart';
import '../tokens/app-typography.dart';

class AppCounter extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  const AppCounter({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 99,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: AppTypography.body),
        ),
        _CounterButton(
          icon: Icons.remove,
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 28,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: AppTypography.monoStrong,
          ),
        ),
        const SizedBox(width: 12),
        _CounterButton(
          icon: Icons.add,
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _CounterButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border.all(
            color: enabled ? AppColors.ink : AppColors.paperBorder,
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? AppColors.ink : AppColors.inkMuted,
        ),
      ),
    );
  }
}
