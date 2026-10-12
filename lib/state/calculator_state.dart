import 'package:flutter/foundation.dart';
import '../app_modules/algebraic_solvers_engine.dart';
import '../app_modules/complex_basen_engine.dart';
import '../app_modules/linear_algebra_engine.dart';
import '../app_modules/statistics_distribution_engine.dart';
import '../app_modules/table_spreadsheet_mathbox_engine.dart';
import '../display_engine/qr_code_generator.dart';
import '../display_engine/lcd_grid_table_renderer.dart';
import '../display_engine/math_nodes.dart';
import '../navigation/cw_menu_tree.dart';
import 'calculator_models.dart';

/// Immutable global state snapshot of the Cal_ 1100_DB_ ClassWiz machine.
@immutable
class CalculatorState {
  /// Active ClassWiz application mode (Default: Calculate).
  final AppMode activeMode;

  /// Keypad modifier latch: SHIFT (gold secondary functions).
  final bool isShift;

  /// Keypad modifier latch: ALPHA / Variable / Hex selection.
  final bool isAlpha;

  /// Cursor insertion mode: true = Insert (`|`), false = Overwrite (`█`).
  final bool isInsertMode;

  /// Active angle unit: Degree (`D`), Radian (`R`), or Gradian (`G`).
  final AngleUnit angleUnit;

  /// Input/Output display format mode (MathI/MathO, MathI/DecimalO, etc.).
  final InputOutputMode ioMode;

  /// Number rounding mode (Norm 1/2, Fix, Sci).
  final NumberFormatMode numberFormat;

  /// Digits parameter for Fix (0..9) or Sci (0..9).
  final int formatDigits;

  /// Whether Engineering SI symbols (k, M, G, m, μ, n, p, f) are enabled.
  final bool engSymbolOn;

  /// Preference for displaying exact rational results (`Improper` vs `Mixed`).
  final FractionResultPreference fractionPreference;

  /// Active output representation view selected via `FORMAT`.
  final OutputFormatView activeFormatView;

  /// Current exponent step shift in Engineering notation (`◀` / `▶` in ENG view).
  final int engStepShift;

  /// Whether user functions f(x) or g(x) are currently defined.
  final bool hasFunctionDefined;

  /// Persistent algebraic expression string for user function `f(x)`.
  final String definedFunctionF;

  /// Persistent algebraic expression string for user function `g(x)`.
  final String definedFunctionG;

  /// Active prompt target when defining a function (`'f'`, `'g'`) or editing
  /// a variable register (`'A'`..`'z'`), or `null` in normal calculation mode.
  final String? definingPromptTarget;

  /// Whether Verify (`TRUE` / `FALSE` equality check) mode is enabled in `TOOLS`.
  final bool isVerifyMode;

  /// Active radix in `Base-N` mode (`DEC`, `HEX`, `BIN`, `OCT`).
  final NumberBase activeBase;

  /// Whether `Complex` mode formats results in Polar form (`r∠θ`) instead of Rectangular (`a+bi`).
  final bool complexPolarDisplay;

  /// Matrix memory registers (`MatA`, `MatB`, `MatC`, `MatD`, `MatAns`).
  final Map<String, Cal_Matrix> matrices;

  /// Vector memory registers (`VctA`, `VctB`, `VctC`, `VctD`, `VctAns`).
  final Map<String, Cal_Vector> vectors;

  /// Active 2D Grid/Table Editor model for Matrix, Vector, Statistics, Table,
  /// Spreadsheet, Equation, Inequality, and Ratio apps (`null` when in standard expression view).
  final LcdGridTableModel? activeGridModel;

  /// Active multi-line solver / summary result lines (e.g. roots, 1-VAR stats, distributions).
  final List<String>? multiLineResultLines;

  /// Title banner for [multiLineResultLines].
  final String? multiLineResultTitle;

  /// Selected line index inside [multiLineResultLines].
  final int multiLineCursorIndex;

  /// Active statistical regression model in `Statistics` mode.
  final StatModelType activeStatModel;

  /// Active probability distribution type in `Distribution` mode.
  final DistributionType activeDistribution;

