import 'package:flutter/material.dart';

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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final vm = blockingVm;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_clock, size: 80, color: cs.error),
              const SizedBox(height: 24),
              Text(
                'Screen-Time Depleted',
                style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "You've used all your earned screen-time. Complete a workout to unlock more time!",
                style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              FilledButton.icon(
                onPressed: onStartWorkout,
                icon: const Icon(Icons.fitness_center),
                label: const Text('Start Workout'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
              const SizedBox(height: 20),
              if (vm.emergencyBreakActive)
                _CountdownBanner(vm: vm)
              else if (vm.canRequestBreak)
                _BreakButton(vm: vm)
              else
                Text(
                  'No break time left today. Resets at midnight.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
    final cs = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: () => _showBreakPicker(context),
      child: Text(
        'Take a break  ·  ${vm.remainingBreakMinutes} min left today',
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
      ),
    );
  }

  Future<void> _showBreakPicker(BuildContext context) async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BreakPickerSheet(vm: vm),
    );
    if (minutes != null && minutes > 0) {
      await vm.requestEmergencyBreak(minutes);
    }
  }
}

// ── Opal-style picker bottom sheet ───────────────────────────────────────────

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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final max = widget.vm.remainingBreakMinutes;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Take a Break',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '$max min remaining today',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          Text(
            '$_selected',
            style: tt.displayLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
          ),
          Text(
            'minutes',
            style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Slider(
            value: _selected.toDouble(),
            min: 1,
            max: max.toDouble(),
            divisions: max > 1 ? max - 1 : 1,
            onChanged: (v) => setState(() => _selected = v.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1 min',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              Text('$max min',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Does not replenish your screen-time balance.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context, _selected),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: Text('Use $_selected min'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined, color: cs.onPrimaryContainer),
              const SizedBox(width: 8),
              Text(
                'Break ends in $label',
                style: tt.titleMedium?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Complete a workout before it ends to keep your apps unlocked.',
            style: tt.bodySmall
                ?.copyWith(color: cs.onPrimaryContainer.withValues(alpha: 0.8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
