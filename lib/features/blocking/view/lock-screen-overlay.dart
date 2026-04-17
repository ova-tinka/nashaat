import 'package:flutter/material.dart';

import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/design/tokens/app-typography.dart';
import '../view-model/blocking-view-model.dart';

class LockScreenOverlay extends StatelessWidget {
  final BlockingViewModel blockingVm;
  final VoidCallback onStartWorkout;

  const LockScreenOverlay({
    super.key,
    required this.blockingVm,
    required this.onStartWorkout,
  });

  @override
  Widget build(BuildContext context) {
    final vm = blockingVm;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                color: AppColors.errorMuted,
                child: const Icon(Icons.lock_clock, size: 40, color: AppColors.error),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Screen-Time Depleted',
                style: AppTypography.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                "You've used all your earned screen-time. Complete a workout to unlock more time!",
                style: AppTypography.body.copyWith(color: AppColors.inkMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton.primary(
                'Start Workout',
                icon: Icons.fitness_center,
                onPressed: onStartWorkout,
                width: double.infinity,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (vm.emergencyBreakActive)
                _CountdownBanner(vm: vm)
              else if (vm.canRequestBreak)
                _BreakButton(vm: vm)
              else
                Text(
                  'No break time left today. Resets at midnight.',
                  style: AppTypography.labelMuted,
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Break button ──────────────────────────────────────────────────────────────

class _BreakButton extends StatelessWidget {
  final BlockingViewModel vm;
  const _BreakButton({required this.vm});

  @override
  Widget build(BuildContext context) {
    return AppButton.ghost(
      'Take a break  ·  ${vm.remainingBreakMinutes} min left today',
      onPressed: () => _showBreakPicker(context),
    );
  }

  Future<void> _showBreakPicker(BuildContext context) async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(),
      builder: (_) => _BreakPickerSheet(vm: vm),
    );
    if (minutes != null && minutes > 0) {
      await vm.requestEmergencyBreak(minutes);
    }
  }
}

// ── Break picker bottom sheet ─────────────────────────────────────────────────

class _BreakPickerSheet extends StatefulWidget {
  final BlockingViewModel vm;
  const _BreakPickerSheet({required this.vm});

  @override
  State<_BreakPickerSheet> createState() => _BreakPickerSheetState();
}

class _BreakPickerSheetState extends State<_BreakPickerSheet> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.vm.remainingBreakMinutes.clamp(1, 15);
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.vm.remainingBreakMinutes;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.xl, AppSpacing.xl,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 3, color: AppColors.paperBorder),
          const SizedBox(height: AppSpacing.lg),
          Text('Take a Break', style: AppTypography.title),
          const SizedBox(height: 4),
          Text('$max min remaining today', style: AppTypography.labelMuted),
          const SizedBox(height: AppSpacing.xl),
          Text(
            '$_selected',
            style: AppTypography.monoStrong.copyWith(fontSize: 64),
          ),
          Text('minutes', style: AppTypography.labelMuted),
          const SizedBox(height: AppSpacing.base),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.ink,
              inactiveTrackColor: AppColors.paperBorder,
              thumbColor: AppColors.ink,
              overlayColor: AppColors.ink.withValues(alpha: 0.08),
              trackShape: const RectangularSliderTrackShape(),
              thumbShape: const RectangularSliderThumbShape(),
            ),
            child: Slider(
              value: _selected.toDouble(),
              min: 1,
              max: max.toDouble(),
              divisions: max > 1 ? max - 1 : 1,
              onChanged: (v) => setState(() => _selected = v.round()),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1 min', style: AppTypography.labelMuted),
              Text('$max min', style: AppTypography.labelMuted),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Does not replenish your screen-time balance.',
            style: AppTypography.labelMuted,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton.primary(
            'Use $_selected min',
            onPressed: () => Navigator.pop(context, _selected),
            width: double.infinity,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton.ghost(
            'Cancel',
            onPressed: () => Navigator.pop(context, null),
            width: double.infinity,
          ),
        ],
      ),
    );
  }
}

// ── Countdown banner ──────────────────────────────────────────────────────────

class _CountdownBanner extends StatelessWidget {
  final BlockingViewModel vm;
  const _CountdownBanner({required this.vm});

  @override
  Widget build(BuildContext context) {
    final secs = vm.emergencyBreakSecondsRemaining;
    final mins = secs ~/ 60;
    final s = secs % 60;
    final label =
        '${mins.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      color: AppColors.acid,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined, color: AppColors.ink, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Break ends in $label',
                style: AppTypography.monoStrong.copyWith(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Complete a workout before it ends to keep your apps unlocked.',
            style: AppTypography.labelMuted,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Custom rectangular slider shapes for brutalist style
class RectangularSliderTrackShape extends SliderTrackShape {
  const RectangularSliderTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 4;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    return Rect.fromLTWH(offset.dx, trackTop, parentBox.size.width, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final activePaint = Paint()..color = sliderTheme.activeTrackColor ?? AppColors.ink;
    final inactivePaint = Paint()..color = sliderTheme.inactiveTrackColor ?? AppColors.paperBorder;

    context.canvas.drawRect(
      Rect.fromLTRB(trackRect.left, trackRect.top, thumbCenter.dx, trackRect.bottom),
      activePaint,
    );
    context.canvas.drawRect(
      Rect.fromLTRB(thumbCenter.dx, trackRect.top, trackRect.right, trackRect.bottom),
      inactivePaint,
    );
  }
}

class RectangularSliderThumbShape extends SliderComponentShape {
  final double thumbRadius;
  const RectangularSliderThumbShape({this.thumbRadius = 8});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size(thumbRadius * 2, thumbRadius * 2);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final paint = Paint()..color = sliderTheme.thumbColor ?? AppColors.ink;
    context.canvas.drawRect(
      Rect.fromCenter(center: center, width: thumbRadius * 2, height: thumbRadius * 2),
      paint,
    );
  }
}
