import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_modules/table_spreadsheet_mathbox_engine.dart';
import '../core/calculator_theme.dart';
import '../navigation/cw_menu_tree.dart';
import '../state/calculator_controller.dart';
import '../state/calculator_models.dart';
import '../state/calculator_state.dart';
import 'qr_code_generator.dart';
import 'lcd_bitmap_font.dart';
import 'lcd_grid_table_renderer.dart';
import 'math_nodes.dart';

/// High-Resolution 4-Shade FSTN LCD Screen Component for the Cal_ 1100_DB_ ClassWiz.
///
/// Renders crystal-clear, high-DPI vector & textbook typography directly at native
/// device resolution while maintaining the 192×63 [LcdFrameBuffer] state for
/// hardware parity and unit-test verification.
class LcdDisplayWidget extends StatefulWidget {
  const LcdDisplayWidget({super.key});

  @override
  State<LcdDisplayWidget> createState() => _LcdDisplayWidgetState();
}

class _LcdDisplayWidgetState extends State<LcdDisplayWidget> {
  final LcdFrameBuffer _frameBuffer = LcdFrameBuffer(
    width: Cal_Theme.lcdWidth,
    height: Cal_Theme.lcdHeight,
  );

  Timer? _blinkTimer;
  bool _cursorVisible = true;
  bool _hasLeftPanOverflow = false;
  bool _hasRightPanOverflow = false;

  @override
  void initState() {
    super.initState();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) {
        setState(() {
          _cursorVisible = !_cursorVisible;
        });
      }
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = CalculatorScope.of(context);
    final state = controller.state;

