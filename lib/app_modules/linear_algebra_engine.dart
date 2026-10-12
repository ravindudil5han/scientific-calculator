import 'dart:math' as math;
import '../state/calculator_models.dart';

/// Cleanly formats a floating-point scalar for Cal_ LCD display, eliminating
/// IEEE 754 noise (e.g. `0.9999999999999999` -> `1`, `-0.0` -> `0`).
String formatCal_Scalar(double value, {int precision = 10}) {
  if (value.isNaN || value.isInfinite) return 'Math ERROR';
  if (value.abs() < 1e-12) return '0';

  final double roundedInt = value.roundToDouble();
  if ((value - roundedInt).abs() < 1e-10 && roundedInt.abs() < 1e12) {
    return roundedInt.toInt().toString();
  }

  String s = value.toStringAsPrecision(precision);
  if (s.contains('.') && !s.contains('e') && !s.contains('E')) {
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  if (s == '-0') return '0';
  return s;
}

/// Represents a 2D matrix ($1 \times 1$ up to $4 \times 4$) in the Cal_ 1100_DB_
/// `Matrix` app (`MatA`, `MatB`, `MatC`, `MatD`, `MatAns`).
class Cal_Matrix {
  final int rows;
  final int cols;
  final List<List<double>> data;

  Cal_Matrix({
    required this.rows,
    required this.cols,
    required List<List<double>> values,
  }) : data = List.generate(
          rows,
          (r) => List.generate(
            cols,
            (c) => (r < values.length && c < values[r].length)
                ? (values[r][c].abs() < 1e-13 ? 0.0 : values[r][c])
                : 0.0,
          ),
        );

  /// Creates an $m \times n$ zero matrix.
  factory Cal_Matrix.zeros(int rows, int cols) {
    return Cal_Matrix(
      rows: rows.clamp(1, 4),
      cols: cols.clamp(1, 4),
      values: List.generate(rows, (_) => List.filled(cols, 0.0)),
    );
  }

  /// Creates an $n \times n$ identity matrix $I_n$.
  factory Cal_Matrix.identity(int n) {
    if (n < 1 || n > 4) {
      throw const FormatException('Dimension ERROR');
    }
    return Cal_Matrix(
      rows: n,
      cols: n,
      values: List.generate(
        n,
        (r) => List.generate(n, (c) => r == c ? 1.0 : 0.0),
      ),
    );
  }

  double get(int r, int c) => data[r][c];

  Cal_Matrix copyWithCell(int r, int c, double val) {
    final next = List.generate(rows, (i) => List<double>.from(data[i]));
    if (r >= 0 && r < rows && c >= 0 && c < cols) {
      next[r][c] = val;
    }
    return Cal_Matrix(rows: rows, cols: cols, values: next);
  }

  Cal_Matrix resize(int newRows, int newCols) {
    return Cal_Matrix(
      rows: newRows.clamp(1, 4),
      cols: newCols.clamp(1, 4),
      values: data,
    );
  }

  /// Matrix addition $A + B$.
  Cal_Matrix add(Cal_Matrix other) {
    if (rows != other.rows || cols != other.cols) {
      throw const FormatException('Dimension ERROR');
    }
    return Cal_Matrix(
      rows: rows,
      cols: cols,
      values: List.generate(
        rows,
        (r) => List.generate(cols, (c) => data[r][c] + other.data[r][c]),
      ),
    );
  }

  /// Matrix subtraction $A - B$.
  Cal_Matrix subtract(Cal_Matrix other) {
    if (rows != other.rows || cols != other.cols) {
      throw const FormatException('Dimension ERROR');
    }
    return Cal_Matrix(
      rows: rows,
      cols: cols,
      values: List.generate(
        rows,
        (r) => List.generate(cols, (c) => data[r][c] - other.data[r][c]),
      ),
    );
  }

  /// Scalar multiplication $k \cdot A$.
  Cal_Matrix scale(double k) {
    return Cal_Matrix(
      rows: rows,
      cols: cols,
      values: List.generate(
        rows,
        (r) => List.generate(cols, (c) => data[r][c] * k),
      ),
    );
  }

  /// Matrix multiplication $A \times B$.
  Cal_Matrix multiply(Cal_Matrix other) {
    if (cols != other.rows) {
      throw const FormatException('Dimension ERROR');
    }
    final result = List.generate(
      rows,
      (r) => List.generate(other.cols, (c) {
        double sum = 0.0;
        for (int k = 0; k < cols; k++) {
          sum += data[r][k] * other.data[k][c];
        }
        return sum;
      }),
    );
    return Cal_Matrix(rows: rows, cols: other.cols, values: result);
  }

  /// Matrix transpose $A^T$ (`Trn(MatA)`).
  Cal_Matrix transpose() {
    return Cal_Matrix(
      rows: cols,
      cols: rows,
      values: List.generate(
        cols,
        (r) => List.generate(rows, (c) => data[c][r]),
      ),
    );
  }

  /// Matrix power ($A^2, A^3, A^{-1}$).
  Cal_Matrix power(int exp) {
    if (rows != cols) {
      throw const FormatException('Dimension ERROR');
    }
    if (exp == -1) return inverse();
    if (exp == 0) return Cal_Matrix.identity(rows);
    if (exp < 0) {
      final inv = inverse();
      return inv.power(-exp);
    }
    Cal_Matrix acc = Cal_Matrix.identity(rows);
    for (int i = 0; i < exp; i++) {
      acc = acc.multiply(this);
    }
    return acc;
  }

  /// Determinant $\det(A)$ via LU Decomposition with Partial Pivoting.
  double determinant() {
    if (rows != cols) {
      throw const FormatException('Dimension ERROR');
    }
    final int n = rows;
    final List<List<double>> lu = List.generate(
      n,
      (r) => List<double>.from(data[r]),
    );
    int swaps = 0;

    for (int k = 0; k < n; k++) {
      int pivotRow = k;
      double maxVal = lu[k][k].abs();
      for (int i = k + 1; i < n; i++) {
        if (lu[i][k].abs() > maxVal) {
          maxVal = lu[i][k].abs();
          pivotRow = i;
        }
      }
      if (maxVal < 1e-12) {
        return 0.0;
      }
      if (pivotRow != k) {
        final tmp = lu[k];
        lu[k] = lu[pivotRow];
        lu[pivotRow] = tmp;
        swaps++;
      }
      for (int i = k + 1; i < n; i++) {
        final double factor = lu[i][k] / lu[k][k];
        lu[i][k] = factor;
        for (int j = k + 1; j < n; j++) {
          lu[i][j] -= factor * lu[k][j];
        }
      }
    }

    double det = (swaps % 2 == 0) ? 1.0 : -1.0;
    for (int i = 0; i < n; i++) {
      det *= lu[i][i];
    }
    if (det.abs() < 1e-12) return 0.0;
    final double rounded = det.roundToDouble();
    if ((det - rounded).abs() < 1e-9) return rounded;
    return det;
  }

  /// Matrix Inversion $A^{-1}$ via Gauss-Jordan Elimination with Partial Pivoting.
  /// Throws `FormatException('Math ERROR')` if $A$ is singular ($\det(A) = 0$).
  Cal_Matrix inverse() {
    if (rows != cols) {
      throw const FormatException('Dimension ERROR');
    }
    final int n = rows;
    final List<List<double>> aug = List.generate(
      n,
      (r) => [
        ...data[r],
        for (int c = 0; c < n; c++) r == c ? 1.0 : 0.0,
      ],
    );

    for (int col = 0; col < n; col++) {
      int pivotRow = col;
      double maxAbs = aug[col][col].abs();
      for (int r = col + 1; r < n; r++) {
        if (aug[r][col].abs() > maxAbs) {
          maxAbs = aug[r][col].abs();
          pivotRow = r;
        }
      }

      if (maxAbs < 1e-11) {
        throw const FormatException('Math ERROR');
      }

      if (pivotRow != col) {
        final tmp = aug[col];
        aug[col] = aug[pivotRow];
        aug[pivotRow] = tmp;
      }

      final double pivot = aug[col][col];
      for (int j = 0; j < 2 * n; j++) {
        aug[col][j] /= pivot;
      }

      for (int r = 0; r < n; r++) {
        if (r != col) {
          final double factor = aug[r][col];
          if (factor.abs() > 1e-15) {
            for (int j = 0; j < 2 * n; j++) {
              aug[r][j] -= factor * aug[col][j];
            }
          }
        }
      }
    }

    final invValues = List.generate(
      n,
      (r) => List.generate(n, (c) {
        final v = aug[r][n + c];
        final rounded = v.roundToDouble();
        return (v - rounded).abs() < 1e-10 ? rounded : v;
      }),
    );
    return Cal_Matrix(rows: n, cols: n, values: invValues);
  }

  /// Row Echelon Form (`Ref(MatA)`).
  Cal_Matrix rowEchelonForm() {
    final List<List<double>> m = List.generate(
      rows,
      (r) => List<double>.from(data[r]),
    );
    int lead = 0;
    for (int r = 0; r < rows; r++) {
      if (lead >= cols) break;
      int i = r;
      while (m[i][lead].abs() < 1e-11) {
        i++;
        if (i == rows) {
          i = r;
          lead++;
          if (lead == cols) {
            return Cal_Matrix(rows: rows, cols: cols, values: m);
          }
        }
      }
      final tmp = m[i];
      m[i] = m[r];
      m[r] = tmp;

      final double lv = m[r][lead];
      for (int j = 0; j < cols; j++) {
        m[r][j] /= lv;
      }
      for (int k = r + 1; k < rows; k++) {
        final double factor = m[k][lead];
        for (int j = 0; j < cols; j++) {
          m[k][j] -= factor * m[r][j];
        }
      }
      lead++;
    }
    return Cal_Matrix(rows: rows, cols: cols, values: m);
  }

  /// Reduced Row Echelon Form (`Rref(MatA)`).
  Cal_Matrix reducedRowEchelonForm() {
    final List<List<double>> m = List.generate(
      rows,
      (r) => List<double>.from(data[r]),
    );
    int lead = 0;
    for (int r = 0; r < rows; r++) {
      if (lead >= cols) break;
      int i = r;
      while (m[i][lead].abs() < 1e-11) {
        i++;
        if (i == rows) {
          i = r;
          lead++;
          if (lead == cols) {
            return Cal_Matrix(rows: rows, cols: cols, values: m);
          }
        }
      }
      final tmp = m[i];
      m[i] = m[r];
      m[r] = tmp;

      final double lv = m[r][lead];
      for (int j = 0; j < cols; j++) {
        m[r][j] /= lv;
      }
      for (int k = 0; k < rows; k++) {
        if (k != r) {
          final double factor = m[k][lead];
          for (int j = 0; j < cols; j++) {
            m[k][j] -= factor * m[r][j];
          }
        }
      }
      lead++;
    }
    return Cal_Matrix(rows: rows, cols: cols, values: m);
  }

  /// Formats the matrix into a compact single-line summary for LCD status/result lines.
  String toCompactString() {
    final rowStrings = data
        .map((r) => '[${r.map(formatCal_Scalar).join(",")}]')
        .join('');
    return rowStrings;
  }
}

/// Represents a 2D or 3D vector in the Cal_ 1100_DB_ `Vector` app
/// (`VctA`, `VctB`, `VctC`, `VctD`, `VctAns`).
class Cal_Vector {
  final List<double> components;

  Cal_Vector(List<double> values)
      : assert(values.length == 2 || values.length == 3),
        components = values
            .map((v) => v.abs() < 1e-13 ? 0.0 : v)
            .toList(growable: false);

  factory Cal_Vector.zeros(int dimension) {
    final int d = dimension.clamp(2, 3);
    return Cal_Vector(List.filled(d, 0.0));
  }

  int get dimension => components.length;

  Cal_Vector copyWithComponent(int index, double value) {
    final next = List<double>.from(components);
    if (index >= 0 && index < next.length) {
      next[index] = value;
    }
    return Cal_Vector(next);
  }

  Cal_Vector resize(int newDim) {
    final d = newDim.clamp(2, 3);
    if (d == dimension) return this;
    if (d == 2) return Cal_Vector([components[0], components[1]]);
    return Cal_Vector([components[0], components[1], 0.0]);
  }

  Cal_Vector add(Cal_Vector other) {
    if (dimension != other.dimension) {
      throw const FormatException('Dimension ERROR');
    }
    return Cal_Vector(
      List.generate(dimension, (i) => components[i] + other.components[i]),
    );
  }

  Cal_Vector subtract(Cal_Vector other) {
    if (dimension != other.dimension) {
      throw const FormatException('Dimension ERROR');
    }
    return Cal_Vector(
      List.generate(dimension, (i) => components[i] - other.components[i]),
    );
  }

  Cal_Vector scale(double k) {
    return Cal_Vector(components.map((c) => c * k).toList());
  }

  /// Dot product $\mathbf{u} \cdot \mathbf{v}$.
  double dot(Cal_Vector other) {
    if (dimension != other.dimension) {
      throw const FormatException('Dimension ERROR');
    }
    double sum = 0.0;
    for (int i = 0; i < dimension; i++) {
      sum += components[i] * other.components[i];
    }
    return sum;
  }

  /// Cross product $\mathbf{u} \times \mathbf{v}$ (promotes 2D vectors to 3D with $z = 0$).
  Cal_Vector cross(Cal_Vector other) {
    if (dimension != other.dimension) {
      throw const FormatException('Dimension ERROR');
    }
    final double u1 = components[0];
    final double u2 = components[1];
    final double u3 = dimension == 3 ? components[2] : 0.0;
    final double v1 = other.components[0];
    final double v2 = other.components[1];
    final double v3 = other.dimension == 3 ? other.components[2] : 0.0;

    return Cal_Vector([
      u2 * v3 - u3 * v2,
      u3 * v1 - u1 * v3,
      u1 * v2 - u2 * v1,
    ]);
  }

  /// Euclidean norm / magnitude $\Vert\mathbf{u}\Vert$.
  double norm() {
    double sumSq = 0.0;
    for (final c in components) {
      sumSq += c * c;
    }
    return math.sqrt(sumSq);
  }

  /// Unit vector $\frac{\mathbf{u}}{\Vert\mathbf{u}\Vert}$ (`UnitV(VctA)`).
  Cal_Vector unitVector() {
    final double n = norm();
    if (n < 1e-13) {
      throw const FormatException('Math ERROR');
    }
    return scale(1.0 / n);
  }

  /// Angle between two vectors $\theta = \arccos\left(\frac{\mathbf{u}\cdot\mathbf{v}}{\Vert\mathbf{u}\Vert \Vert\mathbf{v}\Vert}\right)$.
  double angleWith(Cal_Vector other, AngleUnit angleUnit) {
    if (dimension != other.dimension) {
      throw const FormatException('Dimension ERROR');
    }
    final double denom = norm() * other.norm();
    if (denom < 1e-13) {
      throw const FormatException('Math ERROR');
    }
    final double cosTheta = (dot(other) / denom).clamp(-1.0, 1.0);
    final double rad = math.acos(cosTheta);
    return switch (angleUnit) {
      AngleUnit.degree => rad * 180.0 / math.pi,
      AngleUnit.radian => rad,
      AngleUnit.gradian => rad * 200.0 / math.pi,
    };
  }

  String toCompactString() {
    return '[${components.map(formatCal_Scalar).join(",")}]';
  }
}

/// Result of evaluating a Matrix or Vector calculation expression.
class LinearAlgebraEvalResult {
  final Cal_Matrix? matrixResult;
  final Cal_Vector? vectorResult;
  final double? scalarResult;
  final String displayText;
  final String? error;

  const LinearAlgebraEvalResult({
    this.matrixResult,
    this.vectorResult,
    this.scalarResult,
    required this.displayText,
    this.error,
  });
}

/// Evaluates algebraic expressions in `Matrix` and `Vector` modes.
class LinearAlgebraEvaluator {
  final Map<String, Cal_Matrix> matrices;
  final Map<String, Cal_Vector> vectors;
  final AngleUnit angleUnit;

  const LinearAlgebraEvaluator({
    required this.matrices,
    required this.vectors,
    this.angleUnit = AngleUnit.degree,
  });

  LinearAlgebraEvalResult evaluateMatrixExpression(String rawExpr) {
    try {
      final String expr = rawExpr
          .replaceAll(' ', '')
          .replaceAll('−', '-')
          .replaceAll('×', '*')
          .replaceAll('÷', '/');
      if (expr.isEmpty) {
        return const LinearAlgebraEvalResult(displayText: '');
      }

      // Function forms: Det(MatA), Trn(MatA), Ref(MatA), Rref(MatA), Identity(n)
      if (expr.startsWith('Det(') && expr.endsWith(')')) {
        final inner = expr.substring(4, expr.length - 1);
        final m = _resolveMatrixTerm(inner);
        final det = m.determinant();
        return LinearAlgebraEvalResult(
          scalarResult: det,
          displayText: formatCal_Scalar(det),
        );
      }
      if (expr.startsWith('Trn(') && expr.endsWith(')')) {
        final inner = expr.substring(4, expr.length - 1);
        final m = _resolveMatrixTerm(inner).transpose();
        return LinearAlgebraEvalResult(
          matrixResult: m,
          displayText: m.toCompactString(),
        );
      }
      if (expr.startsWith('Ref(') && expr.endsWith(')')) {
        final inner = expr.substring(4, expr.length - 1);
        final m = _resolveMatrixTerm(inner).rowEchelonForm();
        return LinearAlgebraEvalResult(
          matrixResult: m,
          displayText: m.toCompactString(),
        );
      }
      if (expr.startsWith('Rref(') && expr.endsWith(')')) {
        final inner = expr.substring(5, expr.length - 1);
        final m = _resolveMatrixTerm(inner).reducedRowEchelonForm();
        return LinearAlgebraEvalResult(
          matrixResult: m,
          displayText: m.toCompactString(),
        );
      }
      if (expr.startsWith('Identity(') && expr.endsWith(')')) {
        final inner = expr.substring(9, expr.length - 1);
        final int n = int.tryParse(inner) ?? 0;
        final m = Cal_Matrix.identity(n);
        return LinearAlgebraEvalResult(
          matrixResult: m,
          displayText: m.toCompactString(),
        );
      }

      // Binary addition / subtraction at top level
      final int plusIdx = _findTopLevelOp(expr, '+');
      if (plusIdx != -1) {
        final left = _resolveMatrixTerm(expr.substring(0, plusIdx));
        final right = _resolveMatrixTerm(expr.substring(plusIdx + 1));
        final m = left.add(right);
        return LinearAlgebraEvalResult(
          matrixResult: m,
          displayText: m.toCompactString(),
        );
      }

      final int minusIdx = _findTopLevelOp(expr, '-');
      if (minusIdx > 0) {
        final left = _resolveMatrixTerm(expr.substring(0, minusIdx));
        final right = _resolveMatrixTerm(expr.substring(minusIdx + 1));
        final m = left.subtract(right);
        return LinearAlgebraEvalResult(
          matrixResult: m,
          displayText: m.toCompactString(),
        );
      }

      final m = _resolveMatrixTerm(expr);
      return LinearAlgebraEvalResult(
        matrixResult: m,
        displayText: m.toCompactString(),
      );
    } on FormatException catch (e) {
      return LinearAlgebraEvalResult(
        displayText: '',
        error: e.message,
      );
    } catch (_) {
      return const LinearAlgebraEvalResult(
        displayText: '',
        error: 'Syntax ERROR',
      );
    }
  }

  Cal_Matrix _resolveMatrixTerm(String term) {
    final int mulIdx = _findTopLevelOp(term, '*');
    if (mulIdx != -1) {
      final leftStr = term.substring(0, mulIdx);
      final rightStr = term.substring(mulIdx + 1);
      final double? leftScalar = double.tryParse(leftStr);
      if (leftScalar != null) {
        return _resolveMatrixTerm(rightStr).scale(leftScalar);
      }
      final double? rightScalar = double.tryParse(rightStr);
      if (rightScalar != null) {
        return _resolveMatrixTerm(leftStr).scale(rightScalar);
      }
      return _resolveMatrixTerm(leftStr).multiply(_resolveMatrixTerm(rightStr));
    }

    // Power / Inverse suffixes: MatA^-1, MatA^(-1), MatA⁻¹
    if (term.endsWith('⁻¹')) {
      final base = term.substring(0, term.length - 2);
      return _resolveMatrixTerm(base).inverse();
    }
    if (term.contains('^')) {
      final parts = term.split('^');
      final base = _resolveMatrixTerm(parts[0]);
      final expStr = parts[1].replaceAll('(', '').replaceAll(')', '');
      final int? exp = int.tryParse(expStr);
      if (exp == null) throw const FormatException('Syntax ERROR');
      return base.power(exp);
    }

    // Implicit scalar prefix e.g. 2MatA
    final matchScalar = RegExp(r'^(-?\d+(?:\.\d+)?)(Mat[A-D]|MatAns)$')
        .firstMatch(term);
    if (matchScalar != null) {
      final double k = double.parse(matchScalar.group(1)!);
      final String name = matchScalar.group(2)!;
      return _lookupMatrix(name).scale(k);
    }

    return _lookupMatrix(term);
  }

  Cal_Matrix _lookupMatrix(String name) {
    final m = matrices[name];
    if (m == null) {
      throw const FormatException('Dimension ERROR');
    }
    return m;
  }

  LinearAlgebraEvalResult evaluateVectorExpression(String rawExpr) {
    try {
      final String expr = rawExpr
          .replaceAll(' ', '')
          .replaceAll('−', '-')
          .replaceAll('÷', '/');
      if (expr.isEmpty) {
        return const LinearAlgebraEvalResult(displayText: '');
      }

      if (expr.startsWith('Abs(') && expr.endsWith(')')) {
        final inner = expr.substring(4, expr.length - 1);
        final v = _resolveVectorTerm(inner);
        final n = v.norm();
        return LinearAlgebraEvalResult(
          scalarResult: n,
          displayText: formatCal_Scalar(n),
        );
      }
      if (expr.startsWith('UnitV(') && expr.endsWith(')')) {
        final inner = expr.substring(6, expr.length - 1);
        final v = _resolveVectorTerm(inner).unitVector();
        return LinearAlgebraEvalResult(
          vectorResult: v,
          displayText: v.toCompactString(),
        );
      }
      if (expr.startsWith('DotP(') && expr.endsWith(')')) {
        final inner = expr.substring(5, expr.length - 1);
        final parts = inner.split(',');
        if (parts.length != 2) throw const FormatException('Syntax ERROR');
        final d = _resolveVectorTerm(parts[0]).dot(_resolveVectorTerm(parts[1]));
        return LinearAlgebraEvalResult(
          scalarResult: d,
          displayText: formatCal_Scalar(d),
        );
      }
      if (expr.startsWith('CrossP(') && expr.endsWith(')')) {
        final inner = expr.substring(7, expr.length - 1);
        final parts = inner.split(',');
        if (parts.length != 2) throw const FormatException('Syntax ERROR');
        final v =
            _resolveVectorTerm(parts[0]).cross(_resolveVectorTerm(parts[1]));
        return LinearAlgebraEvalResult(
          vectorResult: v,
          displayText: v.toCompactString(),
        );
      }
      if (expr.startsWith('Angle(') && expr.endsWith(')')) {
        final inner = expr.substring(6, expr.length - 1);
        final parts = inner.split(',');
        if (parts.length != 2) throw const FormatException('Syntax ERROR');
        final ang = _resolveVectorTerm(parts[0]).angleWith(
          _resolveVectorTerm(parts[1]),
          angleUnit,
        );
        return LinearAlgebraEvalResult(
          scalarResult: ang,
          displayText: formatCal_Scalar(ang),
        );
      }

      // Infix dot product `VctA·VctB`
      if (expr.contains('·')) {
        final parts = expr.split('·');
        final d = _resolveVectorTerm(parts[0]).dot(_resolveVectorTerm(parts[1]));
        return LinearAlgebraEvalResult(
          scalarResult: d,
          displayText: formatCal_Scalar(d),
        );
      }

      // Infix cross product `VctA×VctB`
      if (expr.contains('×')) {
        final parts = expr.split('×');
        final leftScalar = double.tryParse(parts[0]);
        if (leftScalar != null) {
          final v = _resolveVectorTerm(parts[1]).scale(leftScalar);
          return LinearAlgebraEvalResult(
            vectorResult: v,
            displayText: v.toCompactString(),
          );
        }
        final v =
            _resolveVectorTerm(parts[0]).cross(_resolveVectorTerm(parts[1]));
        return LinearAlgebraEvalResult(
          vectorResult: v,
          displayText: v.toCompactString(),
        );
      }

      final int plusIdx = _findTopLevelOp(expr, '+');
      if (plusIdx != -1) {
        final v = _resolveVectorTerm(expr.substring(0, plusIdx))
            .add(_resolveVectorTerm(expr.substring(plusIdx + 1)));
        return LinearAlgebraEvalResult(
          vectorResult: v,
          displayText: v.toCompactString(),
        );
      }

      final int minusIdx = _findTopLevelOp(expr, '-');
      if (minusIdx > 0) {
        final v = _resolveVectorTerm(expr.substring(0, minusIdx))
            .subtract(_resolveVectorTerm(expr.substring(minusIdx + 1)));
        return LinearAlgebraEvalResult(
          vectorResult: v,
          displayText: v.toCompactString(),
        );
      }

      final v = _resolveVectorTerm(expr);
      return LinearAlgebraEvalResult(
        vectorResult: v,
        displayText: v.toCompactString(),
      );
    } on FormatException catch (e) {
      return LinearAlgebraEvalResult(displayText: '', error: e.message);
    } catch (_) {
      return const LinearAlgebraEvalResult(
        displayText: '',
        error: 'Syntax ERROR',
      );
    }
  }

  Cal_Vector _resolveVectorTerm(String term) {
    final int mulIdx = _findTopLevelOp(term, '*');
    if (mulIdx != -1) {
      final leftStr = term.substring(0, mulIdx);
      final rightStr = term.substring(mulIdx + 1);
      final double? leftScalar = double.tryParse(leftStr);
      if (leftScalar != null) {
        return _resolveVectorTerm(rightStr).scale(leftScalar);
      }
      final double? rightScalar = double.tryParse(rightStr);
      if (rightScalar != null) {
        return _resolveVectorTerm(leftStr).scale(rightScalar);
      }
      return _resolveVectorTerm(leftStr).cross(_resolveVectorTerm(rightStr));
    }

    final matchScalar = RegExp(r'^(-?\d+(?:\.\d+)?)(Vct[A-D]|VctAns)$')
        .firstMatch(term);
    if (matchScalar != null) {
      final double k = double.parse(matchScalar.group(1)!);
      final String name = matchScalar.group(2)!;
      return _lookupVector(name).scale(k);
    }

    return _lookupVector(term);
  }

  Cal_Vector _lookupVector(String name) {
    final v = vectors[name];
    if (v == null) {
      throw const FormatException('Dimension ERROR');
    }
    return v;
  }

  int _findTopLevelOp(String s, String op) {
    int depth = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      final ch = s[i];
      if (ch == ')') depth++;
      if (ch == '(') depth--;
      if (depth == 0 && ch == op) {
        if (op == '-' && i > 0 && (s[i - 1] == '^' || s[i - 1] == '(')) {
          continue;
        }
        return i;
      }
    }
    return -1;
  }
}
