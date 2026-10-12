import 'package:flutter/material.dart';
import '../core/calculator_theme.dart';
import '../display_engine/math_nodes.dart';
import '../state/calculator_controller.dart';
import '../state/calculator_models.dart';
import 'pebble_key_button.dart';

/// Complete 48-key physical layout of the Cal_ 1100_DB_ ClassWiz,
/// faithfully replicating the exact 9-row geometry, Cross D-Pad, Page Scroll
/// Rocker (`︽`/`︾`), metallic gold `SHIFT` key, and `└` Shift legends from hardware.
class Cal_KeypadMatrix extends StatelessWidget {
  const Cal_KeypadMatrix({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = CalculatorScope.of(context);
    final state = controller.state;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ===================================================================
          // ZONE 1: Top Control, System & Cross D-Pad Cluster (Rows 1–3)
          // ===================================================================
          Expanded(
            flex: 32,
            child: _buildTopNavigationCluster(
              controller,
              state.isShift,
              state.isAlpha,
            ),
          ),
          const SizedBox(height: 3),

          // ===================================================================
          // ZONE 2: Middle Scientific Key Grid (Rows 4–5: 6 circular keys/row)
          // ===================================================================
          Expanded(
            flex: 22,
            child: _buildScientificGrid(
              controller,
              state.isShift,
              state.isAlpha,
            ),
          ),
          const SizedBox(height: 4),

          // ===================================================================
          // ZONE 3: Bottom Numeric & Execution Pad (Rows 6–9: 5 large circular keys/row)
          // ===================================================================
          Expanded(
            flex: 52,
            child: _buildNumericExecutionPad(
              controller,
              state.isShift,
              state.isAlpha,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ZONE 1: Top 6-Column Navigation Cluster (Rows 1, 2, 3)
  // ===========================================================================
  Widget _buildTopNavigationCluster(
    CalculatorController controller,
    bool isShift,
    bool isAlpha,
  ) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Sculpted dark recessed cross-shaped channel behind the 5-button D-Pad
        Positioned.fill(
          child: CustomPaint(
            painter: _DPadCrossChannelPainter(),
          ),
        ),
        Column(
          children: [
            // ROW 1: [ON] [HOME] [ ] [▲] [ ] [︽]
            Expanded(
              flex: 10,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Col 1: ON (recessed smaller circular button)
                  Expanded(
                    child: PebbleKeyButton(
                      primaryLabel: 'ON',
                      topCenterLabel: 'ON',
                      style: PebbleKeyStyle.systemDark,
                      height: 28,
                      fontSize: 9,
                      diameterScale: 0.82,
                      primaryCustomChild: const Cal_OnKeyIcon(),
                      onTap: controller.pressOn,
                    ),
                  ),
                  // Col 2: HOME
                  Expanded(
                    child: PebbleKeyButton(
                      primaryLabel: 'HOME',
                      topCenterLabel: 'HOME',
                      style: PebbleKeyStyle.systemDark,
                      height: 34,
                      fontSize: 9,
                      primaryCustomChild: const Cal_HomeKeyIcon(),
                      onTap: controller.pressHome,
                    ),
                  ),
                  // Col 3: empty space above D-Pad Left
                  const Expanded(child: SizedBox.expand()),
                  // Col 4: D-Pad UP (^)
                  Expanded(
                    child: Cal_DPadRoundButton(
                      size: 35,
                      onTap: controller.pressCursorUp,
                      child: const Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 21,
                        color: Color(0xFF0E0F11),
                      ),
                    ),
                  ),
                  // Col 5: empty space above D-Pad Right
                  const Expanded(child: SizedBox.expand()),
                  // Col 6: Page Up (︽)
                  Expanded(
                    child: PebbleKeyButton(
                      primaryLabel: 'PAGE UP',
                      topCenterLabel: ' ',
                      style: PebbleKeyStyle.systemDark,
                      height: 34,
                      fontSize: 9,
                      primaryCustomChild: const Cal_PageUpKeyIcon(),
                      onTap: controller.pressPageUp,
                    ),
                  ),
                ],
              ),
            ),

            // ROW 2: [SETTINGS] [BACK] [◀] [OK] [▶] [︾]
            Expanded(
              flex: 11,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Col 1: SETTINGS
                  Expanded(
                    child: PebbleKeyButton(
                      primaryLabel: 'SETTINGS',
                      topCenterLabel: 'SETTINGS',
                      style: PebbleKeyStyle.systemDark,
                      height: 34,
                      fontSize: 8.5,
                      primaryCustomChild: const Cal_SettingsKeyIcon(),
                      onTap: controller.pressSettings,
                    ),
                  ),
                  // Col 2: BACK (↩, no top label on hardware)
                  Expanded(
                    child: PebbleKeyButton(
                      primaryLabel: 'BACK',
                      topCenterLabel: ' ',
                      style: PebbleKeyStyle.systemDark,
                      height: 34,
                      fontSize: 9,
                      primaryCustomChild: const Cal_BackKeyIcon(),
                      onTap: controller.pressBack,
                    ),
                  ),
                  // Col 3: D-Pad LEFT (<)
                  Expanded(
                    child: Cal_DPadRoundButton(
                      size: 35,
                      onTap: controller.pressCursorLeft,
                      child: const Icon(
                        Icons.keyboard_arrow_left_rounded,
                        size: 21,
                        color: Color(0xFF0E0F11),
                      ),
                    ),
                  ),
                  // Col 4: D-Pad Center OK
                  Expanded(
                    child: Cal_DPadRoundButton(
                      size: 36,
                      onTap: controller.pressOk,
                      child: Text(
                        'OK',
                        style: TextStyle(
                          color: const Color(0xFF0D0E10),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                          shadows: [
                            Shadow(
                              color: Colors.white.withValues(alpha: 0.18),
                              offset: const Offset(0, 0.6),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Col 5: D-Pad RIGHT (>)
                  Expanded(
                    child: Cal_DPadRoundButton(
                      size: 35,
                      onTap: controller.pressCursorRight,
                      child: const Icon(
                        Icons.keyboard_arrow_right_rounded,
                        size: 21,
                        color: Color(0xFF0E0F11),
                      ),
                    ),
                  ),
                  // Col 6: Page Down (︾)
                  Expanded(
                    child: PebbleKeyButton(
                      primaryLabel: 'PAGE DOWN',
                      topCenterLabel: ' ',
                      style: PebbleKeyStyle.systemDark,
                      height: 34,
                      fontSize: 9,
                      primaryCustomChild: const Cal_PageDownKeyIcon(),
                      onTap: controller.pressPageDown,
                    ),
                  ),
                ],
              ),
            ),

            // ROW 3: [SHIFT] [VARIABLE] [FUNCTION] [▼] [CATALOG] [TOOLS]
            Expanded(
              flex: 11,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Col 1: SHIFT (Metallic Champagne-Gold button with upward arrow)
                  Expanded(
                    child: PebbleKeyButton(
                      primaryLabel: 'SHIFT',
                      topCenterLabel: 'SHIFT',
                      topCenterLabelColor: Cal_Theme.labelShiftGold,
                      style: PebbleKeyStyle.shiftGold,
                      height: 34,
                      fontSize: 9.5,
                      isLatched: isShift,
                      primaryCustomChild: const Cal_ShiftArrowIcon(),
                      onTap: controller.pressShift,
                    ),
                  ),
                  // Col 2: VARIABLE (⇄[x])
                  Expanded(
                    child: PebbleKeyButton(
                      primaryLabel: 'VARIABLE',
                      topCenterLabel: 'VARIABLE',
                      style: PebbleKeyStyle.utilityRound,
                      height: 34,
                      fontSize: 9.5,
                      isLatched: isAlpha,
                      primaryCustomChild: const Cal_VariableKeyIcon(),
                      onTap: controller.pressVariable,
                    ),
                  ),
                  // Col 3: FUNCTION (f(x))
                  Expanded(
                    child: PebbleKeyButton(
                      primaryLabel: 'f(x)',
                      topCenterLabel: 'FUNCTION',
                      style: PebbleKeyStyle.utilityRound,
                      height: 34,
                      fontSize: 12.0,
                      primaryCustomChild: const Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'f(',
                              style: TextStyle(
                                color: Cal_Theme.labelPrimary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: 'x',
                              style: TextStyle(
                                color: Cal_Theme.labelPrimary,
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: ')',
                              style: TextStyle(
                                color: Cal_Theme.labelPrimary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      onTap: controller.pressFunction,
                    ),
                  ),
                  // Col 4: D-Pad DOWN (v)
                  Expanded(
                    child: Cal_DPadRoundButton(
                      size: 35,
                      onTap: controller.pressCursorDown,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 21,
                        color: Color(0xFF0E0F11),
                      ),
                    ),
                  ),
                  // Col 5: CATALOG (Book icon)
                  Expanded(
                    child: PebbleKeyButton(
                      primaryLabel: 'CATALOG',
                      topCenterLabel: 'CATALOG',
                      style: PebbleKeyStyle.utilityRound,
                      height: 34,
                      fontSize: 8.5,
                      primaryCustomChild: const Cal_CatalogBookIcon(),
                      onTap: controller.pressCatalog,
                    ),
                  ),
                  // Col 6: TOOLS (◦◦◦ icon)
                  Expanded(
                    child: PebbleKeyButton(
                      primaryLabel: 'TOOLS',
                      topCenterLabel: 'TOOLS',
                      style: PebbleKeyStyle.utilityRound,
                      height: 34,
                      fontSize: 8.8,
                      primaryCustomChild: const Cal_ToolsDotsIcon(),
                      onTap: controller.pressTools,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // ZONE 2: Middle Scientific Key Grid (Rows 4 & 5 — 6 Circular Keys per Row)
  // ===========================================================================
  Widget _buildScientificGrid(
    CalculatorController controller,
    bool isShift,
    bool isAlpha,
  ) {
    return Column(
      children: [
        // ROW 4: [x (QR)] [■/□ (■ □/□)] [√■ (□√■)] [■^□ (■⁻¹)] [■² (log)] [log■□ (ln)]
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Col 1: x (Shift: QR)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: 'x',
                  shiftLabel: 'QR',
                  style: PebbleKeyStyle.scientific,
                  height: 36,
                  fontSize: 15,
                  primaryCustomChild: const Text(
                    'x',
                    style: TextStyle(
                      color: Cal_Theme.labelPrimary,
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'serif',
                    ),
                  ),
                  onTap: () {
                    if (isShift) {
                      controller.pressQrCode();
                    } else {
                      controller.insertToken(
                        const InputToken(display: 'x', evalText: 'x'),
                      );
                    }
                  },
                ),
              ),
              // Col 2: ■/□ Fraction (Shift: ■ □/□ Mixed Fraction)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: '■/□',
                  shiftCustomBadge: const Cal_MixedFractionShiftBadge(),
                  style: PebbleKeyStyle.scientific,
                  height: 36,
                  fontSize: 12,
                  primaryCustomChild: const Cal_FractionKeyIcon(),
                  onTap: () => controller.insertFraction(mixed: isShift),
                ),
              ),
              // Col 3: √■ Square Root (Shift: □√■ Nth Root)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: '√■',
                  shiftLabel: '□√□',
                  style: PebbleKeyStyle.scientific,
                  height: 36,
                  fontSize: 12.5,
                  onTap: () => controller.insertRadical(nthRoot: isShift),
                ),
              ),
              // Col 4: ■^□ Power (Shift: ■⁻¹ Reciprocal)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: 'xⁿ',
                  shiftLabel: '■⁻¹',
                  style: PebbleKeyStyle.scientific,
                  height: 36,
                  fontSize: 12.5,
                  primaryCustomChild: const Cal_PowerKeyIcon(
                    semanticText: 'xⁿ',
                  ),
                  onTap: () {
                    if (isShift) {
                      controller.insertSuperscript(
                        initialExponent: [
                          CharNode(display: '-', evalText: '-'),
                          CharNode(display: '1', evalText: '1'),
                        ],
                        focusExponent: false,
                      );
                    } else {
                      controller.insertSuperscript();
                    }
                  },
                ),
              ),
              // Col 5: ■² Square (Shift: log)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: 'x²',
                  shiftLabel: 'log',
                  style: PebbleKeyStyle.scientific,
                  height: 36,
                  fontSize: 12.5,
                  primaryCustomChild: const Cal_PowerKeyIcon(
                    exponentText: '2',
                    semanticText: 'x²',
                  ),
                  onTap: () {
                    if (isShift) {
                      controller.insertToken(
                        const InputToken(display: 'log(', evalText: 'log('),
                      );
                    } else {
                      controller.insertSuperscript(
                        initialExponent: [
                          CharNode(display: '2', evalText: '2'),
                        ],
                        focusExponent: false,
                      );
                    }
                  },
                ),
              ),
              // Col 6: log■□ Log Base (Shift: ln)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: 'log■□',
                  shiftLabel: 'ln',
                  style: PebbleKeyStyle.scientific,
                  height: 36,
                  fontSize: 11,
                  primaryCustomChild: const Cal_LogBaseKeyIcon(),
                  onTap: () {
                    if (isShift) {
                      controller.insertToken(
                        const InputToken(display: 'ln(', evalText: 'ln('),
                      );
                    } else {
                      controller.insertLogBase();
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        // ROW 5: [Ans] [sin (sin⁻¹)] [cos (cos⁻¹)] [tan (tan⁻¹)] [( (=)] [) (,)]
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Col 1: Ans
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: 'Ans',
                  style: PebbleKeyStyle.scientific,
                  height: 36,
                  fontSize: 12,
                  onTap: () => controller.insertToken(
                    const InputToken(display: 'Ans', evalText: 'Ans'),
                  ),
                ),
              ),
              // Col 2: sin (Shift: sin⁻¹)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: 'sin',
                  shiftLabel: 'sin⁻¹',
                  style: PebbleKeyStyle.scientific,
                  height: 36,
                  fontSize: 12.5,
                  onTap: () {
                    if (isShift) {
                      controller.insertToken(
                        const InputToken(display: 'sin⁻¹(', evalText: 'asin('),
                      );
                    } else {
                      controller.insertToken(
                        const InputToken(display: 'sin(', evalText: 'sin('),
                      );
                    }
                  },
                ),
              ),
              // Col 3: cos (Shift: cos⁻¹)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: 'cos',
                  shiftLabel: 'cos⁻¹',
                  style: PebbleKeyStyle.scientific,
                  height: 36,
                  fontSize: 12.5,
                  onTap: () {
                    if (isShift) {
                      controller.insertToken(
                        const InputToken(display: 'cos⁻¹(', evalText: 'acos('),
                      );
                    } else {
                      controller.insertToken(
                        const InputToken(display: 'cos(', evalText: 'cos('),
                      );
                    }
                  },
                ),
              ),
              // Col 4: tan (Shift: tan⁻¹)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: 'tan',
                  shiftLabel: 'tan⁻¹',
                  style: PebbleKeyStyle.scientific,
                  height: 36,
                  fontSize: 12.5,
                  onTap: () {
                    if (isShift) {
                      controller.insertToken(
                        const InputToken(display: 'tan⁻¹(', evalText: 'atan('),
                      );
                    } else {
                      controller.insertToken(
                        const InputToken(display: 'tan(', evalText: 'tan('),
                      );
                    }
                  },
                ),
              ),
              // Col 5: ( (Shift: =)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: '(',
                  shiftLabel: '=',
                  style: PebbleKeyStyle.scientific,
                  height: 36,
                  fontSize: 13,
                  onTap: () {
                    if (isShift) {
                      controller.insertToken(
                        const InputToken(display: '=', evalText: '='),
                      );
                    } else {
                      controller.insertToken(
                        const InputToken(display: '(', evalText: '('),
                      );
                    }
                  },
                ),
              ),
              // Col 6: ) (Shift: ,)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: ')',
                  shiftLabel: ',',
                  style: PebbleKeyStyle.scientific,
                  height: 36,
                  fontSize: 13,
                  onTap: () {
                    if (isShift) {
                      controller.insertToken(
                        const InputToken(display: ',', evalText: ','),
                      );
                    } else {
                      controller.insertToken(
                        const InputToken(display: ')', evalText: ')'),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // ZONE 3: Bottom Numeric & Execution Pad (Rows 6, 7, 8, 9 — 5 Keys per Row)
  // ===========================================================================
  Widget _buildNumericExecutionPad(
    CalculatorController controller,
    bool isShift,
    bool isAlpha,
  ) {
    return Column(
      children: [
        // ROW 6: [7 (π)] [8 (e)] [9 (i)] [⌫ (INS)] [AC (OFF)]
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Col 1: 7 (Shift: π)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: '7',
                  shiftLabel: 'π',
                  style: PebbleKeyStyle.numeric,
                  height: 44,
                  fontSize: 18,
                  onTap: () {
                    if (isShift) {
                      controller.insertToken(
                        const InputToken(display: 'π', evalText: 'π'),
                      );
                    } else {
                      controller.insertToken(
                        const InputToken(display: '7', evalText: '7'),
                      );
                    }
                  },
                ),
              ),
              // Col 2: 8 (Shift: e)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: '8',
                  shiftLabel: 'e',
                  style: PebbleKeyStyle.numeric,
                  height: 44,
                  fontSize: 18,
                  onTap: () {
                    if (isShift) {
                      controller.insertToken(
                        const InputToken(display: 'e', evalText: 'e'),
                      );
                    } else {
                      controller.insertToken(
                        const InputToken(display: '8', evalText: '8'),
                      );
                    }
                  },
                ),
              ),
              // Col 3: 9 (Shift: i)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: '9',
                  shiftLabel: 'i',
                  style: PebbleKeyStyle.numeric,
                  height: 44,
                  fontSize: 18,
                  onTap: () {
                    if (isShift) {
                      controller.insertToken(
                        const InputToken(display: 'i', evalText: 'i'),
                      );
                    } else {
                      controller.insertToken(
                        const InputToken(display: '9', evalText: '9'),
                      );
                    }
                  },
                ),
              ),
              // Col 4: [◀×] Backspace (Shift: INS)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: '⌫',
                  shiftLabel: 'INS',
                  style: PebbleKeyStyle.clearAction,
                  height: 44,
                  fontSize: 15,
                  primaryCustomChild: const Cal_BackspacePentagonIcon(),
                  onTap: controller.pressBackspace,
                ),
              ),
              // Col 5: AC (Shift: OFF)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: 'AC',
                  shiftLabel: 'OFF',
                  style: PebbleKeyStyle.clearAction,
                  height: 44,
                  fontSize: 15.5,
                  onTap: controller.pressAc,
                ),
              ),
            ],
          ),
        ),

        // ROW 7: [4 (A)] [5 (B)] [6 (C)] [×] [÷]
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Col 1: 4 (Shift: A)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: '4',
                  shiftLabel: 'A',
                  style: PebbleKeyStyle.numeric,
                  height: 44,
                  fontSize: 18,
                  onTap: () {
                    if (isShift || isAlpha) {
                      controller.insertToken(
                        const InputToken(display: 'A', evalText: 'A'),
                      );
                    } else {
                      controller.insertToken(
                        const InputToken(display: '4', evalText: '4'),
                      );
                    }
                  },
                ),
              ),
              // Col 2: 5 (Shift: B)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: '5',
                  shiftLabel: 'B',
                  style: PebbleKeyStyle.numeric,
                  height: 44,
                  fontSize: 18,
                  onTap: () {
                    if (isShift || isAlpha) {
                      controller.insertToken(
                        const InputToken(display: 'B', evalText: 'B'),
                      );
                    } else {
                      controller.insertToken(
                        const InputToken(display: '5', evalText: '5'),
                      );
                    }
                  },
                ),
              ),
              // Col 3: 6 (Shift: C)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: '6',
                  shiftLabel: 'C',
                  style: PebbleKeyStyle.numeric,
                  height: 44,
                  fontSize: 18,
                  onTap: () {
                    if (isShift || isAlpha) {
                      controller.insertToken(
                        const InputToken(display: 'C', evalText: 'C'),
                      );
                    } else {
                      controller.insertToken(
                        const InputToken(display: '6', evalText: '6'),
                      );
                    }
                  },
                ),
              ),
              // Col 4: × Multiplication
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: '×',
                  style: PebbleKeyStyle.numeric,
                  height: 44,
                  fontSize: 19,
                  onTap: () => controller.insertToken(
                    const InputToken(display: '×', evalText: '×'),
                    isBinaryOperator: true,
                  ),
                ),
              ),
              // Col 5: ÷ Division
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: '÷',
                  style: PebbleKeyStyle.numeric,
                  height: 44,
                  fontSize: 19,
                  onTap: () => controller.insertToken(
                    const InputToken(display: '÷', evalText: '÷'),
                    isBinaryOperator: true,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ROW 8: [1 (D)] [2 (E)] [3 (F)] [+ (° ’ ”)] [− ((−))]
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Col 1: 1 (Shift: D)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: '1',
                  shiftLabel: 'D',
                  style: PebbleKeyStyle.numeric,
                  height: 44,
                  fontSize: 18,
                  onTap: () {
                    if (isShift || isAlpha) {
                      controller.insertToken(
                        const InputToken(display: 'D', evalText: 'D'),
                      );
                    } else {
                      controller.insertToken(
                        const InputToken(display: '1', evalText: '1'),
                      );
                    }
                  },
                ),
              ),
              // Col 2: 2 (Shift: E)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: '2',
                  shiftLabel: 'E',
                  style: PebbleKeyStyle.numeric,
                  height: 44,
                  fontSize: 18,
                  onTap: () {
                    if (isShift || isAlpha) {
                      controller.insertToken(
                        const InputToken(display: 'E', evalText: 'E'),
                      );
                    } else {
                      controller.insertToken(
                        const InputToken(display: '2', evalText: '2'),
                      );
                    }
                  },
                ),
              ),
              // Col 3: 3 (Shift: F)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: '3',
                  shiftLabel: 'F',
                  style: PebbleKeyStyle.numeric,
                  height: 44,
                  fontSize: 18,
                  onTap: () {
                    if (isShift || isAlpha) {
                      controller.insertToken(
                        const InputToken(display: 'F', evalText: 'F'),
                      );
                    } else {
                      controller.insertToken(
                        const InputToken(display: '3', evalText: '3'),
                      );
                    }
                  },
                ),
              ),
              // Col 4: + Addition (Shift: ° ’ ” DMS)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: '+',
                  shiftLabel: '° ’ ”',
                  style: PebbleKeyStyle.numeric,
                  height: 44,
                  fontSize: 19,
                  onTap: () {
                    if (isShift) {
                      controller.insertToken(
                        const InputToken(display: '°', evalText: '°'),
                      );
                    } else {
                      controller.insertToken(
                        const InputToken(display: '+', evalText: '+'),
                        isBinaryOperator: true,
                      );
                    }
                  },
                ),
              ),
              // Col 5: − Subtraction (Shift: (−) Unary Negation)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: '−',
                  shiftLabel: '(−)',
                  style: PebbleKeyStyle.numeric,
                  height: 44,
                  fontSize: 19,
                  onTap: () {
                    if (isShift) {
                      controller.insertToken(
                        const InputToken(display: '-', evalText: '-'),
                      );
                    } else {
                      controller.insertToken(
                        const InputToken(display: '−', evalText: '−'),
                        isBinaryOperator: true,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        // ROW 9: [0 (x)] [. (y)] [×10ⁿ (z)] [FORMAT] [EXE (≈)]
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Col 1: 0 (Shift: x)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: '0',
                  shiftLabel: 'x',
                  style: PebbleKeyStyle.numeric,
                  height: 44,
                  fontSize: 18,
                  onTap: () {
                    if (isShift || isAlpha) {
                      controller.insertToken(
                        const InputToken(display: 'x', evalText: 'x'),
                      );
                    } else {
                      controller.insertToken(
                        const InputToken(display: '0', evalText: '0'),
                      );
                    }
                  },
                ),
              ),
              // Col 2: . Decimal Point (Shift: y)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: '.',
                  shiftLabel: 'y',
                  style: PebbleKeyStyle.numeric,
                  height: 44,
                  fontSize: 20,
                  onTap: () {
                    if (isShift || isAlpha) {
                      controller.insertToken(
                        const InputToken(display: 'y', evalText: 'y'),
                      );
                    } else {
                      controller.insertToken(
                        const InputToken(display: '.', evalText: '.'),
                      );
                    }
                  },
                ),
              ),
              // Col 3: ×10■ Scientific Notation (Shift: z)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: '×10ⁿ',
                  shiftLabel: 'z',
                  style: PebbleKeyStyle.numeric,
                  height: 44,
                  fontSize: 12.5,
                  primaryCustomChild: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text(
                          '×10',
                          style: TextStyle(
                            color: Cal_Theme.labelPrimary,
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.4,
                            height: 1.0,
                          ),
                        ),
                      ),
                      Container(
                        width: 4.0,
                        height: 4.0,
                        color: Cal_Theme.labelPrimary,
                      ),
                    ],
                  ),
                  onTap: () {
                    if (isShift || isAlpha) {
                      controller.insertToken(
                        const InputToken(display: 'z', evalText: 'z'),
                      );
                    } else {
                      controller.insertToken(
                        const InputToken(display: '×10^', evalText: '×10^'),
                        isBinaryOperator: true,
                      );
                    }
                  },
                ),
              ),
              // Col 4: FORMAT (with circular arrows)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: 'FORMAT',
                  style: PebbleKeyStyle.numeric,
                  height: 44,
                  fontSize: 9.0,
                  primaryCustomChild: const Cal_FormatKeyIcon(),
                  onTap: controller.pressFormat,
                ),
              ),
              // Col 5: EXE (Shift: ≈ Approximate)
              Expanded(
                child: PebbleKeyButton(
                  primaryLabel: 'EXE',
                  shiftLabel: '≈',
                  style: PebbleKeyStyle.exeAccent,
                  height: 44,
                  fontSize: 14.5,
                  onTap: controller.pressExe,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Paints the sculpted dark cross-shaped depression channel (`+`) connecting
/// the 5 circular D-Pad buttons (`^`, `<`, `OK`, `>`, `v`) on the Cal_ 1100_DB_.
class _DPadCrossChannelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double colW = size.width / 6.0;
    // Center of Column 4 (index 3.5)
    final double centerX = colW * 3.5;
    // Center of Row 2 D-Pad (OK button keycap center)
    final double centerY = size.height * 0.525;
    final double channelThick = (colW * 0.70).clamp(32.0, 48.0);

    final channelPaint = Paint()
      ..color = const Color(0xFF101113)
      ..style = PaintingStyle.fill;

    // Horizontal arm of cross (spanning Col 3 to Col 5)
    final hRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: colW * 2.86,
        height: channelThick,
      ),
      Radius.circular(channelThick / 2),
    );

    // Vertical arm of cross (spanning Row 1 keycap top to Row 3 keycap bottom)
    final double vTop = size.height * 0.08;
    final double vBottom = size.height * 0.98;
    final vRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        centerX - channelThick / 2,
        vTop,
        centerX + channelThick / 2,
        vBottom,
      ),
      Radius.circular(channelThick / 2),
    );

    canvas.drawRRect(hRect, channelPaint);
    canvas.drawRRect(vRect, channelPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
