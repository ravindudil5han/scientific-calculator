import 'dart:math' as math;
import '../math_engine/math_expression_evaluator.dart';
import '../state/calculator_models.dart';
import 'linear_algebra_engine.dart';

/// Represents a single row in the `Table` app ($x, f(x)[, g(x)]$).
class TableRowEntry {
  final double x;
  final String fxText;
  final String? gxText;

  const TableRowEntry({
    required this.x,
    required this.fxText,
    this.gxText,
  });
}

/// Engine for the `Table` app generating concurrent evaluation tables for $f(x)$ and $g(x)$.
class TableAppEngine {
  static ({List<TableRowEntry> rows, String? error}) generateTable({
    required String definedF,
    String definedG = '',
    required double start,
    required double end,
    required double step,
    AngleUnit angleUnit = AngleUnit.degree,
    Map<String, String> variables = const {},
  }) {
    if (definedF.trim().isEmpty) {
      return (rows: const [], error: 'Syntax ERROR');
    }
    if (step == 0 || (end > start && step < 0) || (end < start && step > 0)) {
      return (rows: const [], error: 'Argument ERROR');
    }

    final int count = ((end - start) / step).floor() + 1;
    final int maxRows = definedG.trim().isNotEmpty ? 30 : 45;
    if (count < 1 || count > maxRows) {
      return (rows: const [], error: 'Range ERROR');
    }

    final List<TableRowEntry> rows = [];
    for (int i = 0; i < count; i++) {
      final double xVal = start + i * step;
      final row = evaluateSingleRow(
        xVal: xVal,
        definedF: definedF,
        definedG: definedG,
        angleUnit: angleUnit,
        variables: variables,
      );
      rows.add(row);
    }
    return (rows: rows, error: null);
  }

  static TableRowEntry evaluateSingleRow({
    required double xVal,
    required String definedF,
    String definedG = '',
    AngleUnit angleUnit = AngleUnit.degree,
    Map<String, String> variables = const {},
  }) {
    final varsWithX = Map<String, String>.from(variables);
    varsWithX['x'] = formatCal_Scalar(xVal);
    final evaluator = MathExpressionEvaluator(
      angleUnit: angleUnit,
      variables: varsWithX,
      definedFunctionF: definedF,
      definedFunctionG: definedG,
    );

    final fRes = evaluator.evaluateString(definedF, forceDecimal: true);
    final String fStr = fRes.error != null ? 'ERROR' : fRes.decimalText;

    String? gStr;
    if (definedG.trim().isNotEmpty) {
      final gRes = evaluator.evaluateString(definedG, forceDecimal: true);
      gStr = gRes.error != null ? 'ERROR' : gRes.decimalText;
    }

    return TableRowEntry(x: xVal, fxText: fStr, gxText: gStr);
  }
}

/// 5-column ($A$–$E$) $\times$ 45-row ($1$–$45$) reactive `Spreadsheet` engine.
class SpreadsheetSheet {
  static const int numCols = 5; // A..E
  static const int numRows = 45; // 1..45
  static const List<String> colNames = ['A', 'B', 'C', 'D', 'E'];

  /// Raw formulas or literal strings indexed by cell key (e.g. `'A1': '10'`, `'C1': '=A1+B1'`).
  final Map<String, String> rawCells;

  /// Evaluated display values indexed by cell key.
  final Map<String, String> evaluatedCells;

  /// Evaluated numeric values indexed by cell key.
  final Map<String, double> numericCells;

  const SpreadsheetSheet({
    this.rawCells = const {},
    this.evaluatedCells = const {},
    this.numericCells = const {},
  });

  static String cellKey(int row, int col) {
    final String c = colNames[col.clamp(0, numCols - 1)];
    final int r = row.clamp(0, numRows - 1) + 1;
    return '$c$r';
  }

  static (int row, int col)? parseCellRef(String ref) {
    final clean = ref.replaceAll(r'$', '').trim().toUpperCase();
    final match = RegExp(r'^([A-E])(\d{1,2})$').firstMatch(clean);
    if (match == null) return null;
    final int col = colNames.indexOf(match.group(1)!);
    final int? rowOneBased = int.tryParse(match.group(2)!);
    if (col < 0 ||
        rowOneBased == null ||
        rowOneBased < 1 ||
        rowOneBased > numRows) {
      return null;
    }
    return (rowOneBased - 1, col);
  }

