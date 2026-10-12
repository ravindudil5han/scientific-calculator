import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/calculator_theme.dart';
import 'lcd_bitmap_font.dart';

/// Typographic metrics for a 2D mathematical node on the virtual LCD.
///
/// Rather than a flat [Size] alone, 2D mathematical layout requires aligning
/// sibling boxes along a shared horizontal mathematical axis (`baseline`).
/// - [width]: Total horizontal advance in LCD pixels.
/// - [ascent]: Pixels extending above the baseline (including top row).
/// - [descent]: Pixels extending strictly below the baseline.
@immutable
class MathMetrics {
  final int width;
  final int ascent;
  final int descent;

  const MathMetrics({
    required this.width,
    required this.ascent,
    required this.descent,
  });

  int get height => ascent + descent;

  Size toSize([double scale = 1.0]) =>
      Size(width * scale, (ascent + descent) * scale);
}

/// Context passed down during recursive 2D layout and rendering.
class MathLayoutContext {
  final String activeContainerId;
  final int activeChildIndex;
  final bool cursorVisible;
  final bool isInsertMode;
  final bool isResultDisplayed;
  final int scaleLevel; // 0 = normal (5×7), 1+ = script/compact (3×5 or compact 5×7)

  /// Populated during layout/render with the exact bounding box of the active cursor
  /// in root expression coordinates.
  Rect? resolvedCursorRect;

  /// Map of `(containerId, slotIndex)` -> global `(x, baselineY, ascent, descent)`
  /// used for spatial Up/Down hit-testing and auto-scrolling.
  final Map<String, List<Rect>> slotBoundsByContainer = {};

  MathLayoutContext({
    required this.activeContainerId,
    required this.activeChildIndex,
    this.cursorVisible = true,
    this.isInsertMode = true,
    this.isResultDisplayed = false,
    this.scaleLevel = 0,
    this.resolvedCursorRect,
  });

  MathLayoutContext asSubscriptContext() {
    return MathLayoutContext(
      activeContainerId: activeContainerId,
      activeChildIndex: activeChildIndex,
      cursorVisible: cursorVisible,
      isInsertMode: isInsertMode,
      isResultDisplayed: isResultDisplayed,
      scaleLevel: scaleLevel + 1,
    );
  }
}

int _nextNodeUid = 1;
String generateMathNodeId([String prefix = 'node']) =>
    '${prefix}_${_nextNodeUid++}';

// =============================================================================
// Abstract Base Visual AST Node
// =============================================================================

/// Base class for all nodes in the Cal_ 1100_DB_ 2D Natural Textbook AST.
abstract class MathNode {
  final String id;

  MathNode({String? id}) : id = id ?? generateMathNodeId();

  /// Computes the 2D baseline-aware metrics in virtual LCD pixel coordinates.
  MathMetrics computeMetrics({int scaleLevel = 0});

  /// Measures the bounding [Size] of this node for a given [TextStyle].
  Size measure(TextStyle style) {
    final double fontScale = (style.fontSize ?? 7.0) / 7.0;
    final metrics = computeMetrics(scaleLevel: fontScale < 0.8 ? 1 : 0);
    return metrics.toSize(fontScale);
  }

  /// Renders this node onto a Flutter [Canvas] at [offset] (top-left of bounding box).
  void render(Canvas canvas, Offset offset, {TextStyle? style}) {
    final metrics = computeMetrics();
    final tempBuffer = LcdFrameBuffer(
      width: math.max(metrics.width + 4, 8),
      height: math.max(metrics.height + 4, 8),
    );
    final ctx = MathLayoutContext(
      activeContainerId: '',
      activeChildIndex: -1,
      cursorVisible: false,
      isResultDisplayed: true,
    );
    renderToLcd(tempBuffer, 0, metrics.ascent, ctx);

    final paint = Paint()..color = style?.color ?? Cal_Theme.lcdInk;
    for (int y = 0; y < tempBuffer.height; y++) {
      for (int x = 0; x < tempBuffer.width; x++) {
        if (tempBuffer.getPixel(x, y) > 0) {
          canvas.drawRect(
            Rect.fromLTWH(offset.dx + x, offset.dy + y, 1, 1),
            paint,
          );
        }
      }
    }
  }

  /// Renders this node directly onto the 192×63 4-shade [LcdFrameBuffer]
  /// with horizontal start [x] and mathematical axis aligned at [baselineY].
  void renderToLcd(
    LcdFrameBuffer fb,
    int x,
    int baselineY,
    MathLayoutContext ctx,
  );

  /// Returns the ordered list of child [MathContainerNode]s owned by this node
  /// in canonical Cal_ 1100_DB_ cursor tab order.
  List<MathContainerNode> get childContainers => const [];

  /// Serializes this visual node into an unambiguous mathematical string for evaluation.
  String toEvalString();

  /// Serializes this visual node into a linear display string for history/status.
  String toDisplayString();

  /// Deep-clones this node with fresh IDs.
  MathNode clone();
}

// =============================================================================
// 1. MathContainerNode (Sequential Horizontal Row of Child Nodes)
// =============================================================================

