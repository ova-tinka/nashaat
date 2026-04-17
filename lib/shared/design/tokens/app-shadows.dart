import 'package:flutter/material.dart';
import 'app-colors.dart';

class AppShadows {
  static const List<BoxShadow> none = [];

  static final List<BoxShadow> subtle = [
    BoxShadow(
      offset: const Offset(0, 1),
      blurRadius: 2,
      color: AppColors.ink.withValues(alpha: 0.08),
    ),
  ];

  static final List<BoxShadow> lift = [
    BoxShadow(
      offset: const Offset(0, 2),
      blurRadius: 4,
      color: AppColors.ink.withValues(alpha: 0.10),
    ),
  ];
}
