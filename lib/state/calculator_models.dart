import 'package:flutter/foundation.dart';
import '../display_engine/math_nodes.dart';

/// All 13 application modes of the Cal_ 1100_DB_ ClassWiz.
enum AppMode {
  calculate('Calculate', 'CALC', '1'),
  complex('Complex', 'CMPLX', '2'),
  baseN('Base-N', 'BASE', '3'),
  matrix('Matrix', 'MAT', '4'),
  vector('Vector', 'VCT', '5'),
  statistics('Statistics', 'STAT', '6'),
  distribution('Distribution', 'DIST', '7'),
  spreadsheet('Spreadsheet', 'SHEET', '8'),
  table('Table', 'TABLE', '9'),
  equation('Equation', 'EQN', 'A'),
  inequality('Inequality', 'INEQ', 'B'),
  ratio('Ratio', 'RATIO', 'C'),
  mathBox('Math Box', 'MBOX', 'D');

  final String title;
  final String shortBadge;
  final String gridCode;

  const AppMode(this.title, this.shortBadge, this.gridCode);
}

/// Angle unit configuration displayed in the top status bar ('D', 'R', 'G').
enum AngleUnit {
  degree('D', 'Degree'),
  radian('R', 'Radian'),
  gradian('G', 'Gradian');

  final String badge;
  final String label;

  const AngleUnit(this.badge, this.label);
}

/// Input/Output display format modes.
enum InputOutputMode {
  mathIMathO('MathI/MathO', true, true),
  mathIDecimalO('MathI/DecimalO', true, false),
  lineILineO('LineI/LineO', false, true),
  lineIDecimalO('LineI/DecimalO', false, false);

  final String label;
  final bool isMathInput;
  final bool isExactOutput;

  const InputOutputMode(this.label, this.isMathInput, this.isExactOutput);
}

/// Number rounding / display format mode.
enum NumberFormatMode {
  norm1('Norm 1'),
  norm2('Norm 2'),
  fix('Fix'),
  sci('Sci');

  final String label;
  const NumberFormatMode(this.label);
}

/// Modal drawers and navigation overlays rendered on the 192×63 LCD.
enum ActiveOverlay {
  none,
  homeGrid,
  settingsMenu,
  catalogMenu,
  toolsMenu,
  variableMenu,
  functionMenu,
  formatMenu,
  qrCode,
}

/// Represents an atomic token in the calculator input buffer.
@immutable
class InputToken {
  final String display;
  final String evalText;
  final bool isTemplatePlaceholder;

  const InputToken({
    required this.display,
    String? evalText,
    this.isTemplatePlaceholder = false,
  }) : evalText = evalText ?? display;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InputToken &&
          runtimeType == other.runtimeType &&
          display == other.display &&
          evalText == other.evalText &&
          isTemplatePlaceholder == other.isTemplatePlaceholder;

  @override
  int get hashCode => Object.hash(display, evalText, isTemplatePlaceholder);
}

/// Represents a committed calculation stored in the 30-entry history stack,
/// including its full 2D Visual AST [rootNode].
@immutable
class CalculationHistoryEntry {
  final List<InputToken> tokens;
  final MathContainerNode? rootNode;
  final String expressionText;
  final String resultText;
  final AppMode mode;

  const CalculationHistoryEntry({
    required this.tokens,
    this.rootNode,
    required this.expressionText,
    required this.resultText,
    required this.mode,
  });
}

/// Selection range within the active token buffer.
@immutable
class CursorSelectionRange {
  final int start;
  final int end;

  const CursorSelectionRange(this.start, this.end);

  bool get isCollapsed => start == end;
}
