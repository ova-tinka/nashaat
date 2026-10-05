import 'package:flutter/material.dart';

import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/atoms/app-sadu-band.dart';
import '../../../shared/design/atoms/app-text.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-radii.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../view-model/blocking-view-model.dart';

/// The shared emergency-break sheet used by Focus and the exhausted state.
class BlockingBreakPickerSheet extends StatefulWidget {
  final BlockingViewModel bvm;

  const BlockingBreakPickerSheet({super.key, required this.bvm});

  @override
  State<BlockingBreakPickerSheet> createState() =>
      _BlockingBreakPickerSheetState();
}

class _BlockingBreakPickerSheetState extends State<BlockingBreakPickerSheet> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.bvm.remainingBreakMinutes.clamp(1, 15).toInt();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    final max = widget.bvm.remainingBreakMinutes;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: SizedBox(
                width: 112,
                child: AppSaduBand(motif: AppSaduMotif.diamonds, height: 10),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppText.title('Take a break'),
            const SizedBox(height: AppSpacing.xs),
            AppText.bodyMuted('$max min left today'),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _BreakAdjustButton(
                  icon: Icons.remove,
                  enabled: _selected > 1,
                  onTap: () => setState(() => _selected--),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppText.hero('$_selected'),
                    AppText.bodyMuted('minutes'),
                  ],
                ),
                _BreakAdjustButton(
                  icon: Icons.add,
                  enabled: _selected < max,
                  onTap: () => setState(() => _selected++),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: palette.calm.withValues(alpha: 0.12),
                border: Border.all(color: palette.calmText),
                borderRadius: AppRadii.card,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: palette.calmText),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppText.bodyMuted(
                      "Breaks don't add to your balance. They reset at midnight.",
                    ),
                  ),
                ],
              ),
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
              onPressed: () => Navigator.pop(context),
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakAdjustButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _BreakAdjustButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 28),
      style: IconButton.styleFrom(
        foregroundColor: palette.textPrimary,
        backgroundColor: palette.raised,
        disabledForegroundColor: palette.textMuted,
        minimumSize: const Size(80, 80),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.card),
      ),
    );
  }
}