/// Holds a sequential list of [MathNode] children and manages horizontal cursor
/// slots `0 .. children.length` between nodes.
class MathContainerNode extends MathNode {
  final List<MathNode> children;
  final bool showEmptyPlaceholder;

  MathContainerNode({
    super.id,
    List<MathNode>? children,
    this.showEmptyPlaceholder = true,
  }) : children = children ?? <MathNode>[];

  bool get isEmpty => children.isEmpty;

  @override
  MathMetrics computeMetrics({int scaleLevel = 0}) {
    if (children.isEmpty) {
      if (!showEmptyPlaceholder) {
        return MathMetrics(
          width: 2,
          ascent: scaleLevel > 0 ? 5 : 7,
          descent: 0,
        );
      }
      // Empty 2D template placeholder box (□ / ■)
      final int boxW = scaleLevel > 0 ? 5 : 6;
      final int boxAscent = scaleLevel > 0 ? 5 : 7;
      return MathMetrics(width: boxW, ascent: boxAscent, descent: 0);
    }

    int totalW = 0;
    int maxAscent = scaleLevel > 0 ? 5 : 7;
    int maxDescent = 0;

    for (int i = 0; i < children.length; i++) {
      final m = children[i].computeMetrics(scaleLevel: scaleLevel);
      totalW += m.width;
      if (i < children.length - 1) {
        totalW += 1; // 1px inter-node spacing
      }
      if (m.ascent > maxAscent) maxAscent = m.ascent;
      if (m.descent > maxDescent) maxDescent = m.descent;
    }

    return MathMetrics(
      width: totalW,
      ascent: maxAscent,
      descent: maxDescent,
    );
  }

  @override
  void renderToLcd(
    LcdFrameBuffer fb,
    int x,
    int baselineY,
    MathLayoutContext ctx,
  ) {
    final bool isFocusedContainer =
        !ctx.isResultDisplayed && ctx.activeContainerId == id;
    final List<Rect> slotRects = [];

    if (children.isEmpty) {
      final int boxW = ctx.scaleLevel > 0 ? 4 : 5;
      final int boxH = ctx.scaleLevel > 0 ? 5 : 7;
      final int topY = baselineY - boxH;
      final rect = Rect.fromLTWH(
        x.toDouble(),
        topY.toDouble(),
        boxW.toDouble(),
        boxH.toDouble(),
      );
      slotRects.add(rect);
      ctx.slotBoundsByContainer[id] = slotRects;

      if (showEmptyPlaceholder) {
        if (isFocusedContainer) {
          // Focused placeholder: solid Shade 4 box when cursor blink is ON,
          // outlined Shade 3 box when blink is OFF
          if (ctx.cursorVisible) {
            fb.fillRect(x, topY, boxW, boxH, 4);
          } else {
            fb.drawRectOutline(x, topY, boxW, boxH, 4);
          }
        } else {
          // Unfocused placeholder: Shade 2 outline (`#747C74`)
          fb.drawRectOutline(x, topY, boxW, boxH, 2);
        }
      } else if (isFocusedContainer && ctx.cursorVisible) {
        // Root empty line cursor
        fb.fillRect(x, topY - 1, ctx.isInsertMode ? 2 : 5, boxH + 2, 4);
      }

      if (isFocusedContainer) {
        ctx.resolvedCursorRect = rect;
      }
      return;
    }

    int cursorX = x;
    final int defaultAscent = ctx.scaleLevel > 0 ? 5 : 7;

    for (int i = 0; i <= children.length; i++) {
      final slotRect = Rect.fromLTWH(
        cursorX.toDouble(),
        (baselineY - defaultAscent).toDouble(),
        2.0,
        (defaultAscent + 1).toDouble(),
      );
      slotRects.add(slotRect);

      if (isFocusedContainer && ctx.activeChildIndex == i) {
        ctx.resolvedCursorRect = slotRect;
        if (ctx.cursorVisible && ctx.isInsertMode) {
          fb.fillRect(
            cursorX - 1,
            baselineY - defaultAscent - 1,
            2,
            defaultAscent + 2,
            4,
          );
        }
      }

      if (i < children.length) {
        final child = children[i];
        final childMetrics = child.computeMetrics(scaleLevel: ctx.scaleLevel);

        final bool isOverwrittenNode =
            isFocusedContainer &&
            !ctx.isInsertMode &&
            ctx.activeChildIndex == i;

        if (isOverwrittenNode && ctx.cursorVisible) {
          fb.fillRect(
            cursorX,
            baselineY - childMetrics.ascent - 1,
            childMetrics.width,
            childMetrics.height + 2,
            4,
          );
          // Render inverted if CharNode
          if (child is CharNode) {
            child.renderToLcdWithShade(
              fb,
              cursorX,
              baselineY,
              ctx,
              overrideShade: 0,
            );
          } else {
            child.renderToLcd(fb, cursorX, baselineY, ctx);
          }
        } else {
          child.renderToLcd(fb, cursorX, baselineY, ctx);
        }

        cursorX += childMetrics.width + 1;
      } else if (isFocusedContainer &&
          !ctx.isInsertMode &&
          ctx.activeChildIndex == children.length &&
          ctx.cursorVisible) {
        fb.fillRect(
          cursorX,
          baselineY - defaultAscent - 1,
          5,
          defaultAscent + 2,
          4,
        );
      }
    }

    ctx.slotBoundsByContainer[id] = slotRects;
  }

