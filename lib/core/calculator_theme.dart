import 'package:flutter/material.dart';

/// Authentic color palette, LCD 4-level grayscale shades, and physical chassis
/// specifications for the Cal_ 1100_DB_ ClassWiz emulator.
class Cal_Theme {
  Cal_Theme._();

  // ===========================================================================
  // 1. Virtual 192 × 63 Dot-Matrix LCD 4-Level Grayscale Palette
  // ===========================================================================
  static const int lcdWidth = 192;
  static const int lcdHeight = 63;
  static const int statusBarHeight = 8;

  /// Shade 0 (0b00): Unlit reflective FSTN LCD background (#DCE4DC icy-mint/sage)
  static const Color lcdBackground = Color(0xFFDCE4DC);

  /// Shade 1 (0b01): Lightest active grayscale dot (#A6B0A6)
  /// Used for inactive 2D template boxes, subtle gridlines, and icon highlights.
  static const Color lcdShade1 = Color(0xFFA6B0A6);

  /// Shade 2 (0b10): Medium grayscale dot (#6E766E)
  /// Used for secondary dividers, scrollbar tracks, and 3D icon midtones.
  static const Color lcdShade2 = Color(0xFF6E766E);

  /// Shade 3 (0b11 - Mid-Dark): Dark grayscale dot (#363C36)
  /// Used for unfocused text, secondary labels, and inactive status elements.
  static const Color lcdShade3 = Color(0xFF363C36);

  /// Shade 4 (Full Ink): High-contrast active LCD pixel (#101410)
  /// Used for primary characters, active cursor, status badges, and highlights.
  static const Color lcdInk = Color(0xFF101410);

  /// Returns the contrast-adjusted (and optionally inverted) color for a given
  /// 4-level LCD shade (`0..4`), interpolating between soft reflective green/gray
  /// and stark high-contrast monochrome as [contrast] varies from `0` to `15`.
  static Color colorForShade(
    int shade, {
    int contrast = 8,
    bool inverted = false,
  }) {
    final int effectiveShade = inverted
        ? (4 - shade.clamp(0, 4))
        : shade.clamp(0, 4);
    final int c = contrast.clamp(0, 15);
    // t in [-1.0, +1.0]: -1.0 = softest green-gray, 0.0 = default (8), +1.0 = stark monochrome
    final double t = (c - 8) / 7.0;

    if (effectiveShade == 0) {
      if (t >= 0) {
        return Color.lerp(lcdBackground, const Color(0xFFE8EFE8), t * 0.65)!;
      } else {
        return Color.lerp(lcdBackground, const Color(0xFFC5CEC5), -t * 0.55)!;
      }
    }

    final Color base = switch (effectiveShade) {
      1 => lcdShade1,
      2 => lcdShade2,
      3 => lcdShade3,
      _ => lcdInk,
    };

    if (t == 0) return base;
    if (t > 0) {
      // Shift active ink toward stark deep monochrome black
      return Color.lerp(base, const Color(0xFF040604), t * 0.72)!;
    } else {
      // Shift active ink toward softer low-contrast FSTN gray-green
      return Color.lerp(base, lcdBackground, (-t) * 0.45)!;
    }
  }

  // ===========================================================================
  // 2. Physical Chassis, Bezel & Solar Panel Colors (Authentic 1100_DB_ Matte Black)
  // ===========================================================================
  static const Color chassisOuterDark = Color(0xFF161719);
  static const Color chassisSurface = Color(0xFF202124);
  static const Color chassisCarbonAccent = Color(0xFF27282C);
  static const Color bezelMetallicOuter = Color(0xFF191A1D);
  static const Color bezelInnerRecess = Color(0xFF121315);
  static const Color solarPanelGlass = Color(0xFF271715);
  static const Color solarPanelGridLine = Color(0xFF382320);

  // ===========================================================================
  // 3. Tactile 48-Key "Pebble" Keycap Palette
  // ===========================================================================
  /// Top Dark System Round Keys (ON, HOME, SETTINGS, BACK, D-Pad, Page Scroll)
  static const Color keySystemDarkSurface = Color(0xFF232427);
  static const Color keySystemDarkHighlight = Color(0xFF323438);
  static const Color keySystemDarkShadow = Color(0xFF0E0F11);

  /// Metallic Champagne-Gold SHIFT Keycap
  static const Color keyShiftGoldSurface = Color(0xFFA7926E);
  static const Color keyShiftGoldHighlight = Color(0xFFD5C3A1);
  static const Color keyShiftGoldShadow = Color(0xFF5A4C35);

  /// Row 3 & Middle Scientific Round Keys (VARIABLE, FUNCTION, CATALOG, TOOLS, x..tan)
  static const Color keyUtilitySurface = Color(0xFF33353A);
  static const Color keyUtilityHighlight = Color(0xFF45484F);
  static const Color keyUtilityShadow = Color(0xFF121316);

  /// Sculpted Cross 5-Way D-Pad & OK Button
  static const Color dPadSurface = Color(0xFF242529);
  static const Color dPadHighlight = Color(0xFF34363B);
  static const Color dPadCenterOk = Color(0xFF222327);

  /// Middle Scientific Function Keys (12 circular keys)
  static const Color keyScientificSurface = Color(0xFF33353A);
  static const Color keyScientificHighlight = Color(0xFF464950);
  static const Color keyScientificShadow = Color(0xFF121316);

  /// Bottom Numeric, Operator, Clear, FORMAT & EXE Round Keys (20 large circular keys)
  static const Color keyNumericSurface = Color(0xFF3D4045);
  static const Color keyNumericHighlight = Color(0xFF50545B);
  static const Color keyNumericShadow = Color(0xFF141518);

  /// Clear & Backspace Keys (⌫, AC — same charcoal grey family on 1100_DB_)
  static const Color keyClearSurface = Color(0xFF3D4045);
  static const Color keyClearHighlight = Color(0xFF50545B);

  /// Dedicated EXE Key (matches bottom row charcoal pebble buttons on 1100_DB_)
  static const Color keyExeSurface = Color(0xFF3D4045);
  static const Color keyExeHighlight = Color(0xFF50545B);
  static const Color keyExeShadow = Color(0xFF141518);

  // ===========================================================================
  // 4. Silk-Screened Legends & Typography Colors
  // ===========================================================================
  /// Primary white keycap face label
  static const Color labelPrimary = Color(0xFFF2F4F7);

  /// SHIFT secondary function legend (Cal_ Warm Champagne Gold)
  static const Color labelShiftGold = Color(0xFFD8B878);

  /// Variable / Alpha / Hexadecimal sub-legend
  static const Color labelAlphaCyan = Color(0xFF5CC4E0);

  /// Subtle silver-white branding text (`Cal_`, `1100_DB_`, `CLASSWIZ`)
  static const Color brandingSilver = Color(0xFFCACED2);
}
