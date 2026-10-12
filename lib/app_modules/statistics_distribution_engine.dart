import 'dart:math' as math;
import 'linear_algebra_engine.dart';

/// Statistical regression / calculation sub-modes in the `Statistics` app.
enum StatModelType {
  oneVar('1-Variable'),
  linear('y = a + bx'),
  quadratic('y = a + bx + cx²'),
  logarithmic('y = a + b·ln(x)'),
  eExponential('y = a·e^(bx)'),
  abExponential('y = a·b^x'),
  power('y = a·x^b'),
  inverse('y = a + b/x');

  final String label;
  const StatModelType(this.label);

  bool get isTwoVar => this != StatModelType.oneVar;
}

/// Complete 1-Variable (`1-VAR`) summary statistics result.
class OneVarStatsResult {
  final double meanX; // x̄
  final double sumX; // ∑x
  final double sumX2; // ∑x²
  final double popStdDevX; // σx
  final double sampleStdDevX; // sx
  final double countN; // n
  final double minX; // min(x)
  final double q1; // Q₁
  final double median; // Med
  final double q3; // Q₃
  final double maxX; // max(x)
  final String? error;

  const OneVarStatsResult({
    this.meanX = 0,
    this.sumX = 0,
    this.sumX2 = 0,
    this.popStdDevX = 0,
    this.sampleStdDevX = 0,
    this.countN = 0,
    this.minX = 0,
    this.q1 = 0,
    this.median = 0,
    this.q3 = 0,
    this.maxX = 0,
    this.error,
  });

  List<String> get displayLines {
    if (error != null) return [error!];
    return [
      'x̄ = ${formatCal_Scalar(meanX)}',
      '∑x = ${formatCal_Scalar(sumX)}',
      '∑x² = ${formatCal_Scalar(sumX2)}',
      'σx = ${formatCal_Scalar(popStdDevX)}',
      'sx = ${formatCal_Scalar(sampleStdDevX)}',
      'n = ${formatCal_Scalar(countN)}',
      'min(x) = ${formatCal_Scalar(minX)}',
      'Q₁ = ${formatCal_Scalar(q1)}',
      'Med = ${formatCal_Scalar(median)}',
      'Q₃ = ${formatCal_Scalar(q3)}',
      'max(x) = ${formatCal_Scalar(maxX)}',
    ];
  }
}

/// Complete 2-Variable (`2-VAR`) & Regression summary result.
class TwoVarStatsResult {
  final StatModelType model;
  final OneVarStatsResult xStats;
  final double meanY; // ȳ
  final double sumY; // ∑y
  final double sumY2; // ∑y²
  final double popStdDevY; // σy
  final double sampleStdDevY; // sy
  final double sumXY; // ∑xy
  final double sumX3; // ∑x³
  final double sumX4; // ∑x⁴
  final double sumX2Y; // ∑x²y
  final double coeffA; // a
  final double coeffB; // b
  final double? coeffC; // c (for quadratic)
  final double? corrR; // r (correlation coefficient)
  final String? error;

  const TwoVarStatsResult({
    required this.model,
    required this.xStats,
    this.meanY = 0,
    this.sumY = 0,
    this.sumY2 = 0,
    this.popStdDevY = 0,
    this.sampleStdDevY = 0,
    this.sumXY = 0,
    this.sumX3 = 0,
    this.sumX4 = 0,
    this.sumX2Y = 0,
    this.coeffA = 0,
    this.coeffB = 0,
    this.coeffC,
    this.corrR,
    this.error,
  });

  /// Predicts $\hat{y}$ for a given $x$ using the fitted regression model.
  double predictY(double x) {
    return switch (model) {
      StatModelType.oneVar => double.nan,
      StatModelType.linear => coeffA + coeffB * x,
      StatModelType.quadratic =>
        coeffA + coeffB * x + (coeffC ?? 0.0) * x * x,
      StatModelType.logarithmic => coeffA + coeffB * math.log(x),
      StatModelType.eExponential => coeffA * math.exp(coeffB * x),
      StatModelType.abExponential => coeffA * math.pow(coeffB, x),
      StatModelType.power => coeffA * math.pow(x, coeffB),
      StatModelType.inverse => coeffA + coeffB / x,
    };
  }

