import 'package:flutter/material.dart';

import '../atoms/app-button.dart';
import '../molecules/app-step-progress.dart';
import 'app-backdrop.dart';
import '../tokens/app-colors.dart';
import '../tokens/app-spacing.dart';

class AppStepScaffold extends StatelessWidget {
  final int totalSteps;
  final int currentStep;
  final Widget body;
  final String nextLabel;
  final VoidCallback? onNext;
  final bool isLoading;
  final String? skipLabel;
  final VoidCallback? onSkip;
  final VoidCallback? onBack;
  final String? progressLabel;
  final String backLabel;

  const AppStepScaffold({
    super.key,
    required this.totalSteps,
    required this.currentStep,
    required this.body,
    this.nextLabel = 'Continue',
    this.onNext,
    this.isLoading = false,
    this.skipLabel,
    this.onSkip,
    this.onBack,
    this.progressLabel,
    this.backLabel = 'Back',
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: IgnorePointer(child: AppBackdrop())),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 24, 12),
                  child: Row(
                    children: [
                      if (currentStep > 0) ...[
                        IconButton(
                          tooltip: backLabel,
                          onPressed:
                              onBack ?? () => Navigator.of(context).maybePop(),
                          icon: Icon(
                            Directionality.of(context) == TextDirection.rtl
                                ? Icons.arrow_forward
                                : Icons.arrow_back,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Expanded(
                        child: AppStepProgress(
                          totalSteps: totalSteps,
                          currentStep: currentStep,
                          label: progressLabel,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: body),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    24,
                    12,
                    24,
                    MediaQuery.viewInsetsOf(context).bottom > 0
                        ? MediaQuery.viewInsetsOf(context).bottom + 12
                        : 24,
                  ),
                  child: Column(
                    children: [
                      AppButton.primary(
                        nextLabel,
                        onPressed: isLoading ? null : onNext,
                        isLoading: isLoading,
                        width: double.infinity,
                      ),
                      if (skipLabel != null) ...[
                        const SizedBox(height: 8),
                        AppButton.ghost(
                          skipLabel!,
                          onPressed: isLoading ? null : onSkip,
                          width: double.infinity,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
