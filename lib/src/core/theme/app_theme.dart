import 'package:flutter/material.dart';

import '../config/app_config.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    const primary = Color(AppConfig.primaryColorHex);
    const primaryDark = Color(AppConfig.primaryDarkColorHex);
    const secondary = Color(AppConfig.secondaryColorHex);
    const accent = Color(AppConfig.accentColorHex);
    const textPrimary = Color(AppConfig.textPrimaryColorHex);
    const textTertiary = Color(AppConfig.textTertiaryColorHex);
    const lineColor = Color(AppConfig.lineColorHex);

    final base = ThemeData(
      useMaterial3: false,
      fontFamily: 'Poppins',
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: accent,
        surface: secondary,
        error: Color(AppConfig.redColorHex),
      ),
      scaffoldBackgroundColor: secondary,
      dividerColor: lineColor,
      splashColor: primary.withValues(alpha: 0.08),
      highlightColor: primary.withValues(alpha: 0.05),
    );

    return base.copyWith(
      textTheme: base.textTheme
          .apply(
            bodyColor: textPrimary,
            displayColor: textPrimary,
            decorationColor: textPrimary,
          )
          .copyWith(
            bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 14),
            bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 12),
            bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 10),
            titleLarge: base.textTheme.titleLarge?.copyWith(fontSize: 18),
            titleMedium: base.textTheme.titleMedium?.copyWith(fontSize: 14),
            titleSmall: base.textTheme.titleSmall?.copyWith(fontSize: 12),
            labelLarge: base.textTheme.labelLarge?.copyWith(fontSize: 13),
            labelMedium: base.textTheme.labelMedium?.copyWith(fontSize: 11),
          ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: secondary,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: AppConfig.textSizeLarge,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        isDense: true,
        filled: false,
        fillColor: secondary,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 10),
        hintStyle: TextStyle(
          color: textTertiary,
          fontSize: AppConfig.textSizeSmall,
          fontWeight: FontWeight.w600,
        ),
        labelStyle: TextStyle(
          color: textPrimary,
          fontSize: AppConfig.textSizeSmall,
          fontWeight: FontWeight.w700,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: lineColor),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: lineColor),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: textPrimary, width: 1.0),
        ),
        disabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: lineColor),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: const TextStyle(
            fontSize: AppConfig.textSizeMedium,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size.fromHeight(42),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          side: const BorderSide(color: lineColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: const TextStyle(
            fontSize: AppConfig.textSizeMedium,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: secondary,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 40),
          padding: const EdgeInsets.all(8),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        dense: true,
        minVerticalPadding: 6,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        horizontalTitleGap: 10,
        minLeadingWidth: 30,
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          color: textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          color: textTertiary,
          fontSize: 11,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        labelStyle: const TextStyle(fontSize: 11),
        secondaryLabelStyle: const TextStyle(fontSize: 11),
      ),
      dialogTheme: DialogThemeData(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle: const TextStyle(
          fontFamily: 'Poppins',
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Poppins',
          color: textPrimary,
          fontSize: 12,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        constraints: BoxConstraints(maxWidth: 640),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: textPrimary,
        unselectedLabelColor: textTertiary,
        indicatorColor: primary,
        labelStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: AppConfig.textSizeLarge,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: AppConfig.textSizeLarge,
          fontWeight: FontWeight.w600,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryDark,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontFamily: 'Poppins',
          fontSize: AppConfig.textSizeSmall,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
