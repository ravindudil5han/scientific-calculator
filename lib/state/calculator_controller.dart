import 'package:flutter/widgets.dart';
import '../app_modules/algebraic_solvers_engine.dart';
import '../app_modules/complex_basen_engine.dart';
import '../app_modules/linear_algebra_engine.dart';
import '../app_modules/statistics_distribution_engine.dart';
import '../app_modules/table_spreadsheet_mathbox_engine.dart';
import '../display_engine/qr_code_generator.dart';
import '../display_engine/lcd_grid_table_renderer.dart';
import '../display_engine/math_editor_engine.dart';
import '../display_engine/math_nodes.dart';
import '../math_engine/calculator_decimal.dart';
import '../math_engine/math_expression_evaluator.dart';
import '../navigation/cw_menu_tree.dart';
import 'calculator_models.dart';
import 'calculator_persistence.dart';
import 'calculator_state.dart';

/// Master state machine, 2D Natural Textbook AST controller, hierarchical
/// menu navigator, specialized app router, and keypad event dispatcher
/// for the Cal_ 1100_DB_.
class CalculatorController extends ChangeNotifier {
  final MathEditorEngine _editor = MathEditorEngine();
  late CalculatorState _state;
  Cal_EvaluationResult? _lastEvalResult;
  ComplexNumber? _lastComplexResult;
  int? _lastBaseNResult;

  // Backing data buffers for interactive grid editors
  String _editingMatrixName = 'MatA';
  String _editingVectorName = 'VctA';
  String _cellInputBuffer = '';
  bool _isEquationPolynomial = false;
  int _equationSimulUnknowns = 2;
  int _equationPolyDegree = 2;
  int _inequalityDegree = 2;
  List<List<double>> _simulMatrix = [
    [1, 1, 2],
    [1, -1, 0],
  ];
  List<double> _polyCoeffs = [1, -3, 2];
  List<double> _ineqCoeffs = [1, -1, -6];
  List<double> _ratioCoeffs = [2, 3, 6]; // A, B, D (or C)
  List<double> _statX = [1, 2, 3, 4, 5];
  List<double> _statY = [2, 4, 6, 8, 10];
  List<double> _statFreq = [1, 1, 1, 1, 1];
  double _tableStart = 1;
  double _tableEnd = 5;
  double _tableStep = 1;
  List<TableRowEntry> _tableRows = const [];

  CalculatorController() {
    _state = CalculatorState(
      rootMathNode: _editor.clone().root,
      activeContainerId: _editor.activeContainerId,
      activeChildIndex: _editor.childIndex,
      matrices: {
        'MatA': Cal_Matrix.zeros(2, 2),
        'MatB': Cal_Matrix.zeros(2, 2),
        'MatC': Cal_Matrix.zeros(2, 2),
        'MatD': Cal_Matrix.zeros(2, 2),
      },
      vectors: {
        'VctA': Cal_Vector.zeros(3),
        'VctB': Cal_Vector.zeros(3),
        'VctC': Cal_Vector.zeros(3),
        'VctD': Cal_Vector.zeros(3),
      },
    );
  }

  CalculatorState get state => _state;
  MathEditorEngine get editor => _editor;
  Cal_EvaluationResult? get lastEvalResult => _lastEvalResult;

  void _emit(CalculatorState nextState) {
    _state = nextState;
    CalculatorPersistenceStore.saveState(nextState);
    notifyListeners();
  }

  /// Explicitly persists the current calculator state to local storage.
  Future<void> saveToPersistentStorage() async {
    CalculatorPersistenceStore.saveState(_state);
  }

  /// Restores saved registers, settings, defined functions, active input buffer,
  /// and calculation history from persistent storage.
  Future<bool> restoreFromPersistentStorage() async {
    final snap = CalculatorPersistenceStore.loadRawSnapshot();
    if (snap == null) return false;
    final restored = CalculatorPersistenceStore.restoreIntoState(_state, snap);
    _editor.clear();
    for (final tok in restored.inputTokens) {
      _editor.insertChar(tok.display, evalText: tok.evalText);
    }
    final clonedEditor = _editor.clone();
    _state = restored.copyWith(
      rootMathNode: clonedEditor.root,
      activeContainerId: clonedEditor.activeContainerId,
      activeChildIndex: clonedEditor.childIndex,
      cursorIndex: clonedEditor.childIndex,
    );
    notifyListeners();
    return true;
  }

  /// Synchronizes the current [_editor] 2D AST and spatial cursor into [_state].
  void _syncEditorToState({
    bool? isResultDisplayed,
    String? resultText,
    String? Function()? alternateResultText,
    bool? isShowingExactForm,
    OutputFormatView? activeFormatView,
    int? engStepShift,
    int? historyCursor,
    List<CalculationHistoryEntry>? history,
    Map<String, String>? variables,
    ActiveOverlay? activeOverlay,
    List<MenuBreadcrumbLevel>? menuBreadcrumbs,
    String? Function()? definingPromptTarget,
    bool? hasFunctionDefined,
    String? definedFunctionF,
    String? definedFunctionG,
    String? Function()? errorMessage,
  }) {
    final clonedEditor = _editor.clone();
    final flatTokens = _flattenRootTokens(clonedEditor.root);

    _emit(
      _state.copyWith(
        rootMathNode: clonedEditor.root,
        activeContainerId: clonedEditor.activeContainerId,
        activeChildIndex: clonedEditor.childIndex,
        inputTokens: flatTokens,
        cursorIndex: clonedEditor.childIndex,
        selectionRange: CursorSelectionRange(
          clonedEditor.childIndex,
          clonedEditor.childIndex,
        ),
        isResultDisplayed: isResultDisplayed ?? false,
        resultText: resultText,
        alternateResultText: alternateResultText,
        isShowingExactForm: isShowingExactForm,
        activeFormatView: activeFormatView,
        engStepShift: engStepShift,
        historyCursor: historyCursor ?? -1,
        history: history,
        variables: variables,
        activeOverlay: activeOverlay,
        menuBreadcrumbs: menuBreadcrumbs,
        definingPromptTarget: definingPromptTarget,
        hasFunctionDefined: hasFunctionDefined,
        definedFunctionF: definedFunctionF,
        definedFunctionG: definedFunctionG,
        errorMessage: errorMessage,
        isShift: false,
        isAlpha: false,
      ),
    );
  }

  List<InputToken> _flattenRootTokens(MathContainerNode root) {
    return root.children
        .map(
          (n) => InputToken(
            display: n.toDisplayString(),
            evalText: _safeEvalPreview(n),
          ),
        )
        .toList();
  }

  String _safeEvalPreview(MathNode node) {
    try {
      return node.toEvalString();
    } catch (_) {
      return node.toDisplayString();
    }
  }

  /// Triggers physical-style low-latency tactile & audio feedback on key down.
  void triggerKeyHaptic({bool heavy = false}) {
    Cal_HardwareFeedback.triggerKeyPress(
      hapticEnabled: _state.hapticFeedbackOn,
      soundEnabled: _state.keyClickSoundOn,
      isHeavyAction: heavy,
    );
  }

  /// Assigns a value directly to a variable register (`A`–`F`, `x`, `y`, `z`, `Ans`, `PreAns`).
  void storeVariable(String registerName, String value) {
    final updated = Map<String, String>.from(_state.variables);
    updated[registerName] = value;
    _emit(_state.copyWith(variables: updated));
  }

  /// Sets the active angle unit (`Degree`, `Radian`, `Gradian`).
  void setAngleUnit(AngleUnit unit) {
    _emit(_state.copyWith(angleUnit: unit));
  }

  /// Defines user algebraic function `f(x)` or `g(x)` directly.
  void defineUserFunction(String fnName, String expression) {
    final bool isF = fnName.toLowerCase() == 'f';
    final nextF = isF ? expression : _state.definedFunctionF;
    final nextG = !isF ? expression : _state.definedFunctionG;
    _emit(
      _state.copyWith(
        definedFunctionF: nextF,
        definedFunctionG: nextG,
        hasFunctionDefined: nextF.isNotEmpty || nextG.isNotEmpty,
      ),
    );
  }

  /// Evaluates a raw expression string using the current calculator state settings,
  /// variable registers, and user-defined functions `f(x)` / `g(x)`.
  Cal_EvaluationResult evaluateExpressionString(
    String expression, {
    bool forceDecimal = false,
  }) {
    return MathExpressionEvaluator(
      angleUnit: _state.angleUnit,
      numberFormat: _state.numberFormat,
      formatDigits: _state.formatDigits,
      variables: _state.variables,
      definedFunctionF: _state.definedFunctionF,
      definedFunctionG: _state.definedFunctionG,
    ).evaluateString(expression, forceDecimal: forceDecimal);
  }

  // ===========================================================================
  // Phase 5 Specialized App Direct APIs & Mode Router
  // ===========================================================================

  /// Switches directly to any of the 13 ClassWiz `AppMode` applications.
  void selectAppMode(AppMode mode) {
    _initializeAppMode(mode);
  }

  /// Assigns a `Cal_Matrix` to register `name` (`MatA`, `MatB`, `MatC`, `MatD`).
  void setMatrix(String name, Cal_Matrix matrix) {
    final updated = Map<String, Cal_Matrix>.from(_state.matrices);
    updated[name] = matrix;
    _emit(_state.copyWith(matrices: updated));
  }

  /// Assigns a `Cal_Vector` to register `name` (`VctA`, `VctB`, `VctC`, `VctD`).
  void setVector(String name, Cal_Vector vector) {
    final updated = Map<String, Cal_Vector>.from(_state.vectors);
    updated[name] = vector;
    _emit(_state.copyWith(vectors: updated));
  }

  /// Sets the active `NumberBase` (`DEC`, `HEX`, `BIN`, `OCT`) in `Base-N` mode,
  /// converting any currently displayed Base-N result to the new radix.
  void setBaseNRadix(NumberBase base) {
    String nextResult = _state.resultText;
    if (_state.activeMode == AppMode.baseN &&
        _state.isResultDisplayed &&
        _lastBaseNResult != null) {
      nextResult = BaseNEngine.formatInBase(_lastBaseNResult!, base);
    }
    _emit(
      _state.copyWith(
        activeBase: base,
        resultText: nextResult,
      ),
    );
  }

  /// Solves a simultaneous linear equation system ($n \in \{2, 3, 4\}$ unknowns)
  /// and displays the solutions on the LCD.
  SimulEquationResult solveSimultaneousEquations(
    List<List<double>> augmentedMatrix,
  ) {
    _isEquationPolynomial = false;
    _equationSimulUnknowns = augmentedMatrix.length;
    _simulMatrix = augmentedMatrix
        .map((r) => List<double>.from(r))
        .toList();
    final res = SimulEquationSolver.solve(augmentedMatrix);
    _emit(
      _state.copyWith(
        activeMode: AppMode.equation,
        activeOverlay: ActiveOverlay.none,
        menuBreadcrumbs: const [],
        activeGridModel: () => null,
        multiLineResultTitle: () => 'Simul ($_equationSimulUnknowns Unknowns)',
        multiLineResultLines: () => res.displayLines,
        multiLineCursorIndex: 0,
        resultText: res.statusMessage ?? res.displayLines.join(', '),
        isResultDisplayed: true,
      ),
    );
    return res;
  }

  /// Solves a polynomial equation of degree 2, 3, or 4 and displays all roots & extrema.
  PolynomialSolveResult solvePolynomialEquation(List<double> coefficients) {
    _isEquationPolynomial = true;
    _equationPolyDegree = coefficients.length - 1;
    _polyCoeffs = List<double>.from(coefficients);
    final res = PolynomialSolver.solve(coefficients);
    if (res.error != null) {
      _emit(
        _state.copyWith(
          activeMode: AppMode.equation,
          activeOverlay: ActiveOverlay.none,
          menuBreadcrumbs: const [],
          errorMessage: () => res.error,
        ),
      );
      return res;
    }
    _emit(
      _state.copyWith(
        activeMode: AppMode.equation,
        activeOverlay: ActiveOverlay.none,
        menuBreadcrumbs: const [],
        activeGridModel: () => null,
        multiLineResultTitle: () => 'Polynomial (Deg $_equationPolyDegree)',
        multiLineResultLines: () => res.displayLines,
        multiLineCursorIndex: 0,
        resultText: res.displayLines.first,
        isResultDisplayed: true,
      ),
    );
    return res;
  }

  /// Solves a polynomial inequality ($P(x) > 0, < 0, \ge 0, \le 0$) and displays the interval.
  String solveInequality({
    required List<double> coefficients,
    required InequalitySign sign,
  }) {
    _inequalityDegree = coefficients.length - 1;
    _ineqCoeffs = List<double>.from(coefficients);
    final intervalStr = InequalitySolver.solve(
      coefficients: coefficients,
      sign: sign,
    );
    if (intervalStr == 'Math ERROR' || intervalStr == 'Argument ERROR') {
      _emit(
        _state.copyWith(
          activeMode: AppMode.inequality,
          activeOverlay: ActiveOverlay.none,
          menuBreadcrumbs: const [],
          errorMessage: () => intervalStr,
        ),
      );
      return intervalStr;
    }
    _emit(
      _state.copyWith(
        activeMode: AppMode.inequality,
        activeOverlay: ActiveOverlay.none,
        menuBreadcrumbs: const [],
        activeInequalitySign: sign,
        activeGridModel: () => null,
        multiLineResultTitle: () =>
            'Inequality (Deg $_inequalityDegree, ${sign.symbol} 0)',
        multiLineResultLines: () => [intervalStr],
        multiLineCursorIndex: 0,
        resultText: intervalStr,
        isResultDisplayed: true,
      ),
    );
    return intervalStr;
  }

  /// Solves a proportion in the `Ratio` app (`A : B = X : D` or `A : B = C : X`).
  String solveRatio({
    required RatioTemplateType type,
    required double a,
    required double b,
    required double cOrD,
  }) {
    _ratioCoeffs = [a, b, cOrD];
    final res = RatioSolver.solve(type: type, a: a, b: b, cOrD: cOrD);
    if (res == 'Math ERROR') {
      _emit(
        _state.copyWith(
          activeMode: AppMode.ratio,
          activeOverlay: ActiveOverlay.none,
          menuBreadcrumbs: const [],
          errorMessage: () => 'Math ERROR',
        ),
      );
      return res;
    }
    _emit(
      _state.copyWith(
        activeMode: AppMode.ratio,
        activeOverlay: ActiveOverlay.none,
        menuBreadcrumbs: const [],
        activeRatioType: type,
        activeGridModel: () => null,
        multiLineResultTitle: () => type.label,
        multiLineResultLines: () => [res],
        multiLineCursorIndex: 0,
        resultText: res,
        isResultDisplayed: true,
      ),
    );
    return res;
  }