  /// Reactive 5×45 `Spreadsheet` state.
  final SpreadsheetSheet spreadsheet;

  /// Active sub-tool in `Math Box` mode (`Dice Roll`, `Coin Toss`, `Number Line`).
  final MathBoxSubTool activeMathBoxTool;

  /// Active inequality orientation (`>`, `<`, `≥`, `≤`) in `Inequality` mode.
  final InequalitySign activeInequalitySign;

  /// Active proportion template (`A:B = X:D` or `A:B = C:X`) in `Ratio` mode.
  final RatioTemplateType activeRatioType;

  /// Root 2D Natural Textbook AST container node.
  final MathContainerNode? rootMathNode;

  /// Active 2D container ID where the spatial cursor resides.
  final String activeContainerId;

  /// Active child slot index inside the focused [MathContainerNode].
  final int activeChildIndex;

  /// Flat token representation of the input buffer.
  final List<InputToken> inputTokens;

  /// Active cursor position within [inputTokens] or [activeChildIndex].
  final int cursorIndex;

  /// Active selection range within [inputTokens].
  final CursorSelectionRange selectionRange;

  /// Evaluated or formatted result string shown on the bottom-right LCD line.
  final String resultText;

  /// Whether the current screen represents a freshly evaluated `EXE` result.
  final bool isResultDisplayed;

  /// Whether the result is currently shown in exact fraction/symbolic form.
  final bool isShowingExactForm;

  /// Alternate decimal/exact representation for quick `FORMAT` / `S⇔D` toggling.
  final String? alternateResultText;

  /// Circular history stack (up to 30 committed expressions).
  final List<CalculationHistoryEntry> history;

  /// Current index into [history] when browsing via ▲/▼ (-1 means live buffer).
  final int historyCursor;

  /// Persistent variable registers (A, B, C, D, E, F, x, y, z, Ans, PreAns).
  final Map<String, String> variables;

  /// Active modal overlay or drawer (HOME, CATALOG, TOOLS, SETTINGS, etc.).
  final ActiveOverlay activeOverlay;

  /// Selected item index in the active menu/overlay or HOME grid.
  final int overlayCursorIndex;

  /// Hierarchical breadcrumb stack for multi-level menus (`CATALOG`, `SETTINGS`, `VARIABLE`, etc.).
  final List<MenuBreadcrumbLevel> menuBreadcrumbs;

  /// Hardware error message if an error dialog is active (e.g. `Math ERROR`).
  final String? errorMessage;

  /// Whether the authentic 192×63 dot-matrix pixel grid & scanline texture is enabled.
  final bool showPixelGrid;

  /// LCD contrast level (0 = lightest, 8 = normal, 15 = darkest).
  final int lcdContrast;

  /// Whether the LCD grayscale palette is inverted (high-contrast negative mode).
  final bool lcdInverted;

  /// QR Code format version (3 = 29×29 standard, 11 = high-density).
  final int qrVersion;

  /// Whether audible membrane key click sound is enabled.
  final bool keyClickSoundOn;

  /// Whether device haptic micro-vibration feedback is enabled.
  final bool hapticFeedbackOn;

  /// Whether the Statistics frequency column (`Freq`) is enabled (`Statistical Disp: On/Off`).
  final bool statFreqOn;

  /// Whether decimal mark uses a comma (`,`) instead of a dot (`.`).
  final bool decimalMarkComma;

  /// Whether 3-digit thousand separator is enabled (`Digit Separator: On/Off`).
  final bool digitSeparatorOn;

  /// Whether multi-line summary displays use Small Font (5 lines) instead of Normal Font (4 lines).
  final bool smallMultiLineFont;

  /// Auto Power Off timeout in minutes (`10` or `60`).
  final int autoPowerOffMinutes;

  /// Active encoded 2D QR Code matrix when `SHIFT + x` (`QR`) is open.
  final Cal_QrCodeMatrix? activeQrMatrix;

  /// Whether the calculator is powered ON (SHIFT + AC powers off).
  final bool isPoweredOn;

