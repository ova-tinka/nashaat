import 'package:flutter/material.dart';

class AppRadii {
  static const double xsValue = 6;
  static const double smValue = 8;
  static const double controlValue = 12;
  static const double buttonValue = 14;
  static const double cardValue = 18;
  static const double pillValue = 999;

  static const BorderRadius xs = BorderRadius.all(Radius.circular(xsValue));
  static const BorderRadius sm = BorderRadius.all(Radius.circular(smValue));
  static const BorderRadius control = BorderRadius.all(
    Radius.circular(controlValue),
  );
  static const BorderRadius button = BorderRadius.all(
    Radius.circular(buttonValue),
  );
  static const BorderRadius card = BorderRadius.all(Radius.circular(cardValue));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(pillValue));

  // Transitional aliases for the old sharp system.
  static const BorderRadius sharp = BorderRadius.zero;
  static const BorderRadius sharpAll = BorderRadius.zero;
}