  Map<String, String> _buildUpdatedStatVariables({
    OneVarStatsResult? oneVar,
    TwoVarStatsResult? twoVar,
  }) {
    final updated = Map<String, String>.from(_state.variables);
    if (oneVar != null) {
      updated['x̄'] = formatCal_Scalar(oneVar.meanX);
      updated['Σx'] = formatCal_Scalar(oneVar.sumX);
      updated['Σx²'] = formatCal_Scalar(oneVar.sumX2);
      updated['σx'] = formatCal_Scalar(oneVar.popStdDevX);
      updated['sx'] = formatCal_Scalar(oneVar.sampleStdDevX);
      updated['n'] = formatCal_Scalar(oneVar.countN);
      updated['min(x)'] = formatCal_Scalar(oneVar.minX);
      updated['Q₁'] = formatCal_Scalar(oneVar.q1);
      updated['Q1'] = formatCal_Scalar(oneVar.q1);
      updated['Med'] = formatCal_Scalar(oneVar.median);
      updated['Q₃'] = formatCal_Scalar(oneVar.q3);
      updated['Q3'] = formatCal_Scalar(oneVar.q3);
      updated['max(x)'] = formatCal_Scalar(oneVar.maxX);
    }
    if (twoVar != null) {
      final xv = twoVar.xStats;
      updated['x̄'] = formatCal_Scalar(xv.meanX);
      updated['Σx'] = formatCal_Scalar(xv.sumX);
      updated['Σx²'] = formatCal_Scalar(xv.sumX2);
      updated['σx'] = formatCal_Scalar(xv.popStdDevX);
      updated['sx'] = formatCal_Scalar(xv.sampleStdDevX);
      updated['n'] = formatCal_Scalar(xv.countN);
      updated['min(x)'] = formatCal_Scalar(xv.minX);
      updated['max(x)'] = formatCal_Scalar(xv.maxX);
      updated['ȳ'] = formatCal_Scalar(twoVar.meanY);
      updated['Σy'] = formatCal_Scalar(twoVar.sumY);
      updated['Σy²'] = formatCal_Scalar(twoVar.sumY2);
      updated['σy'] = formatCal_Scalar(twoVar.popStdDevY);
      updated['sy'] = formatCal_Scalar(twoVar.sampleStdDevY);
      updated['Σxy'] = formatCal_Scalar(twoVar.sumXY);
      updated['Σx³'] = formatCal_Scalar(twoVar.sumX3);
      updated['Σx⁴'] = formatCal_Scalar(twoVar.sumX4);
      updated['Σx²y'] = formatCal_Scalar(twoVar.sumX2Y);
      updated['a'] = formatCal_Scalar(twoVar.coeffA);
      updated['b'] = formatCal_Scalar(twoVar.coeffB);
      if (twoVar.coeffC != null) {
        updated['c'] = formatCal_Scalar(twoVar.coeffC!);
      }
      if (twoVar.corrR != null) {
        updated['r'] = formatCal_Scalar(twoVar.corrR!);
      }
    }
    return updated;
  }

  /// Computes 1-Variable (`1-VAR`) statistics and displays summary lines on the LCD.
  OneVarStatsResult computeOneVarStatistics(
    List<double> xValues, {
    List<double>? frequencies,
  }) {
    _statX = List<double>.from(xValues);
    if (frequencies != null) {
      _statFreq = List<double>.from(frequencies);
    } else {
      _statFreq = List.filled(xValues.length, 1.0);
    }
    final res = StatisticsEngine.computeOneVar(
      xValues,
      frequencies: frequencies,
    );
    final updatedVars = _buildUpdatedStatVariables(oneVar: res);
    _emit(
      _state.copyWith(
        activeMode: AppMode.statistics,
        activeOverlay: ActiveOverlay.none,
        menuBreadcrumbs: const [],
        activeStatModel: StatModelType.oneVar,
        variables: updatedVars,
        activeGridModel: () => null,
        multiLineResultTitle: () => '1-Var Results',
        multiLineResultLines: () => res.displayLines,
        multiLineCursorIndex: 0,
        resultText: res.displayLines.first,
        isResultDisplayed: true,
      ),
    );
    return res;
  }

  /// Computes 2-Variable (`2-VAR`) regression statistics and displays summary lines.
  TwoVarStatsResult computeTwoVarStatistics({
    required StatModelType model,
    required List<double> xValues,
    required List<double> yValues,
  }) {
    _statX = List<double>.from(xValues);
    _statY = List<double>.from(yValues);
    final res = StatisticsEngine.computeTwoVar(
      model: model,
      xValues: xValues,
      yValues: yValues,
    );
    final updatedVars = _buildUpdatedStatVariables(twoVar: res);
    _emit(
      _state.copyWith(
        activeMode: AppMode.statistics,
        activeOverlay: ActiveOverlay.none,
        menuBreadcrumbs: const [],
        activeStatModel: model,
        variables: updatedVars,
        activeGridModel: () => null,
        multiLineResultTitle: () => '2-Var / Reg (${model.label})',
        multiLineResultLines: () => res.twoVarSummaryLines,
        multiLineCursorIndex: 0,
        resultText: res.regressionDisplayLines.join(', '),
        isResultDisplayed: true,
      ),
    );
    return res;
  }

  /// Evaluates a `Distribution` calculation (`Normal PD/CD`, `Inverse Normal`,
  /// `Binomial PD/CD`, `Poisson PD/CD`) and surfaces `Range ERROR` if any
  /// parameter is out of bounds.
  void evaluateDistribution({
    required DistributionType type,
    required List<double> params,
  }) {
    _isDistributionListMode = false;
    _resetDistributionParams(type);
    for (int i = 0; i < params.length && i < _distParams.length; i++) {
      _distParams[i] = (_distParams[i].$1, params[i]);
    }
    _state = _state.copyWith(
      activeMode: AppMode.distribution,
      activeOverlay: ActiveOverlay.none,
      menuBreadcrumbs: const [],
      activeDistribution: type,
      errorMessage: () => null,
    );
    _evaluateActiveDistribution();
  }

  /// Generates the dual-function `Table` for $f(x)$ and $g(x)$ over `[start, end]` with `step`.
  List<TableRowEntry> generateFunctionTable({
    required double start,
    required double end,
    required double step,
  }) {
    _tableStart = start;
    _tableEnd = end;
    _tableStep = step;
    final String fExpr = _state.definedFunctionF.isNotEmpty
        ? _state.definedFunctionF
        : 'x^2';
    final res = TableAppEngine.generateTable(
      definedF: fExpr,
      definedG: _state.definedFunctionG,
      start: start,
      end: end,
      step: step,
      angleUnit: _state.angleUnit,
      variables: _state.variables,
    );
    if (res.error != null) {
      _emit(_state.copyWith(errorMessage: () => res.error));
      return const [];
    }
    _tableRows = res.rows;
    final grid = _buildTableGridModel(activeRow: 0, activeCol: 0);
    _emit(
      _state.copyWith(
        activeMode: AppMode.table,
        activeOverlay: ActiveOverlay.none,
        menuBreadcrumbs: const [],
        activeGridModel: () => grid,
        multiLineResultLines: () => null,
      ),
    );
    return _tableRows;
  }

  /// Sets a cell formula or value in the $5 \times 45$ `Spreadsheet` and recalculates.
  void setSpreadsheetCell(int row, int col, String formulaOrValue) {
    final nextSheet = _state.spreadsheet.setCell(row, col, formulaOrValue);
    final grid = _buildSpreadsheetGridModel(
      nextSheet,
      activeRow: row,
      activeCol: col,
    );
    _emit(
      _state.copyWith(
        activeMode: AppMode.spreadsheet,
        activeOverlay: ActiveOverlay.none,
        menuBreadcrumbs: const [],
        spreadsheet: nextSheet,
        activeGridModel: () => grid,
      ),
    );
  }

  void _initializeAppMode(AppMode mode, {bool showStartupMenu = false}) {
    _editor.clear();
    _cellInputBuffer = '';
    _isDistributionListMode = false;

    LcdGridTableModel? initialGrid;
    List<String>? initialLines;
    String? initialTitle;

    switch (mode) {
      case AppMode.calculate:
      case AppMode.complex:
      case AppMode.baseN:
      case AppMode.matrix:
      case AppMode.vector:
        // Starts on the mode's expression calculation canvas
        break;
      case AppMode.statistics:
        initialGrid = _buildStatisticsGridModel(
          _state.activeStatModel,
          activeRow: 0,
          activeCol: 0,
        );
        break;
      case AppMode.distribution:
        initialGrid = _buildDistributionGridModel(
          _state.activeDistribution,
          activeRow: 0,
        );
        break;
      case AppMode.table:
        final String fExpr = _state.definedFunctionF.isNotEmpty
            ? _state.definedFunctionF
            : 'x^2';
        final tbl = TableAppEngine.generateTable(
          definedF: fExpr,
          definedG: _state.definedFunctionG,
          start: _tableStart,
          end: _tableEnd,
          step: _tableStep,
          angleUnit: _state.angleUnit,
          variables: _state.variables,
        );
        _tableRows = tbl.rows;
        initialGrid = _buildTableGridModel(activeRow: 0, activeCol: 0);
        break;
      case AppMode.spreadsheet:
        initialGrid = _buildSpreadsheetGridModel(
          _state.spreadsheet,
          activeRow: 0,
          activeCol: 0,
        );
        break;
      case AppMode.equation:
        initialGrid = _buildEquationGridModel(activeRow: 0, activeCol: 0);
        break;
      case AppMode.inequality:
        initialGrid = _buildInequalityGridModel(activeCol: 0);
        break;
      case AppMode.ratio:
        initialGrid = _buildRatioGridModel(activeCol: 0);
        break;
      case AppMode.mathBox:
        final sim = MathBoxEngine.runDiceRoll(
          diceCount: 2,
          attempts: 50,
          seed: 991,
        );
        initialTitle = 'Dice Roll (2 Dice, N=50)';
        initialLines = sim.summaryLines;
        break;
    }

    final MenuBreadcrumbLevel? startupMenu =
        showStartupMenu ? CwMenuTreeBuilder.buildAppStartupMenu(mode) : null;

    _emit(
      _state.copyWith(
        activeMode: mode,
        activeOverlay: ActiveOverlay.none,
        menuBreadcrumbs: startupMenu != null ? [startupMenu] : const [],
        overlayCursorIndex: 0,
        definingPromptTarget: () => null,
        activeGridModel: () => initialGrid,
        multiLineResultTitle: () => initialTitle,
        multiLineResultLines: () => initialLines,
        multiLineCursorIndex: 0,
        rootMathNode: _editor.clone().root,
        activeContainerId: _editor.activeContainerId,
        activeChildIndex: 0,
        inputTokens: const [],
        cursorIndex: 0,
        resultText: '',
        isResultDisplayed: false,
        isShift: false,
        isAlpha: false,
      ),
    );
  }

  // ===========================================================================
  // Grid Model Builders for Specialized Apps
  // ===========================================================================

  LcdGridTableModel _buildMatrixGridModel(
    String matName,
    Cal_Matrix mat, {
    required int activeRow,
    required int activeCol,
  }) {
    final int r = activeRow.clamp(0, mat.rows - 1);
    final int c = activeCol.clamp(0, mat.cols - 1);
    final String cellCoord = '$matName[${r + 1},${c + 1}]';
    final String currentVal = _cellInputBuffer.isNotEmpty
        ? _cellInputBuffer
        : formatCal_Scalar(mat.get(r, c));
    return LcdGridTableModel(
      title: matName,
      columnHeaders: List.generate(mat.cols, (i) => '${i + 1}'),
      rowHeaders: List.generate(mat.rows, (i) => '${i + 1}'),
      cells: List.generate(
        mat.rows,
        (ri) => List.generate(
          mat.cols,
          (ci) => formatCal_Scalar(mat.get(ri, ci)),
        ),
      ),
      activeRow: r,
      activeCol: c,
      bottomInputBarText: '$cellCoord = $currentVal',
      isEditingCell: _cellInputBuffer.isNotEmpty,
    );
  }

  LcdGridTableModel _buildVectorGridModel(
    String vctName,
    Cal_Vector vct, {
    required int activeRow,
  }) {
    final int r = activeRow.clamp(0, vct.dimension - 1);
    final String currentVal = _cellInputBuffer.isNotEmpty
        ? _cellInputBuffer
        : formatCal_Scalar(vct.components[r]);
    return LcdGridTableModel(
      title: vctName,
      columnHeaders: [vctName],
      rowHeaders: List.generate(vct.dimension, (i) => '${i + 1}'),
      cells: List.generate(
        vct.dimension,
        (ri) => [formatCal_Scalar(vct.components[ri])],
      ),
      activeRow: r,
      activeCol: 0,
      bottomInputBarText: '$vctName[${r + 1}] = $currentVal',
      isEditingCell: _cellInputBuffer.isNotEmpty,
    );
  }

  LcdGridTableModel _buildStatisticsGridModel(
    StatModelType model, {
    required int activeRow,
    required int activeCol,
  }) {
    final int rows = _statX.length;
    final int r = activeRow.clamp(0, rows - 1);
    final int c = activeCol.clamp(0, 1);
    final List<String> colHeaders =
        model.isTwoVar ? ['x', 'y'] : ['x', 'Freq'];
    final List<List<String>> cells = List.generate(rows, (ri) {
      final String col0 = formatCal_Scalar(_statX[ri]);
      final String col1 = model.isTwoVar
          ? formatCal_Scalar(ri < _statY.length ? _statY[ri] : 0.0)
          : formatCal_Scalar(ri < _statFreq.length ? _statFreq[ri] : 1.0);
      return [col0, col1];
    });
    final String currentVal = _cellInputBuffer.isNotEmpty
        ? _cellInputBuffer
        : cells[r][c];
    return LcdGridTableModel(
      title: 'STAT',
      columnHeaders: colHeaders,
      rowHeaders: List.generate(rows, (i) => '${i + 1}'),
      cells: cells,
      activeRow: r,
      activeCol: c,
      bottomInputBarText: '${colHeaders[c]}[${r + 1}] = $currentVal',
      isEditingCell: _cellInputBuffer.isNotEmpty,
    );
  }

  bool _isDistributionListMode = false;
  final List<double> _distListX = [0.0, 1.0, 2.0, 3.0, 4.0];

  List<(String, double)> _distParams = [
    ('x', 0.0),
    ('σ', 1.0),
    ('μ', 0.0),
  ];

  double _computeDistProbForX(DistributionType dist, double xVal) {
    try {
      return switch (dist) {
        DistributionType.normalPd => DistributionEngine.normalPd(
            x: xVal,
            sigma: _distParams.length > 1 ? _distParams[1].$2 : 1.0,
            mu: _distParams.length > 2 ? _distParams[2].$2 : 0.0,
          ),
        DistributionType.binomialPd => DistributionEngine.binomialPd(
            x: xVal.round(),
            n: (_distParams.length > 1 ? _distParams[1].$2 : 5.0).round(),
            p: _distParams.length > 2 ? _distParams[2].$2 : 0.5,
          ),
        DistributionType.binomialCd => DistributionEngine.binomialCd(
            x: xVal.round(),
            n: (_distParams.length > 1 ? _distParams[1].$2 : 5.0).round(),
            p: _distParams.length > 2 ? _distParams[2].$2 : 0.5,
          ),
        DistributionType.poissonPd => DistributionEngine.poissonPd(
            x: xVal.round(),
            lambda: _distParams.length > 1 ? _distParams[1].$2 : 3.0,
          ),
        DistributionType.poissonCd => DistributionEngine.poissonCd(
            x: xVal.round(),
            lambda: _distParams.length > 1 ? _distParams[1].$2 : 3.0,
          ),
        _ => 0.0,
      };
    } catch (_) {
      return 0.0;
    }
  }

  LcdGridTableModel _buildDistributionGridModel(
    DistributionType dist, {
    required int activeRow,
    int activeCol = 0,
  }) {
    if (_distParams.isEmpty) {
      _resetDistributionParams(dist);
    }
    if (_isDistributionListMode && dist.supportsListMode) {
      final int r = activeRow.clamp(0, _distListX.length - 1);
      final int c = activeCol.clamp(0, 1);
      final List<List<String>> cells = List.generate(_distListX.length, (ri) {
        final double xVal = _distListX[ri];
        final double pVal = _computeDistProbForX(dist, xVal);
        return [formatCal_Scalar(xVal), formatCal_Scalar(pVal)];
      });
      final String currentVal = _cellInputBuffer.isNotEmpty
          ? _cellInputBuffer
          : cells[r][c];
      return LcdGridTableModel(
        title: 'DIST',
        columnHeaders: const ['x', 'P'],
        rowHeaders: List.generate(_distListX.length, (i) => '${i + 1}'),
        cells: cells,
        activeRow: r,
        activeCol: c,
        bottomInputBarText: c == 0
            ? 'x[${r + 1}] = $currentVal'
            : 'P(x=${cells[r][0]}) = ${cells[r][1]}',
        isEditingCell: _cellInputBuffer.isNotEmpty,
      );
    }
    final int r = activeRow.clamp(0, _distParams.length - 1);
    final String currentVal = _cellInputBuffer.isNotEmpty
        ? _cellInputBuffer
        : formatCal_Scalar(_distParams[r].$2);
    return LcdGridTableModel(
      title: 'DIST',
      columnHeaders: [dist.label],
      rowHeaders: _distParams.map((p) => p.$1).toList(),
      cells: _distParams
          .map((p) => [formatCal_Scalar(p.$2)])
          .toList(),
      activeRow: r,
      activeCol: 0,
      bottomInputBarText: '${_distParams[r].$1} = $currentVal',
      isEditingCell: _cellInputBuffer.isNotEmpty,
    );
  }

