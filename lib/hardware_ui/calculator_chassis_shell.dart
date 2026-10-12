import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/calculator_theme.dart';
import '../display_engine/lcd_display_widget.dart';
import '../state/calculator_controller.dart';
import '../state/calculator_models.dart';
import 'calculator_keypad_matrix.dart';

/// Complete physical handheld chassis of the Cal_ 1100_DB_ ClassWiz,
/// faithfully replicating the double-walled dark matte casing, stacked
/// `Cal_` / `1100_DB_` header, wide recessed solar cell, `CLASSWIZ` LCD bezel,
/// and 48-key circular pebble matrix.
class Cal_ChassisShell extends StatefulWidget {
  const Cal_ChassisShell({super.key});

  @override
  State<Cal_ChassisShell> createState() => _Cal_ChassisShellState();
}

class _Cal_ChassisShellState extends State<Cal_ChassisShell> {
  final FocusNode _keyboardFocusNode = FocusNode();
  double _cachedTopCutoutInset = 0.0;

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final controller = CalculatorScope.of(context);
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      controller.pressExe();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      controller.pressBackspace();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      controller.pressAc();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      controller.pressCursorLeft();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      controller.pressCursorRight();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      controller.pressCursorUp();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      controller.pressCursorDown();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageUp) {
      controller.pressPageUp();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageDown) {
      controller.pressPageDown();
      return KeyEventResult.handled;
    }

    final String? ch = event.character;
    if (ch != null && ch.isNotEmpty) {
      if (RegExp(r'^[0-9.]$').hasMatch(ch)) {
        controller.insertToken(InputToken(display: ch, evalText: ch));
        return KeyEventResult.handled;
      }
      if (ch == '+') {
        controller.insertToken(
          const InputToken(display: '+', evalText: '+'),
          isBinaryOperator: true,
        );
        return KeyEventResult.handled;
      }
      if (ch == '-') {
        controller.insertToken(
          const InputToken(display: '−', evalText: '−'),
          isBinaryOperator: true,
        );
        return KeyEventResult.handled;
      }
      if (ch == '*') {
        controller.insertToken(
          const InputToken(display: '×', evalText: '×'),
          isBinaryOperator: true,
        );
        return KeyEventResult.handled;
      }
      if (ch == '/') {
        controller.insertToken(
          const InputToken(display: '÷', evalText: '÷'),
          isBinaryOperator: true,
        );
        return KeyEventResult.handled;
      }
      if (ch == '^') {
        controller.insertToken(
          const InputToken(display: '^', evalText: '^'),
          isBinaryOperator: true,
        );
        return KeyEventResult.handled;
      }
      if (ch == '(' || ch == ')') {
        controller.insertToken(InputToken(display: ch, evalText: ch));
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    final double dpr = view.devicePixelRatio > 0 ? view.devicePixelRatio : 1.0;
    final double viewTop = view.viewPadding.top / dpr;
    final double mqViewTop = MediaQuery.viewPaddingOf(context).top;
    final double mqPadTop = MediaQuery.paddingOf(context).top;
    final double reportedTop = math.max(viewTop, math.max(mqViewTop, mqPadTop));
    if (reportedTop > _cachedTopCutoutInset) {
      _cachedTopCutoutInset = reportedTop;
    }

    final Size screenSize = MediaQuery.sizeOf(context);
    final bool isTallPortraitPhone =
        screenSize.height > 650 && (screenSize.height / screenSize.width) > 1.80;
    final double topNotchInset = _cachedTopCutoutInset > 0
        ? _cachedTopCutoutInset
        : (isTallPortraitPhone ? 34.0 : 0.0);

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0C0E),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 460,
              ),
              // Outer molded dark casing rim extending all the way up to cover the top notch area
              child: Container(
                margin: const EdgeInsets.fromLTRB(2, 0, 2, 2),
                padding: const EdgeInsets.all(5.0),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(34),
                    topRight: Radius.circular(34),
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF2B2C30),
                      Color(0xFF1A1B1E),
                      Color(0xFF111214),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFF3A3C42),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black,
                      blurRadius: 28,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                // Inner recessed faceplate with subtle specular rim
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(29),
                      topRight: Radius.circular(29),
                      bottomLeft: Radius.circular(35),
                      bottomRight: Radius.circular(35),
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF25262A),
                        Cal_Theme.chassisSurface,
                        Color(0xFF1A1B1E),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFF0C0D0F),
                      width: 1.8,
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isCompactLandscape =
                          constraints.maxHeight < 520;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Upper chassis expansion covering the camera cutout / notch area
                          // plus the 52px top faceplate height from the former solar-cell header
                          if (!isCompactLandscape)
                            SizedBox(height: topNotchInset + 52.0)
                          else
                            const SizedBox(height: 8.0),

                          // 1. High-Resolution 4-Shade LCD Screen Bezel
                          const LcdDisplayWidget(),

                          // 2. Full-Height Actual-Size 48-Key Circular Pebble Keypad Matrix
                          Expanded(
                            child: isCompactLandscape
                                ? const SingleChildScrollView(
                                    physics: BouncingScrollPhysics(),
                                    child: SizedBox(
                                      height: 500,
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          top: 2,
                                          bottom: 8,
                                        ),
                                        child: Cal_KeypadMatrix(),
                                      ),
                                    ),
                                  )
                                : const Padding(
                                    padding: EdgeInsets.only(
                                      top: 2,
                                      bottom: 8,
                                    ),
                                    child: Cal_KeypadMatrix(),
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
