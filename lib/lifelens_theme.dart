import 'package:flutter/material.dart';

const PageTransitionsTheme _lifeLensPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
    TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
  },
);

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
      outline: const Color(0xFF3E4255),
      outlineVariant: const Color(0xFF2F3242),
      onSurfaceVariant: const Color(0xFFB8C0D4),
    ),
  );

  final cs = base.colorScheme;

  return base.copyWith(
    splashFactory: InkRipple.splashFactory,
    pageTransitionsTheme: _lifeLensPageTransitionsTheme,
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
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.7)),
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
        borderSide: BorderSide(
          color: cs.outline,
          width: 1.2,
        ),
      ),
      hintStyle: TextStyle(
        color: cs.onSurfaceVariant.withValues(alpha: 0.75),
      ),
    ),
    cardTheme: CardThemeData(
      color: cs.surfaceContainerHighest,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: appBg,
      indicatorColor: cs.primaryContainer.withValues(alpha: 0.85),
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
      color: cs.outlineVariant.withValues(alpha: 0.7),
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

  const appBg = Color(0xFFE7E2EE);
  const cardBg = Color(0xFFDCD4E5);
  const topBarBg = Color(0xFFE1D9E9);

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(
      primary: const Color(0xFF6653C7),
      primaryContainer: const Color(0xFFD0C3EA),
      secondary: const Color(0xFF584A77),
      secondaryContainer: const Color(0xFFD3CBDF),
      surface: appBg,
      surfaceBright: const Color(0xFFEDE8F3),
      surfaceDim: const Color(0xFFD9D1E2),
      surfaceContainerLowest: const Color(0xFFF1ECF7),
      surfaceContainerLow: const Color(0xFFEAE4F0),
      surfaceContainer: const Color(0xFFE5DEEB),
      surfaceContainerHigh: const Color(0xFFE0D8E8),
      // Material 3 container tones (used a LOT by your UI)
      surfaceContainerHighest: cardBg,
      outline: const Color(0xFFAEA4BF),
      outlineVariant: const Color(0xFFBFB5D1),
      onSurfaceVariant: const Color(0xFF555068),
    ),
  );

  final cs = base.colorScheme;

  return base.copyWith(
    splashFactory: InkRipple.splashFactory,
    pageTransitionsTheme: _lifeLensPageTransitionsTheme,
    scaffoldBackgroundColor: appBg,
    canvasColor: cs.surfaceContainerLow,

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
      backgroundColor: topBarBg,
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
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.7)),
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
        borderSide: BorderSide(
          color: cs.outline,
          width: 1.2,
        ),
      ),
      hintStyle: TextStyle(
        color: cs.onSurfaceVariant.withValues(alpha: 0.75),
      ),
    ),

    cardTheme: CardThemeData(
      color: cs.surfaceContainerHighest,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: topBarBg,
      indicatorColor: cs.primaryContainer.withValues(alpha: 0.85),
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

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cs.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cs.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),

    dividerTheme: DividerThemeData(
      color: cs.outlineVariant.withValues(alpha: 0.7),
      thickness: 1,
    ),
  );
}
