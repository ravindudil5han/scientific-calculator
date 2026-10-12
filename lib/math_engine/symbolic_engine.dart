import 'dart:collection';
import '../state/calculator_models.dart';
import 'calculator_decimal.dart';
import 'calculator_exceptions.dart';

/// Result of extracting the largest square factor $n = k^2 \cdot r$ where $r$ is square-free.
class SquareFreeDecomposition {
  final BigInt rootFactor;
  final BigInt squareFreePart;

  const SquareFreeDecomposition(this.rootFactor, this.squareFreePart);
}

/// Decomposes a non-negative [BigInt] $n$ into $k^2 \cdot r$ where $r$ is square-free.
SquareFreeDecomposition extractSquareFactors(BigInt n) {
  if (n < BigInt.zero) {
    throw const MathErrorException('Negative radicand in extractSquareFactors');
  }
  if (n == BigInt.zero) {
    return SquareFreeDecomposition(BigInt.zero, BigInt.one);
  }
  if (n == BigInt.one) {
    return SquareFreeDecomposition(BigInt.one, BigInt.one);
  }

  BigInt root = BigInt.one;
  BigInt rem = n;

  // Factor out powers of 2
  while (rem % BigInt.from(4) == BigInt.zero) {
    root *= BigInt.two;
    rem ~/= BigInt.from(4);
  }

  // Factor out powers of 3
  while (rem % BigInt.from(9) == BigInt.zero) {
    root *= BigInt.from(3);
    rem ~/= BigInt.from(9);
  }

  // Trial division up to sqrt(rem), capped for safety on huge integers
  BigInt d = BigInt.from(5);
  int step = 2;
  int iterations = 0;
  while (d * d <= rem && iterations < 50000) {
    final BigInt d2 = d * d;
    while (rem % d2 == BigInt.zero) {
      root *= d;
      rem ~/= d2;
    }
    d += BigInt.from(step);
    step = 6 - step;
    iterations++;
  }

  // Check if remaining part is a perfect square
  if (rem > BigInt.one && iterations >= 50000) {
    final BigInt s = _integerSqrt(rem);
    if (s * s == rem) {
      root *= s;
      rem = BigInt.one;
    }
  }

  return SquareFreeDecomposition(root, rem);
}

BigInt _integerSqrt(BigInt n) {
  if (n <= BigInt.zero) return BigInt.zero;
  if (n == BigInt.one) return BigInt.one;
  BigInt x0 = BigInt.one << ((n.bitLength + 1) >> 1);
  while (true) {
    final BigInt x1 = (x0 + (n ~/ x0)) >> 1;
    if (x1 >= x0) return x0;
    x0 = x1;
  }
}

/// Computes the canonical prime factorization of a positive integer $n$.
///
/// Examples:
/// - `24` $\to$ `'2^3×3'` (or `'2³×3'` when `useSuperscripts: true`)
/// - `360` $\to$ `'2^3×3^2×5'`
String primeFactorize(BigInt n, {bool useSuperscripts = false}) {
  if (n <= BigInt.zero) {
    throw const ArgumentErrorException('FACT requires a positive integer');
  }
  if (n == BigInt.one) return '1';

  BigInt rem = n;
  final List<(BigInt, int)> factors = [];

  void extractPrime(BigInt p) {
    int count = 0;
    while (rem % p == BigInt.zero) {
      rem ~/= p;
      count++;
    }
    if (count > 0) {
      factors.add((p, count));
    }
  }

  extractPrime(BigInt.two);
  extractPrime(BigInt.from(3));

  BigInt d = BigInt.from(5);
  int step = 2;
  int iter = 0;
  while (d * d <= rem && iter < 200000) {
    extractPrime(d);
    d += BigInt.from(step);
    step = 6 - step;
    iter++;
  }
  if (rem > BigInt.one) {
    factors.add((rem, 1));
  }

  return factors.map((entry) {
    final BigInt prime = entry.$1;
    final int exp = entry.$2;
    if (exp == 1) return prime.toString();
    if (useSuperscripts) {
      return '$prime${_toSuperscriptDigits(exp.toString())}';
    }
    return '$prime^$exp';
  }).join('×');
}