  /// Predicts $\hat{x}$ for a given $y$ using the fitted regression model.
  double predictX(double y) {
    if (coeffB.abs() < 1e-14) return double.nan;
    return switch (model) {
      StatModelType.oneVar => double.nan,
      StatModelType.linear => (y - coeffA) / coeffB,
      StatModelType.quadratic =>
        (-coeffB +
                math.sqrt(
                  math.max(0.0, coeffB * coeffB - 4 * (coeffC ?? 1.0) * (coeffA - y)),
                )) /
            (2.0 * (coeffC ?? 1.0)),
      StatModelType.logarithmic => math.exp((y - coeffA) / coeffB),
      StatModelType.eExponential => math.log(y / coeffA) / coeffB,
      StatModelType.abExponential =>
        math.log(y / coeffA) / math.log(coeffB),
      StatModelType.power => math.pow(y / coeffA, 1.0 / coeffB).toDouble(),
      StatModelType.inverse => coeffB / (y - coeffA),
    };
  }

  List<String> get regressionDisplayLines {
    if (error != null) return [error!];
    final lines = <String>[
      model.label,
      'a = ${formatCal_Scalar(coeffA)}',
      'b = ${formatCal_Scalar(coeffB)}',
    ];
    if (coeffC != null) {
      lines.add('c = ${formatCal_Scalar(coeffC!)}');
    }
    if (corrR != null) {
      lines.add('r = ${formatCal_Scalar(corrR!)}');
    }
    return lines;
  }

  List<String> get twoVarSummaryLines {
    if (error != null) return [error!];
    return [
      'x̄ = ${formatCal_Scalar(xStats.meanX)}',
      '∑x = ${formatCal_Scalar(xStats.sumX)}',
      '∑x² = ${formatCal_Scalar(xStats.sumX2)}',
      'σx = ${formatCal_Scalar(xStats.popStdDevX)}',
      'sx = ${formatCal_Scalar(xStats.sampleStdDevX)}',
      'n = ${formatCal_Scalar(xStats.countN)}',
      'ȳ = ${formatCal_Scalar(meanY)}',
      '∑y = ${formatCal_Scalar(sumY)}',
      '∑y² = ${formatCal_Scalar(sumY2)}',
      'σy = ${formatCal_Scalar(popStdDevY)}',
      'sy = ${formatCal_Scalar(sampleStdDevY)}',
      '∑xy = ${formatCal_Scalar(sumXY)}',
      ...regressionDisplayLines.skip(1),
    ];
  }
}

/// Statistical calculation engine for 1-Variable and 2-Variable regressions.
class StatisticsEngine {
  static OneVarStatsResult computeOneVar(
    List<double> xValues, {
    List<double>? frequencies,
  }) {
    if (xValues.isEmpty) {
      return const OneVarStatsResult(error: 'Math ERROR');
    }

    double sumX = 0.0;
    double sumX2 = 0.0;
    double n = 0.0;
    final List<double> expanded = [];

    for (int i = 0; i < xValues.length; i++) {
      final double x = xValues[i];
      final double f =
          (frequencies != null && i < frequencies.length) ? frequencies[i] : 1.0;
      if (f < 0) return const OneVarStatsResult(error: 'Math ERROR');
      if (f == 0) continue;
      n += f;
      sumX += x * f;
      sumX2 += x * x * f;
      final int fCount = f.round().clamp(1, 500);
      for (int k = 0; k < fCount; k++) {
        expanded.add(x);
      }
    }

    if (n <= 0 || expanded.isEmpty) {
      return const OneVarStatsResult(error: 'Math ERROR');
    }

    final double meanX = sumX / n;
    double sumSqDiff = 0.0;
    for (int i = 0; i < xValues.length; i++) {
      final double f =
          (frequencies != null && i < frequencies.length) ? frequencies[i] : 1.0;
      final double d = xValues[i] - meanX;
      sumSqDiff += f * d * d;
    }

    final double popVar = math.max(0.0, sumSqDiff / n);
    final double popStdDev = math.sqrt(popVar);
    final double sampleStdDev =
        n > 1.0 ? math.sqrt(math.max(0.0, sumSqDiff / (n - 1.0))) : 0.0;

    expanded.sort();
    final double minX = expanded.first;
    final double maxX = expanded.last;
    final double med = _medianOfSlice(expanded, 0, expanded.length);

    final int mid = expanded.length ~/ 2;
    final double q1 = expanded.length == 1
        ? expanded.first
        : _medianOfSlice(expanded, 0, mid);
    final double q3 = expanded.length == 1
        ? expanded.first
        : _medianOfSlice(
            expanded,
            expanded.length.isEven ? mid : mid + 1,
            expanded.length,
          );

    return OneVarStatsResult(
      meanX: meanX,
      sumX: sumX,
      sumX2: sumX2,
      popStdDevX: popStdDev,
      sampleStdDevX: sampleStdDev,
      countN: n,
      minX: minX,
      q1: q1,
      median: med,
      q3: q3,
      maxX: maxX,
    );
  }

