import 'package:flutter/material.dart';

ThemeData lifeLensDarkTheme() {
  const seed = Color(0xFF6D4CFF);

  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
  );

  const appBg = Color(0xFF0F1014);
  const cardBg = Color(0xFF161824);

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(
      primary: const Color(0xFFBFA5FF),
      primaryContainer: const Color(0xFF2B2540),
      secondary: const Color(0xFFB5C7FF),
      secondaryContainer: const Color(0xFF273049),
      surface: appBg,
      surfaceContainerHighest: cardBg,
      outlineVariant: const Color(0xFF2F3242),
      onSurfaceVariant: const Color(0xFFB8C0D4),
    ),
  );

  final cs = base.colorScheme;

  return base.copyWith(
    scaffoldBackgroundColor: appBg,
    textTheme: base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.4,
        height: 1.05,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.2,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w800,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.25),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.25),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
      ),
      labelMedium: base.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: appBg,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w900,
        color: cs.onSurface,
      ),
      iconTheme: IconThemeData(color: cs.onSurface),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant.withOpacity(0.7)),
        ),
        textStyle: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cs.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.primary.withOpacity(0.8), width: 1.4),
      ),
      hintStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.75)),
    ),
    cardTheme: CardThemeData(
      color: cs.surfaceContainerHighest,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.7)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: appBg,
      indicatorColor: cs.primaryContainer.withOpacity(0.85),
      labelTextStyle: WidgetStatePropertyAll(
        base.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: cs.onSurface);
        }
        return IconThemeData(color: cs.onSurfaceVariant);
      }),
    ),
    dividerTheme: DividerThemeData(
      color: cs.outlineVariant.withOpacity(0.7),
      thickness: 1,
    ),
  );
}

ThemeData lifeLensCalmTheme() {
  const seed = Color(0xFF7C5CFF);

  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
  );

  const appBg = Color(0xFFF4F1FF);
  const cardBg = Color(0xFFE9E2FF);

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(
      primary: const Color(0xFF6D4CFF),
      primaryContainer: const Color(0xFFE1D8FF),
      secondary: const Color(0xFF5A4B86),
      secondaryContainer: const Color(0xFFE6E0FF),
      surface: appBg,
      // Material 3 container tones (used a LOT by your UI)
      surfaceContainerHighest: cardBg,
      outlineVariant: const Color(0xFFD2C9F0),
      onSurfaceVariant: const Color(0xFF5F5A70),
    ),
  );

  final cs = base.colorScheme;

  return base.copyWith(
    scaffoldBackgroundColor: appBg,

    textTheme: base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.4,
        height: 1.05,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.2,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w800,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.25),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.25),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
      ),
      labelMedium: base.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: appBg,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w900,
        color: cs.onSurface,
      ),
      iconTheme: IconThemeData(color: cs.onSurface),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant.withOpacity(0.7)),
        ),
        textStyle: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cs.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.primary.withOpacity(0.8), width: 1.4),
      ),
      hintStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.75)),
    ),

    cardTheme: CardThemeData(
      color: cs.surfaceContainerHighest,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.7)),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: appBg,
      indicatorColor: cs.primaryContainer.withOpacity(0.85),
      labelTextStyle: WidgetStatePropertyAll(
        base.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: cs.onSurface);
        }
        return IconThemeData(color: cs.onSurfaceVariant);
      }),
    ),

    dividerTheme: DividerThemeData(
      color: cs.outlineVariant.withOpacity(0.7),
      thickness: 1,
    ),
  );
}
