import 'package:flutter/material.dart';
import 'app-colors.dart';

class AppBorders {
  static BoxBorder hairline = Border.all(color: AppColors.paperBorder, width: 1);
  static BoxBorder hairlineInk = Border.all(color: AppColors.ink, width: 1);
  static BoxBorder heavy = Border.all(color: AppColors.ink, width: 2);
  static BoxBorder acid = Border.all(color: AppColors.acid, width: 2);

  static const BorderSide hairlineSide = BorderSide(color: AppColors.paperBorder, width: 1);
  static const BorderSide inkSide = BorderSide(color: AppColors.ink, width: 1);
  static const BorderSide heavySide = BorderSide(color: AppColors.ink, width: 2);
  static const BorderSide acidSide = BorderSide(color: AppColors.acid, width: 2);
  static const BorderSide errorSide = BorderSide(color: AppColors.error, width: 1);
}