  static double _medianOfSlice(List<double> sorted, int start, int end) {
    final int len = end - start;
    if (len <= 0) return 0.0;
    final int half = start + len ~/ 2;
    if (len.isOdd) {
      return sorted[half];
    } else {
      return 0.5 * (sorted[half - 1] + sorted[half]);
    }
  }

  static TwoVarStatsResult computeTwoVar({
    required StatModelType model,
    required List<double> xValues,
    required List<double> yValues,
  }) {
    final int len = math.min(xValues.length, yValues.length);
    if (len < 2 || (model == StatModelType.quadratic && len < 3)) {
      return TwoVarStatsResult(
        model: model,
        xStats: const OneVarStatsResult(error: 'Math ERROR'),
        error: 'Math ERROR',
      );
    }

    final xs = xValues.sublist(0, len);
    final ys = yValues.sublist(0, len);
    final xStats = computeOneVar(xs);
    final yStats = computeOneVar(ys);
    if (xStats.error != null || yStats.error != null) {
      return TwoVarStatsResult(
        model: model,
        xStats: xStats,
        error: 'Math ERROR',
      );
    }

    double sumXY = 0.0;
    double sumX3 = 0.0;
    double sumX4 = 0.0;
    double sumX2Y = 0.0;
    for (int i = 0; i < len; i++) {
      final double x = xs[i];
      final double y = ys[i];
      final double x2 = x * x;
      sumXY += x * y;
      sumX3 += x2 * x;
      sumX4 += x2 * x2;
      sumX2Y += x2 * y;
    }

    // Transform (x, y) -> (u, v) for linearized least squares y' = A + B*x'
    if (model == StatModelType.quadratic) {
      // Solve 3x3 normal equations for y = a + b*x + c*x^2
      final double n = len.toDouble();
      final double sx = xStats.sumX;
      final double sx2 = xStats.sumX2;
      final double sy = yStats.sumX;
      final mat = Cal_Matrix(
        rows: 3,
        cols: 3,
        values: [
          [n, sx, sx2],
          [sx, sx2, sumX3],
          [sx2, sumX3, sumX4],
        ],
      );
      try {
        final inv = mat.inverse();
        final rhs = Cal_Matrix(
          rows: 3,
          cols: 1,
          values: [
            [sy],
            [sumXY],
            [sumX2Y],
          ],
        );
        final coeffs = inv.multiply(rhs);
        return TwoVarStatsResult(
          model: model,
          xStats: xStats,
          meanY: yStats.meanX,
          sumY: yStats.sumX,
          sumY2: yStats.sumX2,
          popStdDevY: yStats.popStdDevX,
          sampleStdDevY: yStats.sampleStdDevX,
          sumXY: sumXY,
          sumX3: sumX3,
          sumX4: sumX4,
          sumX2Y: sumX2Y,
          coeffA: coeffs.get(0, 0),
          coeffB: coeffs.get(1, 0),
          coeffC: coeffs.get(2, 0),
        );
      } catch (_) {
        return TwoVarStatsResult(
          model: model,
          xStats: xStats,
          error: 'Math ERROR',
        );
      }
    }

    final List<double> uList = [];
    final List<double> vList = [];
    for (int i = 0; i < len; i++) {
      final double x = xs[i];
      final double y = ys[i];
      double u = x;
      double v = y;

      switch (model) {
        case StatModelType.oneVar:
        case StatModelType.linear:
        case StatModelType.quadratic:
          break;
        case StatModelType.logarithmic:
          if (x <= 0) {
            return TwoVarStatsResult(
              model: model,
              xStats: xStats,
              error: 'Math ERROR',
            );
          }
          u = math.log(x);
          break;
        case StatModelType.eExponential:
        case StatModelType.abExponential:
          if (y <= 0) {
            return TwoVarStatsResult(
              model: model,
              xStats: xStats,
              error: 'Math ERROR',
            );
          }
          v = math.log(y);
          break;
        case StatModelType.power:
          if (x <= 0 || y <= 0) {
            return TwoVarStatsResult(
              model: model,
              xStats: xStats,
              error: 'Math ERROR',
            );
          }
          u = math.log(x);
          v = math.log(y);
          break;
        case StatModelType.inverse:
          if (x == 0) {
            return TwoVarStatsResult(
              model: model,
              xStats: xStats,
              error: 'Math ERROR',
            );
          }
          u = 1.0 / x;
          break;
      }
      uList.add(u);
      vList.add(v);
    }

    final double n = len.toDouble();
    double sumU = 0.0, sumV = 0.0, sumU2 = 0.0, sumV2 = 0.0, sumUV = 0.0;
    for (int i = 0; i < len; i++) {
      sumU += uList[i];
      sumV += vList[i];
      sumU2 += uList[i] * uList[i];
      sumV2 += vList[i] * vList[i];
      sumUV += uList[i] * vList[i];
    }

    final double sUU = sumU2 - (sumU * sumU) / n;
    final double sVV = sumV2 - (sumV * sumV) / n;
    final double sUV = sumUV - (sumU * sumV) / n;

    if (sUU.abs() < 1e-14) {
      return TwoVarStatsResult(
        model: model,
        xStats: xStats,
        error: 'Math ERROR',
      );
    }

    final double B = sUV / sUU;
    final double A = (sumV - B * sumU) / n;
    final double r =
        (sUU * sVV) > 1e-16 ? (sUV / math.sqrt(sUU * sVV)).clamp(-1.0, 1.0) : 0.0;

    double a = A;
    double b = B;
    switch (model) {
      case StatModelType.eExponential:
      case StatModelType.power:
        a = math.exp(A);
        b = B;
        break;
      case StatModelType.abExponential:
        a = math.exp(A);
        b = math.exp(B);
        break;
      default:
        break;
    }

    return TwoVarStatsResult(
      model: model,
      xStats: xStats,
      meanY: yStats.meanX,
      sumY: yStats.sumX,
      sumY2: yStats.sumX2,
      popStdDevY: yStats.popStdDevX,
      sampleStdDevY: yStats.sampleStdDevX,
      sumXY: sumXY,
      sumX3: sumX3,
      sumX4: sumX4,
      sumX2Y: sumX2Y,
      coeffA: a,
      coeffB: b,
      corrR: r,
    );
  }
}

