import 'package:flutter/material.dart';

abstract final class Responsive {
  static const navigationRailBreakpoint = 760.0;
  static const phoneBreakpoint = 600.0;

  static double pageInset(BuildContext context, {double desktop = 24}) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 380) return 12;
    if (width < phoneBreakpoint) return 16;
    return desktop;
  }

  static EdgeInsets pagePadding(BuildContext context, {double desktop = 24}) =>
      EdgeInsets.all(pageInset(context, desktop: desktop));

  static double fieldWidth(BuildContext context, {required double maximum}) {
    final available = MediaQuery.sizeOf(context).width - 2 * pageInset(context);
    return available.clamp(0.0, maximum).toDouble();
  }
}
