import 'dart:math' as math;
import 'linear_algebra_engine.dart';

/// Represents a real or complex root $a + bi$ of a polynomial.
class ComplexRoot {
  final double real;
  final double imag;

  const ComplexRoot(this.real, [this.imag = 0.0]);

  bool get isReal => imag.abs() < 1e-8;

  ComplexRoot operator +(ComplexRoot other) =>
      ComplexRoot(real + other.real, imag + other.imag);

  ComplexRoot operator -(ComplexRoot other) =>
      ComplexRoot(real - other.real, imag - other.imag);

  ComplexRoot operator *(ComplexRoot other) => ComplexRoot(
        real * other.real - imag * other.imag,
        real * other.imag + imag * other.real,
      );

  ComplexRoot operator /(ComplexRoot other) {
    final double denom = other.real * other.real + other.imag * other.imag;
    if (denom == 0.0) return const ComplexRoot(double.nan, double.nan);
    return ComplexRoot(
      (real * other.real + imag * other.imag) / denom,
      (imag * other.real - real * other.imag) / denom,
    );
  }

  double get modulus => math.sqrt(real * real + imag * imag);

  String toCal_String() {
    final double r = real.abs() < 1e-10 ? 0.0 : real;
    final double im = imag.abs() < 1e-10 ? 0.0 : imag;
    if (im == 0.0) {
      return formatCal_Scalar(r);
    }
    final String imAbsStr =
        (im.abs() - 1.0).abs() < 1e-10 ? '' : formatCal_Scalar(im.abs());
    if (r == 0.0) {
      return '${im < 0 ? "-" : ""}${imAbsStr}i';
    }
    final String sign = im >= 0 ? '+' : '-';
    return '${formatCal_Scalar(r)}$sign${imAbsStr}i';
  }
}

/// Result of solving a Simultaneous Linear Equation system ($2, 3,$ or $4$ unknowns).
class SimulEquationResult {
  /// Map of variable name (`x`, `y`, `z`, `t`) to formatted value.
  final Map<String, String> solutions;
  final Map<String, double> numericSolutions;

  /// Special status message (`Infinite Solutions`, `No Solution`, or `Math ERROR`).
  final String? statusMessage;

  const SimulEquationResult({
    this.solutions = const {},
    this.numericSolutions = const {},
    this.statusMessage,
  });

  bool get hasUniqueSolution => statusMessage == null && solutions.isNotEmpty;

  List<String> get displayLines {
    if (statusMessage != null) return [statusMessage!];
    return solutions.entries.map((e) => '${e.key} = ${e.value}').toList();
  }
}

/// Solves Simultaneous Linear Equations in 2, 3, or 4 unknowns ($A\mathbf{x} = \mathbf{b}$)
/// using Gauss-Jordan elimination with partial pivoting and rank analysis.
class SimulEquationSolver {
  static const List<String> varNames = ['x', 'y', 'z', 't'];

