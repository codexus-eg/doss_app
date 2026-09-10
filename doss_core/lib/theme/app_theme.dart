import 'package:flutter/material.dart';

/// DOSS Brand Theme v3 — Official Identity
/// Brand Cyan  #06F6FF  |  Brand Blue #00A3E0  |  Navy Deep #08131F
/// Logo gradient: #00A3E0 → #06F6FF   |   Tagline: تنقل بذكاء • Smart Movement
class AppTheme {
  AppTheme._();

  // ─── Brand Colors ──────────────────────────────────────────────────────────
  static const Color brandCyan    = Color(0xFF06F6FF); // Brand Cyan
  static const Color brandBlue    = Color(0xFF00A3E0); // Brand Blue
  static const Color navyDeep     = Color(0xFF08131F); // Navy Deep
  static const Color primaryDark  = Color(0xFF000000); // App background
  static const Color primaryMid   = Color(0xFF0B0F14); // Elevated navy-black
  static const Color primaryLight = Color(0xFF141A21);
  static const Color primary      = brandCyan;         // ← identity primary
  static const Color primaryLight2= Color(0xFF5FF9FF);
  static const Color accent       = brandBlue;         // gradients / secondary
  static const Color accentDark   = Color(0xFF0077A8);
  static const Color success      = Color(0xFF22C55E);
  static const Color error        = Color(0xFFEF4444);
  static const Color warning      = Color(0xFFF59E0B);
  static const Color surface      = Color(0xFF10161D);
  static const Color surfaceLight = Color(0xFF1B242E);
  static const Color card         = Color(0xFF121920);
  static const Color textPrimary  = Color(0xFFFFFFFF);
  static const Color textSecondary= Color(0xFFA8B3BD);
  static const Color textMuted    = Color(0xFF5F6C79);
  static const Color divider      = Color(0xFF1E2831);
  /// Text/icon color that sits ON a cyan surface (cyan is light → needs black)
  static const Color onBrand      = Color(0xFF000000);

  // ─── Logo gradient (blue → cyan) ───────────────────────────────────────────
  static const Color logoStart    = brandBlue;
  static const Color logoEnd      = brandCyan;
  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandBlue, brandCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Google Maps dark style (navy-tinted, brand-matched) ───────────────────
  static const String mapStyle = '''[
    {"elementType":"geometry","stylers":[{"color":"#0b1219"}]},
    {"elementType":"labels.text.fill","stylers":[{"color":"#7d8b98"}]},
    {"elementType":"labels.text.stroke","stylers":[{"color":"#08131f"}]},
    {"featureType":"road","elementType":"geometry","stylers":[{"color":"#182029"}]},
    {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#232d38"}]},
    {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#1e2a35"}]},
    {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#00a3e0"}]},
    {"featureType":"water","elementType":"geometry","stylers":[{"color":"#050b12"}]},
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"transit","stylers":[{"visibility":"off"}]},
    {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]}
  ]''';

  // ─── Input Decoration ──────────────────────────────────────────────────────
  static InputDecoration inputDecoration({
    String? label,
    String? hint,
    IconData? prefixIcon,
    Widget? suffixIcon,
    String? errorText,
  }) => InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon,
        errorText: errorText,
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: surfaceLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brandCyan, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textMuted),
        prefixIconColor: textSecondary,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      );

  // ─── Dark Theme ────────────────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Poppins',
        colorScheme: const ColorScheme.dark(
          primary: brandCyan,
          onPrimary: onBrand,
          secondary: brandBlue,
          onSecondary: textPrimary,
          surface: surface,
          onSurface: textPrimary,
          error: error,
          onError: textPrimary,
        ),
        scaffoldBackgroundColor: primaryDark,
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryDark,
          foregroundColor: textPrimary,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        cardTheme: CardTheme(
          color: card,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: brandCyan,
            foregroundColor: onBrand,
            disabledBackgroundColor: surface,
            disabledForegroundColor: textMuted,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: brandCyan,
            side: const BorderSide(color: brandCyan, width: 1.5),
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: brandCyan,
            textStyle: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: surfaceLight, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: brandCyan, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: error, width: 1.5),
          ),
          labelStyle: const TextStyle(color: textSecondary),
          hintStyle: const TextStyle(color: textMuted),
          prefixIconColor: textSecondary,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
        dividerTheme: const DividerThemeData(
            color: divider, thickness: 1, space: 1),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: primaryMid,
          selectedItemColor: brandCyan,
          unselectedItemColor: textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: brandCyan,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? brandCyan : textMuted),
          trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? brandCyan.withOpacity(0.35)
                  : surfaceLight),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: primaryMid,
          contentTextStyle: const TextStyle(color: textPrimary),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        textTheme: const TextTheme(
          displayLarge:  TextStyle(color: textPrimary, fontWeight: FontWeight.w800),
          displayMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
          displaySmall:  TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
          headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
          headlineMedium:TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          titleLarge:    TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          titleMedium:   TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
          titleSmall:    TextStyle(color: textSecondary,fontWeight: FontWeight.w500),
          bodyLarge:     TextStyle(color: textPrimary),
          bodyMedium:    TextStyle(color: textSecondary),
          bodySmall:     TextStyle(color: textMuted),
          labelLarge:    TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: textSecondary),
        chipTheme: ChipThemeData(
          backgroundColor: surface,
          selectedColor: brandCyan.withOpacity(0.18),
          labelStyle: const TextStyle(color: textPrimary, fontSize: 13),
          side: const BorderSide(color: surfaceLight),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
}
