import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/design/tokens/app-typography.dart';

class TimeExhaustedScreen extends StatelessWidget {
  const TimeExhaustedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  color: AppColors.errorMuted,
                  child: const Icon(
                    Icons.hourglass_bottom,
                    size: 48,
                    color: AppColors.error,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Screen Time Depleted',
                style: AppTypography.title.copyWith(fontSize: 28),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                "You've used all your earned screen time. Complete a workout to unlock more time for your apps.",
                style: AppTypography.body.copyWith(color: AppColors.inkMuted),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              AppButton.primary(
                'Start a Workout',
                icon: Icons.fitness_center,
                onPressed: () {
                  appCoordinator.showDashboard();
                },
                width: double.infinity,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton.ghost(
                'Back to App',
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    appCoordinator.showDashboard();
                  }
                },
                width: double.infinity,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