  String getRaw(int row, int col) => rawCells[cellKey(row, col)] ?? '';
  String getDisplay(int row, int col) =>
      evaluatedCells[cellKey(row, col)] ?? '';

  /// Updates a single cell and recalculates all dependent cells in the sheet.
  SpreadsheetSheet setCell(int row, int col, String input) {
    final nextRaw = Map<String, String>.from(rawCells);
    final String key = cellKey(row, col);
    if (input.trim().isEmpty) {
      nextRaw.remove(key);
    } else {
      nextRaw[key] = input.trim();
    }
    return recalculate(nextRaw);
  }

  /// Fills a rectangular cell range (e.g. `A1:A5`) with a formula or value,
  /// shifting relative cell references when `isFormula` is true.
  SpreadsheetSheet fillRange({
    required String rangeSpec,
    required String formulaOrValue,
    bool shiftRelativeRefs = true,
  }) {
    final parts = rangeSpec.split(':');
    if (parts.length != 2) return this;
    final startCoord = parseCellRef(parts[0]);
    final endCoord = parseCellRef(parts[1]);
    if (startCoord == null || endCoord == null) return this;

    final int rMin = math.min(startCoord.$1, endCoord.$1);
    final int rMax = math.max(startCoord.$1, endCoord.$1);
    final int cMin = math.min(startCoord.$2, endCoord.$2);
    final int cMax = math.max(startCoord.$2, endCoord.$2);

    final nextRaw = Map<String, String>.from(rawCells);
    for (int r = rMin; r <= rMax; r++) {
      for (int c = cMin; c <= cMax; c++) {
        final int dRow = r - rMin;
        final int dCol = c - cMin;
        final String cellExpr = (shiftRelativeRefs &&
                formulaOrValue.startsWith('='))
            ? _shiftFormulaReferences(formulaOrValue, dRow, dCol)
            : formulaOrValue;
        nextRaw[cellKey(r, c)] = cellExpr;
      }
    }
    return recalculate(nextRaw);
  }

  static String _shiftFormulaReferences(String formula, int dRow, int dCol) {
    return formula.replaceAllMapped(
      RegExp(r'(\$?)([A-Ea-e])(\$?)(\d{1,2})'),
      (m) {
        final bool lockCol = m.group(1) == r'$';
        final String colChar = m.group(2)!.toUpperCase();
        final bool lockRow = m.group(3) == r'$';
        final int rowNum = int.parse(m.group(4)!);

        final int baseCol = colNames.indexOf(colChar);
        final int newCol =
            lockCol ? baseCol : (baseCol + dCol).clamp(0, numCols - 1);
        final int newRow =
            lockRow ? rowNum : (rowNum + dRow).clamp(1, numRows);

        return '${lockCol ? r"$" : ""}${colNames[newCol]}${lockRow ? r"$" : ""}$newRow';
      },
    );
  }

  static SpreadsheetSheet recalculate(Map<String, String> nextRaw) {
    final Map<String, String> nextEval = {};
    final Map<String, double> nextNum = {};
    final Set<String> visiting = {};

    double evalCellByKey(String key) {
      if (nextNum.containsKey(key)) return nextNum[key]!;
      if (visiting.contains(key)) {
        throw const FormatException('Circular ERROR');
      }
      final String? raw = nextRaw[key];
      if (raw == null || raw.trim().isEmpty) {
        return 0.0;
      }
      visiting.add(key);
      try {
        final double val = _evaluateCellFormula(raw, evalCellByKey);
        visiting.remove(key);
        nextNum[key] = val;
        nextEval[key] = formatCal_Scalar(val);
        return val;
      } catch (e) {
        visiting.remove(key);
        rethrow;
      }
    }

    for (final key in nextRaw.keys) {
      try {
        evalCellByKey(key);
      } on FormatException catch (e) {
        nextEval[key] = e.message;
      } catch (_) {
        nextEval[key] = 'ERROR';
      }
    }

    return SpreadsheetSheet(
      rawCells: nextRaw,
      evaluatedCells: nextEval,
      numericCells: nextNum,
    );
  }