    // Update the logical framebuffer for scroll flags
    _updateOverflowFlags(state);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Cal_Theme.bezelMetallicOuter,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: const Color(0xFF0B0C0E),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Cal_Theme.bezelInnerRecess,
          borderRadius: BorderRadius.circular(7),
        ),
        child: AspectRatio(
          aspectRatio: 2.65,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _HiResCal_LcdPainter(
                  state: state,
                  cursorVisible: _cursorVisible,
                  hasLeftPanOverflow: _hasLeftPanOverflow,
                  hasRightPanOverflow: _hasRightPanOverflow,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _updateOverflowFlags(CalculatorState state) {
    _hasLeftPanOverflow = false;
    _hasRightPanOverflow = false;
    if (!state.isPoweredOn) return;
    if (state.activeGridModel != null) {
      final flags = LcdGridTableRenderer.renderGrid(
        _frameBuffer,
        state.activeGridModel!,
        cursorVisible: _cursorVisible,
      );
      _hasLeftPanOverflow = flags.leftOverflow;
      _hasRightPanOverflow = flags.rightOverflow;
    }
  }
}

// =============================================================================
// High-Resolution Vector & Textbook Typography LCD Painter (768 × 290 Virtual Space)
// =============================================================================

class _HiResCal_LcdPainter extends CustomPainter {
  static const double vWidth = 768.0;
  static const double vHeight = 290.0;

  final CalculatorState state;
  final bool cursorVisible;
  final bool hasLeftPanOverflow;
  final bool hasRightPanOverflow;

  _HiResCal_LcdPainter({
    required this.state,
    required this.cursorVisible,
    required this.hasLeftPanOverflow,
    required this.hasRightPanOverflow,
  });

  Color _shade(int level) => Cal_Theme.colorForShade(
        level,
        contrast: state.lcdContrast,
        inverted: state.lcdInverted,
      );

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Fill crisp reflective LCD background (Shade 0)
    final bgPaint = Paint()..color = _shade(0);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Scale virtual 768 × 290 high-res coordinate space onto actual Canvas size
    final double sx = size.width / vWidth;
    final double sy = size.height / vHeight;
    canvas.save();
    canvas.scale(sx, sy);

    if (!state.isPoweredOn) {
      _paintPowerOffScreen(canvas);
      canvas.restore();
      return;
    }

    // 2. Render active screen mode at high resolution
    if (state.errorMessage != null) {
      _paintStatusBar(canvas);
      _paintMainCalculationScreen(canvas);
      _paintErrorModal(canvas, state.errorMessage!);
    } else {
      switch (state.activeOverlay) {
        case ActiveOverlay.homeGrid:
          _paintHomeGrid(canvas);
          break;
        case ActiveOverlay.settingsMenu:
        case ActiveOverlay.catalogMenu:
        case ActiveOverlay.variableMenu:
        case ActiveOverlay.functionMenu:
        case ActiveOverlay.toolsMenu:
        case ActiveOverlay.formatMenu:
          _paintStatusBar(canvas);
          _paintBreadcrumbMenu(canvas);
          break;
        case ActiveOverlay.qrCode:
          if (state.activeQrMatrix != null) {
            _paintQrCodeScreen(canvas, state.activeQrMatrix!);
          } else {
            _paintStatusBar(canvas);
            _paintMainCalculationScreen(canvas);
          }
          break;
        case ActiveOverlay.none:
          _paintStatusBar(canvas);
          _paintMainCalculationScreen(canvas);
          break;
      }
    }

    canvas.restore();

    // Subtle top inner bezel shadow for realistic recessed glass depth
    final glassShadow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.10),
          Colors.transparent,
        ],
        stops: const [0.0, 0.06],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glassShadow);
  }

  // ---------------------------------------------------------------------------
  // 1. Power Off Screen
  // ---------------------------------------------------------------------------
  void _paintPowerOffScreen(Canvas canvas) {
    final border1 = Paint()
      ..color = _shade(1)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final border2 = Paint()
      ..color = _shade(2)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, 18, vWidth - 36, vHeight - 36),
        const Radius.circular(12),
      ),
      border1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(26, 26, vWidth - 52, vHeight - 52),
        const Radius.circular(8),
      ),
      border2,
    );

    _drawCenteredText(
      canvas,
      'Press [ON] to wake',
      const Offset(vWidth / 2, vHeight / 2),
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: _shade(3),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Top Status Bar (y: 0..34)
  // ---------------------------------------------------------------------------
  void _paintStatusBar(Canvas canvas) {
    double x = 14;
    const double y = 6;

    // [S] Shift Badge
    x += _drawStatusPill(canvas, 'S', x, y, active: state.isShift, inverted: true) + 10;

    // [A] Alpha Badge
    x += _drawStatusPill(canvas, 'A', x, y, active: state.isAlpha, inverted: true) + 12;

    // √■ Math I/O Indicator
    _drawMathIoBadge(canvas, x, y, active: state.ioMode.isMathInput);
    x += 42;

    // [D] / [R] / [G] Angle Unit Badge
    x += _drawStatusPill(
          canvas,
          state.angleUnit.badge,
          x,
          y,
          active: true,
          inverted: true,
        ) +
        12;

    // FIX Indicator
    x += _drawStatusPill(
          canvas,
          'FIX',
          x,
          y,
          active: state.numberFormat == NumberFormatMode.fix,
          inverted: false,
        ) +
        10;

    // SCI Indicator
    x += _drawStatusPill(
          canvas,
          'SCI',
          x,
          y,
          active: state.numberFormat == NumberFormatMode.sci,
          inverted: false,
        ) +
        10;

    // f(x) Defined Indicator
    x += _drawStatusPill(
          canvas,
          'f(x)',
          x,
          y,
          active: state.hasFunctionDefined,
          inverted: false,
        ) +
        14;

    // Active Mode Badge
    _drawStatusPill(
      canvas,
      state.activeMode.shortBadge,
      x,
      y,
      active: true,
      inverted: false,
    );

    // Right-aligned scroll & overflow arrows
    _drawStatusArrow(canvas, 655, y + 4, '▲', active: state.canScrollUp);
    _drawStatusArrow(canvas, 682, y + 4, '▼', active: state.canScrollDown);
    _drawStatusArrow(
      canvas,
      709,
      y + 4,
      '◀',
      active: hasLeftPanOverflow ||
          state.hasLeftOverflow ||
          (state.activeOverlay != ActiveOverlay.none &&
              state.menuBreadcrumbs.length > 1) ||
          (state.isResultDisplayed &&
              state.activeFormatView == OutputFormatView.engineering),
    );
    _drawStatusArrow(
      canvas,
      736,
      y + 4,
      '▶',
      active: hasRightPanOverflow ||
          state.hasRightOverflow ||
          (state.isResultDisplayed &&
              state.activeFormatView == OutputFormatView.engineering),
    );

    // Crisp 1.5px status separator line at y = 34
    canvas.drawLine(
      const Offset(0, 34),
      const Offset(vWidth, 34),
      Paint()
        ..color = _shade(2)
        ..strokeWidth = 1.5,
    );
  }

  double _drawStatusPill(
    Canvas canvas,
    String text,
    double x,
    double y, {
    required bool active,
    required bool inverted,
  }) {
    final tp = _layoutText(
      text,
      fontSize: 15.5,
      fontWeight: FontWeight.w800,
      color: !active
          ? _shade(1)
          : (inverted ? _shade(0) : _shade(4)),
    );
    final double w = tp.width + 12;
    const double h = 22;

    if (active && inverted) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          const Radius.circular(4),
        ),
        Paint()..color = _shade(4),
      );
    } else if (active) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          const Radius.circular(4),
        ),
        Paint()
          ..color = _shade(2)
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke,
      );
    }

    tp.paint(canvas, Offset(x + 6, y + (h - tp.height) / 2));
    return w;
  }

  void _drawMathIoBadge(Canvas canvas, double x, double y, {required bool active}) {
    final color = active ? _shade(4) : _shade(1);
    final tp = _layoutText(
      '√■',
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: color,
    );
    tp.paint(canvas, Offset(x, y + 2));
  }

  void _drawStatusArrow(
    Canvas canvas,
    double x,
    double y,
    String symbol, {
    required bool active,
  }) {
    final tp = _layoutText(
      symbol,
      fontSize: 15,
      fontWeight: FontWeight.w800,
      color: active ? _shade(4) : _shade(1),
    );
    tp.paint(canvas, Offset(x, y));
  }

  // ---------------------------------------------------------------------------
  // 3. High-Resolution 3×2 Home Screen App Grid (100% Match to Photo)
  // ---------------------------------------------------------------------------
  void _paintHomeGrid(Canvas canvas) {
    final int selected = state.overlayCursorIndex.clamp(
      0,
      AppMode.values.length - 1,
    );
    final int selectedRow = selected ~/ 3;
    final int topVisibleRow = selectedRow > 1 ? selectedRow - 1 : 0;

    const double tileW = 236.0;
    const double tileH = 128.0;
    const double startX = 14.0;
    const double startY = 12.0;
    const double gapX = 10.0;
    const double gapY = 10.0;

    for (int r = 0; r < 2; r++) {
      final int gridRow = topVisibleRow + r;
      for (int c = 0; c < 3; c++) {
        final int appIdx = gridRow * 3 + c;
        if (appIdx >= AppMode.values.length) continue;

        final app = AppMode.values[appIdx];
        final bool isSelected = appIdx == selected;
        final double tx = startX + c * (tileW + gapX);
        final double ty = startY + r * (tileH + gapY);
        final Rect tileRect = Rect.fromLTWH(tx, ty, tileW, tileH);

        if (isSelected) {
          // Solid black rounded tile highlight around both icon and title (exact match to photo)
          canvas.drawRRect(
            RRect.fromRectAndRadius(tileRect, const Radius.circular(10)),
            Paint()..color = _shade(4),
          );
        }

        // Draw high-resolution 4-shade graphical app icon centered in upper half of tile
        final Rect iconRect = Rect.fromLTWH(
          tx + (tileW - 92) / 2,
          ty + 12,
          92,
          56,
        );
        _paintHiResHomeIcon(canvas, app, iconRect, isSelected: isSelected);

        // Draw centered full application title (e.g. 'Spreadsheet', 'Table', 'Equation')
        _drawCenteredText(
          canvas,
          app.title,
          Offset(tx + tileW / 2, ty + 96),
          fontSize: 27,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          color: isSelected ? _shade(0) : _shade(4),
          maxWidth: tileW - 14,
        );
      }
    }

    // Proportional vertical scrollbar on right edge (x: 748..756)
    const double trackX = 748.0;
    const double trackY = 22.0;
    const double trackH = 246.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(trackX, trackY, 7, trackH),
        const Radius.circular(3.5),
      ),
      Paint()..color = _shade(1),
    );
    final double thumbY = trackY + (selectedRow / 4.0) * (trackH - 68.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(trackX, thumbY, 7, 68),
        const Radius.circular(3.5),
      ),
      Paint()..color = _shade(4),
    );
  }

  void _paintHiResHomeIcon(
    Canvas canvas,
    AppMode app,
    Rect rect, {
    required bool isSelected,
  }) {
    final Color fg = isSelected ? _shade(0) : _shade(4);
    final Color mid = isSelected ? _shade(2) : _shade(2);
    final Color light = isSelected ? _shade(1) : _shade(1);
    final Color boxBg = isSelected ? _shade(3) : _shade(0);

    final strokePaint = Paint()
      ..color = fg
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke;

    switch (app) {
      case AppMode.spreadsheet:
        // Authentic Spreadsheet icon: shaded header row & left column + 3x3 cell grid
        final box = rect.deflate(4);
        canvas.drawRRect(
          RRect.fromRectAndRadius(box, const Radius.circular(4)),
          Paint()..color = isSelected ? _shade(0) : _shade(0),
        );
        // Header row & column shading
        canvas.drawRect(
          Rect.fromLTWH(box.left, box.top, box.width, box.height * 0.32),
          Paint()..color = mid,
        );
        canvas.drawRect(
          Rect.fromLTWH(box.left, box.top, box.width * 0.28, box.height),
          Paint()..color = mid,
        );
        final gridPaint = Paint()
          ..color = _shade(4)
          ..strokeWidth = 2.8
          ..style = PaintingStyle.stroke;
        canvas.drawRRect(
          RRect.fromRectAndRadius(box, const Radius.circular(4)),
          gridPaint,
        );
        // Horizontal & vertical grid lines
        for (final f in [0.32, 0.66]) {
          final y = box.top + box.height * f;
          canvas.drawLine(Offset(box.left, y), Offset(box.right, y), gridPaint);
        }
        for (final f in [0.28, 0.64]) {
          final x = box.left + box.width * f;
          canvas.drawLine(Offset(x, box.top), Offset(x, box.bottom), gridPaint);
        }
        break;

      case AppMode.table:
        // Authentic Table icon: dark top header bar + 2x2 framed cells below
        final box = rect.deflate(6);
        canvas.drawRRect(
          RRect.fromRectAndRadius(box, const Radius.circular(4)),
          Paint()..color = _shade(0),
        );
        canvas.drawRect(
          Rect.fromLTWH(box.left, box.top, box.width, box.height * 0.30),
          Paint()..color = _shade(3),
        );
        final gridPaint = Paint()
          ..color = _shade(4)
          ..strokeWidth = 2.8
          ..style = PaintingStyle.stroke;
        canvas.drawRRect(
          RRect.fromRectAndRadius(box, const Radius.circular(4)),
          gridPaint,
        );
        final double midY = box.top + box.height * 0.65;
        final double midX = box.left + box.width * 0.5;
        canvas.drawLine(Offset(box.left, midY), Offset(box.right, midY), gridPaint);
        canvas.drawLine(
          Offset(midX, box.top + box.height * 0.30),
          Offset(midX, box.bottom),
          gridPaint,
        );
        break;

      case AppMode.equation:
        // Authentic Equation icon: bold 'XY=0' over a 6px shaded underline bar
        _drawCenteredText(
          canvas,
          'XY=0',
          Offset(rect.center.dx, rect.top + 22),
          fontSize: 27,
          fontWeight: FontWeight.w900,
          color: fg,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(rect.left + 6, rect.bottom - 10, rect.width - 12, 7),
            const Radius.circular(2),
          ),
          Paint()..color = mid,
        );
        break;

      case AppMode.inequality:
        // Authentic Inequality icon: bold 'XY>0' over a 6px shaded underline bar
        _drawCenteredText(
          canvas,
          'XY>0',
          Offset(rect.center.dx, rect.top + 22),
          fontSize: 27,
          fontWeight: FontWeight.w900,
          color: fg,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(rect.left + 6, rect.bottom - 10, rect.width - 12, 7),
            const Radius.circular(2),
          ),
          Paint()..color = mid,
        );
        break;

      case AppMode.complex:
        // Authentic Complex icon: dark outer box with white '[i]' left half and '∠' right half
        final box = rect.deflate(5);
        canvas.drawRRect(
          RRect.fromRectAndRadius(box, const Radius.circular(5)),
          Paint()..color = _shade(4),
        );
        final leftInner = Rect.fromLTWH(
          box.left + 4,
          box.top + 4,
          box.width * 0.44,
          box.height - 8,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(leftInner, const Radius.circular(3)),
          Paint()..color = _shade(0),
        );
        _drawCenteredText(
          canvas,
          'i',
          leftInner.center,
          fontSize: 26,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          color: _shade(4),
        );
        _drawCenteredText(
          canvas,
          '∠',
          Offset(box.left + box.width * 0.74, box.center.dy),
          fontSize: 25,
          fontWeight: FontWeight.w800,
          color: _shade(0),
        );
        break;

      case AppMode.baseN:
        // Authentic Base-N icon: staggered '2 8 10 16' radices over a shaded bar
        _drawCenteredText(
          canvas,
          '2 8 10 16',
          Offset(rect.center.dx, rect.top + 22),
          fontSize: 21,
          fontWeight: FontWeight.w900,
          color: fg,
          maxWidth: rect.width - 4,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(rect.left + 6, rect.bottom - 10, rect.width - 12, 7),
            const Radius.circular(2),
          ),
          Paint()..color = mid,
        );
        break;

      case AppMode.calculate:
        final box = rect.deflate(6);
        canvas.drawRRect(
          RRect.fromRectAndRadius(box, const Radius.circular(5)),
          Paint()..color = light,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(box, const Radius.circular(5)),
          strokePaint,
        );
        _drawCenteredText(
          canvas,
          '+ −',
          Offset(box.center.dx, box.top + box.height * 0.30),
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: _shade(4),
        );
        _drawCenteredText(
          canvas,
          '× ÷',
          Offset(box.center.dx, box.top + box.height * 0.72),
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: _shade(4),
        );
        break;

      case AppMode.statistics:
        final box = rect.deflate(6);
        canvas.drawRect(
          Rect.fromLTWH(box.left + 8, box.bottom - 22, 16, 22),
          Paint()..color = mid,
        );
        canvas.drawRect(
          Rect.fromLTWH(box.left + 30, box.bottom - 40, 16, 40),
          Paint()..color = fg,
        );
        canvas.drawRect(
          Rect.fromLTWH(box.left + 52, box.bottom - 30, 16, 30),
          Paint()..color = light,
        );
        canvas.drawLine(
          Offset(box.left, box.bottom),
          Offset(box.right, box.bottom),
          strokePaint,
        );
        break;

      case AppMode.distribution:
        final box = rect.deflate(6);
        final path = Path()
          ..moveTo(box.left, box.bottom - 2)
          ..cubicTo(
            box.left + box.width * 0.28,
            box.bottom - 2,
            box.left + box.width * 0.35,
            box.top + 4,
            box.center.dx,
            box.top + 4,
          )
          ..cubicTo(
            box.left + box.width * 0.65,
            box.top + 4,
            box.left + box.width * 0.72,
            box.bottom - 2,
            box.right,
            box.bottom - 2,
          );
        canvas.drawPath(path, strokePaint);
        canvas.drawLine(
          Offset(box.left, box.bottom - 2),
          Offset(box.right, box.bottom - 2),
          strokePaint,
        );
        break;

      case AppMode.matrix:
        _drawCenteredText(
          canvas,
          '[ a  b ]',
          Offset(rect.center.dx, rect.top + 16),
          fontSize: 21,
          fontWeight: FontWeight.w900,
          color: fg,
        );
        _drawCenteredText(
          canvas,
          '[ c  d ]',
          Offset(rect.center.dx, rect.top + 38),
          fontSize: 21,
          fontWeight: FontWeight.w900,
          color: fg,
        );
        break;

      case AppMode.vector:
        final box = rect.deflate(8);
        canvas.drawLine(
          Offset(box.left + 8, box.bottom),
          Offset(box.right - 8, box.top + 6),
          strokePaint,
        );
        canvas.drawLine(
          Offset(box.right - 8, box.top + 6),
          Offset(box.right - 22, box.top + 8),
          strokePaint,
        );
        canvas.drawLine(
          Offset(box.right - 8, box.top + 6),
          Offset(box.right - 10, box.top + 20),
          strokePaint,
        );
        break;

      case AppMode.ratio:
        _drawCenteredText(
          canvas,
          'a:b=x:d',
          Offset(rect.center.dx, rect.top + 22),
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: fg,
          maxWidth: rect.width - 4,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(rect.left + 6, rect.bottom - 10, rect.width - 12, 7),
            const Radius.circular(2),
          ),
          Paint()..color = mid,
        );
        break;

      case AppMode.mathBox:
        final dieRect = Rect.fromLTWH(rect.left + 12, rect.top + 6, 38, 38);
        canvas.drawRRect(
          RRect.fromRectAndRadius(dieRect, const Radius.circular(6)),
          Paint()..color = boxBg,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(dieRect, const Radius.circular(6)),
          strokePaint,
        );
        for (final off in [
          const Offset(-9, -9),
          Offset.zero,
          const Offset(9, 9),
        ]) {
          canvas.drawCircle(dieRect.center + off, 3.2, Paint()..color = fg);
        }
        canvas.drawCircle(
          Offset(rect.right - 22, rect.center.dy + 4),
          15,
          strokePaint,
        );
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // 4. High-Resolution Main Calculation & 2D Natural Textbook Screen
  // ---------------------------------------------------------------------------
  void _paintMainCalculationScreen(Canvas canvas) {
    // 0. App Startup Selection Menu (e.g., Distribution, Statistics, Equation, Inequality, Ratio, Math Box)
    if (state.menuBreadcrumbs.isNotEmpty) {
      _paintBreadcrumbMenu(canvas);
      return;
    }

    final String? promptTarget = state.definingPromptTarget;

    // 1. Math Box -> Number Line view
    if (promptTarget == null &&
        state.activeMode == AppMode.mathBox &&
        state.activeMathBoxTool == MathBoxSubTool.numberLine) {
      _paintHiResNumberLine(canvas);
      return;
    }

    // 2. Multi-Line Solver / Statistics / Distribution / Math Box Summary screen
    if (promptTarget == null && state.multiLineResultLines != null) {
      _paintHiResMultiLineResults(
        canvas,
        title: state.multiLineResultTitle ?? state.activeMode.title,
        lines: state.multiLineResultLines!,
        selectedIndex: state.multiLineCursorIndex,
      );
      return;
    }

    // 3. Specialized 2D Grid & Table Editor
    if (promptTarget == null && state.activeGridModel != null) {
      _paintHiResGridEditor(canvas, state.activeGridModel!);
      return;
    }

    double topWorkspaceY = 40.0;
    if (promptTarget != null) {
      final String bannerLabel = (promptTarget == 'f' || promptTarget == 'g')
          ? 'Define $promptTarget(x) ='
          : promptTarget == 'SOLVER_EQ'
              ? 'Equation Solver (Enter Eq):'
              : promptTarget == 'SOLVER_X'
                  ? 'Solve for x (Initial x =):'
                  : 'Store $promptTarget =';
      canvas.drawRect(
        const Rect.fromLTWH(0, 35, vWidth, 34),
        Paint()..color = _shade(2),
      );
      _drawLeftText(
        canvas,
        bannerLabel,
        const Offset(14, 40),
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: _shade(0),
      );
      topWorkspaceY = 74.0;
    } else if (state.activeMode == AppMode.baseN) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(10, 40, 92, 30),
          const Radius.circular(5),
        ),
        Paint()..color = _shade(3),
      );
      _drawCenteredText(
        canvas,
        state.activeBase.badge,
        const Offset(56, 55),
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: _shade(0),
      );
      topWorkspaceY = 76.0;
    }

    final MathContainerNode? rootNode = state.rootMathNode;
    final bool hasAst = rootNode != null && rootNode.children.isNotEmpty;

    if (!hasAst && !state.isResultDisplayed) {
      double cursorY = topWorkspaceY + 14;
      if (promptTarget == null &&
          state.history.isNotEmpty &&
          state.historyCursor == -1) {
        final prev = state.history.last;
        final String histSummary =
            '${prev.expressionText} = ${prev.resultText}';
        _drawLeftText(
          canvas,
          histSummary,
          Offset(16, topWorkspaceY + 2),
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: _shade(2),
          maxWidth: vWidth - 32,
        );
        canvas.drawLine(
          Offset(12, topWorkspaceY + 34),
          Offset(vWidth - 12, topWorkspaceY + 34),
          Paint()
            ..color = _shade(1)
            ..strokeWidth = 1.5,
        );
        cursorY = topWorkspaceY + 46;
      }

      if (cursorVisible) {
        canvas.drawRect(
          Rect.fromLTWH(
            18,
            cursorY,
            state.isInsertMode ? 4.5 : 16.0,
            36,
          ),
          Paint()..color = _shade(4),
        );
      }

      if (state.isVerifyMode) {
        _drawRightText(
          canvas,
          'VERIFY MODE',
          const Offset(vWidth - 16, vHeight - 36),
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _shade(2),
        );
      }
      return;
    }

    // Measure & Paint High-Resolution 2D Math AST in upper workspace
    if (rootNode != null) {
      final double availW = vWidth - 32.0;
      final double availH =
          (state.resultText.isNotEmpty ? 192.0 : 275.0) - topWorkspaceY;

      double baseFontSize = 32.0;
      _HiResBoxMetrics rootMetrics = _measureHiResContainer(
        rootNode,
        fontSize: baseFontSize,
      );
      if (rootMetrics.height > availH - 8.0 && rootMetrics.height > 0) {
        baseFontSize =
            (32.0 * (availH - 8.0) / rootMetrics.height).clamp(19.0, 32.0);
        rootMetrics = _measureHiResContainer(
          rootNode,
          fontSize: baseFontSize,
        );
      }

      final hiResCtx = _HiResMathRenderContext(
        activeContainerId: state.activeContainerId,
        activeChildIndex: state.activeChildIndex,
        cursorVisible: cursorVisible && !state.isResultDisplayed,
        isInsertMode: state.isInsertMode,
        inkColor: _shade(4),
        placeholderColor: _shade(3),
      );

      // Measure cursor X recursively to support smooth horizontal auto-scroll
      final double cursorX = _locateCursorXInContainer(
        rootNode,
        fontSize: baseFontSize,
        activeContainerId: state.activeContainerId,
        activeChildIndex: state.activeChildIndex,
      ) ??
          rootMetrics.width;

      double scrollX = 0.0;
      if (cursorX > availW - 36) {
        scrollX = cursorX - (availW - 36);
      }

      final double startY = topWorkspaceY +
          math.max(4.0, (availH - rootMetrics.height) * 0.42);

      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(10, topWorkspaceY, vWidth - 20, availH),
      );
      _paintHiResContainer(
        canvas,
        rootNode,
        18.0 - scrollX,
        startY + rootMetrics.ascent,
        fontSize: baseFontSize,
        ctx: hiResCtx,
      );
      canvas.restore();
    }

    // Render High-Resolution Bottom-Right Result Area (y: 196..282)
    if (state.resultText.isNotEmpty) {
      final String badgeText = _formatViewBadge(state);
      if (badgeText.isNotEmpty) {
        final tpBadge = _layoutText(
          badgeText,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: _shade(4),
        );
        final Rect badgeRect = Rect.fromLTWH(
          16,
          vHeight - 52,
          tpBadge.width + 18,
          30,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(badgeRect, const Radius.circular(5)),
          Paint()..color = _shade(1),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(badgeRect, const Radius.circular(5)),
          Paint()
            ..color = _shade(3)
            ..strokeWidth = 1.6
            ..style = PaintingStyle.stroke,
        );
        tpBadge.paint(canvas, Offset(25, badgeRect.top + 4));
      }

      // 2D Natural Textbook Result Formatting
      if (state.activeFormatView == OutputFormatView.recurringDecimal &&
          state.resultText.contains('(') &&
          state.resultText.endsWith(')')) {
        _paintHiResRecurringDecimalResult(canvas, state.resultText);
      } else if (RegExp(r'^-?\d+\s+\d+/\d+$').hasMatch(state.resultText)) {
        _paintHiResMixedFractionResult(canvas, state.resultText);
      } else if (_is2dFractionResultString(state.resultText)) {
        _paintHiRes2dFractionResult(canvas, state.resultText);
      } else if (state.resultText.contains('√') ||
          state.resultText.contains('^')) {
        _paintHiResRichMathResult(canvas, state.resultText, fontSize: 38);
      } else {
        _drawRightText(
          canvas,
          state.resultText,
          const Offset(vWidth - 18, vHeight - 62),
          fontSize: 42,
          fontWeight: FontWeight.w800,
          color: _shade(4),
          maxWidth: vWidth - 110,
        );
      }
    }
  }

  bool _is2dFractionResultString(String text) {
    final int slashIdx = text.indexOf('/');
    if (slashIdx <= 0 || slashIdx >= text.length - 1) return false;
    if (text.indexOf('/', slashIdx + 1) != -1) return false;
    // Avoid treating dates or unit strings with spaces as simple 2D fractions
    if (text.contains(' ')) return false;
    return true;
  }

  void _paintHiResMixedFractionResult(Canvas canvas, String mixedStr) {
    final bool isNeg = mixedStr.startsWith('-');
    final String clean = isNeg ? mixedStr.substring(1) : mixedStr;
    final List<String> spaceParts = clean.split(RegExp(r'\s+'));
    if (spaceParts.length != 2) return;
    final String wholePart = spaceParts[0];
    final List<String> fracParts = spaceParts[1].split('/');
    if (fracParts.length != 2) return;

    final double numW = _measureRichMathStringWidth(fracParts[0], fontSize: 24);
    final double denW = _measureRichMathStringWidth(fracParts[1], fontSize: 24);
    final double barW = math.max(numW, denW) + 16;
    final double rightEdge = vWidth - 20;
    final double barLeft = rightEdge - barW;
    const double barY = vHeight - 44;

    canvas.drawLine(
      Offset(barLeft, barY),
      Offset(rightEdge, barY),
      Paint()
        ..color = _shade(4)
        ..strokeWidth = 2.8,
    );
    _paintRichMathStringSegment(
      canvas,
      fracParts[0],
      Offset(barLeft + (barW - numW) / 2, barY - 30),
      fontSize: 24,
      color: _shade(4),
    );
    _paintRichMathStringSegment(
      canvas,
      fracParts[1],
      Offset(barLeft + (barW - denW) / 2, barY + 3),
      fontSize: 24,
      color: _shade(4),
    );

    final String prefix = isNeg ? '−$wholePart' : wholePart;
    final tpWhole = _layoutText(
      prefix,
      fontSize: 34,
      fontWeight: FontWeight.w800,
      color: _shade(4),
    );
    tpWhole.paint(
      canvas,
      Offset(barLeft - tpWhole.width - 8, barY - tpWhole.height / 2),
    );
  }

  void _paintHiRes2dFractionResult(Canvas canvas, String fractionStr) {
    final bool isNeg =
        fractionStr.startsWith('-') && !fractionStr.startsWith('-(');
    final String clean = isNeg ? fractionStr.substring(1) : fractionStr;
    final int slashIdx = clean.indexOf('/');
    String numStr = clean.substring(0, slashIdx);
    String denStr = clean.substring(slashIdx + 1);
    if (numStr.startsWith('(') &&
        numStr.endsWith(')') &&
        _hasBalancedOuterParens(numStr)) {
      numStr = numStr.substring(1, numStr.length - 1);
    }

    final double numW = _measureRichMathStringWidth(numStr, fontSize: 24);
    final double denW = _measureRichMathStringWidth(denStr, fontSize: 24);
    final double barW = math.max(numW, denW) + 18;
    final double rightEdge = vWidth - 20;
    final double barLeft = rightEdge - barW;
    const double barY = vHeight - 44;

    canvas.drawLine(
      Offset(barLeft, barY),
      Offset(rightEdge, barY),
      Paint()
        ..color = _shade(4)
        ..strokeWidth = 3.0,
    );
    _paintRichMathStringSegment(
      canvas,
      numStr,
      Offset(barLeft + (barW - numW) / 2, barY - 31),
      fontSize: 24,
      color: _shade(4),
    );
    _paintRichMathStringSegment(
      canvas,
      denStr,
      Offset(barLeft + (barW - denW) / 2, barY + 3),
      fontSize: 24,
      color: _shade(4),
    );

    if (isNeg) {
      final tpMinus = _layoutText(
        '−',
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: _shade(4),
      );
      tpMinus.paint(
        canvas,
        Offset(barLeft - tpMinus.width - 8, barY - tpMinus.height / 2),
      );
    }
  }

  bool _hasBalancedOuterParens(String s) {
    if (!s.startsWith('(') || !s.endsWith(')')) return false;
    int depth = 0;
    for (int i = 0; i < s.length; i++) {
      if (s[i] == '(') depth++;
      if (s[i] == ')') depth--;
      if (depth == 0 && i < s.length - 1) return false;
    }
    return depth == 0;
  }

  void _paintHiResRichMathResult(
    Canvas canvas,
    String text, {
    required double fontSize,
  }) {
    double size = fontSize;
    double totalW = _measureRichMathStringWidth(text, fontSize: size);
    const double maxW = vWidth - 110;
    while (totalW > maxW && size > 18) {
      size -= 2.0;
      totalW = _measureRichMathStringWidth(text, fontSize: size);
    }
    final double startX = vWidth - 20 - totalW;
    final double topY = vHeight - 22 - size * 1.05;
    _paintRichMathStringSegment(
      canvas,
      text,
      Offset(startX, topY),
      fontSize: size,
      color: _shade(4),
    );
  }

  double _measureRichMathStringWidth(String text, {required double fontSize}) {
    double w = 0;
    int i = 0;
    while (i < text.length) {
      if (text[i] == '√') {
        i++;
        String rad = '';
        if (i < text.length && text[i] == '(') {
          int depth = 1;
          i++;
          while (i < text.length && depth > 0) {
            if (text[i] == '(') depth++;
            if (text[i] == ')') depth--;
            if (depth > 0) rad += text[i];
            i++;
          }
        } else {
          while (i < text.length && RegExp(r'[0-9a-zA-Z.]').hasMatch(text[i])) {
            rad += text[i];
            i++;
          }
        }
        final tpRad = _layoutText(
          rad,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: Colors.black,
        );
        w += fontSize * 0.48 + tpRad.width + 6;
      } else if (text[i] == '^') {
        i++;
        String exp = '';
        while (i < text.length &&
            RegExp(r'[-+0-9a-zA-Z.]').hasMatch(text[i]) &&
            text[i] != '×') {
          exp += text[i];
          i++;
        }
        final tpExp = _layoutText(
          exp,
          fontSize: fontSize * 0.65,
          fontWeight: FontWeight.w800,
          color: Colors.black,
        );
        w += tpExp.width + 2;
      } else {
        final String ch = text[i] == '-' ? '−' : text[i];
        final tp = _layoutText(
          ch,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: Colors.black,
        );
        w += tp.width;
        i++;
      }
    }
    return w;
  }

  void _paintRichMathStringSegment(
    Canvas canvas,
    String text,
    Offset topLeft, {
    required double fontSize,
    required Color color,
  }) {
    double curX = topLeft.dx;
    final double topY = topLeft.dy;
    int i = 0;
    while (i < text.length) {
      if (text[i] == '√') {
        i++;
        String rad = '';
        if (i < text.length && text[i] == '(') {
          int depth = 1;
          i++;
          while (i < text.length && depth > 0) {
            if (text[i] == '(') depth++;
            if (text[i] == ')') depth--;
            if (depth > 0) rad += text[i];
            i++;
          }
        } else {
          while (i < text.length && RegExp(r'[0-9a-zA-Z.]').hasMatch(text[i])) {
            rad += text[i];
            i++;
          }
        }
        final tpRad = _layoutText(
          rad,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: color,
        );
        final double hookW = fontSize * 0.45;
        final double radTopY = topY + 2;
        final double radBottomY = topY + fontSize * 0.96;
        final Path path = Path()
          ..moveTo(curX, topY + fontSize * 0.58)
          ..lineTo(curX + hookW * 0.32, topY + fontSize * 0.54)
          ..lineTo(curX + hookW * 0.64, radBottomY)
          ..lineTo(curX + hookW, radTopY)
          ..lineTo(curX + hookW + tpRad.width + 4, radTopY)
          ..lineTo(curX + hookW + tpRad.width + 4, radTopY + 4);
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..strokeWidth = 2.4
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.stroke,
        );
        tpRad.paint(canvas, Offset(curX + hookW + 2, topY + 3));
        curX += hookW + tpRad.width + 6;
      } else if (text[i] == '^') {
        i++;
        String exp = '';
        while (i < text.length &&
            RegExp(r'[-+0-9a-zA-Z.]').hasMatch(text[i]) &&
            text[i] != '×') {
          exp += text[i];
          i++;
        }
        final tpExp = _layoutText(
          exp.replaceAll('-', '−'),
          fontSize: fontSize * 0.65,
          fontWeight: FontWeight.w800,
          color: color,
        );
        tpExp.paint(canvas, Offset(curX + 1, topY - fontSize * 0.16));
        curX += tpExp.width + 2;
      } else {
        final String ch = text[i] == '-' ? '−' : text[i];
        final tp = _layoutText(
          ch,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: color,
        );
        tp.paint(canvas, Offset(curX, topY + 2));
        curX += tp.width;
        i++;
      }
    }
  }

  void _paintHiResRecurringDecimalResult(Canvas canvas, String raw) {
    final int openIdx = raw.indexOf('(');
    final String prefix = raw.substring(0, openIdx);
    final String repeating = raw.substring(openIdx + 1, raw.length - 1);
    final String cleanDisplay = '$prefix$repeating';

    final tpFull = _layoutText(
      cleanDisplay,
      fontSize: 40,
      fontWeight: FontWeight.w800,
      color: _shade(4),
    );
    final tpPrefix = _layoutText(
      prefix,
      fontSize: 40,
      fontWeight: FontWeight.w800,
      color: _shade(4),
    );
    final double startX = vWidth - 18 - tpFull.width;
    const double topY = vHeight - 60;
    tpFull.paint(canvas, Offset(startX, topY));

    // Overline bar above repeating digits
    canvas.drawLine(
      Offset(startX + tpPrefix.width, topY - 2),
      Offset(startX + tpFull.width, topY - 2),
      Paint()
        ..color = _shade(4)
        ..strokeWidth = 3.0,
    );
  }

  String _formatViewBadge(CalculatorState state) {
    return switch (state.activeFormatView) {
      OutputFormatView.standard =>
        state.alternateResultText != null
            ? (state.isShowingExactForm ? 'STD' : 'DEC')
            : '',
      OutputFormatView.decimal => 'DEC',
      OutputFormatView.recurringDecimal => 'REC',
      OutputFormatView.improperFraction => 'd/c',
      OutputFormatView.mixedFraction => 'ab/c',
      OutputFormatView.engineering => 'ENG',
      OutputFormatView.sexagesimalDms => 'DMS',
      OutputFormatView.primeFactor => 'FACT',
    };
  }

  // ---------------------------------------------------------------------------
  // 5. High-Resolution 2D Recursive Math AST Layout & Painting
  // ---------------------------------------------------------------------------
  _HiResBoxMetrics _measureHiResContainer(
    MathContainerNode container, {
    required double fontSize,
  }) {
    if (container.children.isEmpty) {
      final double w = container.showEmptyPlaceholder ? fontSize * 0.70 : 8.0;
      return _HiResBoxMetrics(
        width: w,
        ascent: fontSize * 0.80,
        descent: fontSize * 0.20,
      );
    }

    double totalW = 0;
    double maxAscent = fontSize * 0.80;
    double maxDescent = fontSize * 0.20;

    for (final child in container.children) {
      final m = _measureHiResNode(child, fontSize: fontSize);
      totalW += m.width + 2.0;
      if (m.ascent > maxAscent) maxAscent = m.ascent;
      if (m.descent > maxDescent) maxDescent = m.descent;
    }
    return _HiResBoxMetrics(
      width: totalW,
      ascent: maxAscent,
      descent: maxDescent,
    );
  }

  _HiResBoxMetrics _measureHiResNode(
    MathNode node, {
    required double fontSize,
  }) {
    if (node is CharNode) {
      final String disp = node.display;
      if (disp.contains('_') && disp.length >= 3) {
        final int idx = disp.indexOf('_');
        final String baseStr = disp.substring(0, idx);
        final String subStr = disp.substring(idx + 1);
        final tpBase = _layoutText(
          baseStr,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          fontStyle: baseStr.length == 1
              ? FontStyle.italic
              : FontStyle.normal,
          color: Colors.black,
        );
        final tpSub = _layoutText(
          subStr,
          fontSize: math.max(14.0, fontSize * 0.62),
          fontWeight: FontWeight.w700,
          color: Colors.black,
        );
        return _HiResBoxMetrics(
          width: tpBase.width + tpSub.width + 2,
          ascent: fontSize * 0.82,
          descent: fontSize * 0.36,
        );
      }
      if (disp == 'x') {
        return _HiResBoxMetrics(
          width: fontSize * 0.62,
          ascent: fontSize * 0.80,
          descent: fontSize * 0.22,
        );
      }
      final bool isSingleVar =
          disp.length == 1 && RegExp(r'^[a-zA-Z]$').hasMatch(disp);
      final tp = _layoutText(
        disp,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        fontStyle: isSingleVar ? FontStyle.italic : FontStyle.normal,
        color: Colors.black,
      );
      return _HiResBoxMetrics(
        width: tp.width,
        ascent: fontSize * 0.80,
        descent: fontSize * 0.22,
      );
    }
    if (node is FractionNode) {
      final double subSize = math.max(18.0, fontSize * 0.78);
      final numM = _measureHiResContainer(node.numerator, fontSize: subSize);
      final denM = _measureHiResContainer(node.denominator, fontSize: subSize);
      double intW = 0;
      if (node.integerPart != null) {
        intW =
            _measureHiResContainer(node.integerPart!, fontSize: fontSize).width +
                6;
      }
      final double bodyW = math.max(numM.width, denM.width) + 16;
      final double barOffset = fontSize * 0.30;
      return _HiResBoxMetrics(
        width: intW + bodyW,
        ascent: barOffset + 6 + numM.height,
        descent: math.max(fontSize * 0.22, -barOffset + 6 + denM.height),
      );
    }
    if (node is RadicalNode) {
      final radM = _measureHiResContainer(node.radicand, fontSize: fontSize);
      double idxW = 18.0;
      double idxAscent = 0.0;
      if (node.index != null) {
        final double idxSize = math.max(16.0, fontSize * 0.62);
        final idxM = _measureHiResContainer(
          node.index!,
          fontSize: idxSize,
        );
        idxW = math.max(18.0, idxM.width + 8);
        idxAscent = fontSize * 0.45 + idxM.ascent;
      }
      return _HiResBoxMetrics(
        width: idxW + radM.width + 12,
        ascent: math.max(radM.ascent + 8, idxAscent),
        descent: radM.descent + 3,
      );
    }
    if (node is SuperscriptNode) {
      final expM = _measureHiResContainer(
        node.exponent,
        fontSize: math.max(17.0, fontSize * 0.68),
      );
      double baseW = 0;
      double baseAscent = fontSize * 0.80;
      double baseDescent = fontSize * 0.20;
      if (node.base != null) {
        final bM = _measureHiResContainer(node.base!, fontSize: fontSize);
        baseW = bM.width;
        baseAscent = bM.ascent;
        baseDescent = bM.descent;
      }
      final double expBaselineShift = baseAscent * 0.56;
      return _HiResBoxMetrics(
        width: baseW + expM.width + 2,
        ascent: math.max(baseAscent, expBaselineShift + expM.ascent),
        descent: baseDescent,
      );
    }
    if (node is ParenthesisNode) {
      final bodyM = _measureHiResContainer(node.content, fontSize: fontSize);
      final double parenW = node.isAbsoluteValue ? 8.0 : 10.0;
      return _HiResBoxMetrics(
        width: bodyM.width + parenW * 2 + 4,
        ascent: bodyM.ascent + 4,
        descent: bodyM.descent + 4,
      );
    }
    if (node is LogBaseNode) {
      final baseM = _measureHiResContainer(
        node.base,
        fontSize: math.max(16.0, fontSize * 0.62),
      );
      final argM = _measureHiResContainer(node.argument, fontSize: fontSize);
      final tpLog = _layoutText(
        'log',
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      );
      return _HiResBoxMetrics(
        width: tpLog.width + baseM.width + argM.width + 26,
        ascent: argM.ascent + 4,
        descent: math.max(argM.descent + 4, fontSize * 0.22 + baseM.descent + 2),
      );
    }
    if (node is IntegralNode) {
      final double limitSize = math.max(19.0, fontSize * 0.72);
      final upperM = _measureHiResContainer(node.upper, fontSize: limitSize);
      final lowerM = _measureHiResContainer(node.lower, fontSize: limitSize);
      final bodyM = _measureHiResContainer(node.body, fontSize: fontSize);

      final double symW = fontSize * 0.62;
      final double limitsW = math.max(upperM.width, lowerM.width);
      final tpD = _layoutText(
        'd',
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      );
      final double dxW = tpD.width + fontSize * 0.62 + 2;

      final double upperBottomOffset =
          math.max(fontSize * 0.56, bodyM.ascent * 0.45) + 4.0;
      final double lowerTopOffset =
          math.max(fontSize * 0.10, bodyM.descent * 0.35) + 4.0;

      final double totalAscent = math.max(
        bodyM.ascent + 6.0,
        upperBottomOffset + upperM.height + 4.0,
      );
      final double totalDescent = math.max(
        bodyM.descent + 6.0,
        lowerTopOffset + lowerM.height + 4.0,
      );

      return _HiResBoxMetrics(
        width: symW * 0.78 + limitsW + 8.0 + bodyM.width + 6.0 + dxW,
        ascent: totalAscent,
        descent: totalDescent,
      );
    }
    if (node is DerivativeNode) {
      final double fracFontSize = math.max(18.0, fontSize * 0.72);
      final double atFontSize = math.max(17.0, fontSize * 0.65);
      final bodyM = _measureHiResContainer(node.body, fontSize: fontSize);
      final atM = _measureHiResContainer(node.atValue, fontSize: atFontSize);

      final tpD = _layoutText(
        'd',
        fontSize: fracFontSize,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      );
      final double denW = tpD.width + fracFontSize * 0.62 + 2;
      final double fracW = math.max(tpD.width, denW) + 12.0;

      final tpXEq = _layoutText(
        'x=',
        fontSize: atFontSize,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
        color: Colors.black,
      );
      final double barOffset = fontSize * 0.30;
      final double fracAscent = barOffset + 5 + fracFontSize * 0.85;
      final double fracDescent = -barOffset + 5 + fracFontSize * 0.90;

      final double totalAscent = math.max(bodyM.ascent + 6.0, fracAscent + 4.0);
      final double totalDescent = math.max(
        math.max(bodyM.descent + 6.0, fracDescent),
        fontSize * 0.25 + atM.height + 4.0,
      );

      return _HiResBoxMetrics(
        width: fracW + 6.0 + 10.0 + bodyM.width + 10.0 + 8.0 + tpXEq.width + atM.width + 4.0,
        ascent: totalAscent,
        descent: totalDescent,
      );
    }
    if (node is SummationNode) {
      final double limitSize = math.max(17.0, fontSize * 0.65);
      final startM = _measureHiResContainer(node.start, fontSize: limitSize);
      final endM = _measureHiResContainer(node.end, fontSize: limitSize);
      final bodyM = _measureHiResContainer(node.body, fontSize: fontSize);

      final tpVarEq = _layoutText(
        'x=',
        fontSize: limitSize,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
        color: Colors.black,
      );
      final double symW = fontSize * 0.95;
      final double lowerW = tpVarEq.width + startM.width + 2.0;
      final double opColW = math.max(symW, math.max(endM.width, lowerW)) + 6.0;

      final double symAscent = fontSize * 0.82;
      final double symDescent = fontSize * 0.32;
      final double totalAscent = math.max(
        bodyM.ascent + 6.0,
        symAscent + 5.0 + endM.height + 2.0,
      );
      final double totalDescent = math.max(
        bodyM.descent + 6.0,
        symDescent + 5.0 + startM.height + 2.0,
      );

      return _HiResBoxMetrics(
        width: opColW + 6.0 + 10.0 + bodyM.width + 10.0,
        ascent: totalAscent,
        descent: totalDescent,
      );
    }

    final tp = _layoutText(
      node.toDisplayString(),
      fontSize: fontSize * 0.88,
      fontWeight: FontWeight.w600,
      color: Colors.black,
    );
    return _HiResBoxMetrics(
      width: tp.width + 6,
      ascent: fontSize * 0.85,
      descent: fontSize * 0.25,
    );
  }

  double? _locateCursorXInContainer(
    MathContainerNode container, {
    required double fontSize,
    required String activeContainerId,
    required int activeChildIndex,
  }) {
    if (container.id == activeContainerId) {
      double x = 0;
      for (int i = 0;
          i < activeChildIndex && i < container.children.length;
          i++) {
        x +=
            _measureHiResNode(container.children[i], fontSize: fontSize).width +
                2.0;
      }
      return x;
    }

    double curX = 0;
    for (final child in container.children) {
      final double? subX = _locateCursorXInNode(
        child,
        fontSize: fontSize,
        activeContainerId: activeContainerId,
        activeChildIndex: activeChildIndex,
      );
      if (subX != null) {
        return curX + subX;
      }
      curX += _measureHiResNode(child, fontSize: fontSize).width + 2.0;
    }
    return null;
  }

  double? _locateCursorXInNode(
    MathNode node, {
    required double fontSize,
    required String activeContainerId,
    required int activeChildIndex,
  }) {
    if (node is FractionNode) {
      double offset = 0;
      if (node.integerPart != null) {
        final r = _locateCursorXInContainer(
          node.integerPart!,
          fontSize: fontSize,
          activeContainerId: activeContainerId,
          activeChildIndex: activeChildIndex,
        );
        if (r != null) return r;
        offset +=
            _measureHiResContainer(node.integerPart!, fontSize: fontSize).width +
                6;
      }
      final double subSize = math.max(18.0, fontSize * 0.78);
      final rNum = _locateCursorXInContainer(
        node.numerator,
        fontSize: subSize,
        activeContainerId: activeContainerId,
        activeChildIndex: activeChildIndex,
      );
      if (rNum != null) return offset + 8 + rNum;
      final rDen = _locateCursorXInContainer(
        node.denominator,
        fontSize: subSize,
        activeContainerId: activeContainerId,
        activeChildIndex: activeChildIndex,
      );
      if (rDen != null) return offset + 8 + rDen;
    } else if (node is RadicalNode) {
      double offset = 18.0;
      if (node.index != null) {
        final double idxSize = math.max(16.0, fontSize * 0.62);
        final rIdx = _locateCursorXInContainer(
          node.index!,
          fontSize: idxSize,
          activeContainerId: activeContainerId,
          activeChildIndex: activeChildIndex,
        );
        if (rIdx != null) return rIdx;
        offset = math.max(
          18.0,
          _measureHiResContainer(node.index!, fontSize: idxSize).width + 8,
        );
      }
      final rRad = _locateCursorXInContainer(
        node.radicand,
        fontSize: fontSize,
        activeContainerId: activeContainerId,
        activeChildIndex: activeChildIndex,
      );
      if (rRad != null) return offset + rRad;
    } else if (node is SuperscriptNode) {
      double offset = 0;
      if (node.base != null) {
        final rBase = _locateCursorXInContainer(
          node.base!,
          fontSize: fontSize,
          activeContainerId: activeContainerId,
          activeChildIndex: activeChildIndex,
        );
        if (rBase != null) return rBase;
        offset += _measureHiResContainer(node.base!, fontSize: fontSize).width;
      }
      final double expSize = math.max(17.0, fontSize * 0.68);
      final rExp = _locateCursorXInContainer(
        node.exponent,
        fontSize: expSize,
        activeContainerId: activeContainerId,
        activeChildIndex: activeChildIndex,
      );
      if (rExp != null) return offset + rExp;
    } else if (node is ParenthesisNode) {
      final r = _locateCursorXInContainer(
        node.content,
        fontSize: fontSize,
        activeContainerId: activeContainerId,
        activeChildIndex: activeChildIndex,
      );
      if (r != null) return 10.0 + r;
    } else if (node is LogBaseNode) {
      final double subSize = math.max(16.0, fontSize * 0.62);
      final rBase = _locateCursorXInContainer(
        node.base,
        fontSize: subSize,
        activeContainerId: activeContainerId,
        activeChildIndex: activeChildIndex,
      );
      if (rBase != null) return fontSize * 1.4 + rBase;
      final rArg = _locateCursorXInContainer(
        node.argument,
        fontSize: fontSize,
        activeContainerId: activeContainerId,
        activeChildIndex: activeChildIndex,
      );
      if (rArg != null) {
        final baseW = _measureHiResContainer(node.base, fontSize: subSize).width;
        return fontSize * 1.4 + baseW + 12.0 + rArg;
      }
    } else if (node is IntegralNode) {
      final double limitSize = math.max(19.0, fontSize * 0.72);
      final double symW = fontSize * 0.62;
      final rUpper = _locateCursorXInContainer(
        node.upper,
        fontSize: limitSize,
        activeContainerId: activeContainerId,
        activeChildIndex: activeChildIndex,
      );
      if (rUpper != null) return symW * 0.78 + rUpper;
      final rLower = _locateCursorXInContainer(
        node.lower,
        fontSize: limitSize,
        activeContainerId: activeContainerId,
        activeChildIndex: activeChildIndex,
      );
      if (rLower != null) return symW * 0.78 + rLower;
      final rBody = _locateCursorXInContainer(
        node.body,
        fontSize: fontSize,
        activeContainerId: activeContainerId,
        activeChildIndex: activeChildIndex,
      );
      if (rBody != null) {
        final upperM = _measureHiResContainer(node.upper, fontSize: limitSize);
        final lowerM = _measureHiResContainer(node.lower, fontSize: limitSize);
        return symW * 0.78 + math.max(upperM.width, lowerM.width) + 8.0 + rBody;
      }
    } else if (node is DerivativeNode) {
      final double atSize = math.max(17.0, fontSize * 0.65);
      final rBody = _locateCursorXInContainer(
        node.body,
        fontSize: fontSize,
        activeContainerId: activeContainerId,
        activeChildIndex: activeChildIndex,
      );
      if (rBody != null) return fontSize * 1.3 + rBody;
      final rAt = _locateCursorXInContainer(
        node.atValue,
        fontSize: atSize,
        activeContainerId: activeContainerId,
        activeChildIndex: activeChildIndex,
      );
      if (rAt != null) {
        final bodyW = _measureHiResContainer(node.body, fontSize: fontSize).width;
        return fontSize * 1.6 + bodyW + rAt;
      }
    } else if (node is SummationNode) {
      final double limitSize = math.max(17.0, fontSize * 0.65);
      final rEnd = _locateCursorXInContainer(
        node.end,
        fontSize: limitSize,
        activeContainerId: activeContainerId,
        activeChildIndex: activeChildIndex,
      );
      if (rEnd != null) return rEnd;
      final rStart = _locateCursorXInContainer(
        node.start,
        fontSize: limitSize,
        activeContainerId: activeContainerId,
        activeChildIndex: activeChildIndex,
      );
      if (rStart != null) return rStart;
      final rBody = _locateCursorXInContainer(
        node.body,
        fontSize: fontSize,
        activeContainerId: activeContainerId,
        activeChildIndex: activeChildIndex,
      );
      if (rBody != null) return fontSize * 1.3 + rBody;
    }
    return null;
  }

  void _paintHiResContainer(
    Canvas canvas,
    MathContainerNode container,
    double x,
    double baselineY, {
    required double fontSize,
    required _HiResMathRenderContext ctx,
  }) {
    final bool isFocused = container.id == ctx.activeContainerId;

    if (container.children.isEmpty) {
      final double boxW = fontSize * 0.66;
      final double boxH = fontSize * 0.86;
      final Rect boxRect = Rect.fromLTWH(
        x,
        baselineY - boxH * 0.86,
        boxW,
        boxH,
      );

      if (container.showEmptyPlaceholder) {
        if (isFocused && ctx.cursorVisible) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(boxRect, const Radius.circular(1.5)),
            Paint()..color = ctx.inkColor,
          );
        } else {
          canvas.drawRRect(
            RRect.fromRectAndRadius(boxRect, const Radius.circular(1.5)),
            Paint()
              ..color = ctx.inkColor
              ..strokeWidth = 2.2
              ..style = PaintingStyle.stroke,
          );
        }
      } else if (isFocused && ctx.cursorVisible) {
        canvas.drawRect(
          Rect.fromLTWH(
            x,
            baselineY - boxH * 0.90,
            ctx.isInsertMode ? 3.5 : 14.0,
            boxH * 1.06,
          ),
          Paint()..color = ctx.inkColor,
        );
      }
      return;
    }

    double curX = x;
    for (int i = 0; i <= container.children.length; i++) {
      if (isFocused && ctx.activeChildIndex == i && ctx.cursorVisible) {
        double cursorTop = baselineY - fontSize * 0.84;
        double cursorBottom = baselineY + fontSize * 0.22;

        // Match Cal_ 991CW behavior: when cursor is adjacent to a tall 2D
        // calculus structure (e.g. after `∫_□^□ x^4 dx |`), span the full height
        final MathNode? prevNode = i > 0 ? container.children[i - 1] : null;
        final MathNode? nextNode =
            i < container.children.length ? container.children[i] : null;
        final MathNode? tallNeighbor = (prevNode is IntegralNode ||
                prevNode is SummationNode ||
                prevNode is DerivativeNode)
            ? prevNode
            : ((nextNode is IntegralNode ||
                    nextNode is SummationNode ||
                    nextNode is DerivativeNode)
                ? nextNode
                : null);

        if (tallNeighbor != null) {
          final tallM = _measureHiResNode(tallNeighbor, fontSize: fontSize);
          cursorTop = baselineY - tallM.ascent + 2.0;
          cursorBottom = baselineY + tallM.descent - 2.0;
        }

        canvas.drawRect(
          Rect.fromLTWH(
            curX,
            cursorTop,
            ctx.isInsertMode ? 3.5 : 14.0,
            cursorBottom - cursorTop,
          ),
          Paint()..color = ctx.inkColor,
        );
      }
      if (i < container.children.length) {
        final child = container.children[i];
        final childM = _measureHiResNode(child, fontSize: fontSize);
        _paintHiResNode(
          canvas,
          child,
          curX,
          baselineY,
          fontSize: fontSize,
          ctx: ctx,
        );
        curX += childM.width + 2.0;
      }
    }
  }

  void _paintHiResNode(
    Canvas canvas,
    MathNode node,
    double x,
    double baselineY, {
    required double fontSize,
    required _HiResMathRenderContext ctx,
  }) {
    if (node is CharNode) {
      final String disp = node.display;
      if (disp.contains('_') && disp.length >= 3) {
        final int idx = disp.indexOf('_');
        final String baseStr = disp.substring(0, idx);
        final String subStr = disp.substring(idx + 1);
        final tpBase = _layoutText(
          baseStr,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          fontStyle:
              baseStr.length == 1 ? FontStyle.italic : FontStyle.normal,
          color: ctx.inkColor,
        );
        tpBase.paint(canvas, Offset(x, baselineY - fontSize * 0.82));
        final double subSize = math.max(14.0, fontSize * 0.62);
        final tpSub = _layoutText(
          subStr,
          fontSize: subSize,
          fontWeight: FontWeight.w700,
          color: ctx.inkColor,
        );
        tpSub.paint(
          canvas,
          Offset(x + tpBase.width + 1, baselineY - subSize * 0.48),
        );
        return;
      }
      if (disp == 'x') {
        _paintMathVariableX(
          canvas,
          x,
          baselineY,
          fontSize: fontSize,
          color: ctx.inkColor,
        );
        return;
      }
      final bool isSingleVar =
          disp.length == 1 && RegExp(r'^[a-zA-Z]$').hasMatch(disp);
      final tp = _layoutText(
        disp,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        fontStyle: isSingleVar ? FontStyle.italic : FontStyle.normal,
        color: ctx.inkColor,
      );
      tp.paint(canvas, Offset(x, baselineY - fontSize * 0.82));
      return;
    }

    if (node is FractionNode) {
      double curX = x;
      if (node.integerPart != null) {
        final intM =
            _measureHiResContainer(node.integerPart!, fontSize: fontSize);
        _paintHiResContainer(
          canvas,
          node.integerPart!,
          curX,
          baselineY,
          fontSize: fontSize,
          ctx: ctx,
        );
        curX += intM.width + 6;
      }

      final double subSize = math.max(18.0, fontSize * 0.78);
      final numM = _measureHiResContainer(node.numerator, fontSize: subSize);
      final denM = _measureHiResContainer(node.denominator, fontSize: subSize);
      final double bodyW = math.max(numM.width, denM.width) + 16;
      final double barY = baselineY - fontSize * 0.30;

      canvas.drawLine(
        Offset(curX, barY),
        Offset(curX + bodyW, barY),
        Paint()
          ..color = ctx.inkColor
          ..strokeWidth = 2.6,
      );

      _paintHiResContainer(
        canvas,
        node.numerator,
        curX + (bodyW - numM.width) / 2,
        barY - 6 - numM.descent,
        fontSize: subSize,
        ctx: ctx,
      );
      _paintHiResContainer(
        canvas,
        node.denominator,
        curX + (bodyW - denM.width) / 2,
        barY + 6 + denM.ascent,
        fontSize: subSize,
        ctx: ctx,
      );
      return;
    }

    if (node is RadicalNode) {
      double curX = x;
      if (node.index != null) {
        final double idxSize = math.max(16.0, fontSize * 0.62);
        final idxM = _measureHiResContainer(node.index!, fontSize: idxSize);
        _paintHiResContainer(
          canvas,
          node.index!,
          curX,
          baselineY - fontSize * 0.45,
          fontSize: idxSize,
          ctx: ctx,
        );
        curX += math.max(14.0, idxM.width + 4);
      }

      final radM = _measureHiResContainer(node.radicand, fontSize: fontSize);
      final double topY = baselineY - radM.ascent - 6;
      final double bottomY = baselineY + radM.descent;
      final double radStartX = curX + 16;
      final double radEndX = radStartX + radM.width + 8;

      final path = Path()
        ..moveTo(curX, baselineY - radM.ascent * 0.35)
        ..lineTo(curX + 5, baselineY - radM.ascent * 0.38)
        ..lineTo(curX + 10, bottomY)
        ..lineTo(radStartX, topY)
        ..lineTo(radEndX, topY)
        ..lineTo(radEndX, topY + 5);

      canvas.drawPath(
        path,
        Paint()
          ..color = ctx.inkColor
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );

      _paintHiResContainer(
        canvas,
        node.radicand,
        radStartX + 3,
        baselineY,
        fontSize: fontSize,
        ctx: ctx,
      );
      return;
    }

    if (node is SuperscriptNode) {
      double curX = x;
      double baseAscent = fontSize * 0.80;
      if (node.base != null) {
        final bM = _measureHiResContainer(node.base!, fontSize: fontSize);
        baseAscent = bM.ascent;
        _paintHiResContainer(
          canvas,
          node.base!,
          curX,
          baselineY,
          fontSize: fontSize,
          ctx: ctx,
        );
        curX += bM.width + 1;
      }
      final double expSize = math.max(17.0, fontSize * 0.68);
      _paintHiResContainer(
        canvas,
        node.exponent,
        curX,
        baselineY - baseAscent * 0.56,
        fontSize: expSize,
        ctx: ctx,
      );
      return;
    }

    if (node is ParenthesisNode) {
      final bodyM = _measureHiResContainer(node.content, fontSize: fontSize);
      final double parenW = node.isAbsoluteValue ? 8.0 : 10.0;
      final double topY = baselineY - bodyM.ascent - 2.0;
      final double bottomY = baselineY + bodyM.descent + 2.0;

      _paintAutoSizedBracket(
        canvas,
        x: x,
        topY: topY,
        bottomY: bottomY,
        width: parenW,
        isLeft: true,
        isAbsoluteValue: node.isAbsoluteValue,
        color: ctx.inkColor,
      );
      _paintHiResContainer(
        canvas,
        node.content,
        x + parenW + 2.0,
        baselineY,
        fontSize: fontSize,
        ctx: ctx,
      );
      _paintAutoSizedBracket(
        canvas,
        x: x + parenW + 2.0 + bodyM.width + 2.0,
        topY: topY,
        bottomY: bottomY,
        width: parenW,
        isLeft: false,
        isAbsoluteValue: node.isAbsoluteValue,
        color: ctx.inkColor,
      );
      return;
    }

    if (node is LogBaseNode) {
      final tpLog = _layoutText(
        'log',
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: ctx.inkColor,
      );
      tpLog.paint(canvas, Offset(x, baselineY - fontSize * 0.82));
      double curX = x + tpLog.width + 2;

      final double subSize = math.max(16.0, fontSize * 0.62);
      final baseM = _measureHiResContainer(node.base, fontSize: subSize);
      _paintHiResContainer(
        canvas,
        node.base,
        curX,
        baselineY + fontSize * 0.22,
        fontSize: subSize,
        ctx: ctx,
      );
      curX += baseM.width + 3;

      final argM = _measureHiResContainer(node.argument, fontSize: fontSize);
      final double topY = baselineY - argM.ascent - 2.0;
      final double bottomY = baselineY + argM.descent + 2.0;

      _paintAutoSizedBracket(
        canvas,
        x: curX,
        topY: topY,
        bottomY: bottomY,
        width: 9.0,
        isLeft: true,
        isAbsoluteValue: false,
        color: ctx.inkColor,
      );
      curX += 11.0;

      _paintHiResContainer(
        canvas,
        node.argument,
        curX,
        baselineY,
        fontSize: fontSize,
        ctx: ctx,
      );
      curX += argM.width + 2.0;

      _paintAutoSizedBracket(
        canvas,
        x: curX,
        topY: topY,
        bottomY: bottomY,
        width: 9.0,
        isLeft: false,
        isAbsoluteValue: false,
        color: ctx.inkColor,
      );
      return;
    }

    if (node is IntegralNode) {
      final double limitSize = math.max(19.0, fontSize * 0.72);
      final upperM = _measureHiResContainer(node.upper, fontSize: limitSize);
      final lowerM = _measureHiResContainer(node.lower, fontSize: limitSize);
      final bodyM = _measureHiResContainer(node.body, fontSize: fontSize);

      final double symW = fontSize * 0.62;
      final double limitsW = math.max(upperM.width, lowerM.width);

      final double upperBottomOffset =
          math.max(fontSize * 0.56, bodyM.ascent * 0.45) + 4.0;
      final double lowerTopOffset =
          math.max(fontSize * 0.10, bodyM.descent * 0.35) + 4.0;

      final double upperBaselineY =
          baselineY - upperBottomOffset - upperM.descent;
      final double lowerBaselineY =
          baselineY + lowerTopOffset + lowerM.ascent;

      final double intTopY =
          math.min(baselineY - bodyM.ascent - 4.0, upperBaselineY - upperM.ascent - 2.0);
      final double intBottomY =
          math.max(baselineY + bodyM.descent + 4.0, lowerBaselineY + lowerM.descent + 2.0);

      // 1. Paint authentic Cal_ ClassWiz tall integral symbol ∫
      _paintIntegralSymbol(
        canvas,
        x: x,
        topY: intTopY,
        bottomY: intBottomY,
        width: symW,
        color: ctx.inkColor,
      );

      // 2. Paint upper & lower limit containers to the right of the integral stem
      final double limitsX = x + symW * 0.78;
      _paintHiResContainer(
        canvas,
        node.upper,
        limitsX,
        upperBaselineY,
        fontSize: limitSize,
        ctx: ctx,
      );
      _paintHiResContainer(
        canvas,
        node.lower,
        limitsX,
        lowerBaselineY,
        fontSize: limitSize,
        ctx: ctx,
      );

      // 3. Paint integrand body on the main baseline
      double curX = limitsX + limitsW + 8.0;
      _paintHiResContainer(
        canvas,
        node.body,
        curX,
        baselineY,
        fontSize: fontSize,
        ctx: ctx,
      );
      curX += bodyM.width + 6.0;

      // 4. Paint differential "dx" (upright 'd' + mathematical italic 'x')
      final tpD = _layoutText(
        'd',
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: ctx.inkColor,
      );
      tpD.paint(canvas, Offset(curX, baselineY - fontSize * 0.82));
      curX += tpD.width + 1.0;
      _paintMathVariableX(
        canvas,
        curX,
        baselineY,
        fontSize: fontSize,
        color: ctx.inkColor,
      );
      return;
    }

    if (node is DerivativeNode) {
      final double fracFontSize = math.max(18.0, fontSize * 0.72);
      final double atFontSize = math.max(17.0, fontSize * 0.65);
      final bodyM = _measureHiResContainer(node.body, fontSize: fontSize);
      final atM = _measureHiResContainer(node.atValue, fontSize: atFontSize);

      final tpD = _layoutText(
        'd',
        fontSize: fracFontSize,
        fontWeight: FontWeight.w600,
        color: ctx.inkColor,
      );
      final double denW = tpD.width + fracFontSize * 0.62 + 2;
      final double fracW = math.max(tpD.width, denW) + 12.0;
      final double barY = baselineY - fontSize * 0.30;

      // 1. Paint stacked d/dx
      canvas.drawLine(
        Offset(x, barY),
        Offset(x + fracW, barY),
        Paint()
          ..color = ctx.inkColor
          ..strokeWidth = 2.5,
      );
      tpD.paint(
        canvas,
        Offset(x + (fracW - tpD.width) / 2, barY - fracFontSize * 0.92 - 4),
      );
      final double denStartX = x + (fracW - denW) / 2;
      tpD.paint(canvas, Offset(denStartX, barY + 4));
      _paintMathVariableX(
        canvas,
        denStartX + tpD.width + 1,
        barY + 4 + fracFontSize * 0.82,
        fontSize: fracFontSize,
        color: ctx.inkColor,
      );

      // 2. Paint auto-sized parentheses around body
      double curX = x + fracW + 6.0;
      final double parenTopY =
          math.min(baselineY - bodyM.ascent - 2.0, barY - fracFontSize - 4.0);
      final double parenBottomY =
          math.max(baselineY + bodyM.descent + 2.0, barY + fracFontSize + 4.0);

      _paintAutoSizedBracket(
        canvas,
        x: curX,
        topY: parenTopY,
        bottomY: parenBottomY,
        width: 9.0,
        isLeft: true,
        isAbsoluteValue: false,
        color: ctx.inkColor,
      );
      curX += 11.0;

      _paintHiResContainer(
        canvas,
        node.body,
        curX,
        baselineY,
        fontSize: fontSize,
        ctx: ctx,
      );
      curX += bodyM.width + 2.0;

      _paintAutoSizedBracket(
        canvas,
        x: curX,
        topY: parenTopY,
        bottomY: parenBottomY,
        width: 9.0,
        isLeft: false,
        isAbsoluteValue: false,
        color: ctx.inkColor,
      );
      curX += 12.0;

      // 3. Paint evaluation bar |_{x=□}
      final double atBaselineY = baselineY + fontSize * 0.25 + atM.ascent;
      final double barBottomY =
          math.max(parenBottomY + 4.0, atBaselineY + atM.descent + 2.0);
      canvas.drawLine(
        Offset(curX, parenTopY - 2.0),
        Offset(curX, barBottomY),
        Paint()
          ..color = ctx.inkColor
          ..strokeWidth = 2.4,
      );
      curX += 5.0;

      _paintMathVariableX(
        canvas,
        curX,
        atBaselineY,
        fontSize: atFontSize,
        color: ctx.inkColor,
      );
      curX += atFontSize * 0.62 + 1.0;
      final tpEq = _layoutText(
        '=',
        fontSize: atFontSize,
        fontWeight: FontWeight.w600,
        color: ctx.inkColor,
      );
      tpEq.paint(canvas, Offset(curX, atBaselineY - atFontSize * 0.82));
      curX += tpEq.width + 2.0;

      _paintHiResContainer(
        canvas,
        node.atValue,
        curX,
        atBaselineY,
        fontSize: atFontSize,
        ctx: ctx,
      );
      return;
    }

    if (node is SummationNode) {
      final double limitSize = math.max(17.0, fontSize * 0.65);
      final startM = _measureHiResContainer(node.start, fontSize: limitSize);
      final endM = _measureHiResContainer(node.end, fontSize: limitSize);
      final bodyM = _measureHiResContainer(node.body, fontSize: fontSize);

      final tpVarEq = _layoutText(
        'x=',
        fontSize: limitSize,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
        color: ctx.inkColor,
      );
      final double symW = fontSize * 0.95;
      final double lowerW = tpVarEq.width + startM.width + 2.0;
      final double opColW = math.max(symW, math.max(endM.width, lowerW)) + 6.0;

      final double symTopY = baselineY - fontSize * 0.82;
      final double symBottomY = baselineY + fontSize * 0.32;
      final double symLeftX = x + (opColW - symW) / 2;

      // 1. Paint crisp Σ or Π symbol
      _paintSigmaOrPiSymbol(
        canvas,
        x: symLeftX,
        topY: symTopY,
        bottomY: symBottomY,
        width: symW,
        isProduct: node.isProduct,
        color: ctx.inkColor,
      );

      // 2. Paint upper limit centered above Σ/Π
      final double upperBaselineY = symTopY - 5.0 - endM.descent;
      _paintHiResContainer(
        canvas,
        node.end,
        x + (opColW - endM.width) / 2,
        upperBaselineY,
        fontSize: limitSize,
        ctx: ctx,
      );

      // 3. Paint lower limit "x=□" centered below Σ/Π
      final double lowerBaselineY = symBottomY + 5.0 + startM.ascent;
      final double lowerStartX = x + (opColW - lowerW) / 2;
      tpVarEq.paint(
        canvas,
        Offset(lowerStartX, lowerBaselineY - limitSize * 0.82),
      );
      _paintHiResContainer(
        canvas,
        node.start,
        lowerStartX + tpVarEq.width + 2.0,
        lowerBaselineY,
        fontSize: limitSize,
        ctx: ctx,
      );

      // 4. Paint auto-sized parentheses around body
      double curX = x + opColW + 6.0;
      final double parenTopY = baselineY - bodyM.ascent - 2.0;
      final double parenBottomY = baselineY + bodyM.descent + 2.0;

      _paintAutoSizedBracket(
        canvas,
        x: curX,
        topY: parenTopY,
        bottomY: parenBottomY,
        width: 9.0,
        isLeft: true,
        isAbsoluteValue: false,
        color: ctx.inkColor,
      );
      curX += 11.0;

      _paintHiResContainer(
        canvas,
        node.body,
        curX,
        baselineY,
        fontSize: fontSize,
        ctx: ctx,
      );
      curX += bodyM.width + 2.0;

      _paintAutoSizedBracket(
        canvas,
        x: curX,
        topY: parenTopY,
        bottomY: parenBottomY,
        width: 9.0,
        isLeft: false,
        isAbsoluteValue: false,
        color: ctx.inkColor,
      );
      return;
    }

    final tp = _layoutText(
      node.toDisplayString(),
      fontSize: fontSize * 0.88,
      fontWeight: FontWeight.w600,
      color: ctx.inkColor,
    );
    tp.paint(canvas, Offset(x, baselineY - fontSize * 0.78));
  }

  /// Paints the authentic Cal_ ClassWiz mathematical italic variable `x`
  /// (with serif hooks on the top-left/bottom-right stroke and diagonal cross),
  /// matching the user's reference photo `media_1791799894139_3787bb95.png`.
  void _paintMathVariableX(
    Canvas canvas,
    double x,
    double baselineY, {
    required double fontSize,
    required Color color,
  }) {
    final double w = fontSize * 0.56;
    final double topY = baselineY - fontSize * 0.54;
    final double bottomY = baselineY - fontSize * 0.02;

    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = math.max(2.1, fontSize * 0.085)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Main curved serif stroke from top-left to bottom-right
    final Path mainStroke = Path()
      ..moveTo(x + w * 0.05, topY + (bottomY - topY) * 0.18)
      ..quadraticBezierTo(
        x + w * 0.25,
        topY - 1.0,
        x + w * 0.44,
        (topY + bottomY) * 0.5,
      )
      ..quadraticBezierTo(
        x + w * 0.64,
        bottomY + 1.0,
        x + w * 0.94,
        bottomY - (bottomY - topY) * 0.18,
      );

    // Cross diagonal stroke from bottom-left to top-right with hooked ends
    final Path crossStroke = Path()
      ..moveTo(x + w * 0.04, bottomY - (bottomY - topY) * 0.10)
      ..lineTo(x + w * 0.16, bottomY)
      ..lineTo(x + w * 0.84, topY)
      ..lineTo(x + w * 0.96, topY + (bottomY - topY) * 0.10);

    canvas.drawPath(mainStroke, paint);
    canvas.drawPath(crossStroke, paint);
  }

  /// Paints the authentic Cal_ ClassWiz tall integral symbol `∫` spanning
  /// `[topY, bottomY]` with hooked top and bottom terminals.
  void _paintIntegralSymbol(
    Canvas canvas, {
    required double x,
    required double topY,
    required double bottomY,
    required double width,
    required Color color,
  }) {
    final double midX = x + width * 0.46;
    final double topHookRightX = x + width * 0.88;
    final double bottomHookLeftX = x + width * 0.06;
    final double hookH = math.min(14.0, (bottomY - topY) * 0.15);

    final Path path = Path()
      ..moveTo(topHookRightX, topY + hookH * 0.55)
      ..cubicTo(
        topHookRightX,
        topY - 1.0,
        midX,
        topY - 1.0,
        midX,
        topY + hookH,
      )
      ..lineTo(midX, bottomY - hookH)
      ..cubicTo(
        midX,
        bottomY + 1.0,
        bottomHookLeftX,
        bottomY + 1.0,
        bottomHookLeftX,
        bottomY - hookH * 0.55,
      );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    // Crisp terminal bulbs at top-right and bottom-left of integral sign
    canvas.drawCircle(
      Offset(topHookRightX - 1.2, topY + hookH * 0.50),
      2.3,
      Paint()..color = color,
    );
    canvas.drawCircle(
      Offset(bottomHookLeftX + 1.2, bottomY - hookH * 0.50),
      2.3,
      Paint()..color = color,
    );
  }

  /// Paints a crisp Σ (summation) or Π (product) operator symbol.
  void _paintSigmaOrPiSymbol(
    Canvas canvas, {
    required double x,
    required double topY,
    required double bottomY,
    required double width,
    required bool isProduct,
    required Color color,
  }) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter
      ..style = PaintingStyle.stroke;

    if (isProduct) {
      // Product Π
      canvas.drawLine(Offset(x, topY), Offset(x + width, topY), paint);
      canvas.drawLine(
        Offset(x + width * 0.22, topY),
        Offset(x + width * 0.22, bottomY),
        paint,
      );
      canvas.drawLine(
        Offset(x + width * 0.78, topY),
        Offset(x + width * 0.78, bottomY),
        paint,
      );
      canvas.drawLine(
        Offset(x + width * 0.08, bottomY),
        Offset(x + width * 0.36, bottomY),
        paint,
      );
      canvas.drawLine(
        Offset(x + width * 0.64, bottomY),
        Offset(x + width * 0.92, bottomY),
        paint,
      );
    } else {
      // Summation Σ
      final double midY = (topY + bottomY) * 0.5;
      final Path path = Path()
        ..moveTo(x + width, topY + 5.0)
        ..lineTo(x + width, topY)
        ..lineTo(x, topY)
        ..lineTo(x + width * 0.56, midY)
        ..lineTo(x, bottomY)
        ..lineTo(x + width, bottomY)
        ..lineTo(x + width, bottomY - 5.0);
      canvas.drawPath(path, paint);
    }
  }

  /// Paints auto-scaling curved parentheses `(` / `)` or vertical bars `|`.
  void _paintAutoSizedBracket(
    Canvas canvas, {
    required double x,
    required double topY,
    required double bottomY,
    required double width,
    required bool isLeft,
    required bool isAbsoluteValue,
    required Color color,
  }) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (isAbsoluteValue) {
      final double midX = x + width * 0.5;
      canvas.drawLine(Offset(midX, topY), Offset(midX, bottomY), paint);
      return;
    }

    final Path path = Path();
    if (isLeft) {
      path.moveTo(x + width * 0.85, topY);
      path.quadraticBezierTo(
        x - width * 0.15,
        (topY + bottomY) * 0.5,
        x + width * 0.85,
        bottomY,
      );
    } else {
      path.moveTo(x + width * 0.15, topY);
      path.quadraticBezierTo(
        x + width * 1.15,
        (topY + bottomY) * 0.5,
        x + width * 0.15,
        bottomY,
      );
    }
    canvas.drawPath(path, paint);
  }

  // ---------------------------------------------------------------------------
  // 6. High-Resolution Breadcrumb Menus (CATALOG, TOOLS, SETTINGS, FORMAT, etc.)
  // ---------------------------------------------------------------------------
  void _paintBreadcrumbMenu(Canvas canvas) {
    final MenuBreadcrumbLevel? level = state.currentBreadcrumb;
    if (level == null || level.items.isEmpty) return;

    final int clampedIdx = level.selectedIndex.clamp(
      0,
      level.items.length - 1,
    );

    // 1. Breadcrumb Header Bar (y: 35..74)
    canvas.drawRect(
      const Rect.fromLTWH(0, 35, vWidth, 38),
      Paint()..color = _shade(2),
    );
    final String headerTitle = state.menuBreadcrumbs.length > 1
        ? state.menuBreadcrumbs.map((b) => b.title).join(' ▸ ')
        : level.title;
    _drawLeftText(
      canvas,
      headerTitle,
      const Offset(16, 42),
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: _shade(0),
      maxWidth: vWidth - 32,
    );

    // 2. Render 4 High-Res Menu Rows (y: 78..278)
    final int windowStart = clampedIdx >= 3 ? clampedIdx - 3 : 0;
    const double rowH = 50.0;

    for (int i = 0; i < 4; i++) {
      final int itemIdx = windowStart + i;
      if (itemIdx >= level.items.length) break;

      final CwMenuNode item = level.items[itemIdx];
      final bool isSelected = itemIdx == clampedIdx;
      final double rowY = 78.0 + i * rowH;
      final Color fgColor = isSelected ? _shade(0) : _shade(4);

      if (isSelected) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(10, rowY + 2, vWidth - 34, rowH - 4),
            const Radius.circular(6),
          ),
          Paint()..color = _shade(4),
        );
      }

      final bool hasBadge =
          item.rightBadge != null && item.rightBadge!.isNotEmpty;
      final double maxRowTextWidth = (hasBadge && item.rightBadge!.length > 2)
          ? vWidth - 150
          : vWidth - 78;

      _drawLeftText(
        canvas,
        item.label,
        Offset(22, rowY + 11),
        fontSize: 24,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
        color: fgColor,
        maxWidth: maxRowTextWidth,
      );

      if (hasBadge) {
        _drawRightText(
          canvas,
          item.rightBadge!,
          Offset(vWidth - 36, rowY + 11),
          fontSize: 23,
          fontWeight: FontWeight.w700,
          color: fgColor,
        );
      }
    }

    // 3. Proportional Vertical Scrollbar (x: 748)
    const double trackX = 748.0;
    const double trackY = 82.0;
    const double trackH = 192.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(trackX, trackY, 7, trackH),
        const Radius.circular(3.5),
      ),
      Paint()..color = _shade(1),
    );
    final int total = level.items.length;
    final double thumbH = (trackH / total).clamp(26.0, trackH);
    final double thumbY = trackY +
        (total > 1 ? (clampedIdx / (total - 1)) * (trackH - thumbH) : 0.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(trackX, thumbY, 7, thumbH),
        const Radius.circular(3.5),
      ),
      Paint()..color = _shade(4),
    );
  }

  // ---------------------------------------------------------------------------
  // 7. High-Resolution 2D Grid/Table Editor, Multi-Line Results, Number Line & QR
  // ---------------------------------------------------------------------------
  void _paintHiResGridEditor(Canvas canvas, LcdGridTableModel model) {
    // Title & Column Headers (y: 36..72)
    canvas.drawRect(
      const Rect.fromLTWH(0, 35, vWidth, 36),
      Paint()..color = _shade(2),
    );
    _drawLeftText(
      canvas,
      model.title,
      const Offset(14, 41),
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: _shade(0),
    );

    final int totalRows = model.rowHeaders.length;
    final int totalCols = model.columnHeaders.length;
    final int visibleCols = math.min(3, totalCols);
    final int startCol = model.activeCol >= visibleCols
        ? model.activeCol - visibleCols + 1
        : 0;
    final int visibleRows = math.min(3, totalRows);
    final int startRow = model.activeRow >= visibleRows
        ? model.activeRow - visibleRows + 1
        : 0;

    const double rowHeaderW = 92.0;
    final double colW = (vWidth - rowHeaderW - 20) / math.max(1, visibleCols);
    const double headerY = 74.0;
    const double headerH = 34.0;

    // Column headers
    for (int vc = 0; vc < visibleCols; vc++) {
      final int cIdx = startCol + vc;
      final double cx = 10 + rowHeaderW + vc * colW;
      canvas.drawRect(
        Rect.fromLTWH(cx, headerY, colW, headerH),
        Paint()..color = _shade(1),
      );
      canvas.drawRect(
        Rect.fromLTWH(cx, headerY, colW, headerH),
        Paint()
          ..color = _shade(3)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
      _drawCenteredText(
        canvas,
        model.columnHeaders[cIdx],
        Offset(cx + colW / 2, headerY + headerH / 2),
        fontSize: 19,
        fontWeight: FontWeight.w800,
        color: _shade(4),
      );
    }

    // Data rows
    const double cellH = 42.0;
    for (int vr = 0; vr < visibleRows; vr++) {
      final int rIdx = startRow + vr;
      final double ry = headerY + headerH + vr * cellH;

      // Row label
      canvas.drawRect(
        Rect.fromLTWH(10, ry, rowHeaderW, cellH),
        Paint()..color = _shade(1),
      );
      canvas.drawRect(
        Rect.fromLTWH(10, ry, rowHeaderW, cellH),
        Paint()
          ..color = _shade(3)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
      _drawCenteredText(
        canvas,
        model.rowHeaders[rIdx],
        Offset(10 + rowHeaderW / 2, ry + cellH / 2),
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: _shade(4),
      );

      for (int vc = 0; vc < visibleCols; vc++) {
        final int cIdx = startCol + vc;
        final double cx = 10 + rowHeaderW + vc * colW;
        final bool isFocused =
            rIdx == model.activeRow && cIdx == model.activeCol;
        final String cellVal =
            rIdx < model.cells.length && cIdx < model.cells[rIdx].length
                ? model.cells[rIdx][cIdx]
                : '0';

        canvas.drawRect(
          Rect.fromLTWH(cx, ry, colW, cellH),
          Paint()..color = isFocused ? _shade(4) : _shade(0),
        );
        canvas.drawRect(
          Rect.fromLTWH(cx, ry, colW, cellH),
          Paint()
            ..color = _shade(3)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
        );
        _drawRightText(
          canvas,
          cellVal,
          Offset(cx + colW - 10, ry + 9),
          fontSize: 21,
          fontWeight: isFocused ? FontWeight.w800 : FontWeight.w600,
          color: isFocused ? _shade(0) : _shade(4),
          maxWidth: colW - 18,
        );
      }
    }

    // Bottom active cell input line (y: 242..286)
    canvas.drawRect(
      const Rect.fromLTWH(0, 240, vWidth, 50),
      Paint()..color = _shade(1),
    );
    _drawLeftText(
      canvas,
      model.bottomInputBarText,
      const Offset(16, 252),
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: _shade(4),
      maxWidth: vWidth - 32,
    );
  }

  void _paintHiResMultiLineResults(
    Canvas canvas, {
    required String title,
    required List<String> lines,
    required int selectedIndex,
  }) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 35, vWidth, 36),
      Paint()..color = _shade(2),
    );
    _drawLeftText(
      canvas,
      title,
      const Offset(14, 41),
      fontSize: 21,
      fontWeight: FontWeight.w800,
      color: _shade(0),
    );

    final int visibleCount = state.smallMultiLineFont ? 5 : 4;
    final int clamped = selectedIndex.clamp(0, math.max(0, lines.length - 1));
    final int windowStart =
        clamped >= (visibleCount - 1) ? clamped - (visibleCount - 1) : 0;
    final double rowH = state.smallMultiLineFont ? 40.0 : 50.0;
    final double fontSz = state.smallMultiLineFont ? 20.0 : 24.0;
    final double textOffsetY = state.smallMultiLineFont ? 8.0 : 11.0;

    for (int i = 0; i < visibleCount; i++) {
      final int idx = windowStart + i;
      if (idx >= lines.length) break;
      final bool isSel = idx == clamped;
      final double ry = 76.0 + i * rowH;

      if (isSel) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(10, ry + 2, vWidth - 28, rowH - 4),
            const Radius.circular(6),
          ),
          Paint()..color = _shade(4),
        );
      }
      _drawLeftText(
        canvas,
        lines[idx],
        Offset(22, ry + textOffsetY),
        fontSize: fontSz,
        fontWeight: FontWeight.w700,
        color: isSel ? _shade(0) : _shade(4),
        maxWidth: vWidth - 48,
      );
    }
  }

  void _paintHiResNumberLine(Canvas canvas) {
    final String summary =
        state.resultText.isNotEmpty ? state.resultText : '-2 ≤ x ≤ 3';
    _drawCenteredText(
      canvas,
      'Number Line:  $summary',
      const Offset(vWidth / 2, 72),
      fontSize: 25,
      fontWeight: FontWeight.w800,
      color: _shade(4),
    );

    const double lineY = 185.0;
    const double leftX = 90.0;
    const double rightX = vWidth - 90.0;
    final axisPaint = Paint()
      ..color = _shade(3)
      ..strokeWidth = 3.0;
    canvas.drawLine(const Offset(leftX, lineY), const Offset(rightX, lineY), axisPaint);

    const double x1 = 240.0;
    const double x2 = 528.0;
    canvas.drawLine(
      const Offset(x1, lineY - 28),
      const Offset(x2, lineY - 28),
      Paint()
        ..color = _shade(4)
        ..strokeWidth = 4.5,
    );
    canvas.drawCircle(const Offset(x1, lineY - 28), 8, Paint()..color = _shade(4));
    canvas.drawCircle(const Offset(x2, lineY - 28), 8, Paint()..color = _shade(4));

    _drawCenteredText(
      canvas,
      '-2',
      const Offset(x1, lineY + 26),
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: _shade(4),
    );
    _drawCenteredText(
      canvas,
      '0',
      const Offset(355, lineY + 26),
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: _shade(2),
    );
    _drawCenteredText(
      canvas,
      '3',
      const Offset(x2, lineY + 26),
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: _shade(4),
    );
  }

  void _paintQrCodeScreen(Canvas canvas, Cal_QrCodeMatrix qr) {
    final double moduleSize = (vHeight - 28) / qr.size;
    final double qrDrawSize = moduleSize * qr.size;
    const double startX = 24.0;
    final double startY = (vHeight - qrDrawSize) / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(startX - 8, startY - 8, qrDrawSize + 16, qrDrawSize + 16),
        const Radius.circular(6),
      ),
      Paint()..color = _shade(0),
    );

    final darkPaint = Paint()..color = _shade(4);
    for (int r = 0; r < qr.size; r++) {
      for (int c = 0; c < qr.size; c++) {
        if (qr.isDark(r, c)) {
          canvas.drawRect(
            Rect.fromLTWH(
              startX + c * moduleSize,
              startY + r * moduleSize,
              moduleSize + 0.4,
              moduleSize + 0.4,
            ),
            darkPaint,
          );
        }
      }
    }

    final double infoX = startX + qrDrawSize + 28;
    _drawLeftText(
      canvas,
      'QR Code (v${qr.version})',
      Offset(infoX, 42),
      fontSize: 23,
      fontWeight: FontWeight.w800,
      color: _shade(4),
    );
    _drawLeftText(
      canvas,
      'Mode: ${state.activeMode.title}',
      Offset(infoX, 88),
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: _shade(3),
    );
    if (state.expressionDisplayString.isNotEmpty) {
      _drawLeftText(
        canvas,
        state.expressionDisplayString,
        Offset(infoX, 134),
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: _shade(4),
        maxWidth: vWidth - infoX - 18,
      );
    }
    _drawLeftText(
      canvas,
      '[BACK] / [AC] : Close QR',
      Offset(infoX, 224),
      fontSize: 19,
      fontWeight: FontWeight.w600,
      color: _shade(2),
    );
  }

  void _paintErrorModal(Canvas canvas, String errorTitle) {
    const Rect modalRect = Rect.fromLTWH(80, 56, vWidth - 160, 184);
    // Drop shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        modalRect.shift(const Offset(8, 8)),
        const Radius.circular(10),
      ),
      Paint()..color = _shade(3),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(modalRect, const Radius.circular(10)),
      Paint()..color = _shade(0),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(modalRect, const Radius.circular(10)),
      Paint()
        ..color = _shade(4)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke,
    );

    _drawCenteredText(
      canvas,
      errorTitle,
      Offset(modalRect.center.dx, modalRect.top + 66),
      fontSize: 32,
      fontWeight: FontWeight.w900,
      color: _shade(4),
    );
    _drawCenteredText(
      canvas,
      '[BACK] or [OK] : Cancel',
      Offset(modalRect.center.dx, modalRect.top + 132),
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: _shade(3),
    );
  }

  // ---------------------------------------------------------------------------
  // Typography Helpers
  // ---------------------------------------------------------------------------
  TextPainter _layoutText(
    String text, {
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    FontStyle fontStyle = FontStyle.normal,
    double letterSpacing = 0.0,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          letterSpacing: letterSpacing,
          height: 1.05,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return tp;
  }

  void _drawCenteredText(
    Canvas canvas,
    String text,
    Offset center, {
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    FontStyle fontStyle = FontStyle.normal,
    double letterSpacing = 0.0,
    double? maxWidth,
  }) {
    double size = fontSize;
    TextPainter tp = _layoutText(
      text,
      fontSize: size,
      fontWeight: fontWeight,
      color: color,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
    );
    while (maxWidth != null && tp.width > maxWidth && size > 12) {
      size -= 1.5;
      tp = _layoutText(
        text,
        fontSize: size,
        fontWeight: fontWeight,
        color: color,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
      );
    }
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  void _drawLeftText(
    Canvas canvas,
    String text,
    Offset topLeft, {
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? maxWidth,
  }) {
    double size = fontSize;
    TextPainter tp = _layoutText(
      text,
      fontSize: size,
      fontWeight: fontWeight,
      color: color,
    );
    while (maxWidth != null && tp.width > maxWidth && size > 13) {
      size -= 1.5;
      tp = _layoutText(
        text,
        fontSize: size,
        fontWeight: fontWeight,
        color: color,
      );
    }
    tp.paint(canvas, topLeft);
  }

  void _drawRightText(
    Canvas canvas,
    String text,
    Offset topRight, {
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? maxWidth,
  }) {
    double size = fontSize;
    TextPainter tp = _layoutText(
      text,
      fontSize: size,
      fontWeight: fontWeight,
      color: color,
    );
    while (maxWidth != null && tp.width > maxWidth && size > 14) {
      size -= 1.5;
      tp = _layoutText(
        text,
        fontSize: size,
        fontWeight: fontWeight,
        color: color,
      );
    }
    tp.paint(canvas, Offset(topRight.dx - tp.width, topRight.dy));
  }

  @override
  bool shouldRepaint(covariant _HiResCal_LcdPainter oldDelegate) {
    return state != oldDelegate.state ||
        cursorVisible != oldDelegate.cursorVisible ||
        hasLeftPanOverflow != oldDelegate.hasLeftPanOverflow ||
        hasRightPanOverflow != oldDelegate.hasRightPanOverflow;
  }
}

class _HiResBoxMetrics {
  final double width;
  final double ascent;
  final double descent;

  const _HiResBoxMetrics({
    required this.width,
    required this.ascent,
    required this.descent,
  });

  double get height => ascent + descent;
}

class _HiResMathRenderContext {
  final String activeContainerId;
  final int activeChildIndex;
  final bool cursorVisible;
  final bool isInsertMode;
  final Color inkColor;
  final Color placeholderColor;

  const _HiResMathRenderContext({
    required this.activeContainerId,
    required this.activeChildIndex,
    required this.cursorVisible,
    required this.isInsertMode,
    required this.inkColor,
    required this.placeholderColor,
  });
}
