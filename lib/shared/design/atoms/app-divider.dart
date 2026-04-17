import 'package:flutter/material.dart';
import '../tokens/app-colors.dart';

class AppDivider extends StatelessWidget {
  final double indent;
  const AppDivider({super.key, this.indent = 0});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppColors.paperBorder,
      indent: indent,
    );
  }
}

class AppVerticalDivider extends StatelessWidget {
  const AppVerticalDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 1,
      height: double.infinity,
      child: ColoredBox(color: AppColors.paperBorder),
    );
  }
}