  static double _evaluateCellFormula(
    String raw,
    double Function(String key) lookupCell,
  ) {
    final String trimmed = raw.trim();
    if (!trimmed.startsWith('=')) {
      final double? lit = double.tryParse(trimmed);
      if (lit != null) return lit;
      final res = const MathExpressionEvaluator().evaluateString(
        trimmed,
        forceDecimal: true,
      );
      if (res.error != null) throw FormatException(res.error!);
      return double.tryParse(res.decimalText) ?? 0.0;
    }

    String expr = trimmed.substring(1).trim();

    // 1. Expand aggregate range functions: Sum(A1:B3), Mean(A1:A5), Min(A1:A5), Max(A1:A5)
    expr = expr.replaceAllMapped(
      RegExp(
        r'(Sum|SUM|Mean|MEAN|Min|MIN|Max|MAX)\(\s*\$?[A-Ea-e]\$?\d{1,2}\s*:\s*\$?[A-Ea-e]\$?\d{1,2}\s*\)',
      ),
      (m) {
        final full = m.group(0)!;
        final openParen = full.indexOf('(');
        final fnName = full.substring(0, openParen).toUpperCase();
        final rangePart = full.substring(openParen + 1, full.length - 1);
        final endpoints = rangePart.split(':');
        final c1 = parseCellRef(endpoints[0]);
        final c2 = parseCellRef(endpoints[1]);
        if (c1 == null || c2 == null) {
          throw const FormatException('Syntax ERROR');
        }
        final int rMin = math.min(c1.$1, c2.$1);
        final int rMax = math.max(c1.$1, c2.$1);
        final int colMin = math.min(c1.$2, c2.$2);
        final int colMax = math.max(c1.$2, c2.$2);

        final List<double> values = [];
        for (int r = rMin; r <= rMax; r++) {
          for (int c = colMin; c <= colMax; c++) {
            values.add(lookupCell(cellKey(r, c)));
          }
        }
        if (values.isEmpty) return '0';
        final double agg = switch (fnName) {
          'SUM' => values.fold(0.0, (a, b) => a + b),
          'MEAN' => values.fold(0.0, (a, b) => a + b) / values.length,
          'MIN' => values.reduce(math.min),
          'MAX' => values.reduce(math.max),
          _ => 0.0,
        };
        return agg.toString();
      },
    );

    // 2. Replace individual cell references (`A1`, `$B$2`) with their numeric values
    expr = expr.replaceAllMapped(
      RegExp(r'\$?([A-Ea-e])\$?(\d{1,2})\b'),
      (m) {
        final String ref = '${m.group(1)!.toUpperCase()}${m.group(2)!}';
        final parsed = parseCellRef(ref);
        if (parsed == null) throw const FormatException('Syntax ERROR');
        final double v = lookupCell(cellKey(parsed.$1, parsed.$2));
        return '($v)';
      },
    );

    final evalRes = const MathExpressionEvaluator().evaluateString(
      expr,
      forceDecimal: true,
    );
    if (evalRes.error != null) {
      throw FormatException(evalRes.error!);
    }
    return double.tryParse(evalRes.decimalText) ?? 0.0;
  }
}

/// Active sub-tool inside the `Math Box` app.
enum MathBoxSubTool {
  menu('Math Box'),
  diceRoll('Dice Roll'),
  coinToss('Coin Toss'),
  numberLine('Number Line'),
  circle('Circle');

  final String title;
  const MathBoxSubTool(this.title);
}

/// Result of a `Dice Roll` or `Coin Toss` simulation in `Math Box`.
class MathBoxSimulationResult {
  final MathBoxSubTool tool;
  final int itemCount; // 1..3 dice or coins
  final int attempts; // 1..250 tosses
  final List<int> outcomes; // sum per trial (dice: 1..18, coins: 0..3 heads)
  final Map<int, int> frequencies; // outcome -> count

  const MathBoxSimulationResult({
    required this.tool,
    required this.itemCount,
    required this.attempts,
    required this.outcomes,
    required this.frequencies,
  });

  List<String> get summaryLines {
    final List<String> lines = [];
    final sortedKeys = frequencies.keys.toList()..sort();
    for (final k in sortedKeys) {
      final int f = frequencies[k] ?? 0;
      final double rel = attempts > 0 ? f / attempts : 0.0;
      final String label =
          tool == MathBoxSubTool.diceRoll ? 'Sum $k' : '$k Heads';
      lines.add('$label: $f (${formatCal_Scalar(rel, precision: 4)})');
    }
    return lines;
  }

