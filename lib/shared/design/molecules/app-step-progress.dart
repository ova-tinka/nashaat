import 'package:flutter/material.dart';

import '../atoms/app-sadu-band.dart';
import '../tokens/app-colors.dart';
import '../tokens/app-radii.dart';
import '../tokens/app-spacing.dart';

/// The compact woven progress treatment used by the onboarding references.
class AppStepProgress extends StatelessWidget {
  final int totalSteps;
  final int currentStep;
  final String? label;

  const AppStepProgress({
    super.key,
    required this.totalSteps,
    required this.currentStep,
    this.label,
  }) : assert(totalSteps > 0);

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    final safeStep = currentStep.clamp(0, totalSteps - 1).toInt();
    return Semantics(
      label: 'Onboarding progress',
      value: '${safeStep + 1} of $totalSteps',
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: List.generate(totalSteps, (index) {
                final active = index <= safeStep;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      end: index == totalSteps - 1 ? 0 : AppSpacing.xs,
                    ),
                    child: ClipRRect(
                      borderRadius: AppRadii.sm,
                      child: active
                          ? AppSaduBand(
                              motif: AppSaduMotif.diamonds,
                              height: 18,
                            )
                          : ColoredBox(
                              color: palette.raised,
                              child: const SizedBox(height: 18),
                            ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            label ?? '${safeStep + 1} / $totalSteps',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.textMuted,
              fontFamily: 'JetBrains Mono',
            ),
          ),
        ],
      ),
    );
  }
}
