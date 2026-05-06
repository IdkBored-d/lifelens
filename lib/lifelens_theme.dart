import 'package:flutter/material.dart';

const PageTransitionsTheme _lifeLensPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: _LifeLensPageTransitionsBuilder(),
    TargetPlatform.iOS: _LifeLensPageTransitionsBuilder(),
    TargetPlatform.macOS: _LifeLensPageTransitionsBuilder(),
    TargetPlatform.windows: _LifeLensPageTransitionsBuilder(),
    TargetPlatform.linux: _LifeLensPageTransitionsBuilder(),
  },
);

class _LifeLensPageTransitionsBuilder extends PageTransitionsBuilder {
  const _LifeLensPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final primaryCurve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final secondaryCurve = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final enterOffset = Tween<Offset>(
      begin: const Offset(0, 0.018),
      end: Offset.zero,
    ).animate(primaryCurve);
    final exitOffset = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.006),
    ).animate(secondaryCurve);

    return FadeTransition(
      opacity: primaryCurve,
      child: SlideTransition(
        position: exitOffset,
        child: SlideTransition(position: enterOffset, child: child),
      ),
    );
  }
}

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
    splashColor: cs.primary.withValues(alpha: 0.10),
    highlightColor: cs.primary.withValues(alpha: 0.055),
    hoverColor: cs.primary.withValues(alpha: 0.045),
    focusColor: cs.primary.withValues(alpha: 0.08),
    materialTapTargetSize: MaterialTapTargetSize.padded,
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
        animationDuration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        animationDuration: const Duration(milliseconds: 180),
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
        borderSide: BorderSide(color: cs.outline, width: 1.2),
      ),
      hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.75)),
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
  const seed = Color(0xFF4F46E5);

  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
  );

  const appBg = Color(0xFFFFFFFF);
  const surface = Color(0xFFFFFFFF);
  const surfaceSoft = Color(0xFFF1F5F9);
  const surfaceMuted = Color(0xFFF8FAFC);
  const border = Color(0xFFD8DEE8);
  const borderStrong = Color(0xFF94A3B8);
  const text = Color(0xFF0F172A);
  const mutedText = Color(0xFF64748B);
  const primary = Color(0xFF4F46E5);
  const primarySoft = Color(0xFFE0E7FF);
  const secondary = Color(0xFF0F766E);
  const secondarySoft = Color(0xFFCCFBF1);

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primarySoft,
      onPrimaryContainer: const Color(0xFF312E81),
      secondary: secondary,
      onSecondary: Colors.white,
      secondaryContainer: secondarySoft,
      onSecondaryContainer: const Color(0xFF134E4A),
      surface: appBg,
      onSurface: text,
      surfaceBright: surface,
      surfaceDim: surfaceSoft,
      surfaceContainerLowest: surface,
      surfaceContainerLow: const Color(0xFFFBFCFE),
      surfaceContainer: surfaceMuted,
      surfaceContainerHigh: surfaceMuted,
      surfaceContainerHighest: surfaceMuted,
      outline: borderStrong,
      outlineVariant: border,
      onSurfaceVariant: mutedText,
    ),
  );

  final cs = base.colorScheme;

  return base.copyWith(
    splashFactory: InkRipple.splashFactory,
    pageTransitionsTheme: _lifeLensPageTransitionsTheme,
    scaffoldBackgroundColor: appBg,
    canvasColor: surface,
    splashColor: cs.primary.withValues(alpha: 0.09),
    highlightColor: cs.primary.withValues(alpha: 0.045),
    hoverColor: cs.primary.withValues(alpha: 0.035),
    focusColor: cs.primary.withValues(alpha: 0.07),
    materialTapTargetSize: MaterialTapTargetSize.padded,

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
      backgroundColor: surface,
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
        animationDuration: const Duration(milliseconds: 180),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        animationDuration: const Duration(milliseconds: 180),
        elevation: 0,
        backgroundColor: surface,
        foregroundColor: cs.primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant),
        ),
        textStyle: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
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
        borderSide: BorderSide(color: cs.outline, width: 1.2),
      ),
      hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.75)),
    ),

    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant, width: 1),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: surface,
      indicatorColor: cs.primaryContainer,
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
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),

    dividerTheme: DividerThemeData(color: cs.outlineVariant, thickness: 1),
  );
}