String _toSuperscriptDigits(String s) {
  const map = {
    '0': '⁰',
    '1': '¹',
    '2': '²',
    '3': '³',
    '4': '⁴',
    '5': '⁵',
    '6': '⁶',
    '7': '⁷',
    '8': '⁸',
    '9': '⁹',
  };
  return s.split('').map((ch) => map[ch] ?? ch).join();
}

/// Exact Symbolic Algebraic Number in $\mathbb{Q}(\sqrt{r_1}, \sqrt{r_2}, \dots) \cdot \pi^k$.
///
/// Represents canonical exact forms:
/// $$\frac{\sum_{r \ge 1} c_r \sqrt{r}}{d} \cdot \pi^{\text{piPower}}$$
/// where each $r \ge 1$ is square-free ($r = 1$ is the rational component),
/// $d > 0$, and $\gcd(d, |c_{r_1}|, |c_{r_2}|, \dots) = 1$.
class SymbolicValue {
  /// Map from square-free radicand $r \ge 1$ to non-zero integer coefficient $c_r$.
  final SplayTreeMap<BigInt, BigInt> terms;

  /// Common positive denominator $d \ge 1$.
  final BigInt denominator;

  /// Power of $\pi$ ($0$ for algebraic numbers, $1$ for $\pi$-multiples).
  final int piPower;

  SymbolicValue._(this.terms, this.denominator, this.piPower);

  static final SymbolicValue zero = SymbolicValue._(
    SplayTreeMap<BigInt, BigInt>(),
    BigInt.one,
    0,
  );

  static final SymbolicValue one = SymbolicValue.fromRational(BigRational.one);
  static final SymbolicValue minusOne =
      SymbolicValue.fromRational(BigRational.minusOne);
  static final SymbolicValue pi = SymbolicValue._(
    SplayTreeMap<BigInt, BigInt>.from({BigInt.one: BigInt.one}),
    BigInt.one,
    1,
  );

  /// Constructs a normalized [SymbolicValue] by reducing all coefficients and
  /// [denominator] by their greatest common divisor.
  factory SymbolicValue({
    required Map<BigInt, BigInt> rawTerms,
    required BigInt denominator,
    int piPower = 0,
  }) {
    if (denominator == BigInt.zero) {
      throw const MathErrorException('Symbolic division by zero');
    }

    final bool negDen = denominator.isNegative;
    BigInt den = denominator.abs();

    final SplayTreeMap<BigInt, BigInt> cleaned = SplayTreeMap<BigInt, BigInt>();
    for (final entry in rawTerms.entries) {
      final BigInt rad = entry.key;
      final BigInt coeff = negDen ? -entry.value : entry.value;
      if (coeff == BigInt.zero) continue;

      final decomp = extractSquareFactors(rad);
      final BigInt sqFreeRad = decomp.squareFreePart;
      final BigInt effectiveCoeff = coeff * decomp.rootFactor;
      if (effectiveCoeff != BigInt.zero) {
        final BigInt prev = cleaned[sqFreeRad] ?? BigInt.zero;
        final BigInt next = prev + effectiveCoeff;
        if (next == BigInt.zero) {
          cleaned.remove(sqFreeRad);
        } else {
          cleaned[sqFreeRad] = next;
        }
      }
    }

    if (cleaned.isEmpty) {
      return zero;
    }

    BigInt g = den;
    for (final c in cleaned.values) {
      g = bigIntGcd(g, c.abs());
      if (g == BigInt.one) break;
    }

    if (g > BigInt.one) {
      den ~/= g;
      for (final key in cleaned.keys.toList()) {
        cleaned[key] = cleaned[key]! ~/ g;
      }
    }

    return SymbolicValue._(cleaned, den, piPower);
  }

  factory SymbolicValue.fromInt(int n, [int d = 1]) =>
      SymbolicValue.fromRational(BigRational.fromInt(n, d));

