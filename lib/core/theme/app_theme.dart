import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Spacing constants (4px base grid — UI/UX Section 3.3)
// ---------------------------------------------------------------------------

/// Spacing tokens based on a 4px grid.
abstract final class Spacing {
  /// 4px — tight gaps, icon padding.
  static const double xs = 4;

  /// 8px — between related elements.
  static const double sm = 8;

  /// 16px — standard panel padding, between groups.
  static const double md = 16;

  /// 24px — between sections.
  static const double lg = 24;

  /// 32px — major section breaks.
  static const double xl = 32;
}

// ---------------------------------------------------------------------------
// Custom colour tokens (UI/UX Section 3.1)
// ---------------------------------------------------------------------------

/// Colour tokens for the HeatingPlanner application.
///
/// Includes domain-specific colours not covered by Material's
/// [ColorScheme]. Consumed via
/// `Theme.of(context).extension<HeatingPlannerColors>()!`.
@immutable
class HeatingPlannerColors
    extends ThemeExtension<HeatingPlannerColors> {
  const HeatingPlannerColors({
    required this.wallFill,
    required this.wallStroke,
    required this.windowFill,
    required this.doorFill,
    required this.zoneGreen,
    required this.zoneYellow,
    required this.zoneRed,
    required this.supplyPipe,
    required this.returnPipe,
    required this.gridLine,
    required this.gridDot,
    required this.selectionHighlight,
    required this.hoverHighlight,
  });

  /// Default light-theme colour set.
  factory HeatingPlannerColors.light() {
    return const HeatingPlannerColors(
      wallFill: Color(0xFF374151),
      wallStroke: Color(0xFF111827),
      windowFill: Color(0xFF93C5FD),
      doorFill: Color(0xFFFCD34D),
      zoneGreen: Color(0xFF4CAF50),
      zoneYellow: Color(0xFFFFC107),
      zoneRed: Color(0xFFF44336),
      supplyPipe: Color(0xFFEF4444),
      returnPipe: Color(0xFF3B82F6),
      gridLine: Color(0xFFE5E7EB),
      gridDot: Color(0xFFD1D5DB),
      selectionHighlight: Color(0xFF2E86C1),
      hoverHighlight: Color(0xFF2E86C1),
    );
  }

  /// Wall segment fill colour.
  final Color wallFill;

  /// Wall segment outline colour.
  final Color wallStroke;

  /// Window element fill colour.
  final Color windowFill;

  /// Door element fill colour.
  final Color doorFill;

  /// Heating zone — sufficient output (use with 30% opacity).
  final Color zoneGreen;

  /// Heating zone — marginal output (use with 30% opacity).
  final Color zoneYellow;

  /// Heating zone — insufficient output (use with 30% opacity).
  final Color zoneRed;

  /// Supply pipe routing line colour.
  final Color supplyPipe;

  /// Return pipe routing line colour.
  final Color returnPipe;

  /// Canvas grid line colour.
  final Color gridLine;

  /// Canvas grid dot colour.
  final Color gridDot;

  /// Selected element outline (2px, 50% opacity fill).
  final Color selectionHighlight;

  /// Hover highlight (use with 20% opacity).
  final Color hoverHighlight;

  @override
  HeatingPlannerColors copyWith({
    Color? wallFill,
    Color? wallStroke,
    Color? windowFill,
    Color? doorFill,
    Color? zoneGreen,
    Color? zoneYellow,
    Color? zoneRed,
    Color? supplyPipe,
    Color? returnPipe,
    Color? gridLine,
    Color? gridDot,
    Color? selectionHighlight,
    Color? hoverHighlight,
  }) {
    return HeatingPlannerColors(
      wallFill: wallFill ?? this.wallFill,
      wallStroke: wallStroke ?? this.wallStroke,
      windowFill: windowFill ?? this.windowFill,
      doorFill: doorFill ?? this.doorFill,
      zoneGreen: zoneGreen ?? this.zoneGreen,
      zoneYellow: zoneYellow ?? this.zoneYellow,
      zoneRed: zoneRed ?? this.zoneRed,
      supplyPipe: supplyPipe ?? this.supplyPipe,
      returnPipe: returnPipe ?? this.returnPipe,
      gridLine: gridLine ?? this.gridLine,
      gridDot: gridDot ?? this.gridDot,
      selectionHighlight:
          selectionHighlight ?? this.selectionHighlight,
      hoverHighlight:
          hoverHighlight ?? this.hoverHighlight,
    );
  }

  @override
  HeatingPlannerColors lerp(
    HeatingPlannerColors? other,
    double t,
  ) {
    if (other == null) return this;
    return HeatingPlannerColors(
      wallFill:
          Color.lerp(wallFill, other.wallFill, t)!,
      wallStroke:
          Color.lerp(wallStroke, other.wallStroke, t)!,
      windowFill:
          Color.lerp(windowFill, other.windowFill, t)!,
      doorFill:
          Color.lerp(doorFill, other.doorFill, t)!,
      zoneGreen:
          Color.lerp(zoneGreen, other.zoneGreen, t)!,
      zoneYellow:
          Color.lerp(zoneYellow, other.zoneYellow, t)!,
      zoneRed:
          Color.lerp(zoneRed, other.zoneRed, t)!,
      supplyPipe:
          Color.lerp(supplyPipe, other.supplyPipe, t)!,
      returnPipe:
          Color.lerp(returnPipe, other.returnPipe, t)!,
      gridLine:
          Color.lerp(gridLine, other.gridLine, t)!,
      gridDot:
          Color.lerp(gridDot, other.gridDot, t)!,
      selectionHighlight: Color.lerp(
        selectionHighlight,
        other.selectionHighlight,
        t,
      )!,
      hoverHighlight: Color.lerp(
        hoverHighlight,
        other.hoverHighlight,
        t,
      )!,
    );
  }
}

// ---------------------------------------------------------------------------
// ThemeData factory (UI/UX Section 3)
// ---------------------------------------------------------------------------

/// Application [ThemeData] factory.
abstract final class AppTheme {
  // -- Palette constants from UI/UX Section 3.1 --
  static const _primary = Color(0xFF1B4F72);
  static const _primaryLight = Color(0xFF2E86C1);
  static const _surface = Color(0xFFFFFFFF);
  static const _surfaceVariant = Color(0xFFF5F7FA);
  static const _onSurface = Color(0xFF1A1A2E);
  static const _onSurfaceSecondary = Color(0xFF6B7280);
  static const _errorRed = Color(0xFFDC2626);
  static const _success = Color(0xFF10B981);

  /// Light theme for HeatingPlanner.
  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: _primary,
      primaryContainer: _primaryLight,
      secondary: _primaryLight,
      surface: _surface,
      surfaceContainerHighest: _surfaceVariant,
      onSurface: _onSurface,
      onSurfaceVariant: _onSurfaceSecondary,
      error: _errorRed,
      tertiary: _success,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _surface,

      // -- Typography tokens (Section 3.2) --
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: _onSurface,
        ),
        headlineMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _onSurface,
        ),
        headlineSmall: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: _onSurface,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.normal,
          color: _onSurface,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.normal,
          color: _onSurface,
        ),
        bodySmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.normal,
          color: _onSurfaceSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.normal,
          fontFamily: 'monospace',
          color: _onSurface,
        ),
      ),

      // -- Custom colours --
      extensions: [HeatingPlannerColors.light()],
    );
  }
}