  void _resetDistributionParams(DistributionType dist) {
    _distParams = switch (dist) {
      DistributionType.normalPd => [('x', 0.0), ('σ', 1.0), ('μ', 0.0)],
      DistributionType.normalCd => [
          ('Low', -1.96),
          ('Up', 1.96),
          ('σ', 1.0),
          ('μ', 0.0),
        ],
      DistributionType.inverseNormal => [
          ('Area', 0.975),
          ('σ', 1.0),
          ('μ', 0.0),
        ],
      DistributionType.binomialPd || DistributionType.binomialCd => [
          ('x', 2.0),
          ('N', 5.0),
          ('p', 0.5),
        ],
      DistributionType.poissonPd || DistributionType.poissonCd => [
          ('x', 2.0),
          ('λ', 3.0),
        ],
    };
  }

  LcdGridTableModel _buildTableGridModel({
    required int activeRow,
    required int activeCol,
  }) {
    final bool hasG = _state.definedFunctionG.trim().isNotEmpty;
    final List<String> colHeaders = hasG ? ['x', 'f(x)', 'g(x)'] : ['x', 'f(x)'];
    final int rows = _tableRows.isEmpty ? 1 : _tableRows.length;
    final int r = activeRow.clamp(0, rows - 1);
    final int c = activeCol.clamp(0, colHeaders.length - 1);

    final List<List<String>> cells = _tableRows.isEmpty
        ? [
            [for (int i = 0; i < colHeaders.length; i++) '0'],
          ]
        : _tableRows
            .map(
              (row) => [
                formatCal_Scalar(row.x),
                row.fxText,
                if (hasG) row.gxText ?? '0',
              ],
            )
            .toList();

    final String valStr = _cellInputBuffer.isNotEmpty
        ? _cellInputBuffer
        : cells[r][c];
    return LcdGridTableModel(
      title: 'TBL',
      columnHeaders: colHeaders,
      rowHeaders: List.generate(rows, (i) => '${i + 1}'),
      cells: cells,
      activeRow: r,
      activeCol: c,
      bottomInputBarText: '${colHeaders[c]}[${r + 1}] = $valStr',
      isEditingCell: _cellInputBuffer.isNotEmpty,
    );
  }

  LcdGridTableModel _buildSpreadsheetGridModel(
    SpreadsheetSheet sheet, {
    required int activeRow,
    required int activeCol,
  }) {
    final int r = activeRow.clamp(0, 14); // 15 visible rows in UI model
    final int c = activeCol.clamp(0, SpreadsheetSheet.numCols - 1);
    final String key = SpreadsheetSheet.cellKey(r, c);
    final String rawFormula = sheet.getRaw(r, c);
    final String dispVal = sheet.getDisplay(r, c);
    final String barVal = _cellInputBuffer.isNotEmpty
        ? _cellInputBuffer
        : (rawFormula.isNotEmpty ? rawFormula : dispVal);

    return LcdGridTableModel(
      title: 'SHT',
      columnHeaders: SpreadsheetSheet.colNames,
      rowHeaders: List.generate(15, (i) => '${i + 1}'),
      cells: List.generate(
        15,
        (ri) => List.generate(
          SpreadsheetSheet.numCols,
          (ci) => sheet.getDisplay(ri, ci),
        ),
      ),
      activeRow: r,
      activeCol: c,
      bottomInputBarText: '$key: $barVal',
      isEditingCell: _cellInputBuffer.isNotEmpty,
    );
  }

  LcdGridTableModel _buildEquationGridModel({
    required int activeRow,
    required int activeCol,
  }) {
    if (_isEquationPolynomial) {
      final int deg = _equationPolyDegree;
      final List<String> colHeaders = switch (deg) {
        2 => ['a(x²)', 'b(x)', 'c'],
        3 => ['a(x³)', 'b(x²)', 'c(x)', 'd'],
        _ => ['a(x⁴)', 'b(x³)', 'c(x²)', 'd(x)', 'e'],
      };
      final int c = activeCol.clamp(0, colHeaders.length - 1);
      final String valStr = _cellInputBuffer.isNotEmpty
          ? _cellInputBuffer
          : formatCal_Scalar(_polyCoeffs[c]);
      return LcdGridTableModel(
        title: 'POLY',
        columnHeaders: colHeaders,
        rowHeaders: const ['P(x)'],
        cells: [
          _polyCoeffs.map(formatCal_Scalar).toList(),
        ],
        activeRow: 0,
        activeCol: c,
        bottomInputBarText: '${colHeaders[c]} = $valStr',
        isEditingCell: _cellInputBuffer.isNotEmpty,
      );
    } else {
      final int n = _equationSimulUnknowns;
      final List<String> colHeaders = [
        for (int i = 0; i < n; i++) SimulEquationSolver.varNames[i],
        '=',
      ];
      final int r = activeRow.clamp(0, n - 1);
      final int c = activeCol.clamp(0, n);
      final String valStr = _cellInputBuffer.isNotEmpty
          ? _cellInputBuffer
          : formatCal_Scalar(_simulMatrix[r][c]);
      return LcdGridTableModel(
        title: 'SIML',
        columnHeaders: colHeaders,
        rowHeaders: List.generate(n, (i) => 'Eq${i + 1}'),
        cells: _simulMatrix
            .map((row) => row.map(formatCal_Scalar).toList())
            .toList(),
        activeRow: r,
        activeCol: c,
        bottomInputBarText: 'Eq${r + 1}[${colHeaders[c]}] = $valStr',
        isEditingCell: _cellInputBuffer.isNotEmpty,
      );
    }
  }

  LcdGridTableModel _buildInequalityGridModel({required int activeCol}) {
    final int deg = _inequalityDegree;
    final List<String> colHeaders = switch (deg) {
      2 => ['a(x²)', 'b(x)', 'c'],
      3 => ['a(x³)', 'b(x²)', 'c(x)', 'd'],
      _ => ['a(x⁴)', 'b(x³)', 'c(x²)', 'd(x)', 'e'],
    };
    final int c = activeCol.clamp(0, colHeaders.length - 1);
    final String valStr = _cellInputBuffer.isNotEmpty
        ? _cellInputBuffer
        : formatCal_Scalar(_ineqCoeffs[c]);
    return LcdGridTableModel(
      title: 'INEQ',
      columnHeaders: colHeaders,
      rowHeaders: ['${_state.activeInequalitySign.symbol}0'],
      cells: [
        _ineqCoeffs.map(formatCal_Scalar).toList(),
      ],
      activeRow: 0,
      activeCol: c,
      bottomInputBarText: '${colHeaders[c]} = $valStr',
      isEditingCell: _cellInputBuffer.isNotEmpty,
    );
  }

  LcdGridTableModel _buildRatioGridModel({required int activeCol}) {
    final bool isXD =
        _state.activeRatioType == RatioTemplateType.aToBEqualsXToD;
    final List<String> colHeaders = isXD ? ['A', 'B', 'D'] : ['A', 'B', 'C'];
    final int c = activeCol.clamp(0, 2);
    final String valStr = _cellInputBuffer.isNotEmpty
        ? _cellInputBuffer
        : formatCal_Scalar(_ratioCoeffs[c]);
    return LcdGridTableModel(
      title: 'RAT',
      columnHeaders: colHeaders,
      rowHeaders: [isXD ? 'X:D' : 'C:X'],
      cells: [
        _ratioCoeffs.map(formatCal_Scalar).toList(),
      ],
      activeRow: 0,
      activeCol: c,
      bottomInputBarText: '${colHeaders[c]} = $valStr',
      isEditingCell: _cellInputBuffer.isNotEmpty,
    );
  }

  // ===========================================================================
  // Hardware & System Toggles
  // ===========================================================================

  /// Toggles the 192×63 dot-matrix pixel grid & scanline texture overlay.
  void togglePixelGrid() {
    triggerKeyHaptic();
    _emit(_state.copyWith(showPixelGrid: !_state.showPixelGrid));
  }

  /// Cycles angle unit (D -> R -> G -> D).
  void cycleAngleUnit() {
    triggerKeyHaptic();
    final nextAngle = switch (_state.angleUnit) {
      AngleUnit.degree => AngleUnit.radian,
      AngleUnit.radian => AngleUnit.gradian,
      AngleUnit.gradian => AngleUnit.degree,
    };
    _emit(_state.copyWith(angleUnit: nextAngle));
  }

  /// Adjusts LCD contrast (0..15).
  void adjustContrast(int delta) {
    final nextContrast = (_state.lcdContrast + delta).clamp(0, 15);
    _emit(_state.copyWith(lcdContrast: nextContrast));
  }

  // ===========================================================================
  // Top System & Modifier Keys
  // ===========================================================================

  /// KEY-01: `SHIFT`
  void pressShift() {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();
    _emit(
      _state.copyWith(
        isShift: !_state.isShift,
        isAlpha: false,
      ),
    );
  }

  /// Toggles `ALPHA` / Variable modifier latch.
  void pressAlpha() {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();
    _emit(
      _state.copyWith(
        isAlpha: !_state.isAlpha,
        isShift: false,
      ),
    );
  }

  /// KEY-05: `ON`
  void pressOn() {
    triggerKeyHaptic(heavy: true);
    _editor.clear();
    _lastEvalResult = null;
    _cellInputBuffer = '';
    _emit(
      _state.copyWith(
        isPoweredOn: true,
        isShift: false,
        isAlpha: false,
        rootMathNode: _editor.clone().root,
        activeContainerId: _editor.activeContainerId,
        activeChildIndex: 0,
        inputTokens: const [],
        cursorIndex: 0,
        selectionRange: const CursorSelectionRange(0, 0),
        resultText: '',
        isResultDisplayed: false,
        activeFormatView: OutputFormatView.standard,
        engStepShift: 0,
        alternateResultText: () => null,
        definingPromptTarget: () => null,
        activeGridModel: () => null,
        multiLineResultLines: () => null,
        multiLineResultTitle: () => null,
        errorMessage: () => null,
        activeOverlay: ActiveOverlay.none,
        menuBreadcrumbs: const [],
        historyCursor: -1,
      ),
    );
  }

  /// KEY-04: `HOME`
  void pressHome() {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();
    if (_state.activeOverlay == ActiveOverlay.homeGrid) {
      _emit(
        _state.copyWith(
          activeOverlay: ActiveOverlay.none,
          menuBreadcrumbs: const [],
          isShift: false,
          isAlpha: false,
        ),
      );
      return;
    }
    final currentModeIndex = AppMode.values.indexOf(_state.activeMode);
    _emit(
      _state.copyWith(
        activeOverlay: ActiveOverlay.homeGrid,
        overlayCursorIndex: currentModeIndex,
        menuBreadcrumbs: const [],
        isShift: false,
        isAlpha: false,
        errorMessage: () => null,
      ),
    );
  }

  /// KEY-12: `BACK` (`🔙`) — Universal Breadcrumb Unwinder
  void pressBack() {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();

    if (_state.errorMessage != null) {
      _emit(_state.copyWith(errorMessage: () => null, isShift: false));
      return;
    }

    if (_state.activeOverlay != ActiveOverlay.none ||
        _state.menuBreadcrumbs.isNotEmpty) {
      // If inside a nested sub-menu, step back one directory level
      if (_state.menuBreadcrumbs.length > 1) {
        final poppedStack = _state.menuBreadcrumbs.sublist(
          0,
          _state.menuBreadcrumbs.length - 1,
        );
        _emit(
          _state.copyWith(
            menuBreadcrumbs: poppedStack,
            overlayCursorIndex: poppedStack.last.selectedIndex,
            isShift: false,
            isAlpha: false,
          ),
        );
        return;
      }

      if (_state.activeOverlay != ActiveOverlay.none) {
        // At the top level of a menu/drawer, close overlay and return to Math editor
        _emit(
          _state.copyWith(
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
            isShift: false,
            isAlpha: false,
          ),
        );
        return;
      }

      // At the top level of an App Startup Menu, pressing BACK returns to HOME grid
      pressHome();
      return;
    }

    // If viewing multi-line solver results in Equation, Inequality, Ratio, Statistics, Distribution, return to grid (or startup menu for Math Box)
    if (_state.multiLineResultLines != null) {
      _initializeAppMode(
        _state.activeMode,
        showStartupMenu: _state.activeMode == AppMode.mathBox,
      );
      return;
    }

    if (_state.definingPromptTarget != null) {
      final bool wasSolver =
          _state.definingPromptTarget == 'SOLVER_EQ' ||
          _state.definingPromptTarget == 'SOLVER_X';
      _editor.clear();
      if (wasSolver) {
        _initializeAppMode(AppMode.equation, showStartupMenu: true);
      } else {
        _syncEditorToState(
          definingPromptTarget: () => null,
          isResultDisplayed: false,
          resultText: '',
        );
      }
      return;
    }

    // If inside a specialized app's grid editor that has a startup type-selection menu, pressing BACK returns to the startup menu
    if (_state.activeGridModel != null) {
      final startupMenu =
          CwMenuTreeBuilder.buildAppStartupMenu(_state.activeMode);
      if (startupMenu != null) {
        _emit(
          _state.copyWith(
            menuBreadcrumbs: [startupMenu],
            overlayCursorIndex: 0,
            isShift: false,
            isAlpha: false,
          ),
        );
        return;
      }
    }

    if (_state.isResultDisplayed) {
      _editor.moveToRootEnd();
      _syncEditorToState(isResultDisplayed: false);
    }
  }

  /// KEY-02: `VARIABLE` (Shift: `=`)
  void pressVariable() {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();
    if (_state.isShift) {
      insertToken(const InputToken(display: '=', evalText: '='));
      return;
    }
    _toggleOverlayWithBreadcrumb(
      ActiveOverlay.variableMenu,
      CwMenuTreeBuilder.buildVariableDrawer(_state.variables),
    );
  }

  /// KEY-06: `FUNCTION` (`f(x)`)
  void pressFunction() {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();
    _toggleOverlayWithBreadcrumb(
      ActiveOverlay.functionMenu,
      CwMenuTreeBuilder.buildFunctionMenu(
        definedF: _state.definedFunctionF,
        definedG: _state.definedFunctionG,
      ),
    );
  }

  /// KEY-07: `CATALOG`
  void pressCatalog() {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();
    _toggleOverlayWithBreadcrumb(
      ActiveOverlay.catalogMenu,
      CwMenuTreeBuilder.buildCatalogRoot(
        _state.activeMode,
        isVerifyMode: _state.isVerifyMode,
      ),
    );
  }

  /// KEY-11: `TOOLS` (Shift: `SETTINGS`)
  void pressTools() {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();
    if (_state.isShift) {
      _toggleOverlayWithBreadcrumb(
        ActiveOverlay.settingsMenu,
        _buildSettingsRootForState(_state),
      );
      return;
    }
    _toggleOverlayWithBreadcrumb(
      ActiveOverlay.toolsMenu,
      CwMenuTreeBuilder.buildToolsMenu(
        activeMode: _state.activeMode,
        isVerifyMode: _state.isVerifyMode,
      ),
    );
  }

