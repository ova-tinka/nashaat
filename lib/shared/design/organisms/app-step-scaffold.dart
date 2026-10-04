import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../atoms/app-button.dart';
import '../molecules/app-progress-bar.dart';
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
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress header
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 20, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (currentStep > 0)
                        GestureDetector(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Icon(
                            Icons.arrow_back,
                            size: 20,
                            color: palette.textPrimary,
                          ),
                        ),
                      if (currentStep > 0) const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${currentStep + 1} / $totalSteps',
                          style: GoogleFonts.jetBrainsMono(
                            color: palette.textMuted,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AppStepProgressBar(
                    totalSteps: totalSteps,
                    currentStep: currentStep,
                  ),
                ],
              ),
            ),

            // Content
            Expanded(child: body),

            // Footer
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: palette.border, width: 1),
                ),
              ),
              padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 24, 24),
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