  /// [augmentedMatrix] has dimensions $n \times (n + 1)$, where $n \in \{2, 3, 4\}$.
  static SimulEquationResult solve(List<List<double>> augmentedMatrix) {
    final int n = augmentedMatrix.length;
    if (n < 2 || n > 4) {
      return const SimulEquationResult(statusMessage: 'Dimension ERROR');
    }

    final List<List<double>> aug = List.generate(
      n,
      (r) => List<double>.from(augmentedMatrix[r]),
    );

    int pivotRow = 0;
    final List<int> pivotCols = [];

    for (int col = 0; col < n && pivotRow < n; col++) {
      int bestRow = pivotRow;
      double maxAbs = aug[pivotRow][col].abs();
      for (int r = pivotRow + 1; r < n; r++) {
        if (aug[r][col].abs() > maxAbs) {
          maxAbs = aug[r][col].abs();
          bestRow = r;
        }
      }

      if (maxAbs < 1e-11) {
        continue;
      }

      if (bestRow != pivotRow) {
        final tmp = aug[pivotRow];
        aug[pivotRow] = aug[bestRow];
        aug[bestRow] = tmp;
      }

      final double pivotVal = aug[pivotRow][col];
      for (int j = col; j <= n; j++) {
        aug[pivotRow][j] /= pivotVal;
      }

      for (int r = 0; r < n; r++) {
        if (r != pivotRow) {
          final double factor = aug[r][col];
          if (factor.abs() > 1e-14) {
            for (int j = col; j <= n; j++) {
              aug[r][j] -= factor * aug[pivotRow][j];
            }
          }
        }
      }

      pivotCols.add(col);
      pivotRow++;
    }

    // Check rows below rank(A) for inconsistency (0 = non-zero -> No Solution)
    for (int r = pivotRow; r < n; r++) {
      if (aug[r][n].abs() > 1e-9) {
        return const SimulEquationResult(statusMessage: 'No Solution');
      }
    }

    if (pivotRow < n) {
      return const SimulEquationResult(statusMessage: 'Infinite Solutions');
    }

    final Map<String, String> formatted = {};
    final Map<String, double> numeric = {};
    for (int i = 0; i < n; i++) {
      double val = aug[i][n];
      if (val.abs() < 1e-12) val = 0.0;
      final rounded = val.roundToDouble();
      if ((val - rounded).abs() < 1e-10) val = rounded;
      numeric[varNames[i]] = val;
      formatted[varNames[i]] = formatCal_Scalar(val);
    }

    return SimulEquationResult(
      solutions: formatted,
      numericSolutions: numeric,
    );
  }
}

/// Result of solving a Polynomial Equation of degree 2, 3, or 4.
class PolynomialSolveResult {
  final int degree;
  final List<ComplexRoot> roots;
  final String? extremumLabel; // 'Minimum' or 'Maximum' for quadratics
  final double? vertexX;
  final double? vertexY;
  final List<(double, double)> cubicExtrema;
  final String? error;

  const PolynomialSolveResult({
    required this.degree,
    this.roots = const [],
    this.extremumLabel,
    this.vertexX,
    this.vertexY,
    this.cubicExtrema = const [],
    this.error,
  });

  List<String> get displayLines {
    if (error != null) return [error!];
    final List<String> lines = [];
    for (int i = 0; i < roots.length; i++) {
      lines.add('x${i + 1} = ${roots[i].toCal_String()}');
    }
    if (extremumLabel != null && vertexX != null && vertexY != null) {
      lines.add(
        '$extremumLabel: (${formatCal_Scalar(vertexX!)}, ${formatCal_Scalar(vertexY!)})',
      );
    }
    for (final ext in cubicExtrema) {
      lines.add(
        'Extremum: (${formatCal_Scalar(ext.$1)}, ${formatCal_Scalar(ext.$2)})',
      );
    }
    return lines;
  }
}

/// Solves Polynomial Equations of degrees 2, 3, and 4 ($a_n x^n + \dots + a_0 = 0$)
/// for all real and complex roots, plus parabola vertex/extrema.
class PolynomialSolver {
  /// [coefficients] in descending power order:
  /// - Degree 2: `[a, b, c]` for $ax^2 + bx + c = 0$
  /// - Degree 3: `[a, b, c, d]` for $ax^3 + bx^2 + cx + d = 0$
  /// - Degree 4: `[a, b, c, d, e]` for $ax^4 + bx^3 + cx^2 + dx + e = 0$
  static PolynomialSolveResult solve(List<double> coefficients) {
    final int degree = coefficients.length - 1;
    if (degree < 2 || degree > 4) {
      return PolynomialSolveResult(degree: degree, error: 'Argument ERROR');
    }

    // Leading coefficient a == 0 is a degenerate case -> Math ERROR on Cal_ 1100_DB_
    final double a = coefficients[0];
    if (a.abs() < 1e-13) {
      return PolynomialSolveResult(degree: degree, error: 'Math ERROR');
    }

    if (degree == 2) {
      return _solveQuadratic(coefficients[0], coefficients[1], coefficients[2]);
    }

    // Normalize monic polynomial x^n + c_{n-1}x^{n-1} + ... + c_0 = 0
    final List<double> monic =
        coefficients.map((c) => c / a).toList(growable: false);
    final List<ComplexRoot> rawRoots = _durandKernerAberthSolve(monic);
    final List<ComplexRoot> cleanedRoots = _deduplicateAndSortRoots(rawRoots);

    // Compute local extrema for cubics (3ax^2 + 2bx + c = 0)
    final List<(double, double)> cubicExt = [];
    if (degree == 3) {
      final double b = coefficients[1];
      final double c = coefficients[2];
      final double d = coefficients[3];
      final double disc = 4 * b * b - 12 * a * c;
      if (disc >= 0) {
        final double sqrtDisc = math.sqrt(disc);
        final double x1 = (-2 * b - sqrtDisc) / (6 * a);
        final double x2 = (-2 * b + sqrtDisc) / (6 * a);
        double evalCubic(double x) => ((a * x + b) * x + c) * x + d;
        cubicExt.add((x1, evalCubic(x1)));
        if ((x2 - x1).abs() > 1e-8) {
          cubicExt.add((x2, evalCubic(x2)));
        }
      }
    }

    return PolynomialSolveResult(
      degree: degree,
      roots: cleanedRoots,
      cubicExtrema: cubicExt,
    );
  }