  @override
  String toEvalString() {
    if (children.isEmpty) return '';
    return children.map((c) => c.toEvalString()).join();
  }

  @override
  String toDisplayString() {
    if (children.isEmpty) return '□';
    return children.map((c) => c.toDisplayString()).join();
  }

  @override
  MathContainerNode clone() {
    return MathContainerNode(
      showEmptyPlaceholder: showEmptyPlaceholder,
      children: children.map((c) => c.clone()).toList(),
    );
  }
}

// =============================================================================
// 2. CharNode (Digits, Operators, Variables, Atomic Function Names)
// =============================================================================

/// Atomic character or function prefix token (e.g. `7`, `+`, `x`, `sin(`).
class CharNode extends MathNode {
  final String display;
  final String evalText;

  CharNode({
    super.id,
    required this.display,
    String? evalText,
  }) : evalText = evalText ?? display;

  /// Whether this node is an operand constituent (digit, decimal, variable, π, Ans)
  /// eligible for automatic numerator/exponent wrapping.
  bool get isOperandToken {
    const operators = {'+', '−', '-', '×', '÷', '=', ','};
    if (operators.contains(display)) return false;
    if (display.endsWith('(')) return false;
    return true;
  }

  @override
  MathMetrics computeMetrics({int scaleLevel = 0}) {
    if (scaleLevel > 0) {
      // Compact 3×5 font for superscripts, subscripts, and root indices
      final int w = display.length * 4 - 1;
      return MathMetrics(width: math.max(w, 3), ascent: 5, descent: 0);
    }
    // Standard 5×7 font
    final int w = display.length * 6 - 1;
    return MathMetrics(width: math.max(w, 5), ascent: 7, descent: 0);
  }

  @override
  void renderToLcd(
    LcdFrameBuffer fb,
    int x,
    int baselineY,
    MathLayoutContext ctx,
  ) {
    renderToLcdWithShade(fb, x, baselineY, ctx, overrideShade: 4);
  }

  void renderToLcdWithShade(
    LcdFrameBuffer fb,
    int x,
    int baselineY,
    MathLayoutContext ctx, {
    int overrideShade = 4,
  }) {
    if (ctx.scaleLevel > 0) {
      // Render using 3×5 micro font
      int cx = x;
      final int topY = baselineY - 5;
      for (int i = 0; i < display.length; i++) {
        final rows = LcdBitmapFont.microGlyph3x5(display[i]);
        for (int r = 0; r < 5; r++) {
          final bits = rows[r];
          for (int c = 0; c < 3; c++) {
            if ((bits & (1 << (2 - c))) != 0) {
              fb.setPixel(cx + c, topY + r, overrideShade);
            }
          }
        }
        cx += 4;
      }
      return;
    }

    fb.drawText(
      display,
      x,
      baselineY - 7,
      shade: overrideShade,
      letterSpacing: 1,
    );
  }

  @override
  String toEvalString() => evalText;

  @override
  String toDisplayString() => display;

  @override
  CharNode clone() => CharNode(display: display, evalText: evalText);
}

// =============================================================================
// 3. FractionNode (Proper/Improper & Mixed Fractions)
// =============================================================================

/// 2D Fraction (and optional Mixed Fraction) node containing [numerator],
/// [denominator], and optional [integerPart] separated by a dynamic vinculum bar.
class FractionNode extends MathNode {
  final MathContainerNode? integerPart;
  final MathContainerNode numerator;
  final MathContainerNode denominator;

  FractionNode({
    super.id,
    this.integerPart,
    MathContainerNode? numerator,
    MathContainerNode? denominator,
  })  : numerator = numerator ?? MathContainerNode(),
        denominator = denominator ?? MathContainerNode();

  @override
  List<MathContainerNode> get childContainers => [
    ?integerPart,
    numerator,
    denominator,
  ];

  @override
  MathMetrics computeMetrics({int scaleLevel = 0}) {
    final int childScale = scaleLevel;
    final numM = numerator.computeMetrics(scaleLevel: childScale);
    final denM = denominator.computeMetrics(scaleLevel: childScale);

    final int fracBodyW = math.max(numM.width, denM.width) + 4;
    int intW = 0;
    if (integerPart != null) {
      intW = integerPart!.computeMetrics(scaleLevel: childScale).width + 2;
    }

    // Mathematical axis lies 3px above the baseline:
    // Vinculum bar is at y = baselineY - 3.
    // Numerator baseline is at baselineY - 5 - numM.descent.
    // Denominator top is at baselineY - 1, so denominator baseline is at baselineY - 1 + denM.ascent.
    final int ascent = 5 + numM.descent + numM.ascent;
    final int descent = math.max(0, denM.ascent + denM.descent - 1);

    return MathMetrics(
      width: intW + fracBodyW,
      ascent: ascent,
      descent: descent,
    );
  }