  const CalculatorState({
    this.activeMode = AppMode.calculate,
    this.isShift = false,
    this.isAlpha = false,
    this.isInsertMode = true,
    this.angleUnit = AngleUnit.degree,
    this.ioMode = InputOutputMode.mathIMathO,
    this.numberFormat = NumberFormatMode.norm1,
    this.formatDigits = 2,
    this.engSymbolOn = false,
    this.fractionPreference = FractionResultPreference.improper,
    this.activeFormatView = OutputFormatView.standard,
    this.engStepShift = 0,
    this.hasFunctionDefined = false,
    this.definedFunctionF = '',
    this.definedFunctionG = '',
    this.definingPromptTarget,
    this.isVerifyMode = false,
    this.activeBase = NumberBase.dec,
    this.complexPolarDisplay = false,
    this.matrices = const {},
    this.vectors = const {},
    this.activeGridModel,
    this.multiLineResultLines,
    this.multiLineResultTitle,
    this.multiLineCursorIndex = 0,
    this.activeStatModel = StatModelType.oneVar,
    this.activeDistribution = DistributionType.normalPd,
    this.spreadsheet = const SpreadsheetSheet(),
    this.activeMathBoxTool = MathBoxSubTool.diceRoll,
    this.activeInequalitySign = InequalitySign.greaterThan,
    this.activeRatioType = RatioTemplateType.aToBEqualsXToD,
    this.rootMathNode,
    this.activeContainerId = '',
    this.activeChildIndex = 0,
    this.inputTokens = const [],
    this.cursorIndex = 0,
    this.selectionRange = const CursorSelectionRange(0, 0),
    this.resultText = '',
    this.isResultDisplayed = false,
    this.isShowingExactForm = true,
    this.alternateResultText,
    this.history = const [],
    this.historyCursor = -1,
    this.variables = const {
      'A': '0',
      'B': '0',
      'C': '0',
      'D': '0',
      'E': '0',
      'F': '0',
      'x': '0',
      'y': '0',
      'z': '0',
      'Ans': '0',
      'PreAns': '0',
    },
    this.activeOverlay = ActiveOverlay.none,
    this.overlayCursorIndex = 0,
    this.menuBreadcrumbs = const [],
    this.errorMessage,
    this.showPixelGrid = true,
    this.lcdContrast = 8,
    this.lcdInverted = false,
    this.qrVersion = 3,
    this.keyClickSoundOn = false,
    this.hapticFeedbackOn = true,
    this.statFreqOn = false,
    this.decimalMarkComma = false,
    this.digitSeparatorOn = false,
    this.smallMultiLineFont = false,
    this.autoPowerOffMinutes = 10,
    this.activeQrMatrix,
    this.isPoweredOn = true,
  });

  /// Returns the currently focused menu breadcrumb level, or `null` if no menu stack is open.
  MenuBreadcrumbLevel? get currentBreadcrumb =>
      menuBreadcrumbs.isEmpty ? null : menuBreadcrumbs.last;

  /// Concatenates the display string of the 2D AST (or flat tokens).
  String get expressionDisplayString {
    if (rootMathNode != null && rootMathNode!.children.isNotEmpty) {
      return rootMathNode!.toDisplayString();
    }
    return inputTokens.map((t) => t.display).join();
  }

  /// Computes the character offset of the cursor within [expressionDisplayString].
  int get cursorCharOffset {
    int offset = 0;
    final int clamped = cursorIndex.clamp(0, inputTokens.length);
    for (int i = 0; i < clamped; i++) {
      offset += inputTokens[i].display.length;
    }
    return offset;
  }

  /// Whether the upward scroll / history indicator `▲` should be lit.
  bool get canScrollUp {
    if (activeOverlay == ActiveOverlay.homeGrid) {
      return overlayCursorIndex >= 3;
    }
    if (activeOverlay != ActiveOverlay.none || menuBreadcrumbs.isNotEmpty) {
      final level = currentBreadcrumb;
      if (level != null) return level.selectedIndex > 0;
      return overlayCursorIndex > 0;
    }
    if (multiLineResultLines != null) {
      return multiLineCursorIndex > 0;
    }
    if (activeGridModel != null) {
      return activeGridModel!.activeRow > 0;
    }
    if (history.isEmpty) return false;
    return historyCursor == -1 || historyCursor > 0;
  }

