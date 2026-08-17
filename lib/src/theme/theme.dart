import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() => FlexThemeData.light(
        scheme: FlexScheme.mandyRed,
        surfaceMode: FlexSurfaceMode.highBackgroundLowScaffold,
        blendLevel: 1,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 6,
          useM2StyleDividerInM3: true,
          inputDecoratorSchemeColor: SchemeColor.primary,
          inputDecoratorUnfocusedHasBorder: false,
          cardRadius: 14.0,
          dialogRadius: 18.0,
        ),
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
      );

  static ThemeData dark() => FlexThemeData.dark(
        scheme: FlexScheme.mandyRed,
        surfaceMode: FlexSurfaceMode.highBackgroundLowScaffold,
        blendLevel: 2,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 8,
          useM2StyleDividerInM3: true,
          inputDecoratorSchemeColor: SchemeColor.primary,
          inputDecoratorUnfocusedHasBorder: false,
          cardRadius: 14.0,
          dialogRadius: 18.0,
        ),
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
      );
}