  factory SymbolicValue.fromBigInt(BigInt n) =>
      SymbolicValue.fromRational(BigRational(n));

  factory SymbolicValue.fromRational(BigRational r, {int piPower = 0}) {
    if (r.isZero) return zero;
    return SymbolicValue(
      rawTerms: {BigInt.one: r.numerator},
      denominator: r.denominator,
      piPower: piPower,
    );
  }

  /// Constructs $\frac{a\sqrt{b}}{d}$.
  factory SymbolicValue.surd({
    required int coeff,
    required int radicand,
    int denominator = 1,
  }) {
    return SymbolicValue(
      rawTerms: {BigInt.from(radicand): BigInt.from(coeff)},
      denominator: BigInt.from(denominator),
    );
  }

  bool get isZero => terms.isEmpty;

  bool get isRational =>
      piPower == 0 &&
      (terms.isEmpty || (terms.length == 1 && terms.containsKey(BigInt.one)));

  bool get isInteger => isRational && denominator == BigInt.one;

  bool get isPiMultiple => piPower == 1 && terms.isNotEmpty;

  BigRational? toBigRational() {
    if (!isRational) return null;
    if (isZero) return BigRational.zero;
    return BigRational(terms[BigInt.one]!, denominator);
  }

  /// Adds two [SymbolicValue]s if compatible, or returns `null` if exact symbolic
  /// combination is not representable (e.g. $1 + \pi$).
  SymbolicValue? tryAdd(SymbolicValue other) {
    if (isZero) return other;
    if (other.isZero) return this;
    if (piPower != other.piPower) return null;
    if (terms.length + other.terms.length > 6) return null;

    final BigInt commonDen = bigIntLcm(denominator, other.denominator);
    final BigInt scaleA = commonDen ~/ denominator;
    final BigInt scaleB = commonDen ~/ other.denominator;

    final Map<BigInt, BigInt> sumTerms = {};
    for (final e in terms.entries) {
      sumTerms[e.key] = e.value * scaleA;
    }
    for (final e in other.terms.entries) {
      sumTerms[e.key] = (sumTerms[e.key] ?? BigInt.zero) + (e.value * scaleB);
    }

    return SymbolicValue(
      rawTerms: sumTerms,
      denominator: commonDen,
      piPower: piPower,
    );
  }

  SymbolicValue? trySubtract(SymbolicValue other) => tryAdd(-other);

  SymbolicValue operator -() {
    if (isZero) return zero;
    final SplayTreeMap<BigInt, BigInt> neg = SplayTreeMap<BigInt, BigInt>();
    for (final e in terms.entries) {
      neg[e.key] = -e.value;
    }
    return SymbolicValue._(neg, denominator, piPower);
  }

  /// Multiplies two [SymbolicValue]s exactly, automatically simplifying $\sqrt{a}\sqrt{b}$.
  SymbolicValue? tryMultiply(SymbolicValue other) {
    if (isZero || other.isZero) return zero;
    final int nextPi = piPower + other.piPower;
    if (nextPi > 1) return null; // Higher powers of pi fall back to decimal

    final Map<BigInt, BigInt> prodTerms = {};
    for (final a in terms.entries) {
      for (final b in other.terms.entries) {
        final BigInt radProd = a.key * b.key;
        final decomp = extractSquareFactors(radProd);
        final BigInt c = a.value * b.value * decomp.rootFactor;
        final BigInt r = decomp.squareFreePart;
        prodTerms[r] = (prodTerms[r] ?? BigInt.zero) + c;
      }
    }
    if (prodTerms.length > 6) return null;

    return SymbolicValue(
      rawTerms: prodTerms,
      denominator: denominator * other.denominator,
      piPower: nextPi,
    );
  }