  @override
  void renderToLcd(
    LcdFrameBuffer fb,
    int x,
    int baselineY,
    MathLayoutContext ctx,
  ) {
    int curX = x;
    if (integerPart != null) {
      final intM = integerPart!.computeMetrics(scaleLevel: ctx.scaleLevel);
      integerPart!.renderToLcd(fb, curX, baselineY, ctx);
      curX += intM.width + 2;
    }

    final numM = numerator.computeMetrics(scaleLevel: ctx.scaleLevel);
    final denM = denominator.computeMetrics(scaleLevel: ctx.scaleLevel);
    final int fracBodyW = math.max(numM.width, denM.width) + 4;

    final int barY = baselineY - 3;
    // Draw horizontal vinculum bar
    fb.drawHLine(curX, barY, fracBodyW, 4);

    // Center numerator horizontally above vinculum
    final int numX = curX + ((fracBodyW - numM.width) ~/ 2);
    final int numBaselineY = barY - 2 - numM.descent;
    numerator.renderToLcd(fb, numX, numBaselineY, ctx);

    // Center denominator horizontally below vinculum
    final int denX = curX + ((fracBodyW - denM.width) ~/ 2);
    final int denBaselineY = barY + 2 + denM.ascent;
    denominator.renderToLcd(fb, denX, denBaselineY, ctx);
  }

  @override
  String toEvalString() {
    if (numerator.isEmpty || denominator.isEmpty) {
      throw const FormatException('Empty fraction slot');
    }
    if (integerPart != null && integerPart!.isEmpty) {
      throw const FormatException('Empty mixed fraction integer slot');
    }
    final numStr = '(${numerator.toEvalString()})';
    final denStr = '(${denominator.toEvalString()})';
    if (integerPart != null) {
      final intStr = '(${integerPart!.toEvalString()})';
      return '($intStr+($numStr/$denStr))';
    }
    return '($numStr/$denStr)';
  }

  @override
  String toDisplayString() {
    final prefix =
        integerPart != null ? '${integerPart!.toDisplayString()} ' : '';
    return '$prefix(${numerator.toDisplayString()}/${denominator.toDisplayString()})';
  }

  @override
  FractionNode clone() => FractionNode(
    integerPart: integerPart?.clone(),
    numerator: numerator.clone(),
    denominator: denominator.clone(),
  );
}

// =============================================================================
// 4. RadicalNode (Square Root √x and N-th Root ⁿ√x)
// =============================================================================

/// 2D Radical node containing [radicand] and an optional [index] container
/// for $\sqrt[n]{x}$, with dynamic radical hook and vinculum roof.
class RadicalNode extends MathNode {
  final MathContainerNode? index;
  final MathContainerNode radicand;

  RadicalNode({
    super.id,
    this.index,
    MathContainerNode? radicand,
  }) : radicand = radicand ?? MathContainerNode();

  @override
  List<MathContainerNode> get childContainers => [
    ?index,
    radicand,
  ];

  @override
  MathMetrics computeMetrics({int scaleLevel = 0}) {
    final radM = radicand.computeMetrics(scaleLevel: scaleLevel);
    int indexW = 0;
    int indexAscentBoost = 0;
    if (index != null) {
      final idxM = index!.computeMetrics(scaleLevel: 1);
      indexW = math.max(0, idxM.width - 2);
      indexAscentBoost = math.max(0, idxM.height - (radM.ascent ~/ 2));
    }

    // 5px for radical hook + radicand width + 2px right vinculum overhang
    final int totalW = indexW + 5 + radM.width + 2;
    // 2px for vinculum bar + 1px air gap above radicand
    final int ascent = math.max(radM.ascent + 2, radM.ascent + indexAscentBoost);

    return MathMetrics(
      width: totalW,
      ascent: ascent,
      descent: radM.descent,
    );
  }

  @override
  void renderToLcd(
    LcdFrameBuffer fb,
    int x,
    int baselineY,
    MathLayoutContext ctx,
  ) {
    final radM = radicand.computeMetrics(scaleLevel: ctx.scaleLevel);
    int hookX = x;

    if (index != null) {
      final idxM = index!.computeMetrics(scaleLevel: 1);
      final int idxBaselineY = baselineY - (radM.ascent ~/ 2) - 1;
      index!.renderToLcd(fb, x, idxBaselineY, ctx.asSubscriptContext());
      hookX += math.max(0, idxM.width - 2);
    }

    final int topY = baselineY - radM.ascent - 2;
    final int bottomY = baselineY + radM.descent - 1;
    final int midY = (topY + bottomY) ~/ 2 + 1;

    // Draw radical check hook from (hookX, midY) down to (hookX+2, bottomY)
    // and up to (hookX+4, topY)
    fb.setPixel(hookX, midY, 4);
    fb.setPixel(hookX + 1, midY + 1, 4);
    fb.setPixel(hookX + 2, bottomY, 4);
    fb.drawVLine(hookX + 3, (topY + bottomY) ~/ 2, (bottomY - topY) ~/ 2 + 1, 4);
    fb.drawVLine(hookX + 4, topY, (bottomY - topY) ~/ 2 + 1, 4);

    // Draw top horizontal vinculum bar over entire radicand
    final int vinculumW = radM.width + 2;
    fb.drawHLine(hookX + 4, topY, vinculumW, 4);
    // Right end 1px drop tick on vinculum
    fb.setPixel(hookX + 4 + vinculumW - 1, topY + 1, 4);

    // Render radicand content
    radicand.renderToLcd(fb, hookX + 5, baselineY, ctx);
  }