  /// Dedicated `SETTINGS` hardware button (Row 2, Col 1 on the 1100_DB_).
  void pressSettings() {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();
    _toggleOverlayWithBreadcrumb(
      ActiveOverlay.settingsMenu,
      _buildSettingsRootForState(_state),
    );
  }

  /// Dedicated Page Scroll Up (`︽`) rocker top half on the 1100_DB_.
  void pressPageUp() {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();
    if (_state.activeOverlay == ActiveOverlay.homeGrid) {
      final nextIdx = (_state.overlayCursorIndex - 6).clamp(
        0,
        AppMode.values.length - 1,
      );
      _emit(_state.copyWith(overlayCursorIndex: nextIdx, isShift: false));
      return;
    }
    if (_state.activeOverlay != ActiveOverlay.none ||
        _state.menuBreadcrumbs.isNotEmpty) {
      final level = _state.currentBreadcrumb;
      if (level != null && level.items.isNotEmpty) {
        final nextIdx = (level.selectedIndex - 4).clamp(
          0,
          level.items.length - 1,
        );
        final updatedStack = List<MenuBreadcrumbLevel>.from(
          _state.menuBreadcrumbs,
        );
        updatedStack[updatedStack.length - 1] = level.copyWith(
          selectedIndex: nextIdx,
        );
        _emit(
          _state.copyWith(
            menuBreadcrumbs: updatedStack,
            overlayCursorIndex: nextIdx,
            isShift: false,
          ),
        );
      }
      return;
    }
    pressCursorUp();
  }

  /// Dedicated Page Scroll Down (`︾`) rocker bottom half on the 1100_DB_.
  void pressPageDown() {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();
    if (_state.activeOverlay == ActiveOverlay.homeGrid) {
      final nextIdx = (_state.overlayCursorIndex + 6).clamp(
        0,
        AppMode.values.length - 1,
      );
      _emit(_state.copyWith(overlayCursorIndex: nextIdx, isShift: false));
      return;
    }
    if (_state.activeOverlay != ActiveOverlay.none ||
        _state.menuBreadcrumbs.isNotEmpty) {
      final level = _state.currentBreadcrumb;
      if (level != null && level.items.isNotEmpty) {
        final nextIdx = (level.selectedIndex + 4).clamp(
          0,
          level.items.length - 1,
        );
        final updatedStack = List<MenuBreadcrumbLevel>.from(
          _state.menuBreadcrumbs,
        );
        updatedStack[updatedStack.length - 1] = level.copyWith(
          selectedIndex: nextIdx,
        );
        _emit(
          _state.copyWith(
            menuBreadcrumbs: updatedStack,
            overlayCursorIndex: nextIdx,
            isShift: false,
          ),
        );
      }
      return;
    }
    pressCursorDown();
  }

  /// KEY-27: `FORMAT` (Shift: `S⇔D` quick toggle)
  void pressFormat() {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();

    // In Complex mode, FORMAT toggles Rectangular (a+bi) <-> Polar (r∠θ)
    if (_state.activeMode == AppMode.complex && _lastComplexResult != null) {
      final bool nextPolar = !_state.complexPolarDisplay;
      final String formatted = nextPolar
          ? _lastComplexResult!.toPolarString(_state.angleUnit)
          : _lastComplexResult!.toRectangularString();
      _emit(
        _state.copyWith(
          complexPolarDisplay: nextPolar,
          resultText: formatted,
          isResultDisplayed: true,
          isShift: false,
        ),
      );
      return;
    }

    // In Base-N mode, FORMAT cycles radix DEC -> HEX -> BIN -> OCT -> DEC
    if (_state.activeMode == AppMode.baseN) {
      final nextBase = switch (_state.activeBase) {
        NumberBase.dec => NumberBase.hex,
        NumberBase.hex => NumberBase.bin,
        NumberBase.bin => NumberBase.oct,
        NumberBase.oct => NumberBase.dec,
      };
      setBaseNRadix(nextBase);
      return;
    }

    if (_state.isShift) {
      _toggleStandardDecimalResult();
      return;
    }
    if ((_state.isResultDisplayed && _state.resultText.isNotEmpty) ||
        _lastEvalResult != null ||
        _state.activeOverlay == ActiveOverlay.formatMenu) {
      _toggleOverlayWithBreadcrumb(
        ActiveOverlay.formatMenu,
        CwMenuTreeBuilder.buildFormatMenu(),
      );
    } else {
      _toggleStandardDecimalResult();
    }
  }

  /// KEY-14 (Shift): `QR` — Encodes the active expression, result, and app mode
  /// into an ISO/IEC 18004 QR Code (Version 3 or Version 11) rendered on the LCD.
  void pressQrCode() {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();

    if (_state.activeOverlay == ActiveOverlay.qrCode) {
      _emit(
        _state.copyWith(
          activeOverlay: ActiveOverlay.none,
          activeQrMatrix: () => null,
          isShift: false,
          isAlpha: false,
        ),
      );
      return;
    }

    final expr = _state.expressionDisplayString;
    final res = _state.resultText;
    final url = Cal_QrCodeGenerator.buildClassWizUrl(
      modeName: _state.activeMode.title,
      expression: expr,
      result: res,
      version: _state.qrVersion,
    );
    final qrMatrix = Cal_QrCodeGenerator.encode(
      url,
      version: _state.qrVersion,
    );

    _emit(
      _state.copyWith(
        activeOverlay: ActiveOverlay.qrCode,
        activeQrMatrix: () => qrMatrix,
        menuBreadcrumbs: const [],
        isShift: false,
        isAlpha: false,
        errorMessage: () => null,
      ),
    );
  }

  /// Dynamic Engineering Notation (`ENG`) shifter:
  /// - Pressing `ENG` enters Engineering Notation or shifts exponent down by 3
  ///   ($10^3 \to 10^0 \to 10^{-3}$).
  /// - Pressing `Shift + ENG` shifts exponent up by 3
  ///   ($10^{-3} \to 10^0 \to 10^3$).
  void pressEng({bool? shift}) {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();

    final bool useShift = shift ?? _state.isShift;
    final last = _lastEvalResult;
    final Cal_Decimal? dec =
        last?.decimalValue ?? Cal_Decimal.tryParse(_state.resultText);
    if (dec == null) {
      _emit(_state.copyWith(isShift: false));
      return;
    }

    if (_state.activeFormatView != OutputFormatView.engineering) {
      final int initialShift = useShift ? 1 : 0;
      final String formatted = Cal_FormatConverter.formatEngineering(
        dec,
        stepShift: initialShift,
        useSiSymbols: _state.engSymbolOn,
      );
      _emit(
        _state.copyWith(
          activeOverlay: ActiveOverlay.none,
          menuBreadcrumbs: const [],
          activeFormatView: OutputFormatView.engineering,
          engStepShift: initialShift,
          resultText: formatted,
          isShowingExactForm: false,
          isResultDisplayed: true,
          isShift: false,
        ),
      );
      return;
    }

    // Pressing ENG shifts exponent down by 3 (-1 step); Shift+ENG shifts up by 3 (+1 step)
    _shiftEngineeringExponent(useShift ? 1 : -1);
  }

  MenuBreadcrumbLevel _buildSettingsRootForState(CalculatorState s) {
    return CwMenuTreeBuilder.buildSettingsRoot(
      ioMode: s.ioMode,
      angleUnit: s.angleUnit,
      numberFormat: s.numberFormat,
      formatDigits: s.formatDigits,
      engSymbolOn: s.engSymbolOn,
      fractionPref: s.fractionPreference,
      complexPolarDisplay: s.complexPolarDisplay,
      statFreqOn: s.statFreqOn,
      decimalMarkComma: s.decimalMarkComma,
      digitSeparatorOn: s.digitSeparatorOn,
      lcdContrast: s.lcdContrast,
      showPixelGrid: s.showPixelGrid,
      lcdInverted: s.lcdInverted,
      qrVersion: s.qrVersion,
      keyClickSoundOn: s.keyClickSoundOn,
      hapticFeedbackOn: s.hapticFeedbackOn,
      autoPowerOffMinutes: s.autoPowerOffMinutes,
      smallMultiLineFont: s.smallMultiLineFont,
    );
  }

  void _toggleOverlayWithBreadcrumb(
    ActiveOverlay target,
    MenuBreadcrumbLevel rootLevel,
  ) {
    if (_state.activeOverlay == target) {
      _emit(
        _state.copyWith(
          activeOverlay: ActiveOverlay.none,
          menuBreadcrumbs: const [],
          isShift: false,
          isAlpha: false,
        ),
      );
    } else {
      _emit(
        _state.copyWith(
          activeOverlay: target,
          overlayCursorIndex: rootLevel.selectedIndex,
          menuBreadcrumbs: [rootLevel],
          isShift: false,
          isAlpha: false,
          errorMessage: () => null,
        ),
      );
    }
  }

  void _toggleStandardDecimalResult() {
    if (_state.alternateResultText != null &&
        _state.alternateResultText!.isNotEmpty) {
      final current = _state.resultText;
      final alt = _state.alternateResultText!;
      final nextExact = !_state.isShowingExactForm;
      _emit(
        _state.copyWith(
          resultText: alt,
          alternateResultText: () => current,
          isShowingExactForm: nextExact,
          activeFormatView: nextExact
              ? OutputFormatView.standard
              : OutputFormatView.decimal,
          isShift: false,
        ),
      );
    } else {
      _emit(_state.copyWith(isShift: false));
    }
  }

  // ===========================================================================
  // 5-Way Sculpted D-Pad Spatial 2D Navigation (`▲`, `▼`, `◀`, `▶`, `OK`)
  // ===========================================================================

  /// KEY-08: `◀` (Spatial 2D Cursor Left / Breadcrumb Unwind / Grid Left / ENG Shift)
  void pressCursorLeft() {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();

    if (_state.errorMessage != null) {
      _emit(
        _state.copyWith(
          errorMessage: () => null,
          isResultDisplayed: false,
          isShift: false,
        ),
      );
      return;
    }

    if (_state.activeOverlay == ActiveOverlay.homeGrid) {
      final nextIdx = (_state.overlayCursorIndex - 1).clamp(
        0,
        AppMode.values.length - 1,
      );
      _emit(_state.copyWith(overlayCursorIndex: nextIdx, isShift: false));
      return;
    }

    if (_state.activeOverlay != ActiveOverlay.none ||
        _state.menuBreadcrumbs.isNotEmpty) {
      if (_state.menuBreadcrumbs.length > 1) {
        pressBack();
      }
      return;
    }

    if (_state.activeGridModel != null) {
      _moveGridCursor(dRow: 0, dCol: -1);
      return;
    }

    if (_state.isResultDisplayed &&
        _state.activeFormatView == OutputFormatView.engineering &&
        !_state.isShift) {
      _shiftEngineeringExponent(-1);
      return;
    }

    if (_state.isResultDisplayed) {
      if (_state.isShift) {
        _editor.moveToRootStart();
      } else {
        _editor.moveToRootEnd();
      }
      _syncEditorToState(isResultDisplayed: false);
      return;
    }

    if (_state.isShift) {
      _editor.moveToRootStart();
    } else {
      _editor.moveLeft();
    }
    _syncEditorToState(isResultDisplayed: false);
  }

  /// KEY-10: `▶` (Spatial 2D Cursor Right / Sub-Menu Enter / Grid Right / ENG Shift)
  void pressCursorRight() {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();

    if (_state.errorMessage != null) {
      _emit(
        _state.copyWith(
          errorMessage: () => null,
          isResultDisplayed: false,
          isShift: false,
        ),
      );
      return;
    }

    if (_state.activeOverlay == ActiveOverlay.homeGrid) {
      final nextIdx = (_state.overlayCursorIndex + 1).clamp(
        0,
        AppMode.values.length - 1,
      );
      _emit(_state.copyWith(overlayCursorIndex: nextIdx, isShift: false));
      return;
    }

    if (_state.activeOverlay != ActiveOverlay.none ||
        _state.menuBreadcrumbs.isNotEmpty) {
      final currentLevel = _state.currentBreadcrumb;
      if (currentLevel != null && currentLevel.items.isNotEmpty) {
        final node = currentLevel.items[currentLevel.selectedIndex];
        if (node.isSubMenu) {
          _executeOverlaySelection();
        }
      }
      return;
    }

    if (_state.activeGridModel != null) {
      _moveGridCursor(dRow: 0, dCol: 1);
      return;
    }

    if (_state.isResultDisplayed &&
        _state.activeFormatView == OutputFormatView.engineering &&
        !_state.isShift) {
      _shiftEngineeringExponent(1);
      return;
    }

    if (_state.isResultDisplayed) {
      if (_state.isShift) {
        _editor.moveToRootEnd();
      } else {
        _editor.moveToRootStart();
      }
      _syncEditorToState(isResultDisplayed: false);
      return;
    }

    if (_state.isShift) {
      _editor.moveToRootEnd();
    } else {
      _editor.moveRight();
    }
    _syncEditorToState(isResultDisplayed: false);
  }

  void _shiftEngineeringExponent(int delta) {
    final last = _lastEvalResult;
    final Cal_Decimal? dec =
        last?.decimalValue ?? Cal_Decimal.tryParse(_state.resultText);
    if (dec == null) return;

    final int nextShift = (_state.engStepShift + delta).clamp(-6, 6);
    final String formatted = Cal_FormatConverter.formatEngineering(
      dec,
      stepShift: nextShift,
      useSiSymbols: _state.engSymbolOn,
    );
    _emit(
      _state.copyWith(
        engStepShift: nextShift,
        resultText: formatted,
        isShowingExactForm: false,
        isShift: false,
      ),
    );
  }

  /// KEY-03: `▲` (Spatial 2D Cursor Up / Menu Scroll Up / Grid Up / History Up)
  void pressCursorUp() {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();

    if (_state.activeOverlay == ActiveOverlay.homeGrid) {
      final nextIdx = (_state.overlayCursorIndex - 3).clamp(
        0,
        AppMode.values.length - 1,
      );
      _emit(_state.copyWith(overlayCursorIndex: nextIdx, isShift: false));
      return;
    }

    if (_state.activeOverlay != ActiveOverlay.none ||
        _state.menuBreadcrumbs.isNotEmpty) {
      final level = _state.currentBreadcrumb;
      if (level != null && level.items.isNotEmpty) {
        final count = level.items.length;
        final nextIdx = (level.selectedIndex - 1 + count) % count;
        final updatedStack = List<MenuBreadcrumbLevel>.from(
          _state.menuBreadcrumbs,
        );
        updatedStack[updatedStack.length - 1] = level.copyWith(
          selectedIndex: nextIdx,
        );
        _emit(
          _state.copyWith(
            menuBreadcrumbs: updatedStack,
            overlayCursorIndex: nextIdx,
            isShift: false,
          ),
        );
      }
      return;
    }

    if (_state.multiLineResultLines != null) {
      final int nextIdx = (_state.multiLineCursorIndex - 1).clamp(
        0,
        _state.multiLineResultLines!.length - 1,
      );
      _emit(_state.copyWith(multiLineCursorIndex: nextIdx));
      return;
    }

    if (_state.activeGridModel != null) {
      _moveGridCursor(dRow: -1, dCol: 0);
      return;
    }

    if (!_state.isResultDisplayed && _editor.moveUp()) {
      _syncEditorToState(isResultDisplayed: false);
      return;
    }

    if (_state.history.isEmpty) return;
    final int currentHist = _state.historyCursor == -1
        ? _state.history.length
        : _state.historyCursor;
    final int targetHist =
        (currentHist - 1).clamp(0, _state.history.length - 1);
    final entry = _state.history[targetHist];
    if (entry.rootNode != null) {
      _editor.loadFromTree(entry.rootNode!, cursorAtEnd: true);
    }
    _syncEditorToState(
      historyCursor: targetHist,
      resultText: entry.resultText,
      isResultDisplayed: true,
    );
  }