  static PolynomialSolveResult _solveQuadratic(double a, double b, double c) {
    final double vx = -b / (2.0 * a);
    final double vy = c - (b * b) / (4.0 * a);
    final String extType = a > 0 ? 'Minimum' : 'Maximum';

    final double disc = b * b - 4.0 * a * c;
    final List<ComplexRoot> roots;
    if (disc.abs() < 1e-12) {
      roots = [ComplexRoot(vx)];
    } else if (disc > 0) {
      final double sqrtD = math.sqrt(disc);
      // Numerically stable Citardauq / quadratic root formula
      final double r1 = (-b + sqrtD) / (2.0 * a);
      final double r2 = (-b - sqrtD) / (2.0 * a);
      final sorted = [r1, r2]..sort();
      roots = [ComplexRoot(sorted[0]), ComplexRoot(sorted[1])];
    } else {
      final double imagPart = math.sqrt(-disc) / (2.0 * a).abs();
      roots = [
        ComplexRoot(vx, imagPart),
        ComplexRoot(vx, -imagPart),
      ];
    }

    return PolynomialSolveResult(
      degree: 2,
      roots: roots,
      extremumLabel: extType,
      vertexX: vx.abs() < 1e-12 ? 0.0 : vx,
      vertexY: vy.abs() < 1e-12 ? 0.0 : vy,
    );
  }

  /// Solves monic polynomial $P(z) = z^n + c_1 z^{n-1} + \dots + c_n = 0$
  /// using Aberth-Ehrlich simultaneous iteration (with Cauchy bound initialization).
  static List<ComplexRoot> _durandKernerAberthSolve(List<double> monic) {
    final int n = monic.length - 1;
    double maxCoeff = 0.0;
    for (int i = 1; i <= n; i++) {
      if (monic[i].abs() > maxCoeff) maxCoeff = monic[i].abs();
    }
    final double radius = 1.0 + maxCoeff;

    // Initialize roots asymmetrically on a circle of radius `radius * 0.65`
    final List<ComplexRoot> z = List.generate(n, (k) {
      final double angle = (2.0 * math.pi * k / n) + 0.37;
      return ComplexRoot(
        radius * 0.65 * math.cos(angle),
        radius * 0.65 * math.sin(angle),
      );
    });

    ComplexRoot evalPoly(ComplexRoot x) {
      ComplexRoot acc = const ComplexRoot(1.0, 0.0);
      for (int i = 1; i <= n; i++) {
        acc = (acc * x) + ComplexRoot(monic[i], 0.0);
      }
      return acc;
    }

    ComplexRoot evalPolyDeriv(ComplexRoot x) {
      ComplexRoot acc = ComplexRoot(n.toDouble(), 0.0);
      for (int i = 1; i < n; i++) {
        acc = (acc * x) + ComplexRoot((n - i) * monic[i], 0.0);
      }
      return acc;
    }

    for (int iter = 0; iter < 150; iter++) {
      double maxStep = 0.0;
      for (int i = 0; i < n; i++) {
        final pVal = evalPoly(z[i]);
        if (pVal.modulus < 1e-15) continue;
        final dVal = evalPolyDeriv(z[i]);
        if (dVal.modulus < 1e-14) continue;

        final ComplexRoot newtonRatio = pVal / dVal;
        ComplexRoot sumInv = const ComplexRoot(0.0, 0.0);
        for (int j = 0; j < n; j++) {
          if (i != j) {
            final diff = z[i] - z[j];
            if (diff.modulus > 1e-14) {
              sumInv = sumInv + (const ComplexRoot(1.0, 0.0) / diff);
            }
          }
        }

        final denom = const ComplexRoot(1.0, 0.0) - (newtonRatio * sumInv);
        final offset = denom.modulus > 1e-14
            ? newtonRatio / denom
            : newtonRatio;
        z[i] = z[i] - offset;
        if (offset.modulus > maxStep) {
          maxStep = offset.modulus;
        }
      }
      if (maxStep < 1e-14) break;
    }

    // Snap near-integers and near-real roots
    return z.map((r) {
      double re = r.real;
      double im = r.imag;
      if (im.abs() < 1e-7) im = 0.0;
      if ((re - re.roundToDouble()).abs() < 1e-7) re = re.roundToDouble();
      if ((im - im.roundToDouble()).abs() < 1e-7) im = im.roundToDouble();
      if (re.abs() < 1e-11) re = 0.0;
      return ComplexRoot(re, im);
    }).toList();
  }