/// Probability distribution types in the `Distribution` app (in exact Cal_ 1100_DB_ order).
enum DistributionType {
  binomialPd('Binomial PD'),
  binomialCd('Binomial CD'),
  normalPd('Normal PD'),
  normalCd('Normal CD'),
  inverseNormal('Inverse Normal'),
  poissonPd('Poisson PD'),
  poissonCd('Poisson CD');

  final String label;
  const DistributionType(this.label);

  /// Whether this distribution supports both `List` and `Variable` input modes on the 1100_DB_.
  bool get supportsListMode =>
      this != DistributionType.normalCd &&
      this != DistributionType.inverseNormal;
}

/// High-precision probability distributions engine (`Normal`, `Binomial`, `Poisson`).
class DistributionEngine {
  static const double _invSqrt2Pi = 0.3989422804014327; // 1 / sqrt(2*pi)

  /// Standard Normal PDF $\phi(z) = \frac{1}{\sqrt{2\pi}} e^{-z^2/2}$.
  static double standardNormalPdf(double z) {
    return _invSqrt2Pi * math.exp(-0.5 * z * z);
  }

  /// Standard Normal CDF $\Phi(z) = \frac{1}{2}\left[1 + \text{erf}\left(\frac{z}{\sqrt{2}}\right)\right]$.
  static double standardNormalCdf(double z) {
    if (z < -8.5) return 0.0;
    if (z > 8.5) return 1.0;
    return 0.5 * (1.0 + _erf(z / math.sqrt2));
  }