  @override
  String toEvalString() {
    if (radicand.isEmpty) {
      throw const FormatException('Empty radicand');
    }
    if (index != null) {
      if (index!.isEmpty) {
        throw const FormatException('Empty root index');
      }
      return '((${radicand.toEvalString()})^(1/(${index!.toEvalString()})))';
    }
    return '√(${radicand.toEvalString()})';
  }

  @override
  String toDisplayString() {
    if (index != null) {
      return '${index!.toDisplayString()}√(${radicand.toDisplayString()})';
    }
    return '√(${radicand.toDisplayString()})';
  }

  @override
  RadicalNode clone() => RadicalNode(
    index: index?.clone(),
    radicand: radicand.clone(),
  );
}

// =============================================================================
// 5. SuperscriptNode (Powers & Exponents x^y)
// =============================================================================

/// 2D Superscript / Power node containing an optional [base] container (when
/// inserted on an empty slot) and an [exponent] container rendered in compact
/// script scale and elevated above the mathematical baseline.
class SuperscriptNode extends MathNode {
  final MathContainerNode? base;
  final MathContainerNode exponent;

  SuperscriptNode({
    super.id,
    this.base,
    MathContainerNode? exponent,
  }) : exponent = exponent ?? MathContainerNode();

  @override
  List<MathContainerNode> get childContainers => [
    ?base,
    exponent,
  ];

  @override
  MathMetrics computeMetrics({int scaleLevel = 0}) {
    final expM = exponent.computeMetrics(scaleLevel: 1);
    int baseW = 0;
    int baseAscent = 7;
    int baseDescent = 0;

    if (base != null) {
      final bM = base!.computeMetrics(scaleLevel: scaleLevel);
      baseW = bM.width + 1;
      baseAscent = bM.ascent;
      baseDescent = bM.descent;
    }

    final int totalAscent = math.max(baseAscent, (baseAscent - 3) + expM.ascent);
    return MathMetrics(
      width: baseW + expM.width,
      ascent: totalAscent,
      descent: baseDescent,
    );
  }

  @override
  void renderToLcd(
    LcdFrameBuffer fb,
    int x,
    int baselineY,
    MathLayoutContext ctx,
  ) {
    int curX = x;
    int baseAscent = 7;
    if (base != null) {
      final bM = base!.computeMetrics(scaleLevel: ctx.scaleLevel);
      baseAscent = bM.ascent;
      base!.renderToLcd(fb, curX, baselineY, ctx);
      curX += bM.width + 1;
    }

    final int expBaselineY = baselineY - math.max(4, baseAscent - 2);
    exponent.renderToLcd(fb, curX, expBaselineY, ctx.asSubscriptContext());
  }

  @override
  String toEvalString() {
    if (exponent.isEmpty) {
      throw const FormatException('Empty exponent');
    }
    if (base != null) {
      if (base!.isEmpty) {
        throw const FormatException('Empty power base');
      }
      return '((${base!.toEvalString()})^(${exponent.toEvalString()}))';
    }
    return '^(${exponent.toEvalString()})';
  }

  @override
  String toDisplayString() {
    final b = base != null ? base!.toDisplayString() : '';
    return '$b^(${exponent.toDisplayString()})';
  }

  @override
  SuperscriptNode clone() => SuperscriptNode(
    base: base?.clone(),
    exponent: exponent.clone(),
  );
}

// =============================================================================
// 6. ParenthesisNode & AbsNode (Dynamic Auto-Sizing Brackets / Bars)
// =============================================================================

/// Auto-sizing parentheses `( ... )` or absolute value bars `| ... |` scaling
/// dynamically to the height of their internal [content] container.
class ParenthesisNode extends MathNode {
  final MathContainerNode content;
  final bool isAbsoluteValue;

  ParenthesisNode({
    super.id,
    MathContainerNode? content,
    this.isAbsoluteValue = false,
  }) : content = content ?? MathContainerNode();

  @override
  List<MathContainerNode> get childContainers => [content];

  @override
  MathMetrics computeMetrics({int scaleLevel = 0}) {
    final inner = content.computeMetrics(scaleLevel: scaleLevel);
    // 3px left bracket + 1px pad + inner.width + 1px pad + 3px right bracket
    return MathMetrics(
      width: inner.width + 8,
      ascent: math.max(inner.ascent, 7),
      descent: inner.descent,
    );
  }