  /// Whether the downward scroll / history indicator `▼` should be lit.
  bool get canScrollDown {
    if (activeOverlay == ActiveOverlay.homeGrid) {
      return overlayCursorIndex + 3 < AppMode.values.length;
    }
    if (activeOverlay != ActiveOverlay.none || menuBreadcrumbs.isNotEmpty) {
      final level = currentBreadcrumb;
      if (level != null) {
        return level.selectedIndex < level.items.length - 1;
      }
      return true;
    }
    if (multiLineResultLines != null) {
      return multiLineCursorIndex < multiLineResultLines!.length - 1;
    }
    if (activeGridModel != null) {
      return activeGridModel!.activeRow <
          activeGridModel!.rowHeaders.length - 1;
    }
    return historyCursor != -1 && historyCursor < history.length;
  }

  /// Whether the leftward overflow indicator `◀` should be lit.
  bool get hasLeftOverflow => cursorCharOffset > 20;

  /// Whether the rightward overflow indicator `▶` should be lit.
  bool get hasRightOverflow =>
      (expressionDisplayString.length - cursorCharOffset) > 6 &&
      expressionDisplayString.length > 22;

  CalculatorState copyWith({
    AppMode? activeMode,
    bool? isShift,
    bool? isAlpha,
    bool? isInsertMode,
    AngleUnit? angleUnit,
    InputOutputMode? ioMode,
    NumberFormatMode? numberFormat,
    int? formatDigits,
    bool? engSymbolOn,
    FractionResultPreference? fractionPreference,
    OutputFormatView? activeFormatView,
    int? engStepShift,
    bool? hasFunctionDefined,
    String? definedFunctionF,
    String? definedFunctionG,
    String? Function()? definingPromptTarget,
    bool? isVerifyMode,
    NumberBase? activeBase,
    bool? complexPolarDisplay,
    Map<String, Cal_Matrix>? matrices,
    Map<String, Cal_Vector>? vectors,
    LcdGridTableModel? Function()? activeGridModel,
    List<String>? Function()? multiLineResultLines,
    String? Function()? multiLineResultTitle,
    int? multiLineCursorIndex,
    StatModelType? activeStatModel,
    DistributionType? activeDistribution,
    SpreadsheetSheet? spreadsheet,
    MathBoxSubTool? activeMathBoxTool,
    InequalitySign? activeInequalitySign,
    RatioTemplateType? activeRatioType,
    MathContainerNode? rootMathNode,
    String? activeContainerId,
    int? activeChildIndex,
    List<InputToken>? inputTokens,
    int? cursorIndex,
    CursorSelectionRange? selectionRange,
    String? resultText,
    bool? isResultDisplayed,
    bool? isShowingExactForm,
    String? Function()? alternateResultText,
    List<CalculationHistoryEntry>? history,
    int? historyCursor,
    Map<String, String>? variables,
    ActiveOverlay? activeOverlay,
    int? overlayCursorIndex,
    List<MenuBreadcrumbLevel>? menuBreadcrumbs,
    String? Function()? errorMessage,
    bool? showPixelGrid,
    int? lcdContrast,
    bool? lcdInverted,
    int? qrVersion,
    bool? keyClickSoundOn,
    bool? hapticFeedbackOn,
    bool? statFreqOn,
    bool? decimalMarkComma,
    bool? digitSeparatorOn,
    bool? smallMultiLineFont,
    int? autoPowerOffMinutes,
    Cal_QrCodeMatrix? Function()? activeQrMatrix,
    bool? isPoweredOn,
  }) {
    return CalculatorState(
      activeMode: activeMode ?? this.activeMode,
      isShift: isShift ?? this.isShift,
      isAlpha: isAlpha ?? this.isAlpha,
      isInsertMode: isInsertMode ?? this.isInsertMode,
      angleUnit: angleUnit ?? this.angleUnit,
      ioMode: ioMode ?? this.ioMode,
      numberFormat: numberFormat ?? this.numberFormat,
      formatDigits: formatDigits ?? this.formatDigits,
      engSymbolOn: engSymbolOn ?? this.engSymbolOn,
      fractionPreference: fractionPreference ?? this.fractionPreference,
      activeFormatView: activeFormatView ?? this.activeFormatView,
      engStepShift: engStepShift ?? this.engStepShift,
      hasFunctionDefined: hasFunctionDefined ?? this.hasFunctionDefined,
      definedFunctionF: definedFunctionF ?? this.definedFunctionF,
      definedFunctionG: definedFunctionG ?? this.definedFunctionG,
      definingPromptTarget: definingPromptTarget != null
          ? definingPromptTarget()
          : this.definingPromptTarget,
      isVerifyMode: isVerifyMode ?? this.isVerifyMode,
      activeBase: activeBase ?? this.activeBase,
      complexPolarDisplay: complexPolarDisplay ?? this.complexPolarDisplay,
      matrices: matrices ?? this.matrices,
      vectors: vectors ?? this.vectors,
      activeGridModel:
          activeGridModel != null ? activeGridModel() : this.activeGridModel,
      multiLineResultLines: multiLineResultLines != null
          ? multiLineResultLines()
          : this.multiLineResultLines,
      multiLineResultTitle: multiLineResultTitle != null
          ? multiLineResultTitle()
          : this.multiLineResultTitle,
      multiLineCursorIndex: multiLineCursorIndex ?? this.multiLineCursorIndex,
      activeStatModel: activeStatModel ?? this.activeStatModel,
      activeDistribution: activeDistribution ?? this.activeDistribution,
      spreadsheet: spreadsheet ?? this.spreadsheet,
      activeMathBoxTool: activeMathBoxTool ?? this.activeMathBoxTool,
      activeInequalitySign: activeInequalitySign ?? this.activeInequalitySign,
      activeRatioType: activeRatioType ?? this.activeRatioType,
      rootMathNode: rootMathNode ?? this.rootMathNode,
      activeContainerId: activeContainerId ?? this.activeContainerId,
      activeChildIndex: activeChildIndex ?? this.activeChildIndex,
      inputTokens: inputTokens ?? this.inputTokens,
      cursorIndex: cursorIndex ?? this.cursorIndex,
      selectionRange: selectionRange ?? this.selectionRange,
      resultText: resultText ?? this.resultText,
      isResultDisplayed: isResultDisplayed ?? this.isResultDisplayed,
      isShowingExactForm: isShowingExactForm ?? this.isShowingExactForm,
      alternateResultText: alternateResultText != null
          ? alternateResultText()
          : this.alternateResultText,
      history: history ?? this.history,
      historyCursor: historyCursor ?? this.historyCursor,
      variables: variables ?? this.variables,
      activeOverlay: activeOverlay ?? this.activeOverlay,
      overlayCursorIndex: overlayCursorIndex ?? this.overlayCursorIndex,
      menuBreadcrumbs: menuBreadcrumbs ?? this.menuBreadcrumbs,
      errorMessage:
          errorMessage != null ? errorMessage() : this.errorMessage,
      showPixelGrid: showPixelGrid ?? this.showPixelGrid,
      lcdContrast: lcdContrast ?? this.lcdContrast,
      lcdInverted: lcdInverted ?? this.lcdInverted,
      qrVersion: qrVersion ?? this.qrVersion,
      keyClickSoundOn: keyClickSoundOn ?? this.keyClickSoundOn,
      hapticFeedbackOn: hapticFeedbackOn ?? this.hapticFeedbackOn,
      statFreqOn: statFreqOn ?? this.statFreqOn,
      decimalMarkComma: decimalMarkComma ?? this.decimalMarkComma,
      digitSeparatorOn: digitSeparatorOn ?? this.digitSeparatorOn,
      smallMultiLineFont: smallMultiLineFont ?? this.smallMultiLineFont,
      autoPowerOffMinutes: autoPowerOffMinutes ?? this.autoPowerOffMinutes,
      activeQrMatrix:
          activeQrMatrix != null ? activeQrMatrix() : this.activeQrMatrix,
      isPoweredOn: isPoweredOn ?? this.isPoweredOn,
    );
  }
}