  /// Full double-precision error function $\text{erf}(x)$ (accuracy $< 10^{-15}$)
  /// using the positive-term Kummer series for $|x| < 3.0$ and Laplace's
  /// continued fraction for $|x| \ge 3.0$.
  static double _erf(double x) {
    if (x == 0.0) return 0.0;
    final double sign = x < 0 ? -1.0 : 1.0;
    final double ax = x.abs();
    const double twoOverSqrtPi = 1.1283791670955126; // 2 / sqrt(pi)

    if (ax < 3.0) {
      final double x2 = ax * ax;
      double term = ax;
      double sum = ax;
      for (int k = 1; k <= 80; k++) {
        term *= (2.0 * x2) / (2 * k + 1);
        sum += term;
        if (term <= sum * 1e-16) break;
      }
      return sign * (twoOverSqrtPi * math.exp(-x2) * sum).clamp(0.0, 1.0);
    } else {
      double f = 0.0;
      for (int k = 40; k >= 1; k--) {
        f = (0.5 * k) / (ax + f);
      }
      final double erfc =
          (0.5 * twoOverSqrtPi * math.exp(-ax * ax)) / (ax + f);
      return sign * (1.0 - erfc).clamp(0.0, 1.0);
    }
  }

  /// Normal Probability Density (`Normal PD`):
  /// $f(x) = \frac{1}{\sigma\sqrt{2\pi}} e^{-\frac{(x-\mu)^2}{2\sigma^2}}$.
  static double normalPd({
    required double x,
    double sigma = 1.0,
    double mu = 0.0,
  }) {
    if (sigma <= 0) throw const FormatException('Range ERROR');
    final double z = (x - mu) / sigma;
    return standardNormalPdf(z) / sigma;
  }

  /// Normal Cumulative Distribution (`Normal CD`):
  /// $P(\text{lower} \le X \le \text{upper}) = \Phi\left(\frac{\text{upper}-\mu}{\sigma}\right) - \Phi\left(\frac{\text{lower}-\mu}{\sigma}\right)$.
  static double normalCd({
    required double lower,
    required double upper,
    double sigma = 1.0,
    double mu = 0.0,
  }) {
    if (sigma <= 0) throw const FormatException('Range ERROR');
    if (upper < lower) return 0.0;
    final double zLow = (lower - mu) / sigma;
    final double zHigh = (upper - mu) / sigma;
    return (standardNormalCdf(zHigh) - standardNormalCdf(zLow)).clamp(0.0, 1.0);
  }

  /// Inverse Normal Cumulative Distribution (`Inverse Normal`):
  /// Finds $x$ such that $P(X \le x) = \text{area}$ using Acklam's rational
  /// approximation followed by Halley refinement.
  static double inverseNormal({
    required double area,
    double sigma = 1.0,
    double mu = 0.0,
  }) {
    if (sigma <= 0 || area <= 0.0 || area >= 1.0) {
      throw const FormatException('Range ERROR');
    }

    // Acklam's algorithm coefficients for standard normal quantile Φ⁻¹(p)
    const List<double> a = [
      -3.969683028665376e+01,
      2.209460984245205e+02,
      -2.759285104469687e+02,
      1.383577518672690e+02,
      -3.066479806614716e+01,
      2.506628277459239e+00,
    ];
    const List<double> b = [
      -5.447609879822406e+01,
      1.615858368580409e+02,
      -1.556989798598866e+02,
      6.680131188771972e+01,
      -1.328068155288572e+01,
    ];
    const List<double> c = [
      -7.784894002430293e-03,
      -3.223964580411365e-01,
      -2.400758277161838e+00,
      -2.549732539343734e+00,
      4.374664141464968e+00,
      2.938163982698783e+00,
    ];
    const List<double> d = [
      7.784695709041462e-03,
      3.224671290700398e-01,
      2.445134137142996e+00,
      3.754408661907416e+00,
    ];

    const double pLow = 0.02425;
    const double pHigh = 1.0 - pLow;
    double z;

    if (area < pLow) {
      final double q = math.sqrt(-2.0 * math.log(area));
      z = (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
          ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1.0);
    } else if (area <= pHigh) {
      final double q = area - 0.5;
      final double r = q * q;
      z = (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) *
          q /
          (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1.0);
    } else {
      final double q = math.sqrt(-2.0 * math.log(1.0 - area));
      z = -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
          ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1.0);
    }