  /// Generates trial-by-trial `List` view lines (`#1: 7`, `#2: 4`, ...).
  List<String> get trialListLines {
    final List<String> lines = [];
    for (int i = 0; i < outcomes.length; i++) {
      final String unit = tool == MathBoxSubTool.diceRoll ? 'Sum' : 'Heads';
      lines.add('#${i + 1}: $unit = ${outcomes[i]}');
    }
    return lines;
  }
}

/// Simulation engine for `Math Box` (`Dice Roll`, `Coin Toss`, `Number Line`, and `Circle`).
class MathBoxEngine {
  /// Simulates rolling [diceCount] (1..3) six-sided dice for [attempts] (1..250) trials.
  static MathBoxSimulationResult runDiceRoll({
    required int diceCount,
    required int attempts,
    int? seed,
  }) {
    final int nDice = diceCount.clamp(1, 3);
    final int nTrials = attempts.clamp(1, 250);
    final rng = math.Random(seed);

    final Map<int, int> freq = {
      for (int s = nDice; s <= nDice * 6; s++) s: 0,
    };
    final List<int> outcomes = [];

    for (int t = 0; t < nTrials; t++) {
      int sum = 0;
      for (int d = 0; d < nDice; d++) {
        sum += rng.nextInt(6) + 1;
      }
      outcomes.add(sum);
      freq[sum] = (freq[sum] ?? 0) + 1;
    }

    return MathBoxSimulationResult(
      tool: MathBoxSubTool.diceRoll,
      itemCount: nDice,
      attempts: nTrials,
      outcomes: outcomes,
      frequencies: freq,
    );
  }

  /// Simulates tossing [coinCount] (1..3) fair coins for [attempts] (1..250) trials.
  static MathBoxSimulationResult runCoinToss({
    required int coinCount,
    required int attempts,
    int? seed,
  }) {
    final int nCoins = coinCount.clamp(1, 3);
    final int nTrials = attempts.clamp(1, 250);
    final rng = math.Random(seed);

    final Map<int, int> freq = {
      for (int h = 0; h <= nCoins; h++) h: 0,
    };
    final List<int> outcomes = [];

    for (int t = 0; t < nTrials; t++) {
      int heads = 0;
      for (int c = 0; c < nCoins; c++) {
        if (rng.nextBool()) heads++;
      }
      outcomes.add(heads);
      freq[heads] = (freq[heads] ?? 0) + 1;
    }

    return MathBoxSimulationResult(
      tool: MathBoxSubTool.coinToss,
      itemCount: nCoins,
      attempts: nTrials,
      outcomes: outcomes,
      frequencies: freq,
    );
  }

  /// Evaluates `Math Box -> Circle -> Unit Circle` for angle [thetaDeg] in degrees.
  static List<String> buildUnitCircleLines(double thetaDeg) {
    final double rad = thetaDeg * math.pi / 180.0;
    final double s = math.sin(rad);
    final double c = math.cos(rad);
    final String tanStr = (c.abs() < 1e-12)
        ? 'Undefined'
        : formatCal_Scalar(s / c, precision: 6);
    return [
      'θ = ${formatCal_Scalar(thetaDeg)}°',
      'sin(θ) = ${formatCal_Scalar(s, precision: 6)}',
      'cos(θ) = ${formatCal_Scalar(c, precision: 6)}',
      'tan(θ) = $tanStr',
    ];
  }

  /// Evaluates `Math Box -> Circle -> Clock` hand angles at [hour] : [minute].
  static List<String> buildClockAngleLines(int hour, int minute) {
    final int h = hour % 12;
    final int m = minute.clamp(0, 59);
    final double hourAngle = 30.0 * h + 0.5 * m;
    final double minAngle = 6.0 * m;
    double diff = (hourAngle - minAngle).abs();
    if (diff > 180.0) diff = 360.0 - diff;
    final String hh = (hour % 12 == 0 ? 12 : hour % 12).toString().padLeft(2, '0');
    final String mm = m.toString().padLeft(2, '0');
    return [
      'Time = $hh:$mm',
      'Hour Hand = ${formatCal_Scalar(hourAngle)}°',
      'Min Hand = ${formatCal_Scalar(minAngle)}°',
      'Angle Δθ = ${formatCal_Scalar(diff)}°',
    ];
  }
}
