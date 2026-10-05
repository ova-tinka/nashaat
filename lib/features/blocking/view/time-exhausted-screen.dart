import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/atoms/app-nav-icon.dart';
import '../../../shared/design/atoms/app-status-pill.dart';
import '../../../shared/design/atoms/app-text.dart';
import '../../../shared/design/molecules/app-card.dart';
import '../../../shared/design/organisms/app-scaffold.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../view-model/blocking-view-model.dart';
import 'break-picker-sheet.dart';

class TimeExhaustedScreen extends StatelessWidget {
  final int? nextWorkoutMinutes;
  final int? lockedAppCount;
  final BlockingViewModel? blockingVm;

  const TimeExhaustedScreen({
    super.key,
    this.nextWorkoutMinutes,
    this.lockedAppCount,
    this.blockingVm,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    final reward = nextWorkoutMinutes;
    final hasBreak = blockingVm?.canRequestBreak ?? false;
    final lockedLabel = lockedAppCount != null && lockedAppCount! > 0
        ? '${lockedAppCount!} apps locked'
        : 'Apps locked';

    return AppScaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                24,
                32,
                24,
                AppSpacing.lg,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 72,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: AppStatusPill(
                        label: lockedLabel,
                        icon: Icons.lock_outline,
                        tone: AppStatusTone.locked,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Center(
                      child: AppNavIcon(
                        glyph: AppNavGlyph.fanar,
                        selected: true,
                        color: palette.lockedText,
                        size: 112,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppText.hero(
                      "Time's up,\nfor now.",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppText.body(
                      "You've used all your earned screen time. Finish a workout "
                      'to unlock more time for your apps.',
                      textAlign: TextAlign.center,
                      color: palette.textSecondary,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppCard.standard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: palette.raised,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: Icon(
                                Icons.content_cut,
                                size: 28,
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText.section('YOUR NEXT WORKOUT EARNS'),
                                const SizedBox(height: AppSpacing.xs),
                                AppText.heading(
                                  reward == null || reward <= 0
                                      ? 'More screen time'
                                      : '+${_formatMinutes(reward)}',
                                  color: palette.accentText,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton.primary(
                      'Start a workout',
                      onPressed: () => appCoordinator.showDashboard(),
                      width: double.infinity,
                    ),
                    if (hasBreak) ...[
                      const SizedBox(height: AppSpacing.md),
                      AppButton.ghost(
                        'Take a break · ${blockingVm!.remainingBreakMinutes} min left',
                        onPressed: () => _openBreakPicker(context),
                        width: double.infinity,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    TextButton(
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          appCoordinator.showDashboard();
                        }
                      },
                      child: Text(
                        'Back to app',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openBreakPicker(BuildContext context) async {
    final vm = blockingVm;
    if (vm == null || !vm.canRequestBreak) return;
    final minutes = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlockingBreakPickerSheet(bvm: vm),
    );
    if (minutes != null && minutes > 0) {
      await vm.requestEmergencyBreak(minutes);
    }
  }
}

String _formatMinutes(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) return '${remainder}m';
  return '${hours}h ${remainder.toString().padLeft(2, '0')}m';
}
