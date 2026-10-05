import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../atoms/app-button.dart';
import '../atoms/app-sadu-band.dart';
import '../tokens/app-colors.dart';

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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 20, 24, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (currentStep > 0)
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
                      if (currentStep > 0) const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          progressLabel ?? '${currentStep + 1} / $totalSteps',
                          style: GoogleFonts.jetBrainsMono(
                            color: palette.textMuted,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    label: 'Onboarding progress',
                    value: '${currentStep + 1} of $totalSteps',
                    child: AppSaduBand(
                      motif: AppSaduMotif.chevrons,
                      progress: ((currentStep + 1) / totalSteps).clamp(
                        0.0,
                        1.0,
                      ),
                      height: 14,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(child: body),

            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: palette.border, width: 1),
                ),
              ),
              padding: EdgeInsetsDirectional.fromSTEB(
                24,
                16,
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
    );
  }
}