  /// Divides two [SymbolicValue]s and rationalizes monomial or binomial surd denominators!
  SymbolicValue? tryDivide(SymbolicValue other) {
    if (other.isZero) {
      throw const MathErrorException('Division by zero');
    }
    if (isZero) return zero;

    final int nextPi = piPower - other.piPower;
    if (nextPi < 0 || nextPi > 1) return null;

    // Strip piPower from both for algebraic quotient, then restore nextPi
    final SymbolicValue numAlg = SymbolicValue._(terms, denominator, 0);

    // Case 1: Monomial divisor (c * sqrt(r)) / d
    if (other.terms.length == 1) {
      final BigInt r = other.terms.keys.first;
      final BigInt c = other.terms.values.first;
      // Multiply numerator by (other.denominator * sqrt(r)) and divide by (c * r)
      final SymbolicValue multiplier = SymbolicValue(
        rawTerms: {r: other.denominator},
        denominator: c * r,
        piPower: nextPi,
      );
      return numAlg.tryMultiply(multiplier);
    }

    // Case 2: Binomial surd divisor (a*sqrt(r1) + b*sqrt(r2)) / d
    // Multiply numerator and denominator by conjugate (a*sqrt(r1) - b*sqrt(r2))
    if (other.terms.length == 2) {
      final entries = other.terms.entries.toList();
      final BigInt r1 = entries[0].key;
      final BigInt a = entries[0].value;
      final BigInt r2 = entries[1].key;
      final BigInt b = entries[1].value;

      // Norm = a^2 * r1 - b^2 * r2
      final BigInt norm = (a * a * r1) - (b * b * r2);
      if (norm == BigInt.zero) return null;

      final SymbolicValue conjugate = SymbolicValue(
        rawTerms: {
          r1: a * other.denominator,
          r2: -b * other.denominator,
        },
        denominator: norm,
        piPower: nextPi,
      );
      return numAlg.tryMultiply(conjugate);
    }

    return null;
  }

  /// Computes exact square root $\sqrt{x}$ if representable in $\mathbb{Q}(\sqrt{n})$.
  SymbolicValue? trySqrt() {
    if (isZero) return zero;
    if (piPower != 0) return null;

    final Cal_Decimal approx = toCal_Decimal();
    if (approx.isNegative) {
      throw const MathErrorException('Square root of negative number in Real mode');
    }

    // Case 1: Rational input p/q -> sqrt(p/q) = sqrt(p*q) / q
    if (isRational) {
      final BigInt p = terms[BigInt.one]!;
      if (p.isNegative) {
        throw const MathErrorException('Square root of negative rational');
      }
      final BigInt pq = p * denominator;
      if (pq.bitLength > 80) return null;
      final decomp = extractSquareFactors(pq);
      return SymbolicValue(
        rawTerms: {decomp.squareFreePart: decomp.rootFactor},
        denominator: denominator,
      );
    }

    // Case 2: Binomial quadratic surd (A + B*sqrt(C)) / D -> denesting check
    // sqrt((A + B*sqrt(C))/D) = sqrt(D*A + D*B*sqrt(C)) / D
    if (terms.length == 2 && terms.containsKey(BigInt.one)) {
      final BigInt aOrig = terms[BigInt.one]!;
      final bigEntry =
          terms.entries.firstWhere((e) => e.key != BigInt.one);
      final BigInt c = bigEntry.key;
      final BigInt bOrig = bigEntry.value;

      final BigInt A = aOrig * denominator;
      final BigInt B = bOrig * denominator;
      if (A > BigInt.zero) {
        final BigInt disc = (A * A) - (B * B * c);
        if (disc >= BigInt.zero) {
          final BigInt k = _integerSqrt(disc);
          if (k * k == disc && (A + k).isEven && (A - k).isEven) {
            final BigInt u = (A + k) ~/ BigInt.two;
            final BigInt v = (A - k) ~/ BigInt.two;
            final SymbolicValue? sqrtU =
                SymbolicValue.fromBigInt(u).trySqrt();
            final SymbolicValue? sqrtV =
                SymbolicValue.fromBigInt(v).trySqrt();
            if (sqrtU != null && sqrtV != null) {
              final SymbolicValue? combined = B.isNegative
                  ? sqrtU.trySubtract(sqrtV)
                  : sqrtU.tryAdd(sqrtV);
              if (combined != null) {
                return combined.tryDivide(
                  SymbolicValue.fromBigInt(denominator),
                );
              }
            }
          }
        }
      }
    }

    return null;
  }

