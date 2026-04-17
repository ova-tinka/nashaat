import 'package:flutter/material.dart';

import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-typography.dart';

class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.paperBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or continue with', style: AppTypography.labelMuted),
        ),
        const Expanded(child: Divider(color: AppColors.paperBorder)),
      ],
    );
  }
}

class AuthSocialButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onPressed;

  const AuthSocialButton({super.key, required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(label, style: AppTypography.label.copyWith(fontSize: 14)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        alignment: Alignment.center,
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.paperBorder, width: 1),
        shape: const RoundedRectangleBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}

class GoogleIcon extends StatelessWidget {
  const GoogleIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: AppColors.paper,
        border: Border.all(color: AppColors.paperBorder, width: 1),
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}