  @override
  void renderToLcd(
    LcdFrameBuffer fb,
    int x,
    int baselineY,
    MathLayoutContext ctx,
  ) {
    final inner = content.computeMetrics(scaleLevel: ctx.scaleLevel);
    final int topY = baselineY - math.max(inner.ascent, 7);
    final int bottomY = baselineY + inner.descent - 1;
    final int totalH = bottomY - topY + 1;

    if (isAbsoluteValue) {
      // Dynamic vertical bars |content|
      fb.drawVLine(x + 1, topY, totalH, 4);
      content.renderToLcd(fb, x + 4, baselineY, ctx);
      fb.drawVLine(x + 5 + inner.width, topY, totalH, 4);
      return;
    }

    // Dynamic curved left parenthesis
    fb.setPixel(x + 2, topY, 4);
    fb.setPixel(x + 1, topY + 1, 4);
    fb.drawVLine(x, topY + 2, math.max(1, totalH - 4), 4);
    fb.setPixel(x + 1, bottomY - 1, 4);
    fb.setPixel(x + 2, bottomY, 4);

    // Inner content
    content.renderToLcd(fb, x + 4, baselineY, ctx);

    // Dynamic curved right parenthesis
    final int rx = x + 5 + inner.width;
    fb.setPixel(rx, topY, 4);
    fb.setPixel(rx + 1, topY + 1, 4);
    fb.drawVLine(rx + 2, topY + 2, math.max(1, totalH - 4), 4);
    fb.setPixel(rx + 1, bottomY - 1, 4);
    fb.setPixel(rx, bottomY, 4);
  }

  @override
  String toEvalString() {
    if (content.isEmpty) {
      throw const FormatException('Empty parenthesis');
    }
    if (isAbsoluteValue) {
      return 'Abs(${content.toEvalString()})';
    }
    return '(${content.toEvalString()})';
  }

  @override
  String toDisplayString() {
    if (isAbsoluteValue) {
      return '|${content.toDisplayString()}|';
    }
    return '(${content.toDisplayString()})';
  }

  @override
  ParenthesisNode clone() => ParenthesisNode(
    content: content.clone(),
    isAbsoluteValue: isAbsoluteValue,
  );
}

// =============================================================================
// 7. LogBaseNode (Arbitrary-Base Logarithm log_a(b))
// =============================================================================

/// 2D Logarithm with arbitrary subscript [base] and parenthesized [argument].
class LogBaseNode extends MathNode {
  final MathContainerNode base;
  final MathContainerNode argument;

  LogBaseNode({
    super.id,
    MathContainerNode? base,
    MathContainerNode? argument,
  })  : base = base ?? MathContainerNode(),
        argument = argument ?? MathContainerNode();

  @override
  List<MathContainerNode> get childContainers => [base, argument];

  @override
  MathMetrics computeMetrics({int scaleLevel = 0}) {
    final baseM = base.computeMetrics(scaleLevel: 1);
    final argM = argument.computeMetrics(scaleLevel: scaleLevel);
    // "log" (17px) + baseM.width + "(" (4px) + argM.width + ")" (4px)
    return MathMetrics(
      width: 18 + baseM.width + 8 + argM.width,
      ascent: math.max(7, argM.ascent),
      descent: math.max(3, argM.descent),
    );
  }

  @override
  void renderToLcd(
    LcdFrameBuffer fb,
    int x,
    int baselineY,
    MathLayoutContext ctx,
  ) {
    fb.drawText('log', x, baselineY - 7, shade: 4);
    int curX = x + 18;

    final baseM = base.computeMetrics(scaleLevel: 1);
    base.renderToLcd(fb, curX, baselineY + 3, ctx.asSubscriptContext());
    curX += baseM.width + 1;

    final argM = argument.computeMetrics(scaleLevel: ctx.scaleLevel);
    final int topY = baselineY - math.max(argM.ascent, 7);
    final int bottomY = baselineY + argM.descent - 1;
    final int totalH = bottomY - topY + 1;

    // Left paren
    fb.setPixel(curX + 2, topY, 4);
    fb.drawVLine(curX + 1, topY + 1, math.max(1, totalH - 2), 4);
    fb.setPixel(curX + 2, bottomY, 4);
    curX += 4;

    argument.renderToLcd(fb, curX, baselineY, ctx);
    curX += argM.width + 1;

    // Right paren
    fb.setPixel(curX, topY, 4);
    fb.drawVLine(curX + 1, topY + 1, math.max(1, totalH - 2), 4);
    fb.setPixel(curX, bottomY, 4);
  }

  @override
  String toEvalString() {
    if (base.isEmpty || argument.isEmpty) {
      throw const FormatException('Empty log_a(b) slot');
    }
    return 'log(${base.toEvalString()},${argument.toEvalString()})';
  }

  @override
  String toDisplayString() =>
      'log_${base.toDisplayString()}(${argument.toDisplayString()})';

  @override
  LogBaseNode clone() => LogBaseNode(
    base: base.clone(),
    argument: argument.clone(),
  );
}

// =============================================================================
// 8. Advanced Calculus & Analysis Template Nodes (∫, ∑, d/dx)
// =============================================================================

/// 2D Definite Integral node: $\int_{\text{lower}}^{\text{upper}} (\text{body})\,dx$.
class IntegralNode extends MathNode {
  final MathContainerNode lower;
  final MathContainerNode upper;
  final MathContainerNode body;

  IntegralNode({
    super.id,
    MathContainerNode? lower,
    MathContainerNode? upper,
    MathContainerNode? body,
  })  : lower = lower ?? MathContainerNode(),
        upper = upper ?? MathContainerNode(),
        body = body ?? MathContainerNode();