  /// Computes exact integer power $x^n$ when $n$ is a small integer.
  SymbolicValue? tryPow(SymbolicValue exponent) {
    if (!exponent.isRational) return null;
    final BigRational expRat = exponent.toBigRational()!;

    if (expRat.isZero) {
      if (isZero) throw const MathErrorException('0^0 is undefined');
      return one;
    }

    // Handle fractional exponent p/2 via sqrt
    if (expRat.denominator == BigInt.two && expRat.numerator.abs() <= BigInt.from(6)) {
      final SymbolicValue? root = trySqrt();
      if (root == null) return null;
      return root.tryPow(SymbolicValue.fromBigInt(expRat.numerator));
    }

    if (!expRat.isInteger) return null;
    final BigInt expBig = expRat.numerator;
    if (expBig.abs() > BigInt.from(20)) return null;
    int n = expBig.toInt();

    if (n < 0) {
      final SymbolicValue? posPow =
          tryPow(SymbolicValue.fromInt(-n));
      if (posPow == null) return null;
      return one.tryDivide(posPow);
    }

    SymbolicValue acc = one;
    for (int i = 0; i < n; i++) {
      final next = acc.tryMultiply(this);
      if (next == null) return null;
      acc = next;
    }
    return acc;
  }

  /// Converts this [SymbolicValue] to a 30-digit [Cal_Decimal].
  Cal_Decimal toCal_Decimal() {
    if (isZero) return Cal_Decimal.zero;
    Cal_Decimal numSum = Cal_Decimal.zero;
    for (final entry in terms.entries) {
      final BigInt rad = entry.key;
      final BigInt coeff = entry.value;
      final Cal_Decimal cDec = Cal_Decimal.fromBigInt(coeff);
      if (rad == BigInt.one) {
        numSum = numSum + cDec;
      } else {
        numSum = numSum + (cDec * Cal_Decimal.fromBigInt(rad).sqrt());
      }
    }
    Cal_Decimal res = numSum / Cal_Decimal.fromBigInt(denominator);
    if (piPower == 1) {
      res = res * Cal_Decimal.pi;
    }
    return res;
  }

  /// Formats this [SymbolicValue] as a canonical Cal_ exact string (e.g.
  /// `'1/2'`, `'2√3'`, `'5√2'`, `'√3/2'`, `'(√6-√2)/4'`, `'1/6π'`), or
  /// returns `null` if it exceeds Cal_'s compactness guard.
  String? toExactDisplayString() {
    if (isZero) return '0';

    // Compactness guard: fall back to decimal if denominator or coefficients are huge
    if (denominator > BigInt.from(99999)) return null;
    for (final e in terms.entries) {
      if (e.key > BigInt.from(99999) || e.value.abs() > BigInt.from(999999)) {
        return null;
      }
    }

    // Pure rational (or rational multiple of pi)
    if (terms.length == 1 && terms.containsKey(BigInt.one)) {
      final BigInt num = terms[BigInt.one]!;
      if (piPower == 1) {
        if (denominator == BigInt.one) {
          if (num == BigInt.one) return 'π';
          if (num == -BigInt.one) return '-π';
          return '$numπ';
        }
        if (num == BigInt.one) return 'π/$denominator';
        if (num == -BigInt.one) return '-π/$denominator';
        final String denStr = denominator.toString();
        return '$num/$denStrπ';
      }
      if (denominator == BigInt.one) return num.toString();
      return '$num/$denominator';
    }

    // Single surd term: (c * sqrt(r)) / d
    if (terms.length == 1 && piPower == 0) {
      final BigInt r = terms.keys.first;
      final BigInt c = terms.values.first;
      final String surdCore = _formatSingleSurdTerm(c, r);
      if (denominator == BigInt.one) {
        return surdCore;
      }
      return '$surdCore/$denominator';
    }

    // Multi-term surd combination: e.g. (√6 - √2)/4 or 1 + √2
    if (piPower == 0) {
      // Order terms: place positive terms first or sort by radicand descending/ascending
      final entries = terms.entries.toList()
        ..sort((a, b) {
          // Put positive terms before negative terms for cleaner (√6-√2)/4 formatting
          final bool aPos = a.value > BigInt.zero;
          final bool bPos = b.value > BigInt.zero;
          if (aPos != bPos) return aPos ? -1 : 1;
          return b.key.compareTo(a.key);
        });

      final StringBuffer buf = StringBuffer();
      for (int i = 0; i < entries.length; i++) {
        final BigInt r = entries[i].key;
        final BigInt c = entries[i].value;
        if (i == 0) {
          buf.write(r == BigInt.one ? c.toString() : _formatSingleSurdTerm(c, r));
        } else {
          final String op = c.isNegative ? '-' : '+';
          final BigInt absC = c.abs();
          final String termStr = r == BigInt.one
              ? absC.toString()
              : _formatSingleSurdTerm(absC, r);
          buf.write('$op$termStr');
        }
      }

      final String numExpr = buf.toString();
      final String result = denominator == BigInt.one
          ? numExpr
          : '($numExpr)/$denominator';
      return result.length <= 18 ? result : null;
    }

    return null;
  }