  /// KEY-13: `▼` (Spatial 2D Cursor Down / Menu Scroll Down / Grid Down / History Down)
  void pressCursorDown() {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();

    if (_state.activeOverlay == ActiveOverlay.homeGrid) {
      final nextIdx = (_state.overlayCursorIndex + 3).clamp(
        0,
        AppMode.values.length - 1,
      );
      _emit(_state.copyWith(overlayCursorIndex: nextIdx, isShift: false));
      return;
    }

    if (_state.activeOverlay != ActiveOverlay.none ||
        _state.menuBreadcrumbs.isNotEmpty) {
      final level = _state.currentBreadcrumb;
      if (level != null && level.items.isNotEmpty) {
        final count = level.items.length;
        final nextIdx = (level.selectedIndex + 1) % count;
        final updatedStack = List<MenuBreadcrumbLevel>.from(
          _state.menuBreadcrumbs,
        );
        updatedStack[updatedStack.length - 1] = level.copyWith(
          selectedIndex: nextIdx,
        );
        _emit(
          _state.copyWith(
            menuBreadcrumbs: updatedStack,
            overlayCursorIndex: nextIdx,
            isShift: false,
          ),
        );
      }
      return;
    }

    if (_state.multiLineResultLines != null) {
      final int nextIdx = (_state.multiLineCursorIndex + 1).clamp(
        0,
        _state.multiLineResultLines!.length - 1,
      );
      _emit(_state.copyWith(multiLineCursorIndex: nextIdx));
      return;
    }

    if (_state.activeGridModel != null) {
      _moveGridCursor(dRow: 1, dCol: 0);
      return;
    }

    if (!_state.isResultDisplayed && _editor.moveDown()) {
      _syncEditorToState(isResultDisplayed: false);
      return;
    }

    if (_state.history.isEmpty || _state.historyCursor == -1) return;
    if (_state.historyCursor < _state.history.length - 1) {
      final int targetHist = _state.historyCursor + 1;
      final entry = _state.history[targetHist];
      if (entry.rootNode != null) {
        _editor.loadFromTree(entry.rootNode!, cursorAtEnd: true);
      }
      _syncEditorToState(
        historyCursor: targetHist,
        resultText: entry.resultText,
        isResultDisplayed: true,
      );
    }
  }

  void _moveGridCursor({required int dRow, required int dCol}) {
    final g = _state.activeGridModel;
    if (g == null) return;
    if (_cellInputBuffer.isNotEmpty) {
      _commitActiveGridCell(advanceCursor: false);
    }
    final curGrid = _state.activeGridModel!;
    final int nextRow = (curGrid.activeRow + dRow).clamp(
      0,
      curGrid.rowHeaders.length - 1,
    );
    final int nextCol = (curGrid.activeCol + dCol).clamp(
      0,
      curGrid.columnHeaders.length - 1,
    );
    _rebuildActiveGridAt(nextRow, nextCol);
  }

  void _rebuildActiveGridAt(int row, int col) {
    final LcdGridTableModel? rebuilt = switch (_state.activeMode) {
      AppMode.matrix => _buildMatrixGridModel(
          _editingMatrixName,
          _state.matrices[_editingMatrixName] ?? Cal_Matrix.zeros(2, 2),
          activeRow: row,
          activeCol: col,
        ),
      AppMode.vector => _buildVectorGridModel(
          _editingVectorName,
          _state.vectors[_editingVectorName] ?? Cal_Vector.zeros(3),
          activeRow: row,
        ),
      AppMode.statistics => _buildStatisticsGridModel(
          _state.activeStatModel,
          activeRow: row,
          activeCol: col,
        ),
      AppMode.distribution => _buildDistributionGridModel(
          _state.activeDistribution,
          activeRow: row,
          activeCol: col,
        ),
      AppMode.table => _buildTableGridModel(activeRow: row, activeCol: col),
      AppMode.spreadsheet => _buildSpreadsheetGridModel(
          _state.spreadsheet,
          activeRow: row,
          activeCol: col,
        ),
      AppMode.equation => _buildEquationGridModel(
          activeRow: row,
          activeCol: col,
        ),
      AppMode.inequality => _buildInequalityGridModel(activeCol: col),
      AppMode.ratio => _buildRatioGridModel(activeCol: col),
      _ => _state.activeGridModel,
    };
    _emit(_state.copyWith(activeGridModel: () => rebuilt, isShift: false));
  }

  /// KEY-09: `OK` (Center D-Pad Confirmation)
  void pressOk() {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic(heavy: true);

    if (_state.errorMessage != null) {
      pressBack();
      return;
    }

    if (_state.activeOverlay != ActiveOverlay.none ||
        _state.menuBreadcrumbs.isNotEmpty) {
      _executeOverlaySelection();
      return;
    }

    pressExe();
  }

  // ===========================================================================
  // Hierarchical Overlay & Menu Action Dispatcher
  // ===========================================================================

  void _executeOverlaySelection() {
    if (_state.activeOverlay == ActiveOverlay.homeGrid) {
      final idx = _state.overlayCursorIndex.clamp(
        0,
        AppMode.values.length - 1,
      );
      final selectedMode = AppMode.values[idx];
      _initializeAppMode(selectedMode, showStartupMenu: true);
      return;
    }

    final currentLevel = _state.currentBreadcrumb;
    if (currentLevel == null || currentLevel.items.isEmpty) {
      _emit(
        _state.copyWith(
          activeOverlay: ActiveOverlay.none,
          menuBreadcrumbs: const [],
        ),
      );
      return;
    }

    final int idx = currentLevel.selectedIndex.clamp(
      0,
      currentLevel.items.length - 1,
    );
    final CwMenuNode selectedNode = currentLevel.items[idx];

    if (selectedNode.isSubMenu) {
      final nextStack = [
        ..._state.menuBreadcrumbs,
        MenuBreadcrumbLevel(
          title: selectedNode.label,
          items: selectedNode.children,
          selectedIndex: 0,
        ),
      ];
      _emit(
        _state.copyWith(
          menuBreadcrumbs: nextStack,
          overlayCursorIndex: 0,
          isShift: false,
        ),
      );
      return;
    }

    if (selectedNode.action != null) {
      _executeMenuAction(selectedNode.action!);
    } else {
      _emit(
        _state.copyWith(
          activeOverlay: ActiveOverlay.none,
          menuBreadcrumbs: const [],
        ),
      );
    }
  }