  static List<ComplexRoot> _deduplicateAndSortRoots(List<ComplexRoot> raw) {
    final List<ComplexRoot> reals = [];
    final List<ComplexRoot> complexList = [];

    for (final r in raw) {
      if (r.isReal) {
        final bool exists =
            reals.any((existing) => (existing.real - r.real).abs() < 1e-5);
        if (!exists) {
          reals.add(ComplexRoot(r.real, 0.0));
        }
      } else {
        final bool exists = complexList.any(
          (existing) =>
              (existing.real - r.real).abs() < 1e-5 &&
              (existing.imag - r.imag).abs() < 1e-5,
        );
        if (!exists) {
          complexList.add(r);
        }
      }
    }

    reals.sort((a, b) => a.real.compareTo(b.real));
    complexList.sort((a, b) {
      final int cmpRe = a.real.compareTo(b.real);
      if (cmpRe != 0) return cmpRe;
      return b.imag.compareTo(a.imag); // a+bi before a-bi
    });

    return [...reals, ...complexList];
  }
}

/// Orientation of a Polynomial Inequality ($P(x) > 0, < 0, \ge 0, \le 0$).
enum InequalitySign {
  greaterThan('>', strict: true, positiveTarget: true),
  lessThan('<', strict: true, positiveTarget: false),
  greaterOrEqual('≥', strict: false, positiveTarget: true),
  lessOrEqual('≤', strict: false, positiveTarget: false);

  final String symbol;
  final bool strict;
  final bool positiveTarget;

  const InequalitySign(
    this.symbol, {
    required this.strict,
    required this.positiveTarget,
  });
}