  static String _formatSingleSurdTerm(BigInt coeff, BigInt radicand) {
    if (radicand == BigInt.one) return coeff.toString();
    if (coeff == BigInt.one) return '√$radicand';
    if (coeff == -BigInt.one) return '-√$radicand';
    return '$coeff√$radicand';
  }
}

/// Exact Symbolic Trigonometric & Inverse Trigonometric Lookup Engine.
class SymbolicTrigEngine {
  /// Attempts to convert [angle] in [unit] to an exact rational degree in $[0, 360)$.
  static BigRational? _toNormalizedDegrees(
    SymbolicValue angle,
    AngleUnit unit,
  ) {
    BigRational? rawDeg;
    switch (unit) {
      case AngleUnit.degree:
        rawDeg = angle.toBigRational();
        break;
      case AngleUnit.gradian:
        final r = angle.toBigRational();
        if (r != null) {
          rawDeg = r * BigRational.fromInt(9, 10);
        }
        break;
      case AngleUnit.radian:
        if (angle.isZero) {
          rawDeg = BigRational.zero;
        } else if (angle.piPower == 1 &&
            angle.terms.length == 1 &&
            angle.terms.containsKey(BigInt.one)) {
          final coeff = BigRational(angle.terms[BigInt.one]!, angle.denominator);
          rawDeg = coeff * BigRational.fromInt(180);
        }
        break;
    }

    if (rawDeg == null || !rawDeg.isInteger) return null;
    int degMod = (rawDeg.numerator % BigInt.from(360)).toInt();
    if (degMod < 0) degMod += 360;
    return BigRational.fromInt(degMod);
  }

  /// Exact symbolic evaluation of $\sin(\theta)$ for all multiples of $15^\circ$.
  static SymbolicValue? trySin(SymbolicValue angle, AngleUnit unit) {
    final BigRational? degRat = _toNormalizedDegrees(angle, unit);
    if (degRat == null || !degRat.isInteger) return null;
    final int deg = degRat.numerator.toInt();
    return _sinAtDegree(deg);
  }

  /// Exact symbolic evaluation of $\cos(\theta)$ for all multiples of $15^\circ$.
  static SymbolicValue? tryCos(SymbolicValue angle, AngleUnit unit) {
    final BigRational? degRat = _toNormalizedDegrees(angle, unit);
    if (degRat == null || !degRat.isInteger) return null;
    final int deg = (90 - degRat.numerator.toInt()) % 360;
    return _sinAtDegree(deg < 0 ? deg + 360 : deg);
  }