  /// Cal_ CW tab order: Integrand body -> Lower limit -> Upper limit.
  @override
  List<MathContainerNode> get childContainers => [body, lower, upper];

  @override
  MathMetrics computeMetrics({int scaleLevel = 0}) {
    final lowM = lower.computeMetrics(scaleLevel: 1);
    final upM = upper.computeMetrics(scaleLevel: 1);
    final bodyM = body.computeMetrics(scaleLevel: scaleLevel);

    final int limitsW = math.max(lowM.width, upM.width);
    // 6px integral symbol + limitsW + 2px pad + bodyM.width + 2px pad + "dx" (11px)
    final int totalW = 6 + limitsW + 2 + bodyM.width + 13;
    final int ascent = math.max(bodyM.ascent + 2, 7 + upM.ascent);
    final int descent = math.max(bodyM.descent + 2, 3 + lowM.ascent);

    return MathMetrics(width: totalW, ascent: ascent, descent: descent);
  }

  @override
  void renderToLcd(
    LcdFrameBuffer fb,
    int x,
    int baselineY,
    MathLayoutContext ctx,
  ) {
    final lowM = lower.computeMetrics(scaleLevel: 1);
    final upM = upper.computeMetrics(scaleLevel: 1);
    final bodyM = body.computeMetrics(scaleLevel: ctx.scaleLevel);

    final int topY = baselineY - math.max(bodyM.ascent, 9);
    final int bottomY = baselineY + math.max(bodyM.descent, 4);

    // Tall integral symbol ∫
    fb.setPixel(x + 3, topY, 4);
    fb.setPixel(x + 4, topY, 4);
    fb.drawVLine(x + 2, topY + 1, bottomY - topY - 1, 4);
    fb.setPixel(x, bottomY, 4);
    fb.setPixel(x + 1, bottomY, 4);

    // Upper and lower limits in compact script font
    final int limitsX = x + 6;
    upper.renderToLcd(fb, limitsX, topY + 4, ctx.asSubscriptContext());
    lower.renderToLcd(fb, limitsX, bottomY + 1, ctx.asSubscriptContext());

    int curX = limitsX + math.max<int>(lowM.width, upM.width) + 2;

    // Integrand body + "dx" (no forced outer parentheses, matching 1100_DB_)
    body.renderToLcd(fb, curX, baselineY, ctx);
    curX += bodyM.width + 2;
    fb.drawText('dx', curX, baselineY - 7, shade: 4);
  }

  @override
  String toEvalString() {
    if (body.isEmpty || lower.isEmpty || upper.isEmpty) {
      throw const FormatException('Empty integral slot');
    }
    return 'integrate(${body.toEvalString()},${lower.toEvalString()},${upper.toEvalString()})';
  }

  @override
  String toDisplayString() =>
      '∫(${body.toDisplayString()},${lower.toDisplayString()},${upper.toDisplayString()})';

  @override
  IntegralNode clone() => IntegralNode(
    lower: lower.clone(),
    upper: upper.clone(),
    body: body.clone(),
  );
}

/// 2D Discrete Summation or Product node: $\sum_{x=\text{start}}^{\text{end}} (\text{body})$
/// or $\prod_{x=\text{start}}^{\text{end}} (\text{body})$.
class SummationNode extends MathNode {
  final MathContainerNode start;
  final MathContainerNode end;
  final MathContainerNode body;
  final bool isProduct;

  SummationNode({
    super.id,
    MathContainerNode? start,
    MathContainerNode? end,
    MathContainerNode? body,
    this.isProduct = false,
  })  : start = start ?? MathContainerNode(),
        end = end ?? MathContainerNode(),
        body = body ?? MathContainerNode();

  @override
  List<MathContainerNode> get childContainers => [body, start, end];

  @override
  MathMetrics computeMetrics({int scaleLevel = 0}) {
    final startM = start.computeMetrics(scaleLevel: 1);
    final endM = end.computeMetrics(scaleLevel: 1);
    final bodyM = body.computeMetrics(scaleLevel: scaleLevel);

    final int sigmaW = math.max(10, math.max(8 + startM.width, endM.width));
    return MathMetrics(
      width: sigmaW + 9 + bodyM.width,
      ascent: math.max(bodyM.ascent, 8 + endM.ascent),
      descent: math.max(bodyM.descent, 4 + startM.ascent),
    );
  }