    // 2 Newton-Halley steps to polish to full double precision
    for (int i = 0; i < 2; i++) {
      final double err = standardNormalCdf(z) - area;
      final double pdf = standardNormalPdf(z);
      if (pdf > 1e-15) {
        final double u = err / pdf;
        z = z - u / (1.0 + 0.5 * z * u);
      }
    }

    if (z.abs() < 1e-12) z = 0.0;
    return mu + sigma * z;
  }

  /// Binomial Probability Density (`Binomial PD`):
  /// $P(X = x) = \binom{n}{x} p^x (1-p)^{n-x}$.
  static double binomialPd({
    required int x,
    required int n,
    required double p,
  }) {
    if (n < 0 || p < 0.0 || p > 1.0) {
      throw const FormatException('Range ERROR');
    }
    if (x < 0 || x > n) return 0.0;
    if (p == 0.0) return x == 0 ? 1.0 : 0.0;
    if (p == 1.0) return x == n ? 1.0 : 0.0;

    return _binomialComb(n, x) *
        math.pow(p, x).toDouble() *
        math.pow(1.0 - p, n - x).toDouble();
  }

  /// Binomial Cumulative Distribution (`Binomial CD`):
  /// $P(X \le x) = \sum_{k=0}^x \binom{n}{k} p^k (1-p)^{n-k}$.
  static double binomialCd({
    required int x,
    required int n,
    required double p,
  }) {
    if (n < 0 || p < 0.0 || p > 1.0) {
      throw const FormatException('Range ERROR');
    }
    if (x < 0) return 0.0;
    if (x >= n) return 1.0;

    double sum = 0.0;
    for (int k = 0; k <= x; k++) {
      sum += binomialPd(x: k, n: n, p: p);
    }
    return sum.clamp(0.0, 1.0);
  }

  static double _binomialComb(int n, int k) {
    if (k < 0 || k > n) return 0.0;
    final int m = math.min(k, n - k);
    double res = 1.0;
    for (int i = 1; i <= m; i++) {
      res = res * (n - m + i) / i;
    }
    return res;
  }

  /// Poisson Probability Density (`Poisson PD`):
  /// $P(X = x) = \frac{\lambda^x e^{-\lambda}}{x!}$.
  static double poissonPd({
    required int x,
    required double lambda,
  }) {
    if (lambda <= 0.0) throw const FormatException('Range ERROR');
    if (x < 0) return 0.0;

    // Compute in log space to prevent factorial overflow for large x
    double logFact = 0.0;
    for (int i = 2; i <= x; i++) {
      logFact += math.log(i);
    }
    final double logProb = x * math.log(lambda) - lambda - logFact;
    return math.exp(logProb);
  }

  /// Poisson Cumulative Distribution (`Poisson CD`):
  /// $P(X \le x) = \sum_{k=0}^x \frac{\lambda^k e^{-\lambda}}{k!}$.
  static double poissonCd({
    required int x,
    required double lambda,
  }) {
    if (lambda <= 0.0) throw const FormatException('Range ERROR');
    if (x < 0) return 0.0;

    double sum = 0.0;
    for (int k = 0; k <= x; k++) {
      sum += poissonPd(x: k, lambda: lambda);
    }
    return sum.clamp(0.0, 1.0);
  }
}