  /// Exact symbolic evaluation of $\tan(\theta)$ for all multiples of $15^\circ$.
  static SymbolicValue? tryTan(SymbolicValue angle, AngleUnit unit) {
    final BigRational? degRat = _toNormalizedDegrees(angle, unit);
    if (degRat == null || !degRat.isInteger) return null;
    final int deg = degRat.numerator.toInt();
    if (deg == 90 || deg == 270) {
      throw const MathErrorException('tan(90/270) is undefined');
    }
    final s = _sinAtDegree(deg);
    final c = tryCos(angle, unit);
    if (s == null || c == null) return null;
    return s.tryDivide(c);
  }

  static SymbolicValue? _sinAtDegree(int deg) {
    if (deg >= 180) {
      final base = _sinAtDegree(deg - 180);
      return base == null ? null : -base;
    }
    if (deg > 90) {
      return _sinAtDegree(180 - deg);
    }
    return switch (deg) {
      0 => SymbolicValue.zero,
      15 => SymbolicValue(
          rawTerms: {
            BigInt.from(6): BigInt.one,
            BigInt.two: -BigInt.one,
          },
          denominator: BigInt.from(4),
        ),
      30 => SymbolicValue.fromInt(1, 2),
      45 => SymbolicValue.surd(coeff: 1, radicand: 2, denominator: 2),
      60 => SymbolicValue.surd(coeff: 1, radicand: 3, denominator: 2),
      75 => SymbolicValue(
          rawTerms: {
            BigInt.from(6): BigInt.one,
            BigInt.two: BigInt.one,
          },
          denominator: BigInt.from(4),
        ),
      90 => SymbolicValue.one,
      _ => null,
    };
  }

  /// Exact symbolic evaluation of $\arcsin(x)$ for canonical ratios ($0, \pm\frac{1}{2}, \pm\frac{\sqrt{2}}{2}, \pm\frac{\sqrt{3}}{2}, \pm 1$).
  static SymbolicValue? tryAsin(SymbolicValue arg, AngleUnit unit) {
    final int? deg = _matchKnownSinValue(arg);
    if (deg == null) return null;
    return _degreesToAngleSymbolic(deg, unit);
  }

  /// Exact symbolic evaluation of $\arccos(x)$ for canonical ratios.
  static SymbolicValue? tryAcos(SymbolicValue arg, AngleUnit unit) {
    final int? sinDeg = _matchKnownSinValue(arg);
    if (sinDeg == null) return null;
    return _degreesToAngleSymbolic(90 - sinDeg, unit);
  }

  /// Exact symbolic evaluation of $\arctan(x)$ for canonical ratios ($0, \pm\frac{\sqrt{3}}{3}, \pm 1, \pm\sqrt{3}$).
  static SymbolicValue? tryAtan(SymbolicValue arg, AngleUnit unit) {
    final String? exact = arg.toExactDisplayString();
    final int? deg = switch (exact) {
      '0' => 0,
      '√3/3' => 30,
      '-√3/3' => -30,
      '1' => 45,
      '-1' => -45,
      '√3' => 60,
      '-√3' => -60,
      _ => null,
    };
    if (deg == null) return null;
    return _degreesToAngleSymbolic(deg, unit);
  }

  static int? _matchKnownSinValue(SymbolicValue arg) {
    final String? exact = arg.toExactDisplayString();
    return switch (exact) {
      '0' => 0,
      '1/2' => 30,
      '-1/2' => -30,
      '√2/2' => 45,
      '-√2/2' => -45,
      '√3/2' => 60,
      '-√3/2' => -60,
      '1' => 90,
      '-1' => -90,
      _ => null,
    };
  }

  static SymbolicValue _degreesToAngleSymbolic(int deg, AngleUnit unit) {
    return switch (unit) {
      AngleUnit.degree => SymbolicValue.fromInt(deg),
      AngleUnit.gradian =>
        SymbolicValue.fromRational(BigRational.fromInt(deg * 10, 9)),
      AngleUnit.radian => SymbolicValue.fromRational(
          BigRational.fromInt(deg, 180),
          piPower: deg == 0 ? 0 : 1,
        ),
    };
  }
}