  @override
  void renderToLcd(
    LcdFrameBuffer fb,
    int x,
    int baselineY,
    MathLayoutContext ctx,
  ) {
    final startM = start.computeMetrics(scaleLevel: 1);
    final endM = end.computeMetrics(scaleLevel: 1);
    final bodyM = body.computeMetrics(scaleLevel: ctx.scaleLevel);
    final int blockW = math.max(10, math.max(8 + startM.width, endM.width));

    final int sigX = x + ((blockW - 6) ~/ 2);
    if (isProduct) {
      // Draw capital Pi ∏ symbol
      fb.drawHLine(sigX, baselineY - 7, 5, 4);
      fb.drawVLine(sigX + 1, baselineY - 6, 6, 4);
      fb.drawVLine(sigX + 3, baselineY - 6, 6, 4);
    } else {
      fb.drawGlyph5x7('∑', sigX, baselineY - 7, shade: 4);
    }

    // Upper bound above ∑ / ∏
    final int endX = x + ((blockW - endM.width) ~/ 2);
    end.renderToLcd(fb, endX, baselineY - 8, ctx.asSubscriptContext());

    // Lower bound "x=□" below ∑ / ∏
    fb.setPixel(x, baselineY + 2, 4);
    fb.setPixel(x + 2, baselineY + 2, 4);
    fb.setPixel(x + 1, baselineY + 3, 4);
    fb.setPixel(x, baselineY + 4, 4);
    fb.setPixel(x + 2, baselineY + 4, 4);
    fb.drawHLine(x + 4, baselineY + 2, 3, 4);
    fb.drawHLine(x + 4, baselineY + 4, 3, 4);
    start.renderToLcd(fb, x + 8, baselineY + 5, ctx.asSubscriptContext());

    int curX = x + blockW + 2;
    fb.drawGlyph5x7('(', curX, baselineY - 7, shade: 4);
    curX += 5;
    body.renderToLcd(fb, curX, baselineY, ctx);
    curX += bodyM.width + 1;
    fb.drawGlyph5x7(')', curX, baselineY - 7, shade: 4);
  }

  @override
  String toEvalString() {
    if (body.isEmpty || start.isEmpty || end.isEmpty) {
      throw const FormatException('Empty summation/product slot');
    }
    final String fn = isProduct ? 'prod' : 'sum';
    return '$fn(${body.toEvalString()},${start.toEvalString()},${end.toEvalString()})';
  }

  @override
  String toDisplayString() {
    final String sym = isProduct ? '∏' : '∑';
    return '$sym(${body.toDisplayString()},${start.toDisplayString()},${end.toDisplayString()})';
  }

  @override
  SummationNode clone() => SummationNode(
    start: start.clone(),
    end: end.clone(),
    body: body.clone(),
    isProduct: isProduct,
  );
}

/// 2D Numerical Derivative node: $\left.\frac{d}{dx}(\text{body})\right|_{x=\text{atValue}}$.
class DerivativeNode extends MathNode {
  final MathContainerNode body;
  final MathContainerNode atValue;

  DerivativeNode({
    super.id,
    MathContainerNode? body,
    MathContainerNode? atValue,
  })  : body = body ?? MathContainerNode(),
        atValue = atValue ?? MathContainerNode();

  @override
  List<MathContainerNode> get childContainers => [body, atValue];

  @override
  MathMetrics computeMetrics({int scaleLevel = 0}) {
    final bodyM = body.computeMetrics(scaleLevel: scaleLevel);
    final atM = atValue.computeMetrics(scaleLevel: 1);
    // "d/dx(" (24px) + bodyM.width + ")|x=" (16px) + atM.width
    return MathMetrics(
      width: 24 + bodyM.width + 16 + atM.width,
      ascent: math.max(9, bodyM.ascent),
      descent: math.max(4, bodyM.descent),
    );
  }

  @override
  void renderToLcd(
    LcdFrameBuffer fb,
    int x,
    int baselineY,
    MathLayoutContext ctx,
  ) {
    // Compact 2D d/dx fraction prefix
    fb.drawText('d', x + 3, baselineY - 9, shade: 4);
    fb.drawHLine(x, baselineY - 3, 11, 4);
    fb.drawText('dx', x, baselineY - 1, shade: 4);

    int curX = x + 13;
    final bodyM = body.computeMetrics(scaleLevel: ctx.scaleLevel);
    fb.drawGlyph5x7('(', curX, baselineY - 7, shade: 4);
    curX += 5;
    body.renderToLcd(fb, curX, baselineY, ctx);
    curX += bodyM.width + 1;
    fb.drawGlyph5x7(')', curX, baselineY - 7, shade: 4);
    curX += 5;

    // Evaluation bar |x=□
    fb.drawVLine(curX, baselineY - 9, 13, 4);
    curX += 2;
    fb.setPixel(curX, baselineY + 1, 4);
    fb.setPixel(curX + 2, baselineY + 1, 4);
    fb.setPixel(curX + 1, baselineY + 2, 4);
    fb.setPixel(curX, baselineY + 3, 4);
    fb.setPixel(curX + 2, baselineY + 3, 4);
    fb.drawHLine(curX + 4, baselineY + 1, 3, 4);
    fb.drawHLine(curX + 4, baselineY + 3, 3, 4);
    curX += 8;

    atValue.renderToLcd(fb, curX, baselineY + 4, ctx.asSubscriptContext());
  }

  @override
  String toEvalString() {
    if (body.isEmpty || atValue.isEmpty) {
      throw const FormatException('Empty derivative slot');
    }
    return 'deriv(${body.toEvalString()},${atValue.toEvalString()})';
  }

  @override
  String toDisplayString() =>
      'd/dx(${body.toDisplayString()},${atValue.toDisplayString()})';

  @override
  DerivativeNode clone() => DerivativeNode(
    body: body.clone(),
    atValue: atValue.clone(),
  );
}
