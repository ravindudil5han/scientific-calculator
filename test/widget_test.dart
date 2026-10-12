import 'dart:ui' as ui;
import 'package:scientific_calculator/app_modules/algebraic_solvers_engine.dart';
import 'package:scientific_calculator/app_modules/complex_basen_engine.dart';
import 'package:scientific_calculator/app_modules/linear_algebra_engine.dart';
import 'package:scientific_calculator/app_modules/statistics_distribution_engine.dart';
import 'package:scientific_calculator/app_modules/table_spreadsheet_mathbox_engine.dart';
import 'package:scientific_calculator/core/calculator_theme.dart';
import 'package:scientific_calculator/display_engine/qr_code_generator.dart';
import 'package:scientific_calculator/display_engine/lcd_bitmap_font.dart';
import 'package:scientific_calculator/display_engine/lcd_display_widget.dart';
import 'package:scientific_calculator/display_engine/lcd_grid_table_renderer.dart';
import 'package:scientific_calculator/display_engine/math_editor_engine.dart';
import 'package:scientific_calculator/display_engine/math_nodes.dart';
import 'package:scientific_calculator/main.dart';
import 'package:scientific_calculator/math_engine/calculator_decimal.dart';
import 'package:scientific_calculator/math_engine/constants_conversions_engine.dart';
import 'package:scientific_calculator/math_engine/math_expression_evaluator.dart';
import 'package:scientific_calculator/navigation/cw_menu_tree.dart';
import 'package:scientific_calculator/state/calculator_controller.dart';
import 'package:scientific_calculator/state/calculator_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cal_ 1100_DB_ Phase 0, 1 & 2 (2D Math AST & Cursor Engine)', () {
    test('CalculatorController state initialization and modifier latches', () {
      final controller = CalculatorController();
      expect(controller.state.activeMode, AppMode.calculate);
      expect(controller.state.angleUnit, AngleUnit.degree);
      expect(controller.state.isShift, isFalse);
      expect(controller.state.isAlpha, isFalse);
      expect(controller.state.showPixelGrid, isTrue);

      controller.pressShift();
      expect(controller.state.isShift, isTrue);

      controller.cycleAngleUnit();
      expect(controller.state.angleUnit, AngleUnit.radian);
      controller.cycleAngleUnit();
      expect(controller.state.angleUnit, AngleUnit.gradian);
      controller.cycleAngleUnit();
      expect(controller.state.angleUnit, AngleUnit.degree);
    });

    test('Basic input buffer, cursor navigation (◀/▶), and EXE logging', () {
      final controller = CalculatorController();

      controller.insertToken(const InputToken(display: '2', evalText: '2'));
      controller.insertToken(
        const InputToken(display: '+', evalText: '+'),
        isBinaryOperator: true,
      );
      controller.insertToken(const InputToken(display: '3', evalText: '3'));
      controller.insertToken(
        const InputToken(display: '×', evalText: '×'),
        isBinaryOperator: true,
      );
      controller.insertToken(const InputToken(display: '4', evalText: '4'));

      expect(controller.state.expressionDisplayString, '2+3×4');
      expect(controller.state.cursorIndex, 5);

      // Move cursor left twice and insert '0' after '3' -> '2+30×4'
      controller.pressCursorLeft();
      controller.pressCursorLeft();
      expect(controller.state.cursorIndex, 3);
      controller.insertToken(const InputToken(display: '0', evalText: '0'));
      expect(controller.state.expressionDisplayString, '2+30×4');

      // Evaluate with EXE: 2 + 30 * 4 = 122
      controller.pressExe();
      expect(controller.state.isResultDisplayed, isTrue);
      expect(controller.state.resultText, '122');
      expect(controller.state.history.length, 1);
      expect(controller.state.history.first.expressionText, '2+30×4');
      expect(controller.state.history.first.resultText, '122');
      expect(controller.state.variables['Ans'], '122');
    });

    test('2D FractionNode smart wrapping, spatial Up/Down/Right, and dissolution', () {
      final controller = CalculatorController();

      // 1. Insert empty FractionNode and verify cursor starts in numerator
      controller.insertFraction();
      final frac1 =
          controller.editor.root.children.first as FractionNode;
      expect(controller.editor.activeContainerId, frac1.numerator.id);

      // Pressing Backspace inside completely empty FractionNode dissolves it cleanly
      controller.pressBackspace();
      expect(controller.editor.root.children, isEmpty);
      expect(controller.editor.activeContainerId, controller.editor.root.id);

      // 2. Smart operand wrapping: type '3', then press Fraction key -> '3' in numerator, cursor in denominator
      controller.insertToken(const InputToken(display: '3', evalText: '3'));
      controller.insertFraction();
      final frac2 =
          controller.editor.root.children.first as FractionNode;
      expect(frac2.numerator.toDisplayString(), '3');
      expect(controller.editor.activeContainerId, frac2.denominator.id);

      // Type '4' in denominator -> 3/4
      controller.insertToken(const InputToken(display: '4', evalText: '4'));
      expect(frac2.denominator.toDisplayString(), '4');

      // Press Up to jump spatially from denominator to numerator
      controller.pressCursorUp();
      expect(controller.editor.activeContainerId, frac2.numerator.id);

      // Press Down to jump back to denominator
      controller.pressCursorDown();
      expect(controller.editor.activeContainerId, frac2.denominator.id);

      // Press Right at end of denominator -> exits fraction back to root container
      controller.pressCursorRight();
      expect(controller.editor.activeContainerId, controller.editor.root.id);
      expect(controller.editor.childIndex, 1);

      // Add + 1/4 and evaluate -> 3/4 + 1/4 = 1
      controller.insertToken(
        const InputToken(display: '+', evalText: '+'),
        isBinaryOperator: true,
      );
      controller.insertFraction();
      controller.insertToken(const InputToken(display: '1', evalText: '1'));
      controller.pressCursorRight(); // jumps from numerator to denominator
      controller.insertToken(const InputToken(display: '4', evalText: '4'));

      controller.pressExe();
      expect(controller.state.resultText, '1');
    });

    test('2D RadicalNode, SuperscriptNode, ParenthesisNode, and Calculus templates', () {
      final editor = MathEditorEngine();

      // √(9) + 2^3
      editor.insertRadical();
      editor.insertChar('9');
      editor.moveRight(); // Exit radical to root
      editor.insertChar('+');
      editor.insertChar('2');
      editor.insertSuperscript();
      editor.insertChar('3');
      editor.moveRight(); // Exit exponent to root

      expect(editor.root.toDisplayString(), '√(9)+2^(3)');
      expect(editor.root.toEvalString(), '√(9)+2^(3)');

      // Verify measure() and render() on Canvas work cleanly for all 2D nodes
      final size = editor.root.measure(const TextStyle(fontSize: 14));
      expect(size.width, greaterThan(20));
      expect(size.height, greaterThan(10));

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      editor.root.render(canvas, Offset.zero);
      final picture = recorder.endRecording();
      picture.dispose();

      // Test IntegralNode, SummationNode, DerivativeNode evaluation via Controller
      final controller = CalculatorController();
      // d/dx(x^2)|x=3 = 6
      controller.insertDerivative();
      controller.insertToken(const InputToken(display: 'x', evalText: 'x'));
      controller.insertSuperscript(
        initialExponent: [CharNode(display: '2', evalText: '2')],
        focusExponent: false,
      );
      controller.pressCursorRight(); // Move from body to atValue slot (x=□)
      controller.insertToken(const InputToken(display: '3', evalText: '3'));
      controller.pressExe();
      expect(controller.state.resultText, '6');
    });
  });

  group('Cal_ 1100_DB_ Phase 3 (Math Lexer, Semantic AST, High-Precision & Symbolic Engine)', () {
    test('Order of operations (PEMDAS/BODMAS), implicit multiplication & auto-closing parens', () {
      final eval = const MathExpressionEvaluator(
        angleUnit: AngleUnit.degree,
        variables: {'x': '4'},
      );

      // Standard PEMDAS
      expect(eval.evaluateString('2 + 3 * 4 - 10 / 2').primaryText, '9');
      expect(eval.evaluateString('(2 + 3) * (4 + 1)').primaryText, '25');
      expect(eval.evaluateString('2^3^2').primaryText, '512');

      // Implicit multiplication cases required by Phase 3 spec:
      // 1. Digit adjacent to bracket: 2(3) -> 6
      expect(eval.evaluateString('2(3)').primaryText, '6');
      // 2. Digit adjacent to radical: 3√2 -> 3√2 (and 3√4 -> 6)
      expect(eval.evaluateString('3√2').primaryText, '3√2');
      expect(eval.evaluateString('3√(4)').primaryText, '6');
      // 3. Digit adjacent to function: 2sin(30) -> 2 * 1/2 = 1
      expect(eval.evaluateString('2sin(30)').primaryText, '1');
      // 4. Adjacent brackets: (2)(3) -> 6
      expect(eval.evaluateString('(2)(3)').primaryText, '6');
      // 5. Digit adjacent to variable: 5x -> 5 * 4 = 20
      expect(eval.evaluateString('5x').primaryText, '20');

      // Cal_ Level 4 Juxtaposed Implicit Multiplication vs Explicit Division:
      // 6÷2(1+2) = 1, whereas 6÷2×(1+2) = 9
      expect(eval.evaluateString('6÷2(1+2)').primaryText, '1');
      expect(eval.evaluateString('6÷2×(1+2)').primaryText, '9');

      // Automatic closing of dangling parentheses at end of expression:
      expect(eval.evaluateString('2(3+4').primaryText, '14');
      expect(eval.evaluateString('sin(30').primaryText, '1/2');
    });

    test('High-precision BCD/Decimal arithmetic (0.1 + 0.2 == 0.3, 10^15 - 1)', () {
      final eval = const MathExpressionEvaluator();

      // Strictly 0.3 with zero IEEE 754 float artifact
      final resAdd = eval.evaluateString('0.1 + 0.2');
      expect(resAdd.primaryText, '0.3');
      expect(resAdd.decimalText, '0.3');
      expect(resAdd.exactText, '3/10');

      // 0.3 - 0.1 - 0.2 == 0
      expect(eval.evaluateString('0.3 - 0.1 - 0.2').decimalText, '0');

      // High-precision 15-digit integer: 10^15 - 1 == 999999999999999
      final resPow = eval.evaluateString('10^15 - 1');
      expect(resPow.primaryText, '999999999999999');
      expect(resPow.decimalText, '999999999999999');

      // Direct Cal_Decimal precision check up to 25 digits
      final bigA = Cal_Decimal.parse('100000000000000000000');
      final bigB = Cal_Decimal.parse('1');
      expect((bigA - bigB).toPlainString(), '99999999999999999999');
    });

    test('Exact symbolic reduction: fractions, surds, rationalization, denesting & special trig', () {
      final evalDeg = const MathExpressionEvaluator(angleUnit: AngleUnit.degree);
      final evalRad = const MathExpressionEvaluator(angleUnit: AngleUnit.radian);

      // Rational fraction simplification
      final fracHalf = evalDeg.evaluateString('4/8');
      expect(fracHalf.primaryText, '1/2');
      expect(fracHalf.decimalText, '0.5');

      final fracImproper = evalDeg.evaluateString('7/3');
      expect(fracImproper.primaryText, '7/3');
      expect(fracImproper.mixedFractionText, '2 1/3');
      expect(fracImproper.recurringDecimalText, '2.(3)');

      // Surd reduction: √12 -> 2√3, √50 -> 5√2, √72 -> 6√2
      expect(evalDeg.evaluateString('√(12)').primaryText, '2√3');
      expect(evalDeg.evaluateString('√(50)').primaryText, '5√2');
      expect(evalDeg.evaluateString('√(72)').primaryText, '6√2');
      expect(evalDeg.evaluateString('√(12) + √(27)').primaryText, '5√3');

      // Surd denominator rationalization: 1/(√3 - 1) -> (√3+1)/2
      expect(evalDeg.evaluateString('1/(√(3)-1)').primaryText, '(√3+1)/2');

      // Nested radical denesting: √(3 + 2√2) -> √2+1
      expect(evalDeg.evaluateString('√(3+2√(2))').primaryText, '√2+1');

      // Special angle exact trig in Degree mode:
      expect(evalDeg.evaluateString('sin(0)').primaryText, '0');
      expect(evalDeg.evaluateString('sin(30)').primaryText, '1/2');
      expect(evalDeg.evaluateString('sin(45)').primaryText, '√2/2');
      expect(evalDeg.evaluateString('sin(60)').primaryText, '√3/2');
      expect(evalDeg.evaluateString('sin(90)').primaryText, '1');
      expect(evalDeg.evaluateString('cos(30)').primaryText, '√3/2');
      expect(evalDeg.evaluateString('cos(60)').primaryText, '1/2');
      expect(evalDeg.evaluateString('cos(90)').primaryText, '0');
      expect(evalDeg.evaluateString('tan(45)').primaryText, '1');
      expect(evalDeg.evaluateString('tan(30)').primaryText, '√3/3');
      expect(evalDeg.evaluateString('sin(15)').primaryText, '(√6-√2)/4');

      // Special angle exact trig in Radian mode:
      expect(evalRad.evaluateString('sin(π/6)').primaryText, '1/2');
      expect(evalRad.evaluateString('cos(π/6)').primaryText, '√3/2');
      expect(evalRad.evaluateString('tan(π/4)').primaryText, '1');
      expect(evalRad.evaluateString('acos(√(2)/2)').primaryText, 'π/4');
    });

    test('Core math capabilities: GCD, LCM, FACT, n!, nPr, nCr, logs, hyperbolic & calculus', () {
      final eval = const MathExpressionEvaluator(angleUnit: AngleUnit.degree);

      // Number theory & combinatorics
      expect(eval.evaluateString('GCD(24, 36)').primaryText, '12');
      expect(eval.evaluateString('LCM(12, 18)').primaryText, '36');
      expect(eval.evaluateString('fact(24)').primaryText, '2^3×3');
      expect(eval.evaluateString('24 FACT').primaryText, '2^3×3');
      expect(eval.evaluateString('5!').primaryText, '120');
      expect(eval.evaluateString('5 nPr 2').primaryText, '20');
      expect(eval.evaluateString('5P2').primaryText, '20');
      expect(eval.evaluateString('5 nCr 2').primaryText, '10');
      expect(eval.evaluateString('5C2').primaryText, '10');
      expect(eval.evaluateString('17 ÷R 5').primaryText, '3, R=2');

      // Exponentials, logs & hyperbolic
      expect(eval.evaluateString('ln(e)').primaryText, '1');
      expect(eval.evaluateString('log(1000)').primaryText, '3');
      expect(eval.evaluateString('log(2, 8)').primaryText, '3');
      expect(eval.evaluateString('sinh(0)').primaryText, '0');
      expect(eval.evaluateString('cosh(0)').primaryText, '1');
      expect(eval.evaluateString('tanh(0)').primaryText, '0');
      expect(eval.evaluateString('asinh(0)').primaryText, '0');
      expect(eval.evaluateString('acosh(1)').primaryText, '0');
      expect(eval.evaluateString('atanh(0)').primaryText, '0');

      // Calculus primitives:
      // Richardson Extrapolation derivative: d/dx(x^3) at x = 2 -> 12
      expect(eval.evaluateString('deriv(x^3, 2)').primaryText, '12');
      // Adaptive Gauss-Kronrod G7-K15 quadrature: ∫_0^3 (x^2) dx -> 9
      expect(eval.evaluateString('integrate(x^2, 0, 3)').primaryText, '9');
      // Finite summation ∑_{x=1}^5 (x^2) -> 55
      expect(eval.evaluateString('sum(x^2, 1, 5)').primaryText, '55');
      // Finite product ∏_{x=1}^4 (x) -> 24
      expect(eval.evaluateString('prod(x, 1, 4)').primaryText, '24');
    });

    test('Memory registers (A-F, x-z), Ans, PreAns, and operator chaining after EXE', () {
      final controller = CalculatorController();

      // Evaluate 10 -> Ans = 10, PreAns = 0
      controller.insertToken(const InputToken(display: '10', evalText: '10'));
      controller.pressExe();
      expect(controller.state.resultText, '10');
      expect(controller.state.variables['Ans'], '10');
      expect(controller.state.variables['PreAns'], '0');

      // Chaining: pressing '+' immediately after EXE prepends 'Ans' -> 'Ans+5' = 15
      controller.insertToken(
        const InputToken(display: '+', evalText: '+'),
        isBinaryOperator: true,
      );
      controller.insertToken(const InputToken(display: '5', evalText: '5'));
      expect(controller.state.expressionDisplayString, 'Ans+5');
      controller.pressExe();
      expect(controller.state.resultText, '15');
      expect(controller.state.variables['Ans'], '15');
      expect(controller.state.variables['PreAns'], '10');

      // Store and recall register A
      controller.storeVariable('A', '7');
      controller.insertToken(const InputToken(display: '3', evalText: '3'));
      controller.insertToken(const InputToken(display: 'A', evalText: 'A'));
      controller.insertToken(
        const InputToken(display: '+', evalText: '+'),
        isBinaryOperator: true,
      );
      controller.insertToken(
        const InputToken(display: 'PreAns', evalText: 'PreAns'),
      );
      controller.pressExe();
      // 3*A + PreAns = 3*7 + 10 = 31
      expect(controller.state.resultText, '31');
    });

    test('Strict Cal_ Error Handling: Syntax ERROR, Math ERROR, and Argument ERROR', () {
      final eval = const MathExpressionEvaluator(angleUnit: AngleUnit.degree);

      // Syntax ERROR cases:
      expect(eval.evaluateString('2+*3').error, 'Syntax ERROR');
      expect(eval.evaluateString('5+').error, 'Syntax ERROR');
      expect(eval.evaluateString('(2+3))').error, 'Syntax ERROR');

      // Math ERROR cases:
      expect(eval.evaluateString('1/0').error, 'Math ERROR');
      expect(eval.evaluateString('ln(0)').error, 'Math ERROR');
      expect(eval.evaluateString('ln(-5)').error, 'Math ERROR');
      expect(eval.evaluateString('√(-4)').error, 'Math ERROR');
      expect(eval.evaluateString('tan(90)').error, 'Math ERROR');
      expect(eval.evaluateString('asin(2)').error, 'Math ERROR');
      expect(eval.evaluateString('10^100').error, 'Math ERROR');

      // Argument ERROR cases:
      expect(eval.evaluateString('(-3)!').error, 'Argument ERROR');
      expect(eval.evaluateString('2.5!').error, 'Argument ERROR');
      expect(eval.evaluateString('5 nCr 2.5').error, 'Argument ERROR');
      expect(eval.evaluateString('3 nCr 5').error, 'Argument ERROR');
      expect(eval.evaluateString('GCD(2.5, 4)').error, 'Argument ERROR');
    });

    testWidgets('Renders Cal_ 1100_DB_ chassis, 192x63 LCD, and 2D keys', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(430, 920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const Cal_1100_DB_App());

      expect(find.text('Cal_'), findsNothing);
      expect(find.text('1100_DB_'), findsNothing);
      expect(find.text('CLASSWIZ'), findsNothing);
      expect(find.text('EXE'), findsOneWidget);

      // Tap √■, 1, 6, ▶ (exit radical), +, 5, x², EXE -> √(16) + 5² = 29
      await tester.tap(find.text('√■'));
      await tester.pump();
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('6'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.keyboard_arrow_right_rounded));
      await tester.pump();
      await tester.tap(find.text('+'));
      await tester.pump();
      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.text('x²'));
      await tester.pump();
      await tester.tap(find.text('EXE'));
      await tester.pump();

      final scope = tester.widget<CalculatorScope>(
        find.byType(CalculatorScope),
      );
      expect(scope.notifier!.state.resultText, '29');
    });
  });

  group('Cal_ 1100_DB_ Phase 4 (Hierarchical Navigation, CATALOG, FORMAT, VARIABLE, FUNCTION & SETTINGS)', () {
    test('HOME 13-App selection grid D-Pad navigation and mode switching', () {
      final controller = CalculatorController();
      expect(controller.state.activeMode, AppMode.calculate);

      // Open HOME grid
      controller.pressHome();
      expect(controller.state.activeOverlay, ActiveOverlay.homeGrid);
      expect(controller.state.overlayCursorIndex, 0);

      // Navigate right twice -> Base-N (index 2) and down once -> Vector (index 5) -> Statistics (index 5 is Statistics: 0=Calc,1=Cmplx,2=BaseN,3=Mat,4=Vct,5=Stat)
      controller.pressCursorRight();
      controller.pressCursorRight();
      expect(controller.state.overlayCursorIndex, 2);
      controller.pressCursorDown();
      expect(controller.state.overlayCursorIndex, 5);

      // Confirm selection with OK
      controller.pressOk();
      expect(controller.state.activeOverlay, ActiveOverlay.none);
      expect(controller.state.activeMode, AppMode.statistics);
    });

    test('CATALOG multi-level hierarchical navigation & BACK breadcrumb unwinding', () {
      final controller = CalculatorController();

      // Type '2+' first to verify closing overlay preserves active Math editor state
      controller.insertToken(const InputToken(display: '2', evalText: '2'));
      controller.insertToken(
        const InputToken(display: '+', evalText: '+'),
        isBinaryOperator: true,
      );

      // Open CATALOG root level
      controller.pressCatalog();
      expect(controller.state.activeOverlay, ActiveOverlay.catalogMenu);
      expect(controller.state.menuBreadcrumbs.length, 1);
      expect(controller.state.currentBreadcrumb!.title, 'CATALOG');
      expect(controller.state.currentBreadcrumb!.items.length, 8);

      // Navigate Down twice -> 'Numeric Calc' (index 2)
      controller.pressCursorDown();
      controller.pressCursorDown();
      expect(
        controller.state.currentBreadcrumb!.items[
          controller.state.currentBreadcrumb!.selectedIndex
        ].label,
        'Numeric Calc',
      );

      // Enter 'Numeric Calc' sub-menu via OK
      controller.pressOk();
      expect(controller.state.menuBreadcrumbs.length, 2);
      expect(controller.state.currentBreadcrumb!.title, 'Numeric Calc');

      // Press BACK -> unwinds 1 level back to 'CATALOG' root (preserving index 2)
      controller.pressBack();
      expect(controller.state.activeOverlay, ActiveOverlay.catalogMenu);
      expect(controller.state.menuBreadcrumbs.length, 1);
      expect(controller.state.currentBreadcrumb!.selectedIndex, 2);

      // Press BACK again at top level -> closes CATALOG and preserves '2+' in editor
      controller.pressBack();
      expect(controller.state.activeOverlay, ActiveOverlay.none);
      expect(controller.state.expressionDisplayString, '2+');

      // Re-open CATALOG -> Numeric Calc -> select GCD( and evaluate 2 + GCD(12, 18) = 8
      controller.pressCatalog();
      controller.pressCursorDown();
      controller.pressCursorDown();
      controller.pressOk(); // Enter Numeric Calc
      controller.pressOk(); // Select GCD(
      expect(controller.state.activeOverlay, ActiveOverlay.none);
      controller.insertToken(const InputToken(display: '12', evalText: '12'));
      controller.insertToken(const InputToken(display: ',', evalText: ','));
      controller.insertToken(const InputToken(display: '18', evalText: '18'));
      controller.insertToken(const InputToken(display: ')', evalText: ')'));
      controller.pressExe();
      expect(controller.state.resultText, '8');
    });

    test('FORMAT output switcher: Standard, Decimal, Recurring, Improper, Mixed, ENG (◀/▶), DMS & Prime Factor', () {
      final controller = CalculatorController();

      // Evaluate 7 / 3 -> exact '7/3'
      controller.insertToken(const InputToken(display: '7', evalText: '7'));
      controller.insertToken(
        const InputToken(display: '÷', evalText: '/'),
        isBinaryOperator: true,
      );
      controller.insertToken(const InputToken(display: '3', evalText: '3'));
      controller.pressExe();
      expect(controller.state.resultText, '7/3');

      // Open FORMAT -> select Recurring Decimal (index 2)
      controller.pressFormat();
      expect(controller.state.activeOverlay, ActiveOverlay.formatMenu);
      controller.pressCursorDown(); // 1: Decimal
      controller.pressCursorDown(); // 2: Recurring Decimal
      controller.pressOk();
      expect(controller.state.resultText, '2.(3)');

      // Open FORMAT -> select Mixed Fraction (index 4)
      controller.pressFormat();
      for (int i = 0; i < 4; i++) {
        controller.pressCursorDown();
      }
      controller.pressOk();
      expect(controller.state.resultText, '2 1/3');

      // Evaluate 12500 -> test ENG notation and ◀/▶ exponent shifting + Prime Factor
      controller.pressAc();
      controller.insertToken(
        const InputToken(display: '12500', evalText: '12500'),
      );
      controller.pressExe();
      expect(controller.state.resultText, '12500');

      // Open FORMAT -> select ENG Notation (index 5)
      controller.pressFormat();
      for (int i = 0; i < 5; i++) {
        controller.pressCursorDown();
      }
      controller.pressOk();
      expect(controller.state.resultText, '12.5×10^3');

      // Press ▶ in ENG mode to shift exponent by +3 -> 0.0125×10^6
      controller.pressCursorRight();
      expect(controller.state.resultText, '0.0125×10^6');
      // Press ◀ twice to shift exponent to 12500×10^0
      controller.pressCursorLeft();
      controller.pressCursorLeft();
      expect(controller.state.resultText, '12500×10^0');

      // Open FORMAT -> select Prime Factor (FACT) (index 7)
      controller.pressFormat();
      for (int i = 0; i < 7; i++) {
        controller.pressCursorDown();
      }
      controller.pressOk();
      expect(controller.state.resultText, '2^2×5^5');

      // Evaluate 12.5 -> Open FORMAT -> Sexagesimal (DMS) (index 6) -> 12°30'0''
      controller.pressAc();
      controller.insertToken(
        const InputToken(display: '12.5', evalText: '12.5'),
      );
      controller.pressExe();
      controller.pressFormat();
      for (int i = 0; i < 6; i++) {
        controller.pressCursorDown();
      }
      controller.pressOk();
      expect(controller.state.resultText, "12°30'0''");
    });

    test('VARIABLE drawer: live value inspection, Store (Ans -> Var), Edit (Var =), and Recall', () {
      final controller = CalculatorController();

      // Compute 42 -> Ans = 42
      controller.insertToken(const InputToken(display: '42', evalText: '42'));
      controller.pressExe();
      expect(controller.state.variables['Ans'], '42');

      // Open VARIABLE drawer -> select A -> Store (Ans -> A)
      controller.pressVariable();
      expect(controller.state.activeOverlay, ActiveOverlay.variableMenu);
      controller.pressOk(); // Enter 'A' sub-menu
      expect(controller.state.menuBreadcrumbs.length, 2);
      controller.pressCursorDown(); // Index 1: Store (Ans -> A)
      controller.pressOk();
      expect(controller.state.activeOverlay, ActiveOverlay.none);
      expect(controller.state.variables['A'], '42');
      expect(controller.state.resultText, 'A = 42');

      // Open VARIABLE drawer -> select B (index 1) -> Edit (B = ...) -> type 8 -> EXE
      controller.pressVariable();
      controller.pressCursorDown(); // B
      controller.pressOk(); // Enter 'B' sub-menu
      controller.pressCursorDown();
      controller.pressCursorDown(); // Index 2: Edit (B = ...)
      controller.pressOk();
      expect(controller.state.definingPromptTarget, 'B');
      controller.insertToken(const InputToken(display: '8', evalText: '8'));
      controller.pressExe();
      expect(controller.state.definingPromptTarget, isNull);
      expect(controller.state.variables['B'], '8');

      // Recall A + B -> 50
      controller.pressAc();
      controller.pressVariable();
      controller.pressOk(); // Enter A
      controller.pressOk(); // Recall A
      controller.insertToken(
        const InputToken(display: '+', evalText: '+'),
        isBinaryOperator: true,
      );
      controller.pressVariable();
      controller.pressCursorDown(); // B
      controller.pressOk(); // Enter B
      controller.pressOk(); // Recall B
      controller.pressExe();
      expect(controller.state.resultText, '50');
    });

    test('FUNCTION manager: Define f(x), Define g(x) composing f(x), and evaluate f(3) & g(3)', () {
      final controller = CalculatorController();
      expect(controller.state.hasFunctionDefined, isFalse);

      // Open FUNCTION menu -> select 'Define f(x)' (index 2) -> type 'x^2 + 1' -> EXE
      controller.pressFunction();
      expect(controller.state.activeOverlay, ActiveOverlay.functionMenu);
      controller.pressCursorDown();
      controller.pressCursorDown(); // Index 2: Define f(x)
      controller.pressOk();
      expect(controller.state.definingPromptTarget, 'f');

      controller.insertToken(const InputToken(display: 'x', evalText: 'x'));
      controller.insertSuperscript(
        initialExponent: [CharNode(display: '2', evalText: '2')],
        focusExponent: false,
      );
      controller.insertToken(
        const InputToken(display: '+', evalText: '+'),
        isBinaryOperator: true,
      );
      controller.insertToken(const InputToken(display: '1', evalText: '1'));
      controller.pressExe();

      expect(controller.state.definingPromptTarget, isNull);
      expect(controller.state.hasFunctionDefined, isTrue);
      expect(controller.state.definedFunctionF, 'x^(2)+1');

      // Open FUNCTION menu -> select 'Define g(x)' (index 3) -> type '2*f(x)' -> EXE
      controller.pressFunction();
      controller.pressCursorDown();
      controller.pressCursorDown();
      controller.pressCursorDown(); // Index 3: Define g(x)
      controller.pressOk();
      expect(controller.state.definingPromptTarget, 'g');
      controller.insertToken(const InputToken(display: '2', evalText: '2'));
      controller.insertToken(const InputToken(display: 'f(', evalText: 'f('));
      controller.insertToken(const InputToken(display: 'x', evalText: 'x'));
      controller.insertToken(const InputToken(display: ')', evalText: ')'));
      controller.pressExe();
      expect(controller.state.definedFunctionG, '2f(x)');

      // Insert f(3) via FUNCTION menu -> f(3) = 3^2 + 1 = 10
      controller.pressFunction();
      controller.pressOk(); // Index 0: f(x) -> inserts 'f('
      controller.insertToken(const InputToken(display: '3', evalText: '3'));
      controller.insertToken(const InputToken(display: ')', evalText: ')'));
      controller.pressExe();
      expect(controller.state.resultText, '10');

      // Insert g(3) via FUNCTION menu -> g(3) = 2 * f(3) = 20
      controller.pressAc();
      controller.pressFunction();
      controller.pressCursorDown(); // Index 1: g(x) -> inserts 'g('
      controller.pressOk();
      controller.insertToken(const InputToken(display: '3', evalText: '3'));
      controller.insertToken(const InputToken(display: ')', evalText: ')'));
      controller.pressExe();
      expect(controller.state.resultText, '20');
    });

    test('SETTINGS hierarchical menu: Angle Unit, Fix/Sci/Norm, Engineer Symbol, Fraction Result & Reset', () {
      final controller = CalculatorController();

      // Open SETTINGS (SHIFT + TOOLS)
      controller.pressShift();
      controller.pressTools();
      expect(controller.state.activeOverlay, ActiveOverlay.settingsMenu);
      expect(controller.state.currentBreadcrumb!.title, 'SETTINGS');

      // Enter 'Calc Settings' (index 0) -> 'Angle Unit' (index 1) -> select 'Radian' (index 1)
      controller.pressOk(); // Calc Settings
      expect(controller.state.currentBreadcrumb!.title, 'Calc Settings');
      controller.pressCursorDown(); // Angle Unit
      controller.pressOk();
      expect(controller.state.currentBreadcrumb!.title, 'Angle Unit');
      controller.pressCursorDown(); // Radian
      controller.pressOk();
      expect(controller.state.angleUnit, AngleUnit.radian);

      // Step back to Calc Settings -> enter 'Fraction Result' (index 4) -> select 'Mixed Fraction' (index 0)
      controller.pressBack(); // Back to Calc Settings
      controller.pressCursorDown(); // Number Format (2)
      controller.pressCursorDown(); // Engineer Symbol (3)
      controller.pressCursorDown(); // Fraction Result (4)
      controller.pressOk();
      expect(controller.state.currentBreadcrumb!.title, 'Fraction Result');
      controller.pressOk(); // Mixed Fraction (index 0)

      // Close SETTINGS via BACK -> BACK -> BACK
      controller.pressBack();
      controller.pressBack();
      controller.pressBack();
      expect(controller.state.activeOverlay, ActiveOverlay.none);

      // Evaluate 7/3 -> automatically displays Mixed Fraction '2 1/3' due to FractionResultPreference.mixed
      controller.insertToken(const InputToken(display: '7', evalText: '7'));
      controller.insertToken(
        const InputToken(display: '÷', evalText: '/'),
        isBinaryOperator: true,
      );
      controller.insertToken(const InputToken(display: '3', evalText: '3'));
      controller.pressExe();
      expect(controller.state.resultText, '2 1/3');
    });
  });

  group('Cal_ 1100_DB_ Phase 5 (Specialized App Modules: Solvers, Linear Algebra, Statistics, Distributions & Utilities)', () {
    test('Matrix App: 3x3 & 4x4 LU Determinant, Gauss-Jordan Inversion, Multiplication, Powers, Ref & Rref', () {
      // 3x3 Matrix with det = 1:
      final matA = Cal_Matrix(
        rows: 3,
        cols: 3,
        values: const [
          [1, 2, 3],
          [0, 1, 4],
          [5, 6, 0],
        ],
      );
      expect(matA.determinant(), closeTo(1.0, 1e-10));

      // Inverse of matA:
      // [-24,  18,   5]
      // [ 20, -15,  -4]
      // [ -5,   4,   1]
      final invA = matA.inverse();
      expect(invA.get(0, 0), closeTo(-24.0, 1e-9));
      expect(invA.get(0, 1), closeTo(18.0, 1e-9));
      expect(invA.get(0, 2), closeTo(5.0, 1e-9));
      expect(invA.get(1, 0), closeTo(20.0, 1e-9));
      expect(invA.get(1, 1), closeTo(-15.0, 1e-9));
      expect(invA.get(1, 2), closeTo(-4.0, 1e-9));
      expect(invA.get(2, 0), closeTo(-5.0, 1e-9));
      expect(invA.get(2, 1), closeTo(4.0, 1e-9));
      expect(invA.get(2, 2), closeTo(1.0, 1e-9));

      // Verify A * A^-1 == I_3
      final prodI = matA.multiply(invA);
      expect(prodI.toCompactString(), '[1,0,0][0,1,0][0,0,1]');

      // 4x4 Matrix inversion & determinant verification
      final mat4 = Cal_Matrix(
        rows: 4,
        cols: 4,
        values: const [
          [2, 1, 0, 0],
          [1, 2, 1, 0],
          [0, 1, 2, 1],
          [0, 0, 1, 2],
        ],
      );
      expect(mat4.determinant(), closeTo(5.0, 1e-9));
      final inv4 = mat4.inverse();
      expect(mat4.multiply(inv4).toCompactString(), '[1,0,0,0][0,1,0,0][0,0,1,0][0,0,0,1]');

      // Singular matrix throws Math ERROR on inverse
      final singular = Cal_Matrix(
        rows: 2,
        cols: 2,
        values: const [
          [1, 2],
          [2, 4],
        ],
      );
      expect(singular.determinant(), 0.0);
      expect(() => singular.inverse(), throwsA(isA<FormatException>()));

      // Controller integration in Matrix mode
      final controller = CalculatorController();
      controller.selectAppMode(AppMode.matrix);
      controller.setMatrix('MatA', matA);
      controller.insertToken(
        const InputToken(display: 'Det(MatA)', evalText: 'Det(MatA)'),
      );
      controller.pressExe();
      expect(controller.state.resultText, '1');
    });

    test('Vector App: 2D & 3D Dot product, Cross product, Norm, Angle, and Unit Vector', () {
      final u = Cal_Vector(const [1, 0, 0]);
      final v = Cal_Vector(const [0, 1, 0]);

      expect(u.dot(v), 0.0);
      expect(u.cross(v).toCompactString(), '[0,0,1]');
      expect(u.angleWith(v, AngleUnit.degree), closeTo(90.0, 1e-9));

      final w = Cal_Vector(const [3, 4]);
      expect(w.norm(), closeTo(5.0, 1e-10));
      expect(w.unitVector().toCompactString(), '[0.6,0.8]');
    });

    test('Equation App: Simultaneous Linear (2, 3, 4 unknowns, Infinite/No Solution) & Polynomial (Deg 2, 3, 4 + Vertex)', () {
      // 1. Simultaneous 2 Unknowns: x + y = 5, 2x - y = 1 -> x = 2, y = 3
      final sim2 = SimulEquationSolver.solve(const [
        [1, 1, 5],
        [2, -1, 1],
      ]);
      expect(sim2.hasUniqueSolution, isTrue);
      expect(sim2.solutions['x'], '2');
      expect(sim2.solutions['y'], '3');

      // 2. Simultaneous 3 Unknowns:
      // x + y + z = 6, 2y + 5z = -4, 2x + 5y - z = 27 -> x = 5, y = 3, z = -2
      final sim3 = SimulEquationSolver.solve(const [
        [1, 1, 1, 6],
        [0, 2, 5, -4],
        [2, 5, -1, 27],
      ]);
      expect(sim3.solutions['x'], '5');
      expect(sim3.solutions['y'], '3');
      expect(sim3.solutions['z'], '-2');

      // 3. Simultaneous 4 Unknowns:
      final sim4 = SimulEquationSolver.solve(const [
        [1, 0, 0, 1, 5],
        [0, 1, 1, 0, 5],
        [1, 1, 0, 0, 3],
        [0, 0, 1, 1, 7],
      ]);
      // Rank is 3 < 4 with consistent RHS -> Infinite Solutions
      expect(sim4.statusMessage, 'Infinite Solutions');

      // No Solution detection: x + y = 2, x + y = 5
      final noSol = SimulEquationSolver.solve(const [
        [1, 1, 2],
        [1, 1, 5],
      ]);
      expect(noSol.statusMessage, 'No Solution');

      // 4. Polynomial Degree 2 (Real roots & Vertex): x^2 - 4x + 3 = 0 -> x1 = 1, x2 = 3, Min: (2, -1)
      final quadReal = PolynomialSolver.solve(const [1, -4, 3]);
      expect(quadReal.roots.map((r) => r.toCal_String()).toList(), ['1', '3']);
      expect(quadReal.extremumLabel, 'Minimum');
      expect(quadReal.vertexX, closeTo(2.0, 1e-10));
      expect(quadReal.vertexY, closeTo(-1.0, 1e-10));

      // 5. Polynomial Degree 2 (Complex roots): x^2 - 2x + 5 = 0 -> 1+2i, 1-2i
      final quadComplex = PolynomialSolver.solve(const [1, -2, 5]);
      expect(
        quadComplex.roots.map((r) => r.toCal_String()).toList(),
        ['1+2i', '1-2i'],
      );

      // 6. Polynomial Degree 3: (x-1)(x-2)(x-3) = x^3 - 6x^2 + 11x - 6 = 0 -> 1, 2, 3
      final cubic = PolynomialSolver.solve(const [1, -6, 11, -6]);
      expect(
        cubic.roots.map((r) => r.toCal_String()).toList(),
        ['1', '2', '3'],
      );

      // 7. Polynomial Degree 4: (x^2 - 1)(x^2 - 4) = x^4 - 5x^2 + 4 = 0 -> -2, -1, 1, 2
      final quartic = PolynomialSolver.solve(const [1, 0, -5, 0, 4]);
      expect(
        quartic.roots.map((r) => r.toCal_String()).toList(),
        ['-2', '-1', '1', '2'],
      );

      // 8. Degenerate leading coefficient a = 0 -> Math ERROR
      final degen = PolynomialSolver.solve(const [0, 2, 1]);
      expect(degen.error, 'Math ERROR');
    });

    test('Inequality & Ratio Apps: Exact interval notation and proportion solving', () {
      // x^2 - x - 6 < 0 -> (x-3)(x+2) < 0 -> -2 < x < 3
      expect(
        InequalitySolver.solve(
          coefficients: const [1, -1, -6],
          sign: InequalitySign.lessThan,
        ),
        '-2 < x < 3',
      );

      // x^2 - x - 6 ≥ 0 -> x ≤ -2, 3 ≤ x
      expect(
        InequalitySolver.solve(
          coefficients: const [1, -1, -6],
          sign: InequalitySign.greaterOrEqual,
        ),
        'x ≤ -2, 3 ≤ x',
      );

      // x^2 + 1 > 0 -> All Real Numbers; x^2 + 1 < 0 -> No Solution
      expect(
        InequalitySolver.solve(
          coefficients: const [1, 0, 1],
          sign: InequalitySign.greaterThan,
        ),
        'All Real Numbers',
      );
      expect(
        InequalitySolver.solve(
          coefficients: const [1, 0, 1],
          sign: InequalitySign.lessThan,
        ),
        'No Solution',
      );

      // Ratio: 3 : 4 = X : 12 -> X = 9; 2 : 5 = 6 : X -> X = 15
      expect(
        RatioSolver.solve(
          type: RatioTemplateType.aToBEqualsXToD,
          a: 3,
          b: 4,
          cOrD: 12,
        ),
        'X = 9',
      );
      expect(
        RatioSolver.solve(
          type: RatioTemplateType.aToBEqualsCToX,
          a: 2,
          b: 5,
          cOrD: 6,
        ),
        'X = 15',
      );
    });

    test('Statistics & Distribution Apps: 1-VAR, 2-VAR Regressions, Normal, Binomial & Poisson', () {
      // 1-VAR Statistics on [2, 4, 4, 4, 5, 5, 7, 9]:
      // mean = 5, popStdDev (σx) = 2, n = 8, min = 2, Med = 4.5, max = 9
      final oneVar = StatisticsEngine.computeOneVar(
        const [2, 4, 4, 4, 5, 5, 7, 9],
      );
      expect(oneVar.meanX, closeTo(5.0, 1e-10));
      expect(oneVar.popStdDevX, closeTo(2.0, 1e-10));
      expect(oneVar.countN, 8.0);
      expect(oneVar.minX, 2.0);
      expect(oneVar.median, 4.5);
      expect(oneVar.maxX, 9.0);

      // 2-VAR Linear Regression on y = 3 + 2x:
      final twoVar = StatisticsEngine.computeTwoVar(
        model: StatModelType.linear,
        xValues: const [1, 2, 3, 4],
        yValues: const [5, 7, 9, 11],
      );
      expect(twoVar.coeffA, closeTo(3.0, 1e-10));
      expect(twoVar.coeffB, closeTo(2.0, 1e-10));
      expect(twoVar.corrR, closeTo(1.0, 1e-10));
      expect(twoVar.predictY(5.0), closeTo(13.0, 1e-10));
      expect(twoVar.predictX(13.0), closeTo(5.0, 1e-10));

      // Normal PD at x = 0 (σ=1, μ=0) -> 1/sqrt(2*pi) ≈ 0.39894228
      expect(
        DistributionEngine.normalPd(x: 0.0, sigma: 1.0, mu: 0.0),
        closeTo(0.3989422804, 1e-7),
      );
      // Normal CD (-1.959964, 1.959964) -> 0.95
      expect(
        DistributionEngine.normalCd(lower: -1.95996398, upper: 1.95996398),
        closeTo(0.95, 1e-5),
      );
      // Inverse Normal (Area = 0.975, σ=1, μ=0) -> 1.95996398
      expect(
        DistributionEngine.inverseNormal(area: 0.975, sigma: 1.0, mu: 0.0),
        closeTo(1.95996398, 1e-6),
      );

      // Binomial PD (x=2, n=4, p=0.5) = 6 * (1/16) = 0.375
      expect(
        DistributionEngine.binomialPd(x: 2, n: 4, p: 0.5),
        closeTo(0.375, 1e-10),
      );
      // Binomial CD (x=2, n=4, p=0.5) = (1 + 4 + 6)/16 = 0.6875
      expect(
        DistributionEngine.binomialCd(x: 2, n: 4, p: 0.5),
        closeTo(0.6875, 1e-10),
      );

      // Poisson PD (x=2, λ=2) = (4 * e^-2) / 2 = 2 * e^-2 ≈ 0.270670566
      expect(
        DistributionEngine.poissonPd(x: 2, lambda: 2.0),
        closeTo(0.270670566, 1e-8),
      );
    });

    test('Complex & Base-N Apps: Rectangular/Polar complex arithmetic and 32-bit two\'s complement bitwise logic', () {
      const cmp = ComplexExpressionEvaluator(angleUnit: AngleUnit.degree);

      expect(cmp.evaluate('(1+2i)*(3-4i)').rectangularText, '11+2i');
      expect(cmp.evaluate('5/(3+4i)').rectangularText, '0.6-0.8i');
      expect(cmp.evaluate('Abs(3+4i)').rectangularText, '5');
      expect(cmp.evaluate('Arg(1+i)').rectangularText, '45');
      expect(cmp.evaluate('Conjg(3+4i)').rectangularText, '3-4i');
      expect(cmp.evaluate('2∠60').polarText, '2∠60');

      // Base-N 32-bit two's complement:
      expect(BaseNEngine.formatInBase(-1, NumberBase.hex), 'FFFFFFFF');
      expect(
        BaseNEngine.formatInBase(-1, NumberBase.bin),
        '11111111111111111111111111111111',
      );
      expect(BaseNEngine.evaluate('12 AND 10', NumberBase.dec).formatted, '8');
      expect(BaseNEngine.evaluate('12 OR 10', NumberBase.dec).formatted, '14');
      expect(BaseNEngine.evaluate('12 XOR 10', NumberBase.dec).formatted, '6');
      expect(BaseNEngine.evaluate('FF + 1', NumberBase.hex).formatted, '100');
      expect(BaseNEngine.evaluate('1010 + 0101', NumberBase.bin).formatted, '1111');
    });

    test('Table, Spreadsheet, Math Box & Specialized 2D LCD Grid Renderer', () {
      // 1. Table App generation for f(x) = x^2 and g(x) = 2x + 1 over [1, 3] step 1
      final tbl = TableAppEngine.generateTable(
        definedF: 'x^2',
        definedG: '2x+1',
        start: 1,
        end: 3,
        step: 1,
      );
      expect(tbl.error, isNull);
      expect(tbl.rows.length, 3);
      expect(tbl.rows[2].fxText, '9');
      expect(tbl.rows[2].gxText, '7');

      // 2. Spreadsheet App: formulas, relative/absolute refs, Sum/Mean & Circular ERROR
      var sheet = const SpreadsheetSheet();
      sheet = sheet.setCell(0, 0, '10'); // A1 = 10
      sheet = sheet.setCell(1, 0, '20'); // A2 = 20
      sheet = sheet.setCell(2, 0, '=A1+A2'); // A3 = 30
      sheet = sheet.setCell(3, 0, '=Sum(A1:A3)'); // A4 = 60
      sheet = sheet.setCell(4, 0, '=Mean(A1:A3)'); // A5 = 20
      expect(sheet.getDisplay(2, 0), '30');
      expect(sheet.getDisplay(3, 0), '60');
      expect(sheet.getDisplay(4, 0), '20');

      // Circular reference detection: B1 = B2, B2 = B1 -> Circular ERROR
      sheet = sheet.setCell(0, 1, '=B2');
      sheet = sheet.setCell(1, 1, '=B1');
      expect(sheet.getDisplay(0, 1), 'Circular ERROR');

      // 3. Math Box Dice Roll & Coin Toss empirical simulations
      final dice = MathBoxEngine.runDiceRoll(diceCount: 2, attempts: 100, seed: 42);
      expect(dice.outcomes.length, 100);
      expect(dice.frequencies.values.fold(0, (a, b) => a + b), 100);

      final coins = MathBoxEngine.runCoinToss(coinCount: 3, attempts: 80, seed: 42);
      expect(coins.outcomes.length, 80);
      expect(coins.frequencies.values.fold(0, (a, b) => a + b), 80);

      // 4. Verify 2D LCD Grid Renderer rasterizes onto 192x63 LcdFrameBuffer cleanly
      final fb = LcdFrameBuffer(width: 192, height: 63);
      final controller = CalculatorController();
      controller.selectAppMode(AppMode.spreadsheet);
      expect(controller.state.activeGridModel, isNotNull);
      LcdGridTableRenderer.renderGrid(fb, controller.state.activeGridModel!);
    });
  });

  group('Cal_ 1100_DB_ Phase 6 (CODATA Constants, Unit Conversions, Symbolic Polish & Hardware Fidelity)', () {
    test('47 CODATA Scientific Constants dictionary & expression evaluation', () {
      // Verify exact count of 47 built-in CODATA constants across 5 categories
      expect(CodataLibrary.allConstants.length, 47);
      expect(CodataCategory.values.length, 5);
      for (final cat in CodataCategory.values) {
        expect(CodataLibrary.byCategory(cat), isNotEmpty);
      }

      const evaluator = MathExpressionEvaluator();
      // Speed of light c₀ = 299792458 m/s
      expect(evaluator.evaluateString('c₀').primaryText, '299792458');
      // Standard gravity g_n = 9.80665 m/s²
      expect(evaluator.evaluateString('g_n').decimalText, '9.80665');
      // Standard atmosphere atm = 101325 Pa
      expect(evaluator.evaluateString('atm').primaryText, '101325');
      // Standard temperature t₀ = 273.15 K
      expect(evaluator.evaluateString('t₀').decimalText, '273.15');
      // Avogadro constant N_A = 6.02214076×10^23
      expect(evaluator.evaluateString('N_A').decimalText, '6.02214076×10^23');
      // Planck constant h = 6.62607015×10^-34
      expect(evaluator.evaluateString('h').decimalText, '6.62607015×10^-34');
      // Elementary charge e_c = 1.602176634×10^-19
      expect(evaluator.evaluateString('e_c').decimalText, '1.602176634×10^-19');
      // Arithmetic with CODATA constants: 2 * c₀ = 599584916
      expect(evaluator.evaluateString('2c₀').primaryText, '599584916');
    });

    test('40+ Unit Conversion pairs across all 11 categories including affine Temperature formulas', () {
      expect(UnitConverterEngine.allPairs.length, greaterThanOrEqualTo(40));
      expect(UnitCategory.values.length, 11);

      const evaluator = MathExpressionEvaluator();
      // Length: 1 in ► cm = 2.54; 2.54 cm ► in = 1
      expect(evaluator.evaluateString('1►in►cm').decimalText, '2.54');
      expect(evaluator.evaluateString('2.54►cm►in').decimalText, '1');
      // Mass: 1 kg ► lb ≈ 2.204622622
      expect(
        double.parse(evaluator.evaluateString('1►kg►lb').decimalText),
        closeTo(2.2046226218, 1e-7),
      );
      // Pressure: 1 atm ► Pa = 101325; 101325 Pa ► atm = 1
      expect(evaluator.evaluateString('1►atm►Pa').decimalText, '101325');
      expect(evaluator.evaluateString('101325►Pa►atm').decimalText, '1');
      // Energy: 1 cal ► J = 4.184
      expect(evaluator.evaluateString('1►cal►J').decimalText, '4.184');
      // Velocity: 36 km/h ► m/s = 10
      expect(evaluator.evaluateString('36►km/h►m/s').decimalText, '10');

      // Affine Temperature conversions: °C ↔ °F ↔ K
      expect(evaluator.evaluateString('0►°C►°F').decimalText, '32');
      expect(evaluator.evaluateString('100►°C►°F').decimalText, '212');
      expect(evaluator.evaluateString('-40►°C►°F').decimalText, '-40');
      expect(evaluator.evaluateString('212►°F►°C').decimalText, '100');
      expect(evaluator.evaluateString('0►°C►K').decimalText, '273.15');
      expect(evaluator.evaluateString('273.15►K►°C').decimalText, '0');
      expect(evaluator.evaluateString('32►°F►K').decimalText, '273.15');
    });

    test('Exact Surds & Radical Rationalization, Dynamic ENG shifting, Sexagesimal DMS & Recurring Decimal', () {
      const evaluator = MathExpressionEvaluator();

      // 1. Exact Surds & Radical Rationalization:
      // 1/√3 -> √3/3, 6/√2 -> 3√2, √18 + √50 -> 8√2
      expect(evaluator.evaluateString('1/√(3)').exactText, '√3/3');
      expect(evaluator.evaluateString('6/√(2)').exactText, '3√2');
      expect(evaluator.evaluateString('√(18)+√(50)').exactText, '8√2');

      // 2. Dynamic ENG shifting via controller.pressEng() and pressEng(shift: true):
      final controller = CalculatorController();
      // Evaluate 12345
      for (final ch in ['1', '2', '3', '4', '5']) {
        controller.insertToken(InputToken(display: ch, evalText: ch));
      }
      controller.pressExe();
      expect(controller.state.resultText, '12345');

      // First pressEng() enters Engineering Notation (12.345×10^3)
      controller.pressEng();
      expect(controller.state.activeFormatView, OutputFormatView.engineering);
      expect(controller.state.resultText, '12.345×10^3');

      // Pressing ENG again shifts exponent down by 3 (10^3 -> 10^0 -> 10^-3)
      controller.pressEng();
      expect(controller.state.resultText, '12345×10^0');
      controller.pressEng();
      expect(controller.state.resultText, '12345000×10^-3');

      // Pressing Shift + ENG shifts exponent up by 3 (10^-3 -> 10^0 -> 10^3)
      controller.pressEng(shift: true);
      expect(controller.state.resultText, '12345×10^0');
      controller.pressEng(shift: true);
      expect(controller.state.resultText, '12.345×10^3');

      // 3. Sexagesimal (DMS) two-way parsing & formatting:
      // 2°35'6'' == 2.585 and 2.585 -> 2°35'6''
      final dmsRes = evaluator.evaluateString("2°35'6''");
      expect(dmsRes.decimalText, '2.585');
      expect(
        Cal_FormatConverter.formatSexagesimalDms(dmsRes.decimalValue!),
        "2°35'6''",
      );

      // 4. Recurring Decimal Detection & Vinculum Notation:
      // 1/7 -> 0.(142857)
      final recRes = evaluator.evaluateString('1/7');
      expect(recRes.recurringDecimalText, '0.(142857)');
    });

    test('ClassWiz QR Code Generator (Version 3 & Version 11), LCD Contrast/Inversion & Persistent Storage', () async {
      final controller = CalculatorController();

      // 1. Evaluate an expression and generate QR Code (Version 3 & Version 11)
      controller.insertToken(const InputToken(display: '2', evalText: '2'));
      controller.insertToken(
        const InputToken(display: '+', evalText: '+'),
        isBinaryOperator: true,
      );
      controller.insertToken(const InputToken(display: '3', evalText: '3'));
      controller.pressExe();
      expect(controller.state.resultText, '5');

      // Trigger QR Code (default Version 3: 29x29)
      controller.pressQrCode();
      expect(controller.state.activeOverlay, ActiveOverlay.qrCode);
      expect(controller.state.activeQrMatrix, isNotNull);
      expect(controller.state.activeQrMatrix!.version, 3);
      expect(controller.state.activeQrMatrix!.size, 29);
      expect(
        controller.state.activeQrMatrix!.payloadUrl,
        contains('wes.Cal_.com'),
      );

      // Render QR Code onto 192x63 LCD FrameBuffer and verify finder patterns
      final fb = LcdFrameBuffer(width: 192, height: 63);
      Cal_QrCodeGenerator.renderOnLcd(
        fb,
        controller.state.activeQrMatrix!,
        modeLabel: controller.state.activeMode.title,
        expressionText: controller.state.expressionDisplayString,
        resultText: controller.state.resultText,
      );
      // Verify Version 11 high-density encoding as well
      final qrV11 = Cal_QrCodeGenerator.encode(
        Cal_QrCodeGenerator.buildClassWizUrl(
          modeName: 'Calculate',
          expression: 'x^2+1',
          result: '2',
          version: 11,
        ),
        version: 11,
      );
      expect(qrV11.version, 11);
      expect(qrV11.size, 53);

      // Close QR overlay with BACK
      controller.pressBack();
      expect(controller.state.activeOverlay, ActiveOverlay.none);

      // 2. LCD Contrast (0..15) & Inversion (lcdInverted)
      final normalBg = Cal_Theme.colorForShade(0, contrast: 8, inverted: false);
      final invertedBg = Cal_Theme.colorForShade(0, contrast: 8, inverted: true);
      final normalInk = Cal_Theme.colorForShade(4, contrast: 8, inverted: false);
      expect(invertedBg, equals(normalInk));
      expect(normalBg, isNot(equals(invertedBg)));

      // 3. Persistent Storage: save & restore variables, functions, settings, and history
      controller.storeVariable('A', '42');
      controller.defineUserFunction('f', 'x^2+5');
      controller.setAngleUnit(AngleUnit.radian);
      await controller.saveToPersistentStorage();

      final freshController = CalculatorController();
      expect(freshController.state.variables['A'], '0');
      expect(freshController.state.angleUnit, AngleUnit.degree);

      await freshController.restoreFromPersistentStorage();
      expect(freshController.state.variables['A'], '42');
      expect(freshController.state.definedFunctionF, 'x^2+5');
      expect(freshController.state.angleUnit, AngleUnit.radian);
      expect(freshController.state.history, isNotEmpty);
    });

    test(
      'Authentic Cal_ 1100_DB_ App Startup Menus, Distribution List/Variable, Equation Solver & Statistics CATALOG',
      () {
        final controller = CalculatorController();

        // 1. Enter Distribution from HOME (index 6) -> verify exact Cal_ 1100_DB_ menu order:
        // Binomial PD, Binomial CD, Normal PD, Normal CD, Inverse Normal, Poisson PD, Poisson CD
        controller.pressHome();
        for (int i = 0; i < 6; i++) {
          controller.pressCursorRight();
        }
        controller.pressOk();
        expect(controller.state.activeMode, AppMode.distribution);
        expect(controller.state.menuBreadcrumbs, isNotEmpty);
        final distItems = controller.state.currentBreadcrumb!.items;
        expect(
          distItems.map((e) => e.label).toList(),
          equals([
            'Binomial PD',
            'Binomial CD',
            'Normal PD',
            'Normal CD',
            'Inverse Normal',
            'Poisson PD',
            'Poisson CD',
          ]),
        );

        // Select Binomial PD -> opens 'List' vs 'Variable' sub-menu
        controller.pressOk();
        expect(
          controller.state.currentBreadcrumb!.items.map((e) => e.label).toList(),
          equals(['List', 'Variable']),
        );
        // Select 'List' (index 0) -> opens 2-column x | P table
        controller.pressOk();
        expect(controller.state.menuBreadcrumbs, isEmpty);
        expect(controller.state.activeGridModel, isNotNull);
        expect(
          controller.state.activeGridModel!.columnHeaders,
          equals(['x', 'P']),
        );

        // Pressing BACK from the Distribution table returns to the Distribution startup menu
        controller.pressBack();
        expect(controller.state.menuBreadcrumbs, isNotEmpty);
        expect(
          controller.state.currentBreadcrumb!.items.first.label,
          'Binomial PD',
        );

        // 2. Enter Equation from HOME (index 9) -> Simul Equation, Polynomial, Solver
        controller.pressHome();
        while (controller.state.overlayCursorIndex < 9) {
          controller.pressCursorRight();
        }
        controller.pressOk();
        expect(controller.state.activeMode, AppMode.equation);
        expect(
          controller.state.currentBreadcrumb!.items.map((e) => e.label).toList(),
          equals(['Simul Equation', 'Polynomial', 'Solver']),
        );
        // Select 'Solver' (index 2) -> solve 2x+3=11 -> x = 4, L-R = 0
        controller.pressCursorDown();
        controller.pressCursorDown();
        controller.pressOk();
        expect(controller.state.definingPromptTarget, 'SOLVER_EQ');
        for (final ch in ['2', 'x', '+', '3', '=', '1', '1']) {
          controller.insertToken(InputToken(display: ch, evalText: ch));
        }
        controller.pressExe();
        expect(controller.state.resultText, 'x = 4');
        expect(
          controller.state.multiLineResultLines,
          containsAll(['x = 4', 'L-R = 0']),
        );

        // 3. Statistics Normal Dist P(0) = 0.5 and Verify relational operators (≠, >, <, ≥, ≤)
        controller.selectAppMode(AppMode.calculate);
        expect(
          controller.evaluateExpressionString('P(0)', forceDecimal: true).decimalText,
          '0.5',
        );
        expect(
          controller.evaluateExpressionString('Q(0)', forceDecimal: true).decimalText,
          '0',
        );
        expect(
          controller.evaluateExpressionString('R(0)', forceDecimal: true).decimalText,
          '0.5',
        );

        controller.pressTools();
        controller.pressCursorDown(); // Verify ON
        controller.pressOk();
        expect(controller.state.isVerifyMode, isTrue);
        controller.pressAc();
        for (final ch in ['5', '≥', '3']) {
          controller.insertToken(InputToken(display: ch, evalText: ch));
        }
        controller.pressExe();
        expect(controller.state.resultText, 'TRUE');
      },
    );

    testWidgets(
      'CATALOG > Func Analysis > Integral (∫), Derivative (d/dx), Summation (∑) 2D Natural Textbook display & evaluation',
      (WidgetTester tester) async {
        final controller = CalculatorController();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CalculatorScope(
                controller: controller,
                child: const SizedBox(
                  width: 420,
                  height: 220,
                  child: LcdDisplayWidget(),
                ),
              ),
            ),
          ),
        );

        // 1. Open CATALOG -> Func Analysis -> Integral (∫)
        controller.pressCatalog();
        expect(
          controller.state.currentBreadcrumb!.items.first.label,
          'Func Analysis',
        );
        controller.pressOk();
        expect(
          controller.state.currentBreadcrumb!.items.map((e) => e.label).toList(),
          equals([
            'Derivative (d/dx)',
            'Integral (∫)',
            'Summation (∑)',
            'Product (∏)',
            'Logarithm (logₐb)',
          ]),
        );

        // Select 'Integral (∫)' (index 1)
        controller.pressCursorDown();
        controller.pressOk();
        expect(controller.state.rootMathNode, isNotNull);
        expect(
          controller.state.rootMathNode!.children.single,
          isA<IntegralNode>(),
        );

        // Type x^4 in integrand body (matching reference photo ∫_□^□ x^4 dx)
        controller.insertToken(const InputToken(display: 'x', evalText: 'x'));
        controller.insertSuperscript();
        controller.insertToken(const InputToken(display: '4', evalText: '4'));
        controller.pressCursorRight(); // exit exponent back to body

        // Pump widget while Integral has empty placeholder boxes □ for upper/lower bounds
        await tester.pump();

        // Navigate ▼ to lower limit box and enter 0, then ▲ to upper limit box and enter 1
        controller.pressCursorDown();
        controller.insertToken(const InputToken(display: '0', evalText: '0'));
        controller.pressCursorUp();
        controller.insertToken(const InputToken(display: '1', evalText: '1'));
        controller.pressExe();
        await tester.pump();

        expect(controller.state.errorMessage, isNull);
        expect(controller.state.resultText, '0.2');
        expect(controller.state.alternateResultText, '1/5');

        // Also verify DerivativeNode and SummationNode render in high-res 2D without exceptions
        controller.pressAc();
        controller.insertDerivative();
        controller.insertToken(const InputToken(display: 'x', evalText: 'x'));
        controller.insertSuperscript(
          initialExponent: [CharNode(display: '2')],
          focusExponent: false,
        );
        controller.pressCursorRight();
        controller.insertToken(const InputToken(display: '3', evalText: '3'));
        controller.pressExe();
        await tester.pump();
        expect(controller.state.resultText, '6');

        controller.pressAc();
        controller.insertSummation();
        await tester.pump();
      },
    );
  });
}