/// Solves quadratic, cubic, and quartic polynomial inequalities ($P(x) \lesseqgtr 0$)
/// and formats exact interval/union notation for the Cal_ 1100_DB_ LCD.
class InequalitySolver {
  static String solve({
    required List<double> coefficients,
    required InequalitySign sign,
  }) {
    if (coefficients.isEmpty || coefficients[0].abs() < 1e-13) {
      return 'Math ERROR';
    }

    final polyRes = PolynomialSolver.solve(coefficients);
    if (polyRes.error != null) return polyRes.error!;

    double evalPoly(double x) {
      double acc = 0.0;
      for (final c in coefficients) {
        acc = acc * x + c;
      }
      return acc;
    }

    // Collect distinct real roots sorted ascending
    final List<double> realRoots = [];
    for (final r in polyRes.roots) {
      if (r.isReal) {
        if (!realRoots.any((x) => (x - r.real).abs() < 1e-6)) {
          realRoots.add(r.real);
        }
      }
    }
    realRoots.sort();

    final int k = realRoots.length;
    // Test sign of P(x) in each of the k+1 open intervals:
    // I_0 = (-inf, r_0), I_1 = (r_0, r_1), ..., I_k = (r_{k-1}, +inf)
    final List<bool> intervalSat = List.generate(k + 1, (idx) {
      final double testX;
      if (k == 0) {
        testX = 0.0;
      } else if (idx == 0) {
        testX = realRoots.first - 2.0;
      } else if (idx == k) {
        testX = realRoots.last + 2.0;
      } else {
        testX = 0.5 * (realRoots[idx - 1] + realRoots[idx]);
      }
      final double val = evalPoly(testX);
      return sign.positiveTarget ? (val > 1e-11) : (val < -1e-11);
    });

    final bool rootIncluded = !sign.strict;

    // Case 1: No real roots
    if (k == 0) {
      return intervalSat[0] ? 'All Real Numbers' : 'No Solution';
    }

    // Merge adjacent intervals when the shared boundary root is also included
    // Represent segments as (double? lower, double? upper, bool closedLower, bool closedUpper)
    final List<String> parts = [];
    int i = 0;
    while (i <= k) {
      if (!intervalSat[i]) {
        // Check if isolated root r_i (at right endpoint of interval i) is a single point solution
        if (rootIncluded &&
            i < k &&
            !intervalSat[i] &&
            !intervalSat[i + 1] &&
            (parts.isEmpty ||
                !parts.last.endsWith(formatCal_Scalar(realRoots[i])))) {
          parts.add('x = ${formatCal_Scalar(realRoots[i])}');
        }
        i++;
        continue;
      }

      final double? lower = (i == 0) ? null : realRoots[i - 1];
      int endIdx = i;
      while (endIdx < k && rootIncluded && intervalSat[endIdx + 1]) {
        endIdx++;
      }
      final double? upper = (endIdx == k) ? null : realRoots[endIdx];

      final String op = sign.strict ? '<' : '≤';
      if (lower == null && upper == null) {
        return 'All Real Numbers';
      } else if (lower == null && upper != null) {
        parts.add('x $op ${formatCal_Scalar(upper)}');
      } else if (lower != null && upper == null) {
        parts.add('${formatCal_Scalar(lower)} $op x');
      } else if (lower != null && upper != null) {
        parts.add(
          '${formatCal_Scalar(lower)} $op x $op ${formatCal_Scalar(upper)}',
        );
      }

      i = endIdx + 1;
    }

    if (parts.isEmpty) {
      return 'No Solution';
    }

    // Check special case `x < r, r < x` -> `x ≠ r`
    if (sign.strict &&
        k == 1 &&
        intervalSat[0] &&
        intervalSat[1] &&
        parts.length == 2) {
      return 'x ≠ ${formatCal_Scalar(realRoots[0])}';
    }

    return parts.join(', ');
  }
}

/// Template type for the `Ratio` app ($A : B = X : D$ or $A : B = C : X$).
enum RatioTemplateType {
  /// $A : B = X : D \implies X = \frac{A \cdot D}{B}$
  aToBEqualsXToD('A : B = X : D'),

  /// $A : B = C : X \implies X = \frac{B \cdot C}{A}$
  aToBEqualsCToX('A : B = C : X');

  final String label;
  const RatioTemplateType(this.label);
}

/// Solves proportions in the `Ratio` app.
class RatioSolver {
  static String solve({
    required RatioTemplateType type,
    required double a,
    required double b,
    required double cOrD,
  }) {
    if (type == RatioTemplateType.aToBEqualsXToD) {
      // A : B = X : D -> X = (A * D) / B
      if (b.abs() < 1e-13) return 'Math ERROR';
      final double x = (a * cOrD) / b;
      return 'X = ${formatCal_Scalar(x)}';
    } else {
      // A : B = C : X -> X = (B * C) / A
      if (a.abs() < 1e-13) return 'Math ERROR';
      final double x = (b * cOrD) / a;
      return 'X = ${formatCal_Scalar(x)}';
    }
  }
}
