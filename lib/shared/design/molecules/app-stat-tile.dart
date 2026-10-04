import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../tokens/app-colors.dart';
import '../tokens/app-radii.dart';

class AppStatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final Color? accentColor;

  const AppStatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    final textTheme = Theme.of(context).textTheme;
    final valueColor = accentColor ?? palette.textPrimary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.card,
        border: palette.cardEdge == Colors.transparent
            ? null
            : Border.all(color: palette.cardEdge),
        borderRadius: AppRadii.control,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: accentColor ?? palette.textMuted),
            const SizedBox(height: 6),
          ],
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              color: valueColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}