  void _executeMenuAction(CwMenuAction action) {
    switch (action.type) {
      case 'insert_template':
        _emit(
          _state.copyWith(
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        switch (action.payload) {
          case 'deriv':
            insertDerivative();
            break;
          case 'integral':
            insertIntegral();
            break;
          case 'sum':
            insertSummation(isProduct: false);
            break;
          case 'prod':
            insertSummation(isProduct: true);
            break;
          case 'logbase':
            insertLogBase();
            break;
          case 'abs':
            insertParenthesis(isAbsoluteValue: true);
            break;
        }
        break;

      case 'insert_op':
      case 'insert_token':
        final parts = action.payload.split('|');
        final String display = parts[0];
        final String evalText = parts.length > 1 ? parts[1] : parts[0];
        _emit(
          _state.copyWith(
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        insertToken(
          InputToken(display: display, evalText: evalText),
          isBinaryOperator: action.type == 'insert_op',
        );
        break;

      case 'var_recall':
        final String reg = action.payload;
        _emit(
          _state.copyWith(
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        insertToken(InputToken(display: reg, evalText: reg));
        break;

      case 'var_store_ans':
        final String reg = action.payload;
        final String ansVal = _state.variables['Ans'] ?? '0';
        final updatedVars = Map<String, String>.from(_state.variables);
        updatedVars[reg] = ansVal;
        _emit(
          _state.copyWith(
            variables: updatedVars,
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
            resultText: '$reg = $ansVal',
            isResultDisplayed: true,
          ),
        );
        break;

      case 'var_edit_prompt':
        final String reg = action.payload;
        _editor.clear();
        _syncEditorToState(
          activeOverlay: ActiveOverlay.none,
          menuBreadcrumbs: const [],
          definingPromptTarget: () => reg,
          isResultDisplayed: false,
          resultText: '',
        );
        break;

      case 'fn_insert':
        _emit(
          _state.copyWith(
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        insertToken(
          InputToken(display: action.payload, evalText: action.payload),
        );
        break;

      case 'fn_define':
        final String fnTarget = action.payload; // 'f' or 'g'
        _editor.clear();
        _syncEditorToState(
          activeOverlay: ActiveOverlay.none,
          menuBreadcrumbs: const [],
          definingPromptTarget: () => fnTarget,
          isResultDisplayed: false,
          resultText: '',
        );
        break;

      case 'format_select':
        _applyFormatSelection(action.payload);
        break;

      case 'tools_undo':
        if (_state.history.isNotEmpty) {
          final lastEntry = _state.history.last;
          if (lastEntry.rootNode != null) {
            _editor.loadFromTree(lastEntry.rootNode!, cursorAtEnd: true);
          }
        }
        _syncEditorToState(
          activeOverlay: ActiveOverlay.none,
          menuBreadcrumbs: const [],
          isResultDisplayed: false,
        );
        break;

      case 'tools_toggle_verify':
        _emit(
          _state.copyWith(
            isVerifyMode: !_state.isVerifyMode,
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        break;

      case 'tools_clear_history':
        _emit(
          _state.copyWith(
            history: const [],
            historyCursor: -1,
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        break;

      // Specialized App Mode Actions:
      case 'complex_format':
        final bool polar = action.payload == 'polar';
        final String nextRes = _lastComplexResult != null
            ? (polar
                ? _lastComplexResult!.toPolarString(_state.angleUnit)
                : _lastComplexResult!.toRectangularString())
            : _state.resultText;
        if (_state.activeOverlay == ActiveOverlay.settingsMenu) {
          _updateSettingsAndRefreshBreadcrumbs(
            _state.copyWith(complexPolarDisplay: polar, resultText: nextRes),
          );
        } else {
          _emit(
            _state.copyWith(
              complexPolarDisplay: polar,
              resultText: nextRes,
              activeOverlay: ActiveOverlay.none,
              menuBreadcrumbs: const [],
            ),
          );
        }
        break;

      case 'basen_set_base':
        final base = switch (action.payload) {
          'hex' => NumberBase.hex,
          'bin' => NumberBase.bin,
          'oct' => NumberBase.oct,
          _ => NumberBase.dec,
        };
        _emit(
          _state.copyWith(
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        setBaseNRadix(base);
        break;

      case 'matrix_view':
        _emit(
          _state.copyWith(
            activeGridModel: () => null,
            multiLineResultLines: () => null,
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        break;

      case 'matrix_edit':
        _editingMatrixName = action.payload;
        final mat =
            _state.matrices[_editingMatrixName] ?? Cal_Matrix.zeros(2, 2);
        final grid = _buildMatrixGridModel(
          _editingMatrixName,
          mat,
          activeRow: 0,
          activeCol: 0,
        );
        _emit(
          _state.copyWith(
            activeGridModel: () => grid,
            multiLineResultLines: () => null,
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        break;

      case 'matrix_resize':
        final dims = action.payload.split('x');
        final int r = int.tryParse(dims[0]) ?? 2;
        final int c = int.tryParse(dims.length > 1 ? dims[1] : dims[0]) ?? 2;
        final curMat =
            _state.matrices[_editingMatrixName] ?? Cal_Matrix.zeros(r, c);
        final resized = curMat.resize(r, c);
        setMatrix(_editingMatrixName, resized);
        final grid = _buildMatrixGridModel(
          _editingMatrixName,
          resized,
          activeRow: 0,
          activeCol: 0,
        );
        _emit(
          _state.copyWith(
            activeGridModel: () => grid,
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        break;

      case 'vector_view':
        _emit(
          _state.copyWith(
            activeGridModel: () => null,
            multiLineResultLines: () => null,
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        break;

      case 'vector_edit':
        _editingVectorName = action.payload;
        final vct =
            _state.vectors[_editingVectorName] ?? Cal_Vector.zeros(3);
        final grid = _buildVectorGridModel(
          _editingVectorName,
          vct,
          activeRow: 0,
        );
        _emit(
          _state.copyWith(
            activeGridModel: () => grid,
            multiLineResultLines: () => null,
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        break;

      case 'vector_resize':
        final int dim = int.tryParse(action.payload) ?? 3;
        final curVct =
            _state.vectors[_editingVectorName] ?? Cal_Vector.zeros(dim);
        final resized = curVct.resize(dim);
        setVector(_editingVectorName, resized);
        final grid = _buildVectorGridModel(
          _editingVectorName,
          resized,
          activeRow: 0,
        );
        _emit(
          _state.copyWith(
            activeGridModel: () => grid,
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        break;

      case 'stat_model':
        final model = StatModelType.values.firstWhere(
          (m) => m.name == action.payload,
          orElse: () => StatModelType.oneVar,
        );
        final grid = _buildStatisticsGridModel(
          model,
          activeRow: 0,
          activeCol: 0,
        );
        _emit(
          _state.copyWith(
            activeStatModel: model,
            activeGridModel: () => grid,
            multiLineResultLines: () => null,
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        break;

      case 'stat_action':
        _emit(
          _state.copyWith(
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        if (action.payload == 'summary') {
          if (_state.activeStatModel == StatModelType.oneVar) {
            computeOneVarStatistics(_statX, frequencies: _statFreq);
          } else {
            computeTwoVarStatistics(
              model: _state.activeStatModel,
              xValues: _statX,
              yValues: _statY,
            );
          }
        } else if (action.payload == 'calc_screen') {
          Map<String, String> updatedVars = _state.variables;
          try {
            if (_state.activeStatModel == StatModelType.oneVar) {
              final res = StatisticsEngine.computeOneVar(
                _statX,
                frequencies: _statFreq,
              );
              updatedVars = _buildUpdatedStatVariables(oneVar: res);
            } else {
              final res = StatisticsEngine.computeTwoVar(
                model: _state.activeStatModel,
                xValues: _statX,
                yValues: _statY,
              );
              updatedVars = _buildUpdatedStatVariables(twoVar: res);
            }
          } catch (_) {}
          _emit(
            _state.copyWith(
              variables: updatedVars,
              activeGridModel: () => null,
              multiLineResultLines: () => null,
              activeOverlay: ActiveOverlay.none,
              menuBreadcrumbs: const [],
            ),
          );
        } else if (action.payload == 'table') {
          final grid = _buildStatisticsGridModel(
            _state.activeStatModel,
            activeRow: 0,
            activeCol: 0,
          );
          _emit(
            _state.copyWith(
              activeGridModel: () => grid,
              multiLineResultLines: () => null,
            ),
          );
        } else if (action.payload == 'sort_asc') {
          _statX.sort();
          _rebuildActiveGridAt(0, 0);
        } else if (action.payload == 'sort_desc') {
          _statX.sort((a, b) => b.compareTo(a));
          _rebuildActiveGridAt(0, 0);
        } else if (action.payload == 'clear') {
          _statX = [0.0];
          _statY = [0.0];
          _statFreq = [1.0];
          _rebuildActiveGridAt(0, 0);
        }
        break;

      case 'dist_select':
        final dist = DistributionType.values.firstWhere(
          (d) => d.name == action.payload,
          orElse: () => DistributionType.normalPd,
        );
        _isDistributionListMode = false;
        _resetDistributionParams(dist);
        final grid = _buildDistributionGridModel(dist, activeRow: 0);
        _emit(
          _state.copyWith(
            activeDistribution: dist,
            activeGridModel: () => grid,
            multiLineResultLines: () => null,
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        break;

      case 'dist_select_list':
        final dist = DistributionType.values.firstWhere(
          (d) => d.name == action.payload,
          orElse: () => DistributionType.binomialPd,
        );
        _isDistributionListMode = true;
        _resetDistributionParams(dist);
        final grid = _buildDistributionGridModel(dist, activeRow: 0, activeCol: 0);
        _emit(
          _state.copyWith(
            activeDistribution: dist,
            activeGridModel: () => grid,
            multiLineResultLines: () => null,
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        break;

      case 'table_action':
        _emit(
          _state.copyWith(
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        generateFunctionTable(
          start: _tableStart,
          end: _tableEnd,
          step: _tableStep,
        );
        break;

      case 'sheet_action':
        if (action.payload == 'clear') {
          const emptySheet = SpreadsheetSheet();
          final grid = _buildSpreadsheetGridModel(
            emptySheet,
            activeRow: 0,
            activeCol: 0,
          );
          _emit(
            _state.copyWith(
              spreadsheet: emptySheet,
              activeGridModel: () => grid,
              activeOverlay: ActiveOverlay.none,
              menuBreadcrumbs: const [],
            ),
          );
        }
        break;

      case 'sheet_insert':
        final curGrid = _state.activeGridModel;
        final int r = curGrid?.activeRow ?? 0;
        final int c = curGrid?.activeCol ?? 0;
        _emit(
          _state.copyWith(
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        setSpreadsheetCell(r, c, action.payload);
        break;

      case 'eq_simul':
        _isEquationPolynomial = false;
        _equationSimulUnknowns = (int.tryParse(action.payload) ?? 2).clamp(2, 4);
        _simulMatrix = List.generate(
          _equationSimulUnknowns,
          (r) => List.generate(
            _equationSimulUnknowns + 1,
            (c) => r == c ? 1.0 : (c == _equationSimulUnknowns ? 1.0 : 0.0),
          ),
        );
        final grid = _buildEquationGridModel(activeRow: 0, activeCol: 0);
        _emit(
          _state.copyWith(
            activeGridModel: () => grid,
            multiLineResultLines: () => null,
            definingPromptTarget: () => null,
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        break;

      case 'eq_poly':
        _isEquationPolynomial = true;
        _equationPolyDegree = (int.tryParse(action.payload) ?? 2).clamp(2, 4);
        _polyCoeffs = [
          1.0,
          for (int i = 0; i < _equationPolyDegree; i++) 0.0,
        ];
        final grid = _buildEquationGridModel(activeRow: 0, activeCol: 0);
        _emit(
          _state.copyWith(
            activeGridModel: () => grid,
            multiLineResultLines: () => null,
            definingPromptTarget: () => null,
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        break;

      case 'eq_solver_start':
        _editor.clear();
        _state = _state.copyWith(
          activeGridModel: () => null,
          multiLineResultLines: () => null,
        );
        _syncEditorToState(
          activeOverlay: ActiveOverlay.none,
          menuBreadcrumbs: const [],
          definingPromptTarget: () => 'SOLVER_EQ',
          isResultDisplayed: false,
          resultText: '',
        );
        break;

      case 'eq_action':
        _emit(
          _state.copyWith(
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        if (_isEquationPolynomial) {
          solvePolynomialEquation(_polyCoeffs);
        } else {
          solveSimultaneousEquations(_simulMatrix);
        }
        break;

      case 'ineq_setup':
        final parts = action.payload.split('|');
        _inequalityDegree = (int.tryParse(parts[0]) ?? 2).clamp(2, 4);
        _ineqCoeffs = [
          1.0,
          for (int i = 0; i < _inequalityDegree; i++) 0.0,
        ];
        final signStr = parts.length > 1 ? parts[1] : '>';
        final sign = switch (signStr) {
          '<' => InequalitySign.lessThan,
          '≥' => InequalitySign.greaterOrEqual,
          '≤' => InequalitySign.lessOrEqual,
          _ => InequalitySign.greaterThan,
        };
        final grid = _buildInequalityGridModel(activeCol: 0);
        _emit(
          _state.copyWith(
            activeInequalitySign: sign,
            activeGridModel: () => grid,
            multiLineResultLines: () => null,
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        break;

      case 'ineq_deg':
        _inequalityDegree = (int.tryParse(action.payload) ?? 2).clamp(2, 4);
        _ineqCoeffs = [
          1.0,
          for (int i = 0; i < _inequalityDegree; i++) 0.0,
        ];
        final grid = _buildInequalityGridModel(activeCol: 0);
        _emit(
          _state.copyWith(
            activeGridModel: () => grid,
            multiLineResultLines: () => null,
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        break;

      case 'ineq_sign':
        final sign = switch (action.payload) {
          '<' => InequalitySign.lessThan,
          '≥' => InequalitySign.greaterOrEqual,
          '≤' => InequalitySign.lessOrEqual,
          _ => InequalitySign.greaterThan,
        };
        _emit(
          _state.copyWith(
            activeInequalitySign: sign,
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        _rebuildActiveGridAt(0, _state.activeGridModel?.activeCol ?? 0);
        break;

      case 'ineq_action':
        _emit(
          _state.copyWith(
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        solveInequality(
          coefficients: _ineqCoeffs,
          sign: _state.activeInequalitySign,
        );
        break;

      case 'ratio_type':
        final rType = action.payload == 'C_X'
            ? RatioTemplateType.aToBEqualsCToX
            : RatioTemplateType.aToBEqualsXToD;
        _emit(
          _state.copyWith(
            activeRatioType: rType,
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        _rebuildActiveGridAt(0, 0);
        break;

      case 'ratio_action':
        _emit(
          _state.copyWith(
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        solveRatio(
          type: _state.activeRatioType,
          a: _ratioCoeffs[0],
          b: _ratioCoeffs[1],
          cOrD: _ratioCoeffs[2],
        );
        break;

      case 'mathbox_select':
        if (action.payload == 'dice') {
          final sim = MathBoxEngine.runDiceRoll(
            diceCount: 2,
            attempts: 50,
            seed: 991,
          );
          _emit(
            _state.copyWith(
              activeMathBoxTool: MathBoxSubTool.diceRoll,
              multiLineResultTitle: () => 'Dice Roll (2 Dice, N=50)',
              multiLineResultLines: () => sim.summaryLines,
              multiLineCursorIndex: 0,
              activeOverlay: ActiveOverlay.none,
              menuBreadcrumbs: const [],
            ),
          );
        } else if (action.payload == 'coin') {
          final sim = MathBoxEngine.runCoinToss(
            coinCount: 3,
            attempts: 50,
            seed: 991,
          );
          _emit(
            _state.copyWith(
              activeMathBoxTool: MathBoxSubTool.coinToss,
              multiLineResultTitle: () => 'Coin Toss (3 Coins, N=50)',
              multiLineResultLines: () => sim.summaryLines,
              multiLineCursorIndex: 0,
              activeOverlay: ActiveOverlay.none,
              menuBreadcrumbs: const [],
            ),
          );
        } else if (action.payload == 'unit_circle') {
          final lines = MathBoxEngine.buildUnitCircleLines(30.0);
          _emit(
            _state.copyWith(
              activeMathBoxTool: MathBoxSubTool.circle,
              multiLineResultTitle: () => 'Unit Circle (θ = 30°)',
              multiLineResultLines: () => lines,
              multiLineCursorIndex: 0,
              activeOverlay: ActiveOverlay.none,
              menuBreadcrumbs: const [],
            ),
          );
        } else if (action.payload == 'clock') {
          final lines = MathBoxEngine.buildClockAngleLines(3, 30);
          _emit(
            _state.copyWith(
              activeMathBoxTool: MathBoxSubTool.circle,
              multiLineResultTitle: () => 'Clock (03:30)',
              multiLineResultLines: () => lines,
              multiLineCursorIndex: 0,
              activeOverlay: ActiveOverlay.none,
              menuBreadcrumbs: const [],
            ),
          );
        } else {
          _emit(
            _state.copyWith(
              activeMathBoxTool: MathBoxSubTool.numberLine,
              multiLineResultLines: () => null,
              activeOverlay: ActiveOverlay.none,
              menuBreadcrumbs: const [],
            ),
          );
        }
        break;

      case 'mathbox_view':
        final bool isCoin = _state.activeMathBoxTool == MathBoxSubTool.coinToss;
        final sim = isCoin
            ? MathBoxEngine.runCoinToss(coinCount: 3, attempts: 50, seed: 991)
            : MathBoxEngine.runDiceRoll(diceCount: 2, attempts: 50, seed: 991);
        final bool showList = action.payload == 'list';
        _emit(
          _state.copyWith(
            multiLineResultTitle: () =>
                '${isCoin ? "Coin Toss" : "Dice Roll"} (${showList ? "List" : "Rel. Freq"})',
            multiLineResultLines: () =>
                showList ? sim.trialListLines : sim.summaryLines,
            multiLineCursorIndex: 0,
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        break;

      case 'set_io':
        final nextIo = switch (action.payload) {
          'mathIMathO' => InputOutputMode.mathIMathO,
          'mathIDecimalO' => InputOutputMode.mathIDecimalO,
          'lineILineO' => InputOutputMode.lineILineO,
          'lineIDecimalO' => InputOutputMode.lineIDecimalO,
          _ => InputOutputMode.mathIMathO,
        };
        _updateSettingsAndRefreshBreadcrumbs(_state.copyWith(ioMode: nextIo));
        break;

      case 'set_angle':
        final nextAngle = switch (action.payload) {
          'degree' => AngleUnit.degree,
          'radian' => AngleUnit.radian,
          'gradian' => AngleUnit.gradian,
          _ => AngleUnit.degree,
        };
        _updateSettingsAndRefreshBreadcrumbs(
          _state.copyWith(angleUnit: nextAngle),
        );
        break;

      case 'set_fix':
        final digits = int.tryParse(action.payload) ?? 2;
        _updateSettingsAndRefreshBreadcrumbs(
          _state.copyWith(
            numberFormat: NumberFormatMode.fix,
            formatDigits: digits.clamp(0, 9),
          ),
        );
        break;

      case 'set_sci':
        final digits = int.tryParse(action.payload) ?? 2;
        _updateSettingsAndRefreshBreadcrumbs(
          _state.copyWith(
            numberFormat: NumberFormatMode.sci,
            formatDigits: digits.clamp(0, 9),
          ),
        );
        break;

      case 'set_norm':
        final mode = action.payload == '2'
            ? NumberFormatMode.norm2
            : NumberFormatMode.norm1;
        _updateSettingsAndRefreshBreadcrumbs(
          _state.copyWith(numberFormat: mode),
        );
        break;

      case 'set_eng_sym':
        _updateSettingsAndRefreshBreadcrumbs(
          _state.copyWith(engSymbolOn: action.payload == 'on'),
        );
        break;

      case 'set_frac_pref':
        final pref = action.payload == 'mixed'
            ? FractionResultPreference.mixed
            : FractionResultPreference.improper;
        _updateSettingsAndRefreshBreadcrumbs(
          _state.copyWith(fractionPreference: pref),
        );
        break;

      case 'set_stat_freq':
        _updateSettingsAndRefreshBreadcrumbs(
          _state.copyWith(statFreqOn: action.payload == 'on'),
        );
        break;

      case 'set_dec_mark':
        _updateSettingsAndRefreshBreadcrumbs(
          _state.copyWith(decimalMarkComma: action.payload == 'comma'),
        );
        break;

      case 'set_digit_sep':
        _updateSettingsAndRefreshBreadcrumbs(
          _state.copyWith(digitSeparatorOn: action.payload == 'on'),
        );
        break;

      case 'set_auto_power':
        final mins = int.tryParse(action.payload) ?? 10;
        _updateSettingsAndRefreshBreadcrumbs(
          _state.copyWith(autoPowerOffMinutes: mins),
        );
        break;

      case 'set_multiline_font':
        _updateSettingsAndRefreshBreadcrumbs(
          _state.copyWith(smallMultiLineFont: action.payload == 'small'),
        );
        break;

      case 'set_contrast':
        final contrast = int.tryParse(action.payload) ?? 8;
        _updateSettingsAndRefreshBreadcrumbs(
          _state.copyWith(lcdContrast: contrast.clamp(0, 15)),
        );
        break;

      case 'toggle_pixel_grid':
        _updateSettingsAndRefreshBreadcrumbs(
          _state.copyWith(showPixelGrid: !_state.showPixelGrid),
        );
        break;

      case 'toggle_lcd_invert':
        _updateSettingsAndRefreshBreadcrumbs(
          _state.copyWith(lcdInverted: !_state.lcdInverted),
        );
        break;

      case 'set_qr_version':
        final ver = action.payload == '3' ? 3 : 11;
        _updateSettingsAndRefreshBreadcrumbs(
          _state.copyWith(qrVersion: ver),
        );
        break;

      case 'toggle_key_sound':
        _updateSettingsAndRefreshBreadcrumbs(
          _state.copyWith(keyClickSoundOn: !_state.keyClickSoundOn),
        );
        break;

      case 'toggle_haptics':
        _updateSettingsAndRefreshBreadcrumbs(
          _state.copyWith(hapticFeedbackOn: !_state.hapticFeedbackOn),
        );
        break;

      case 'reset_variables':
        _emit(
          _state.copyWith(
            variables: const {
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
            activeOverlay: ActiveOverlay.none,
            menuBreadcrumbs: const [],
          ),
        );
        break;

      case 'reset_initialize_all':
        _editor.clear();
        _lastEvalResult = null;
        _cellInputBuffer = '';
        CalculatorPersistenceStore.clearPersistedState();
        _emit(
          CalculatorState(
            rootMathNode: _editor.clone().root,
            activeContainerId: _editor.activeContainerId,
            activeChildIndex: 0,
          ),
        );
        break;
    }
  }

  /// Rebuilds the `SETTINGS` breadcrumb stack in-place so radio badges (`●`/`○`)
  /// immediately reflect the updated setting while keeping the current depth and selection.
  void _updateSettingsAndRefreshBreadcrumbs(CalculatorState updated) {
    final freshRoot = _buildSettingsRootForState(updated);
    final List<MenuBreadcrumbLevel> rebuiltStack = [];
    MenuBreadcrumbLevel currentLevel = freshRoot;

    for (int depth = 0; depth < updated.menuBreadcrumbs.length; depth++) {
      final oldLevel = updated.menuBreadcrumbs[depth];
      final clampedIdx = oldLevel.selectedIndex.clamp(
        0,
        currentLevel.items.length - 1,
      );
      final syncedLevel = currentLevel.copyWith(selectedIndex: clampedIdx);
      rebuiltStack.add(syncedLevel);

      if (depth + 1 < updated.menuBreadcrumbs.length &&
          syncedLevel.items[clampedIdx].isSubMenu) {
        final childNode = syncedLevel.items[clampedIdx];
        currentLevel = MenuBreadcrumbLevel(
          title: childNode.label,
          items: childNode.children,
          selectedIndex: updated.menuBreadcrumbs[depth + 1].selectedIndex,
        );
      } else {
        break;
      }
    }

    _emit(
      updated.copyWith(
        menuBreadcrumbs: rebuiltStack,
        overlayCursorIndex: rebuiltStack.isNotEmpty
            ? rebuiltStack.last.selectedIndex
            : 0,
      ),
    );
  }

  void _applyFormatSelection(String formatKey) {
    final last = _lastEvalResult;
    if (last == null) {
      _emit(
        _state.copyWith(
          activeOverlay: ActiveOverlay.none,
          menuBreadcrumbs: const [],
        ),
      );
      _toggleStandardDecimalResult();
      return;
    }

    final Cal_Decimal dec =
        last.decimalValue ??
        Cal_Decimal.tryParse(last.decimalText) ??
        Cal_Decimal.zero;

    String formatted = last.primaryText;
    bool exactFlag = false;
    OutputFormatView nextView = OutputFormatView.standard;
    int nextEngShift = 0;

    switch (formatKey) {
      case 'standard':
        formatted = _preferredExactOrDecimal(last);
        exactFlag = last.exactText != null && formatted == last.exactText;
        nextView = OutputFormatView.standard;
        break;
      case 'decimal':
        formatted = last.decimalText;
        exactFlag = false;
        nextView = OutputFormatView.decimal;
        break;
      case 'recurring':
        formatted = last.recurringDecimalText ?? last.decimalText;
        exactFlag = false;
        nextView = OutputFormatView.recurringDecimal;
        break;
      case 'improper':
        formatted = last.exactText ?? last.decimalText;
        exactFlag = last.exactText != null;
        nextView = OutputFormatView.improperFraction;
        break;
      case 'mixed':
        formatted = last.mixedFractionText ?? last.exactText ?? last.decimalText;
        exactFlag = false;
        nextView = OutputFormatView.mixedFraction;
        break;
      case 'eng':
        nextEngShift = 0;
        formatted = Cal_FormatConverter.formatEngineering(
          dec,
          stepShift: 0,
          useSiSymbols: _state.engSymbolOn,
        );
        exactFlag = false;
        nextView = OutputFormatView.engineering;
        break;
      case 'dms':
        formatted = Cal_FormatConverter.formatSexagesimalDms(dec);
        exactFlag = false;
        nextView = OutputFormatView.sexagesimalDms;
        break;
      case 'fact':
        formatted = last.primeFactorText ?? last.decimalText;
        exactFlag = false;
        nextView = OutputFormatView.primeFactor;
        break;
    }

    _emit(
      _state.copyWith(
        activeOverlay: ActiveOverlay.none,
        menuBreadcrumbs: const [],
        resultText: formatted,
        isShowingExactForm: exactFlag,
        activeFormatView: nextView,
        engStepShift: nextEngShift,
        isResultDisplayed: true,
        isShift: false,
      ),
    );
  }

  String _preferredExactOrDecimal(Cal_EvaluationResult res) {
    if (_state.fractionPreference == FractionResultPreference.mixed &&
        res.mixedFractionText != null) {
      return res.mixedFractionText!;
    }
    return res.exactText ?? res.decimalText;
  }

  // ===========================================================================
  // 2D Natural Textbook Insertion & Editing Operations
  // ===========================================================================

  void _prepareEditorForInput({required bool autoPrependAns}) {
    if (_state.errorMessage != null) {
      _emit(_state.copyWith(errorMessage: () => null));
    }
    if (_state.activeOverlay != ActiveOverlay.none ||
        _state.menuBreadcrumbs.isNotEmpty) {
      _emit(
        _state.copyWith(
          activeOverlay: ActiveOverlay.none,
          menuBreadcrumbs: const [],
        ),
      );
    }
    if (_state.isResultDisplayed) {
      _editor.clear();
      if (autoPrependAns && _state.definingPromptTarget == null) {
        _editor.insertChar('Ans', evalText: 'Ans');
      }
    }
  }

  /// Inserts an atomic character or operator token into the active 2D container
  /// (or into the active cell input line when a 2D Grid/Table Editor is open).
  void insertToken(
    InputToken token, {
    bool isBinaryOperator = false,
  }) {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();

    if (_state.menuBreadcrumbs.isNotEmpty &&
        _state.activeOverlay == ActiveOverlay.none) {
      _emit(_state.copyWith(menuBreadcrumbs: const []));
    }

    if (_state.activeGridModel != null) {
      _cellInputBuffer += token.display;
      _rebuildActiveGridAt(
        _state.activeGridModel!.activeRow,
        _state.activeGridModel!.activeCol,
      );
      return;
    }

    // In Complex mode, pressing the 'x' variable key inserts imaginary unit 'i'
    InputToken resolved = token;
    if (_state.activeMode == AppMode.complex && token.display == 'x') {
      resolved = const InputToken(display: 'i', evalText: 'i');
    }

    _prepareEditorForInput(autoPrependAns: isBinaryOperator);

    _editor.insertChar(
      resolved.display,
      evalText: resolved.evalText,
      isInsertMode: _state.isInsertMode,
    );
    _syncEditorToState(isResultDisplayed: false);
  }

  /// KEY-15: Inserts a 2D `FractionNode` (or mixed fraction when `SHIFT` is active).
  void insertFraction({bool mixed = false}) {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();

    if (!_state.ioMode.isMathInput || _state.activeGridModel != null) {
      insertToken(
        const InputToken(display: '/', evalText: '/'),
        isBinaryOperator: true,
      );
      return;
    }

    _prepareEditorForInput(autoPrependAns: !mixed && _state.isResultDisplayed);
    _editor.insertFraction(mixed: mixed);
    _syncEditorToState(isResultDisplayed: false);
  }

  /// KEY-16: Inserts a 2D `RadicalNode` ($\sqrt{\square}$ or $\sqrt[\square]{\square}$).
  void insertRadical({bool nthRoot = false}) {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();

    if (!_state.ioMode.isMathInput || _state.activeGridModel != null) {
      insertToken(const InputToken(display: '√(', evalText: '√('));
      return;
    }

    _prepareEditorForInput(autoPrependAns: false);
    _editor.insertRadical(nthRoot: nthRoot);
    _syncEditorToState(isResultDisplayed: false);
  }

  /// KEY-17 / KEY-18: Inserts a 2D `SuperscriptNode` ($x^\square, x^2, x^{-1}, 10^\square, e^\square$).
  void insertSuperscript({
    List<MathNode>? initialBase,
    List<MathNode>? initialExponent,
    bool focusExponent = true,
  }) {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();

    _prepareEditorForInput(autoPrependAns: initialBase == null);
    _editor.insertSuperscript(
      initialBase: initialBase,
      initialExponent: initialExponent,
      focusExponent: focusExponent,
    );
    _syncEditorToState(isResultDisplayed: false);
  }

  /// KEY-24 (Shift): Inserts a 2D auto-sizing `ParenthesisNode` or `|□|` Abs box.
  void insertParenthesis({bool isAbsoluteValue = false}) {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();
    _prepareEditorForInput(autoPrependAns: false);
    _editor.insertParenthesis(isAbsoluteValue: isAbsoluteValue);
    _syncEditorToState(isResultDisplayed: false);
  }

  /// KEY-18 (Shift): Inserts a 2D `LogBaseNode` ($\log_{\blacksquare}(\square)$).
  void insertLogBase() {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();
    _prepareEditorForInput(autoPrependAns: false);
    _editor.insertLogBase();
    _syncEditorToState(isResultDisplayed: false);
  }

  /// KEY-28: Inserts a 2D `IntegralNode` ($\int_\square^\square (\blacksquare)\,dx$).
  void insertIntegral() {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();
    _prepareEditorForInput(autoPrependAns: false);
    _editor.insertIntegral();
    _syncEditorToState(isResultDisplayed: false);
  }

  /// Inserts a 2D `SummationNode` ($\sum_{x=\square}^\square (\blacksquare)$ or $\prod$).
  void insertSummation({bool isProduct = false}) {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();
    _prepareEditorForInput(autoPrependAns: false);
    _editor.insertSummation(isProduct: isProduct);
    _syncEditorToState(isResultDisplayed: false);
  }

  /// KEY-28 (Shift): Inserts a 2D `DerivativeNode` ($\left.\frac{d}{dx}(\blacksquare)\right|_{x=\square}$).
  void insertDerivative() {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();
    _prepareEditorForInput(autoPrependAns: false);
    _editor.insertDerivative();
    _syncEditorToState(isResultDisplayed: false);
  }

  /// KEY-32: `⌫` (Backspace / Shift: `INS` Overwrite Toggle)
  void pressBackspace() {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic();

    if (_state.isShift) {
      _emit(
        _state.copyWith(
          isInsertMode: !_state.isInsertMode,
          isShift: false,
        ),
      );
      return;
    }

    if (_state.errorMessage != null) {
      _emit(_state.copyWith(errorMessage: () => null));
      return;
    }

    if (_state.activeGridModel != null && _cellInputBuffer.isNotEmpty) {
      _cellInputBuffer = _cellInputBuffer.substring(
        0,
        _cellInputBuffer.length - 1,
      );
      _rebuildActiveGridAt(
        _state.activeGridModel!.activeRow,
        _state.activeGridModel!.activeCol,
      );
      return;
    }

    if (_state.isResultDisplayed) {
      _editor.moveToRootEnd();
      _syncEditorToState(isResultDisplayed: false);
      return;
    }

    _editor.deleteBackward(isInsertMode: _state.isInsertMode);
    _syncEditorToState(isResultDisplayed: false);
  }

  /// KEY-33: `AC` (All Clear / Shift: `OFF`)
  void pressAc() {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic(heavy: true);

    if (_state.isShift) {
      _emit(
        _state.copyWith(
          isPoweredOn: false,
          isShift: false,
          isAlpha: false,
          activeOverlay: ActiveOverlay.none,
          menuBreadcrumbs: const [],
        ),
      );
      return;
    }

    if (_state.activeGridModel != null && _cellInputBuffer.isNotEmpty) {
      _cellInputBuffer = '';
      _rebuildActiveGridAt(
        _state.activeGridModel!.activeRow,
        _state.activeGridModel!.activeCol,
      );
      return;
    }

    _editor.clear();
    _lastEvalResult = null;
    _syncEditorToState(
      isResultDisplayed: false,
      resultText: '',
      alternateResultText: () => null,
      definingPromptTarget: () => null,
      activeOverlay: ActiveOverlay.none,
      menuBreadcrumbs: const [],
      errorMessage: () => null,
    );
  }

  /// Commits the current `_cellInputBuffer` into the active 2D Grid/Table cell.
  void _commitActiveGridCell({required bool advanceCursor}) {
    final g = _state.activeGridModel;
    if (g == null) return;
    final int r = g.activeRow;
    final int c = g.activeCol;
    final String rawInput = _cellInputBuffer.trim();
    _cellInputBuffer = '';

    double parseCellNumber(String s, double fallback) {
      if (s.isEmpty) return fallback;
      final d = double.tryParse(s);
      if (d != null) return d;
      final evalRes = evaluateExpressionString(s, forceDecimal: true);
      return double.tryParse(evalRes.decimalText) ?? fallback;
    }

    switch (_state.activeMode) {
      case AppMode.matrix:
        final mat =
            _state.matrices[_editingMatrixName] ?? Cal_Matrix.zeros(2, 2);
        if (rawInput.isNotEmpty) {
          final updatedMat = mat.copyWithCell(
            r,
            c,
            parseCellNumber(rawInput, mat.get(r, c)),
          );
          setMatrix(_editingMatrixName, updatedMat);
        }
        break;

      case AppMode.vector:
        final vct =
            _state.vectors[_editingVectorName] ?? Cal_Vector.zeros(3);
        if (rawInput.isNotEmpty) {
          final updatedVct = vct.copyWithComponent(
            r,
            parseCellNumber(rawInput, vct.components[r]),
          );
          setVector(_editingVectorName, updatedVct);
        }
        break;

      case AppMode.statistics:
        if (rawInput.isNotEmpty) {
          final val = parseCellNumber(rawInput, 0.0);
          if (c == 0) {
            _statX[r] = val;
          } else if (_state.activeStatModel.isTwoVar) {
            _statY[r] = val;
          } else {
            _statFreq[r] = val;
          }
        }
        break;

      case AppMode.distribution:
        if (_isDistributionListMode &&
            _state.activeDistribution.supportsListMode) {
          if (rawInput.isNotEmpty && c == 0 && r < _distListX.length) {
            _distListX[r] = parseCellNumber(rawInput, _distListX[r]);
          }
          final int nextR = advanceCursor && r + 1 < _distListX.length ? r + 1 : r;
          _rebuildActiveGridAt(nextR, c);
          return;
        }
        if (rawInput.isNotEmpty) {
          final val = parseCellNumber(rawInput, _distParams[r].$2);
          _distParams[r] = (_distParams[r].$1, val);
        }
        if (advanceCursor && r == _distParams.length - 1) {
          _evaluateActiveDistribution();
          return;
        }
        break;

      case AppMode.table:
        if (rawInput.isNotEmpty && c == 0 && r < _tableRows.length) {
          final double newX = parseCellNumber(rawInput, _tableRows[r].x);
          final String fExpr = _state.definedFunctionF.isNotEmpty
              ? _state.definedFunctionF
              : 'x^2';
          final updatedRow = TableAppEngine.evaluateSingleRow(
            xVal: newX,
            definedF: fExpr,
            definedG: _state.definedFunctionG,
            angleUnit: _state.angleUnit,
            variables: _state.variables,
          );
          final nextRows = List<TableRowEntry>.from(_tableRows);
          nextRows[r] = updatedRow;
          _tableRows = nextRows;
        }
        break;

      case AppMode.spreadsheet:
        if (rawInput.isNotEmpty) {
          setSpreadsheetCell(r, c, rawInput);
        }
        break;

      case AppMode.equation:
        if (_isEquationPolynomial) {
          if (rawInput.isNotEmpty) {
            _polyCoeffs[c] = parseCellNumber(rawInput, _polyCoeffs[c]);
          }
          if (advanceCursor && c == _polyCoeffs.length - 1) {
            solvePolynomialEquation(_polyCoeffs);
            return;
          }
        } else {
          if (rawInput.isNotEmpty) {
            _simulMatrix[r][c] = parseCellNumber(rawInput, _simulMatrix[r][c]);
          }
          if (advanceCursor &&
              r == _equationSimulUnknowns - 1 &&
              c == _equationSimulUnknowns) {
            solveSimultaneousEquations(_simulMatrix);
            return;
          }
        }
        break;

      case AppMode.inequality:
        if (rawInput.isNotEmpty) {
          _ineqCoeffs[c] = parseCellNumber(rawInput, _ineqCoeffs[c]);
        }
        if (advanceCursor && c == _ineqCoeffs.length - 1) {
          solveInequality(
            coefficients: _ineqCoeffs,
            sign: _state.activeInequalitySign,
          );
          return;
        }
        break;

      case AppMode.ratio:
        if (rawInput.isNotEmpty) {
          _ratioCoeffs[c] = parseCellNumber(rawInput, _ratioCoeffs[c]);
        }
        if (advanceCursor && c == 2) {
          solveRatio(
            type: _state.activeRatioType,
            a: _ratioCoeffs[0],
            b: _ratioCoeffs[1],
            cOrD: _ratioCoeffs[2],
          );
          return;
        }
        break;

      default:
        break;
    }

    int nextRow = r;
    int nextCol = c;
    if (advanceCursor) {
      if (c + 1 < g.columnHeaders.length) {
        nextCol = c + 1;
      } else if (r + 1 < g.rowHeaders.length) {
        nextCol = 0;
        nextRow = r + 1;
      }
    }
    _rebuildActiveGridAt(nextRow, nextCol);
  }

  void _evaluateActiveDistribution() {
    try {
      final dist = _state.activeDistribution;
      final double probOrVal = switch (dist) {
        DistributionType.normalPd => DistributionEngine.normalPd(
            x: _distParams[0].$2,
            sigma: _distParams[1].$2,
            mu: _distParams[2].$2,
          ),
        DistributionType.normalCd => DistributionEngine.normalCd(
            lower: _distParams[0].$2,
            upper: _distParams[1].$2,
            sigma: _distParams[2].$2,
            mu: _distParams[3].$2,
          ),
        DistributionType.inverseNormal => DistributionEngine.inverseNormal(
            area: _distParams[0].$2,
            sigma: _distParams[1].$2,
            mu: _distParams[2].$2,
          ),
        DistributionType.binomialPd => DistributionEngine.binomialPd(
            x: _distParams[0].$2.round(),
            n: _distParams[1].$2.round(),
            p: _distParams[2].$2,
          ),
        DistributionType.binomialCd => DistributionEngine.binomialCd(
            x: _distParams[0].$2.round(),
            n: _distParams[1].$2.round(),
            p: _distParams[2].$2,
          ),
        DistributionType.poissonPd => DistributionEngine.poissonPd(
            x: _distParams[0].$2.round(),
            lambda: _distParams[1].$2,
          ),
        DistributionType.poissonCd => DistributionEngine.poissonCd(
            x: _distParams[0].$2.round(),
            lambda: _distParams[1].$2,
          ),
      };

      final String label =
          dist == DistributionType.inverseNormal ? 'xInv' : 'P';
      final String formatted = '$label = ${formatCal_Scalar(probOrVal)}';
      _emit(
        _state.copyWith(
          activeGridModel: () => null,
          multiLineResultTitle: () => dist.label,
          multiLineResultLines: () => [
            for (final p in _distParams)
              '${p.$1} = ${formatCal_Scalar(p.$2)}',
            formatted,
          ],
          multiLineCursorIndex: _distParams.length,
          resultText: formatted,
          isResultDisplayed: true,
        ),
      );
    } on FormatException catch (e) {
      _emit(_state.copyWith(errorMessage: () => e.message));
    }
  }

  /// Solves a general single-variable equation `LHS = RHS` (or `expr = 0`) for `x`
  /// using damped Newton-Secant iteration (`Equation -> Solver`, `FN-460`–`FN-463`).
  (double?, double) _solveGeneralEquationForX(String rawEquation) {
    final parts = rawEquation.split('=');
    final String diffExpr = parts.length >= 2
        ? '(${parts[0]})-(${parts.sublist(1).join('=')})'
        : rawEquation;

    double? evalAt(double xVal) {
      final vars = Map<String, String>.from(_state.variables);
      vars['x'] = xVal.toString();
      final res = MathExpressionEvaluator(
        angleUnit: _state.angleUnit,
        numberFormat: NumberFormatMode.norm2,
        formatDigits: 9,
        variables: vars,
        definedFunctionF: _state.definedFunctionF,
        definedFunctionG: _state.definedFunctionG,
      ).evaluateString(diffExpr, forceDecimal: true);
      if (res.error != null) return null;
      return res.decimalValue?.toDouble() ??
          double.tryParse(res.decimalText.replaceAll('−', '-'));
    }

    final double initialX = double.tryParse(_state.variables['x'] ?? '0') ?? 0.0;
    final List<double> seeds = [initialX, 1.0, 0.5, -1.0, 2.0, -2.0, 0.1, 5.0];
    for (final seed in seeds) {
      double x0 = seed;
      double x1 = seed + 0.01;
      double? f0 = evalAt(x0);
      double? f1 = evalAt(x1);
      if (f0 == null || f1 == null) continue;
      if (f0.abs() < 1e-12) return (x0, f0.abs());

      for (int iter = 0; iter < 60; iter++) {
        if (f1 == null) break;
        if (f1.abs() < 1e-11) {
          final double cleanX = (x1 - x1.roundToDouble()).abs() < 1e-9
              ? x1.roundToDouble()
              : x1;
          final double lr = (evalAt(cleanX) ?? f1).abs();
          return (cleanX, lr < 1e-9 ? 0.0 : lr);
        }
        final double denom = f1 - f0!;
        if (denom.abs() < 1e-15) {
          x1 += 0.05;
          f1 = evalAt(x1);
          continue;
        }
        final double step = f1 * (x1 - x0) / denom;
        final double x2 = x1 - step.clamp(-100.0, 100.0);
        x0 = x1;
        f0 = f1;
        x1 = x2;
        f1 = evalAt(x1);
      }
    }
    return (null, 0.0);
  }

  /// KEY-48: `EXE` (Execute / Shift: `≈` Approximate Evaluation)
  void pressExe() {
    if (!_state.isPoweredOn) return;
    triggerKeyHaptic(heavy: true);

    if (_state.activeOverlay != ActiveOverlay.none ||
        _state.menuBreadcrumbs.isNotEmpty) {
      _executeOverlaySelection();
      return;
    }

    if (_state.activeGridModel != null) {
      _commitActiveGridCell(advanceCursor: true);
      return;
    }

    // Handle active function definition (`Define f(x)` / `Define g(x)`), Solver (`SOLVER_EQ`), or variable edit (`A =`)
    if (_state.definingPromptTarget != null) {
      final String target = _state.definingPromptTarget!;
      if (target == 'SOLVER_EQ') {
        if (_editor.isEmpty) return;
        final String eqEval;
        try {
          eqEval = _editor.root.toEvalString().trim();
        } on FormatException {
          _emit(_state.copyWith(errorMessage: () => 'Syntax ERROR'));
          return;
        }
        final String eqDisp = _editor.root.toDisplayString();
        final (root, lrDiff) = _solveGeneralEquationForX(eqEval);
        if (root == null) {
          _emit(_state.copyWith(errorMessage: () => 'Can\'t Solve'));
          return;
        }
        final String rootStr = formatCal_Scalar(root);
        final String lrStr = formatCal_Scalar(lrDiff);
        final updatedVars = Map<String, String>.from(_state.variables);
        updatedVars['x'] = rootStr;
        _editor.clear();
        _emit(
          _state.copyWith(
            definingPromptTarget: () => null,
            variables: updatedVars,
            multiLineResultTitle: () => 'Equation Solver',
            multiLineResultLines: () => [
              eqDisp.contains('=') ? eqDisp : '$eqDisp = 0',
              'x = $rootStr',
              'L-R = $lrStr',
            ],
            multiLineCursorIndex: 1,
            resultText: 'x = $rootStr',
            isResultDisplayed: true,
          ),
        );
        return;
      }
      if (target == 'f' || target == 'g') {
        final String exprEval;
        try {
          exprEval = _editor.root.toEvalString().trim();
        } on FormatException {
          _emit(
            _state.copyWith(
              errorMessage: () => 'Syntax ERROR',
              isShift: false,
              isAlpha: false,
            ),
          );
          return;
        }
        final String nextF = target == 'f' ? exprEval : _state.definedFunctionF;
        final String nextG = target == 'g' ? exprEval : _state.definedFunctionG;
        _editor.clear();
        _syncEditorToState(
          definingPromptTarget: () => null,
          definedFunctionF: nextF,
          definedFunctionG: nextG,
          hasFunctionDefined: nextF.isNotEmpty || nextG.isNotEmpty,
          isResultDisplayed: false,
          resultText: '',
        );
        return;
      } else {
        if (_editor.isEmpty) {
          _syncEditorToState(definingPromptTarget: () => null);
          return;
        }
        final evaluator = MathExpressionEvaluator(
          angleUnit: _state.angleUnit,
          numberFormat: _state.numberFormat,
          formatDigits: _state.formatDigits,
          variables: _state.variables,
          definedFunctionF: _state.definedFunctionF,
          definedFunctionG: _state.definedFunctionG,
        );
        final evalResult = evaluator.evaluateVisualAst(
          _editor.root,
          forceDecimal: false,
        );
        if (evalResult.error != null) {
          _emit(_state.copyWith(errorMessage: () => evalResult.error));
          return;
        }
        final updatedVars = Map<String, String>.from(_state.variables);
        updatedVars[target] = evalResult.decimalText;
        _lastEvalResult = evalResult;
        _editor.moveToRootEnd();
        _syncEditorToState(
          definingPromptTarget: () => null,
          variables: updatedVars,
          resultText: '$target = ${evalResult.primaryText}',
          isResultDisplayed: true,
        );
        return;
      }
    }

    if (_editor.isEmpty) {
      _emit(_state.copyWith(isShift: false, isAlpha: false));
      return;
    }

    final String exprEval;
    try {
      exprEval = _editor.root.toEvalString();
    } on FormatException {
      _emit(
        _state.copyWith(
          errorMessage: () => 'Syntax ERROR',
          isShift: false,
          isAlpha: false,
        ),
      );
      return;
    }

    // 1. Complex Mode Evaluation
    if (_state.activeMode == AppMode.complex) {
      String cleanCmpExpr = exprEval.trim();
      bool? forcePolar;
      if (cleanCmpExpr.endsWith('►r∠θ')) {
        cleanCmpExpr = cleanCmpExpr.substring(0, cleanCmpExpr.length - 4);
        forcePolar = true;
      } else if (cleanCmpExpr.endsWith('►a+bi')) {
        cleanCmpExpr = cleanCmpExpr.substring(0, cleanCmpExpr.length - 5);
        forcePolar = false;
      }
      final cmpRes = ComplexExpressionEvaluator(
        angleUnit: _state.angleUnit,
      ).evaluate(cleanCmpExpr);
      if (cmpRes.error != null) {
        _emit(_state.copyWith(errorMessage: () => cmpRes.error, isShift: false));
        return;
      }
      _lastComplexResult = cmpRes.value;
      final bool usePolar = forcePolar ?? _state.complexPolarDisplay;
      final String displayText = usePolar
          ? cmpRes.polarText
          : cmpRes.rectangularText;
      final String altText = usePolar
          ? cmpRes.rectangularText
          : cmpRes.polarText;
      _editor.moveToRootEnd();
      _syncEditorToState(
        resultText: displayText,
        alternateResultText: () => altText,
        isResultDisplayed: true,
      );
      return;
    }

    // 2. Base-N Mode Evaluation
    if (_state.activeMode == AppMode.baseN) {
      final bnRes = BaseNEngine.evaluate(exprEval, _state.activeBase);
      if (bnRes.error != null) {
        _emit(_state.copyWith(errorMessage: () => bnRes.error, isShift: false));
        return;
      }
      _lastBaseNResult = bnRes.value;
      _editor.moveToRootEnd();
      _syncEditorToState(
        resultText: bnRes.formatted,
        isResultDisplayed: true,
      );
      return;
    }

    // 3. Matrix Mode Evaluation
    if (_state.activeMode == AppMode.matrix) {
      final laEval = LinearAlgebraEvaluator(
        matrices: _state.matrices,
        vectors: _state.vectors,
        angleUnit: _state.angleUnit,
      );
      final res = laEval.evaluateMatrixExpression(exprEval);
      if (res.error != null) {
        _emit(_state.copyWith(errorMessage: () => res.error, isShift: false));
        return;
      }
      if (res.matrixResult != null) {
        setMatrix('MatAns', res.matrixResult!);
      }
      _editor.moveToRootEnd();
      _syncEditorToState(
        resultText: res.displayText,
        isResultDisplayed: true,
      );
      return;
    }

    // 4. Vector Mode Evaluation
    if (_state.activeMode == AppMode.vector) {
      final laEval = LinearAlgebraEvaluator(
        matrices: _state.matrices,
        vectors: _state.vectors,
        angleUnit: _state.angleUnit,
      );
      final res = laEval.evaluateVectorExpression(exprEval);
      if (res.error != null) {
        _emit(_state.copyWith(errorMessage: () => res.error, isShift: false));
        return;
      }
      if (res.vectorResult != null) {
        setVector('VctAns', res.vectorResult!);
      }
      _editor.moveToRootEnd();
      _syncEditorToState(
        resultText: res.displayText,
        isResultDisplayed: true,
      );
      return;
    }

    // 5. Verify Mode (`TRUE` / `FALSE` relational check in Calculate mode: =, ≠, >, <, ≥, ≤)
    if (_state.activeMode == AppMode.calculate && _state.isVerifyMode) {
      for (final relOp in const ['≠', '≥', '≤', '=', '>', '<']) {
        if (exprEval.contains(relOp)) {
          final parts = exprEval.split(relOp);
          if (parts.length == 2) {
            final leftRes =
                evaluateExpressionString(parts[0], forceDecimal: true);
            final rightRes =
                evaluateExpressionString(parts[1], forceDecimal: true);
            if (leftRes.error == null && rightRes.error == null) {
              final double a = double.tryParse(leftRes.decimalText) ?? 0.0;
              final double b = double.tryParse(rightRes.decimalText) ?? 1.0;
              final bool holds = switch (relOp) {
                '=' => (a - b).abs() < 1e-11,
                '≠' => (a - b).abs() >= 1e-11,
                '≥' => a > b - 1e-11,
                '≤' => a < b + 1e-11,
                '>' => a > b + 1e-11,
                '<' => a < b - 1e-11,
                _ => false,
              };
              final String verdict = holds ? 'TRUE' : 'FALSE';
              _editor.moveToRootEnd();
              _syncEditorToState(
                resultText: verdict,
                isResultDisplayed: true,
              );
              return;
            }
          }
          break;
        }
      }
    }

    // 6. Standard Calculate Mode Evaluation
    final bool forceDecimal = _state.isShift || !_state.ioMode.isExactOutput;
    final exprDisplay = _editor.root.toDisplayString();
    final evaluator = MathExpressionEvaluator(
      angleUnit: _state.angleUnit,
      numberFormat: _state.numberFormat,
      formatDigits: _state.formatDigits,
      variables: _state.variables,
      definedFunctionF: _state.definedFunctionF,
      definedFunctionG: _state.definedFunctionG,
    );
    final evalResult = evaluator.evaluateVisualAst(
      _editor.root,
      forceDecimal: forceDecimal,
    );

    if (evalResult.error != null) {
      _emit(
        _state.copyWith(
          errorMessage: () => evalResult.error,
          isShift: false,
          isAlpha: false,
        ),
      );
      return;
    }

    _lastEvalResult = evalResult;

    final updatedVars = Map<String, String>.from(_state.variables);
    updatedVars['PreAns'] = updatedVars['Ans'] ?? '0';
    updatedVars['Ans'] = evalResult.decimalText;
    if (evalResult.assignedVariable != null) {
      updatedVars[evalResult.assignedVariable!] = evalResult.decimalText;
    }

    String displayResult = evalResult.primaryText;
    if (!forceDecimal &&
        _state.fractionPreference == FractionResultPreference.mixed &&
        evalResult.mixedFractionText != null) {
      displayResult = evalResult.mixedFractionText!;
    }
    if (_state.engSymbolOn &&
        !forceDecimal &&
        evalResult.exactText == null &&
        evalResult.decimalValue != null) {
      displayResult = Cal_FormatConverter.formatEngineering(
        evalResult.decimalValue!,
        stepShift: 0,
        useSiSymbols: true,
      );
    }

    final clonedSnapshot = _editor.clone();
    final updatedHistory = List<CalculationHistoryEntry>.from(_state.history);
    updatedHistory.add(
      CalculationHistoryEntry(
        tokens: _flattenRootTokens(clonedSnapshot.root),
        rootNode: clonedSnapshot.root,
        expressionText: exprDisplay,
        resultText: displayResult,
        mode: _state.activeMode,
      ),
    );
    if (updatedHistory.length > 30) {
      updatedHistory.removeAt(0);
    }

    _editor.moveToRootEnd();
    _syncEditorToState(
      resultText: displayResult,
      alternateResultText: () => evalResult.alternateText,
      isResultDisplayed: true,
      isShowingExactForm: displayResult == evalResult.exactText &&
          evalResult.exactText != evalResult.decimalText,
      activeFormatView: forceDecimal
          ? OutputFormatView.decimal
          : OutputFormatView.standard,
      engStepShift: 0,
      variables: updatedVars,
      history: updatedHistory,
      historyCursor: -1,
    );
  }
}

/// InheritedNotifier scope exposing [CalculatorController] across the widget tree.
class CalculatorScope extends InheritedNotifier<CalculatorController> {
  const CalculatorScope({
    super.key,
    required CalculatorController controller,
    required super.child,
  }) : super(notifier: controller);

  static CalculatorController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<CalculatorScope>();
    assert(scope != null, 'No CalculatorScope found in widget tree');
    return scope!.notifier!;
  }
}
