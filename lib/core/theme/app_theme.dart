import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Color Palette
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF9D97FF);
  static const Color secondary = Color(0xFF00D9C0);
  static const Color background = Color(0xFF0D0D1A);
  static const Color surface = Color(0xFF16162A);
  static const Color surfaceContainer = Color(0xFF1E1E36);
  static const Color surfaceContainerHigh = Color(0xFF252545);
  static const Color onBackground = Color(0xFFF0F0FF);
  static const Color onSurface = Color(0xFFCCCCEE);
  static const Color onSurfaceMuted = Color(0xFF8888AA);
  static const Color error = Color(0xFFFF6B8A);
  static const Color success = Color(0xFF00D9C0);
  static const Color warning = Color(0xFFFFB74D);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        primaryContainer: Color(0xFF2E2B6E),
        secondary: secondary,
        secondaryContainer: Color(0xFF00695C),
        surface: surface,
        surfaceContainerHighest: surfaceContainerHigh,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: onBackground,
        error: error,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          color: onBackground,
          fontWeight: FontWeight.w700,
          fontSize: 32,
        ),
        headlineLarge: GoogleFonts.inter(
          color: onBackground,
          fontWeight: FontWeight.w700,
          fontSize: 24,
        ),
        headlineMedium: GoogleFonts.inter(
          color: onBackground,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        titleLarge: GoogleFonts.inter(
          color: onBackground,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
        bodyLarge: GoogleFonts.inter(color: onBackground, fontSize: 16),
        bodyMedium: GoogleFonts.inter(color: onSurface, fontSize: 14),
        bodySmall: GoogleFonts.inter(color: onSurfaceMuted, fontSize: 12),
        labelLarge: GoogleFonts.inter(
          color: onBackground,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2A2A50), width: 1),
        ),
        margin: const EdgeInsets.all(0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2A2A50)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2A2A50)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        labelStyle: GoogleFonts.inter(color: onSurfaceMuted),
        hintStyle: GoogleFonts.inter(color: onSurfaceMuted),
        prefixIconColor: onSurfaceMuted,
        suffixIconColor: onSurfaceMuted,
        errorStyle: GoogleFonts.inter(color: error, fontSize: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF3A3A6A),
          disabledForegroundColor: onSurfaceMuted,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: surfaceContainer,
        selectedIconTheme: IconThemeData(color: primary, size: 24),
        selectedLabelTextStyle: TextStyle(
          color: primary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        unselectedIconTheme: IconThemeData(color: onSurfaceMuted, size: 22),
        unselectedLabelTextStyle: TextStyle(
          color: onSurfaceMuted,
          fontSize: 12,
        ),
        indicatorColor: Color(0x226C63FF),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        labelType: NavigationRailLabelType.all,
        groupAlignment: -1.0,
        minWidth: 190,
        minExtendedWidth: 220,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceContainer,
        selectedItemColor: primary,
        unselectedItemColor: onSurfaceMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceContainer,
        foregroundColor: onBackground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: onBackground,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        iconTheme: const IconThemeData(color: onBackground),
        actionsIconTheme: const IconThemeData(color: onSurfaceMuted),
        shape: const Border(
          bottom: BorderSide(color: Color(0xFF2A2A50), width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A2A50),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceContainerHigh,
        contentTextStyle: GoogleFonts.inter(color: onBackground),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(16),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceContainerHigh,
        selectedColor: const Color(0xFF2E2B6E),
        labelStyle: GoogleFonts.inter(color: onSurface, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: const BorderSide(color: Color(0xFF2A2A50)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        titleTextStyle: GoogleFonts.inter(
          color: onBackground,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        contentTextStyle: GoogleFonts.inter(color: onSurface, fontSize: 14),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),
      iconTheme: const IconThemeData(color: onSurface, size: 22),
    );
  }
}
