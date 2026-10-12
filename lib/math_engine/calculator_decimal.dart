import 'dart:math' as math;
import '../state/calculator_models.dart';
import 'calculator_exceptions.dart';

/// Greatest common divisor of two non-negative [BigInt] values.
BigInt bigIntGcd(BigInt a, BigInt b) {
  BigInt x = a.abs();
  BigInt y = b.abs();
  while (y != BigInt.zero) {
    final BigInt t = x % y;
    x = y;
    y = t;
  }
  return x == BigInt.zero ? BigInt.one : x;
}

/// Least common multiple of two [BigInt] values.
BigInt bigIntLcm(BigInt a, BigInt b) {
  if (a == BigInt.zero || b == BigInt.zero) return BigInt.zero;
  final BigInt absA = a.abs();
  final BigInt absB = b.abs();
  return (absA ~/ bigIntGcd(absA, absB)) * absB;
}

/// Exact arbitrary-precision rational number $p / q$ with $q > 0$ and $\gcd(|p|, q) = 1$.
class BigRational implements Comparable<BigRational> {
  final BigInt numerator;
  final BigInt denominator;

  const BigRational._(this.numerator, this.denominator);

  static final BigRational zero = BigRational._(BigInt.zero, BigInt.one);
  static final BigRational one = BigRational._(BigInt.one, BigInt.one);
  static final BigRational minusOne = BigRational._(-BigInt.one, BigInt.one);
  static final BigRational two = BigRational._(BigInt.two, BigInt.one);
  static final BigRational half = BigRational._(BigInt.one, BigInt.two);

  factory BigRational(BigInt numerator, [BigInt? denominator]) {
    final BigInt den = denominator ?? BigInt.one;
    if (den == BigInt.zero) {
      throw const MathErrorException('Division by zero in BigRational');
    }
    if (numerator == BigInt.zero) {
      return zero;
    }
    final bool negative = (numerator.isNegative) ^ (den.isNegative);
    final BigInt absNum = numerator.abs();
    final BigInt absDen = den.abs();
    final BigInt g = bigIntGcd(absNum, absDen);
    final BigInt redNum = absNum ~/ g;
    final BigInt redDen = absDen ~/ g;
    return BigRational._(negative ? -redNum : redNum, redDen);
  }

  factory BigRational.fromInt(int n, [int d = 1]) =>
      BigRational(BigInt.from(n), BigInt.from(d));

  /// Parses an exact decimal or fraction string into a [BigRational].
  static BigRational? tryParse(String raw) {
    final String clean = raw.trim().replaceAll('−', '-');
    if (clean.isEmpty) return null;

    if (clean.contains('/')) {
      final parts = clean.split('/');
      if (parts.length != 2) return null;
      final n = BigInt.tryParse(parts[0].trim());
      final d = BigInt.tryParse(parts[1].trim());
      if (n == null || d == null || d == BigInt.zero) return null;
      return BigRational(n, d);
    }

    // Handle scientific notation e.g. 1.5e-3
    final sciParts = clean.toLowerCase().split('e');
    if (sciParts.length > 2) return null;
    int expOffset = 0;
    if (sciParts.length == 2) {
      final parsedExp = int.tryParse(sciParts[1]);
      if (parsedExp == null || parsedExp.abs() > 120) return null;
      expOffset = parsedExp;
    }

    final String mantissa = sciParts[0];
    final bool isNeg = mantissa.startsWith('-');
    final String unsigned =
        (mantissa.startsWith('-') || mantissa.startsWith('+'))
            ? mantissa.substring(1)
            : mantissa;

    final dotParts = unsigned.split('.');
    if (dotParts.length > 2) return null;
    final String intPart = dotParts[0].isEmpty ? '0' : dotParts[0];
    final String fracPart = dotParts.length == 2 ? dotParts[1] : '';
    final BigInt? combinedDigits = BigInt.tryParse('$intPart$fracPart');
    if (combinedDigits == null) return null;

    final int totalScale = fracPart.length - expOffset;
    final BigInt signedDigits = isNeg ? -combinedDigits : combinedDigits;
    if (totalScale >= 0) {
      return BigRational(signedDigits, BigInt.from(10).pow(totalScale));
    } else {
      return BigRational(signedDigits * BigInt.from(10).pow(-totalScale));
    }
  }

  bool get isZero => numerator == BigInt.zero;
  bool get isInteger => denominator == BigInt.one;
  bool get isNegative => numerator.isNegative;
  bool get isPositive => numerator > BigInt.zero;

  BigRational operator +(BigRational other) => BigRational(
        numerator * other.denominator + other.numerator * denominator,
        denominator * other.denominator,
      );

  BigRational operator -(BigRational other) => BigRational(
        numerator * other.denominator - other.numerator * denominator,
        denominator * other.denominator,
      );

  BigRational operator *(BigRational other) => BigRational(
        numerator * other.numerator,
        denominator * other.denominator,
      );

  BigRational operator /(BigRational other) {
    if (other.isZero) {
      throw const MathErrorException('Division by zero');
    }
    return BigRational(
      numerator * other.denominator,
      denominator * other.numerator,
    );
  }

  BigRational operator -() => BigRational._(-numerator, denominator);

  BigRational abs() => isNegative ? -this : this;

  BigRational powInt(int exponent) {
    if (exponent == 0) {
      if (isZero) throw const MathErrorException('0^0 is undefined');
      return one;
    }
    if (exponent < 0) {
      if (isZero) throw const MathErrorException('0 to negative power');
      final int posExp = -exponent;
      return BigRational(denominator.pow(posExp), numerator.pow(posExp));
    }
    return BigRational(numerator.pow(exponent), denominator.pow(exponent));
  }

  /// Converts to improper fraction string `num/den` (or integer `num` if `den == 1`).
  String toImproperFractionString() {
    if (isInteger) return numerator.toString();
    return '$numerator/$denominator';
  }

  /// Converts to mixed fraction string `int num/den` when $|p| > q > 1$.
  String toMixedFractionString() {
    if (isInteger) return numerator.toString();
    final BigInt absNum = numerator.abs();
    if (absNum < denominator) return toImproperFractionString();
    final BigInt whole = absNum ~/ denominator;
    final BigInt rem = absNum % denominator;
    final String sign = isNegative ? '-' : '';
    return '$sign$whole $rem/$denominator';
  }

  /// Returns the exact terminating decimal string if the denominator has only
  /// prime factors $2$ and $5$, or `null` if it is a repeating decimal.
  String? toTerminatingDecimalString({int maxFractionDigits = 20}) {
    if (isInteger) return numerator.toString();
    BigInt d = denominator;
    int twos = 0;
    int fives = 0;
    while (d % BigInt.two == BigInt.zero) {
      d ~/= BigInt.two;
      twos++;
    }
    while (d % BigInt.from(5) == BigInt.zero) {
      d ~/= BigInt.from(5);
      fives++;
    }
    if (d != BigInt.one) return null;
    final int scale = math.max(twos, fives);
    if (scale > maxFractionDigits) return null;

    final BigInt multiplier =
        BigInt.two.pow(scale - twos) * BigInt.from(5).pow(scale - fives);
    final BigInt scaled = numerator.abs() * multiplier;
    final String digits = scaled.toString().padLeft(scale + 1, '0');
    final String intPart = digits.substring(0, digits.length - scale);
    final String fracPart = digits
        .substring(digits.length - scale)
        .replaceAll(RegExp(r'0+$'), '');
    final String sign = isNegative ? '-' : '';
    return fracPart.isEmpty ? '$sign$intPart' : '$sign$intPart.$fracPart';
  }

  /// Converts to recurring decimal notation (e.g. `1/3 -> 0.(3)`).
  String? toRecurringDecimalString({int maxCycleLength = 16}) {
    if (isInteger) return numerator.toString();
    final terminating = toTerminatingDecimalString();
    if (terminating != null) return terminating;

    final String sign = isNegative ? '-' : '';
    final BigInt absNum = numerator.abs();
    final BigInt intPart = absNum ~/ denominator;
    BigInt rem = absNum % denominator;

    final Map<BigInt, int> seenRemainders = {};
    final StringBuffer digits = StringBuffer();
    int pos = 0;

    while (rem != BigInt.zero && pos <= maxCycleLength) {
      if (seenRemainders.containsKey(rem)) {
        final int cycleStart = seenRemainders[rem]!;
        final String full = digits.toString();
        final String nonRepeating = full.substring(0, cycleStart);
        final String repeating = full.substring(cycleStart);
        return '$sign$intPart.$nonRepeating($repeating)';
      }
      seenRemainders[rem] = pos;
      rem *= BigInt.from(10);
      final BigInt digit = rem ~/ denominator;
      digits.write(digit.toString());
      rem %= denominator;
      pos++;
    }
    return null;
  }

  /// Converts this exact rational to a 30-digit [Cal_Decimal].
  Cal_Decimal toCal_Decimal() {
    return Cal_Decimal.fromBigInt(numerator) /
        Cal_Decimal.fromBigInt(denominator);
  }

  @override
  int compareTo(BigRational other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);

  @override
  bool operator ==(Object other) =>
      other is BigRational &&
      numerator == other.numerator &&
      denominator == other.denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  String toString() => toImproperFractionString();
}

/// Arbitrary-precision BCD/Decimal floating-point number for the Cal_ 1100_DB_.
///
/// Represents $\text{unscaled} \times 10^{-\text{scale}}$ using [BigInt] so that
/// decimal arithmetic ($0.1 + 0.2 = 0.3$, $10^{15} - 1 = 999999999999999$) never
/// suffers from IEEE-754 binary floating-point rounding artifacts.
class Cal_Decimal implements Comparable<Cal_Decimal> {
  /// Internal significant decimal digits (exceeds Cal_'s 23-digit BCD register).
  static const int internalPrecision = 30;

  final BigInt unscaled;
  final int scale;

  const Cal_Decimal._(this.unscaled, this.scale);

  static final Cal_Decimal zero = Cal_Decimal._(BigInt.zero, 0);
  static final Cal_Decimal one = Cal_Decimal._(BigInt.one, 0);
  static final Cal_Decimal minusOne = Cal_Decimal._(-BigInt.one, 0);
  static final Cal_Decimal two = Cal_Decimal._(BigInt.two, 0);
  static final Cal_Decimal ten = Cal_Decimal._(BigInt.from(10), 0);
  static final Cal_Decimal hundred = Cal_Decimal._(BigInt.from(100), 0);

  /// 32-digit $\pi$ constant.
  static final Cal_Decimal pi = Cal_Decimal.parse(
    '3.1415926535897932384626433832795',
  );

  /// 32-digit Euler's constant $e$.
  static final Cal_Decimal e = Cal_Decimal.parse(
    '2.7182818284590452353602874713527',
  );

  /// 32-digit $\ln(10)$ constant.
  static final Cal_Decimal ln10 = Cal_Decimal.parse(
    '2.3025850929940456840179914546844',
  );

  /// 32-digit $\ln(2)$ constant.
  static final Cal_Decimal ln2 = Cal_Decimal.parse(
    '0.6931471805599453094172321214582',
  );

  factory Cal_Decimal(BigInt unscaled, int scale, {bool clampPrecision = true}) {
    if (unscaled == BigInt.zero) return zero;

    BigInt u = unscaled;
    int s = scale;

    // Strip redundant trailing zeros when scale > 0
    final BigInt tenBig = BigInt.from(10);
    while (s > 0 && u % tenBig == BigInt.zero) {
      u ~/= tenBig;
      s--;
    }

    if (clampPrecision) {
      final String absStr = u.abs().toString();
      if (absStr.length > internalPrecision) {
        final int drop = absStr.length - internalPrecision;
        final BigInt divisor = tenBig.pow(drop);
        final BigInt half = divisor ~/ BigInt.two;
        final BigInt absU = u.abs();
        final BigInt rem = absU % divisor;
        BigInt rounded = absU ~/ divisor;
        if (rem >= half) {
          rounded += BigInt.one;
        }
        u = u.isNegative ? -rounded : rounded;
        s -= drop;
        while (s > 0 && u % tenBig == BigInt.zero) {
          u ~/= tenBig;
          s--;
        }
      }
    }

    return Cal_Decimal._(u, s);
  }

  factory Cal_Decimal.fromInt(int value) =>
      Cal_Decimal(BigInt.from(value), 0, clampPrecision: false);

  factory Cal_Decimal.fromBigInt(BigInt value) =>
      Cal_Decimal(value, 0, clampPrecision: false);

  factory Cal_Decimal.fromDouble(double value) {
    if (value.isNaN || value.isInfinite) {
      throw const MathErrorException('Non-finite value');
    }
    return Cal_Decimal.parse(value.toStringAsPrecision(15));
  }

  /// Parses an arbitrary-precision decimal string without touching IEEE-754 `double`.
  factory Cal_Decimal.parse(String raw) {
    final String clean = raw
        .trim()
        .replaceAll('−', '-')
        .replaceAll('×10^', 'e')
        .replaceAll('*10^', 'e')
        .replaceAll(' ', '');
    if (clean.isEmpty) {
      throw const SyntaxErrorException('Empty numeric literal');
    }

    final sciParts = clean.toLowerCase().split('e');
    if (sciParts.length > 2) {
      throw SyntaxErrorException('Invalid scientific literal: $raw');
    }

    int expOffset = 0;
    if (sciParts.length == 2) {
      final int? parsedExp = int.tryParse(sciParts[1]);
      if (parsedExp == null) {
        throw SyntaxErrorException('Invalid exponent: $raw');
      }
      expOffset = parsedExp;
    }

    final String mantissa = sciParts[0];
    final bool isNeg = mantissa.startsWith('-');
    final String unsigned =
        (mantissa.startsWith('-') || mantissa.startsWith('+'))
            ? mantissa.substring(1)
            : mantissa;
    if (unsigned.isEmpty || unsigned == '.') {
      throw SyntaxErrorException('Malformed numeric literal: $raw');
    }

    final dotParts = unsigned.split('.');
    if (dotParts.length > 2) {
      throw SyntaxErrorException('Multiple decimal points: $raw');
    }

    final String intPart = dotParts[0].isEmpty ? '0' : dotParts[0];
    final String fracPart = dotParts.length == 2 ? dotParts[1] : '';
    final BigInt? digits = BigInt.tryParse('$intPart$fracPart');
    if (digits == null) {
      throw SyntaxErrorException('Invalid digits: $raw');
    }

    final BigInt signed = isNeg ? -digits : digits;
    final int scale = fracPart.length - expOffset;
    return Cal_Decimal(signed, scale, clampPrecision: false);
  }

  static Cal_Decimal? tryParse(String raw) {
    try {
      return Cal_Decimal.parse(raw);
    } catch (_) {
      return null;
    }
  }

  bool get isZero => unscaled == BigInt.zero;
  bool get isNegative => unscaled.isNegative;
  bool get isPositive => unscaled > BigInt.zero;

  /// Base-10 order of magnitude $\lfloor \log_{10}|x| \rfloor$.
  int get exponent10 {
    if (isZero) return 0;
    final int digits = unscaled.abs().toString().length;
    return digits - 1 - scale;
  }

  /// Whether this value is an exact integer.
  bool get isInteger {
    if (isZero) return true;
    if (scale <= 0) return true;
    final BigInt divisor = BigInt.from(10).pow(scale);
    return (unscaled % divisor) == BigInt.zero;
  }

  /// Converts to an exact [BigInt] if [isInteger] is true, otherwise throws [ArgumentErrorException].
  BigInt toExactBigInt() {
    if (isZero) return BigInt.zero;
    if (scale <= 0) {
      return unscaled * BigInt.from(10).pow(-scale);
    }
    final BigInt divisor = BigInt.from(10).pow(scale);
    if (unscaled % divisor != BigInt.zero) {
      throw const ArgumentErrorException('Expected integer argument');
    }
    return unscaled ~/ divisor;
  }

  /// Enforces Cal_'s $[-99, +99]$ exponent range.
  Cal_Decimal checkRange() {
    if (isZero) return zero;
    final int exp = exponent10;
    if (exp >= 100) {
      throw const MathErrorException('Exponent overflow (>= 10^100)');
    }
    if (exp < -99) {
      return zero;
    }
    return this;
  }

  Cal_Decimal operator +(Cal_Decimal other) {
    if (isZero) return other;
    if (other.isZero) return this;
    final int targetScale = math.max(scale, other.scale);
    final BigInt tenBig = BigInt.from(10);
    final BigInt a = unscaled * tenBig.pow(targetScale - scale);
    final BigInt b = other.unscaled * tenBig.pow(targetScale - other.scale);
    return Cal_Decimal(a + b, targetScale).checkRange();
  }

  Cal_Decimal operator -(Cal_Decimal other) => this + (-other);

  Cal_Decimal operator -() =>
      isZero ? zero : Cal_Decimal._(-unscaled, scale);

  Cal_Decimal abs() => isNegative ? -this : this;

  Cal_Decimal operator *(Cal_Decimal other) {
    if (isZero || other.isZero) return zero;
    return Cal_Decimal(
      unscaled * other.unscaled,
      scale + other.scale,
    ).checkRange();
  }

  Cal_Decimal operator /(Cal_Decimal other) {
    if (other.isZero) {
      throw const MathErrorException('Division by zero');
    }
    if (isZero) return zero;

    final int numDigits = unscaled.abs().toString().length;
    final int denDigits = other.unscaled.abs().toString().length;
    final int digitDeficit = math.max(0, denDigits - numDigits);
    final int extraScale = internalPrecision + 6 + digitDeficit;
    final BigInt tenBig = BigInt.from(10);
    final BigInt scaledNumerator = unscaled.abs() * tenBig.pow(extraScale);
    final BigInt absDen = other.unscaled.abs();
    BigInt quotient = scaledNumerator ~/ absDen;
    final BigInt rem = scaledNumerator % absDen;
    if (rem * BigInt.two >= absDen) {
      quotient += BigInt.one;
    }

    final bool neg = isNegative ^ other.isNegative;
    final BigInt signedQuotient = neg ? -quotient : quotient;
    return Cal_Decimal(
      signedQuotient,
      scale - other.scale + extraScale,
    ).checkRange();
  }

  /// Exact integer power $x^n$ using binary exponentiation without float precision loss.
  Cal_Decimal powInt(int n) {
    if (n == 0) {
      if (isZero) throw const MathErrorException('0^0 is undefined');
      return one;
    }
    if (isZero) {
      if (n < 0) throw const MathErrorException('0 to negative power');
      return zero;
    }
    final bool negExp = n < 0;
    int exp = n.abs();

    // For moderate integer exponents on integers (like 10^15), preserve full exactness
    final bool keepFull = !negExp && scale == 0 && exponent10 * exp <= 28;
    Cal_Decimal result = one;
    Cal_Decimal base = this;

    while (exp > 0) {
      if ((exp & 1) == 1) {
        result = Cal_Decimal(
          result.unscaled * base.unscaled,
          result.scale + base.scale,
          clampPrecision: !keepFull,
        );
      }
      exp >>= 1;
      if (exp > 0) {
        base = Cal_Decimal(
          base.unscaled * base.unscaled,
          base.scale * 2,
          clampPrecision: !keepFull,
        );
      }
    }

    if (negExp) {
      return (one / result).checkRange();
    }
    return result.checkRange();
  }

  /// High-precision square root $\sqrt{x}$ computed via integer Newton-Raphson
  /// to 30 significant digits.
  Cal_Decimal sqrt() {
    if (isNegative) {
      throw const MathErrorException('Square root of negative number in Real mode');
    }
    if (isZero) return zero;
    if (this == one) return one;

    // Align scale to an even number with at least 2 * (internalPrecision + 4) digits
    int targetScale = scale + 2 * (internalPrecision + 4);
    if (targetScale.isOdd) targetScale++;
    final int shift = targetScale - scale;
    final BigInt radicand = unscaled * BigInt.from(10).pow(shift);

    // Integer square root via Newton's method
    BigInt x0 = BigInt.one << ((radicand.bitLength + 1) >> 1);
    while (true) {
      final BigInt x1 = (x0 + (radicand ~/ x0)) >> 1;
      if (x1 >= x0) break;
      x0 = x1;
    }
    return Cal_Decimal(x0, targetScale ~/ 2).checkRange();
  }

  /// High-precision natural exponential $e^x$ via range reduction $x = k \ln(2) + r$
  /// and 28-term Taylor series.
  Cal_Decimal exp() {
    if (isZero) return one;
    final double approx = toDouble();
    if (approx > 230.2585092994046) {
      throw const MathErrorException('exp overflow (>= 10^100)');
    }
    if (approx < -230.2585092994046) {
      return zero;
    }

    final int k = (approx / 0.6931471805599453).round();
    final Cal_Decimal r = this - (ln2 * Cal_Decimal.fromInt(k));

    Cal_Decimal sum = one;
    Cal_Decimal term = one;
    for (int i = 1; i <= 32; i++) {
      term = (term * r) / Cal_Decimal.fromInt(i);
      if (term.isZero || term.exponent10 < -32) break;
      sum = sum + term;
    }

    if (k > 0) {
      sum = sum * Cal_Decimal.fromBigInt(BigInt.one << k);
    } else if (k < 0) {
      sum = sum / Cal_Decimal.fromBigInt(BigInt.one << (-k));
    }
    return sum.checkRange();
  }

  /// High-precision natural logarithm $\ln(x)$ via argument reduction and Halley/series refinement.
  Cal_Decimal ln() {
    if (isZero || isNegative) {
      throw const MathErrorException('ln of non-positive number');
    }
    if (this == one) return zero;

    // Reduce x = m * 10^k where m in [0.1, 10)
    final int k10 = exponent10;
    Cal_Decimal m = Cal_Decimal(unscaled, scale + k10);

    // Further reduce m towards 1 using square roots: ln(m) = 2^6 * ln(m^(1/64))
    for (int i = 0; i < 6; i++) {
      m = m.sqrt();
    }

    // Use artanh series: ln(m) = 2 * sum_{n=0..inf} ((m-1)/(m+1))^(2n+1) / (2n+1)
    final Cal_Decimal u = (m - one) / (m + one);
    final Cal_Decimal u2 = u * u;
    Cal_Decimal term = u;
    Cal_Decimal sum = u;
    for (int n = 1; n <= 25; n++) {
      term = term * u2;
      final Cal_Decimal contrib = term / Cal_Decimal.fromInt(2 * n + 1);
      if (contrib.isZero || contrib.exponent10 < -32) break;
      sum = sum + contrib;
    }

    final Cal_Decimal lnM = sum * Cal_Decimal.fromInt(128);
    return (lnM + (ln10 * Cal_Decimal.fromInt(k10))).checkRange();
  }

  /// Base-10 logarithm $\log_{10}(x)$.
  Cal_Decimal log10() {
    if (isZero || isNegative) {
      throw const MathErrorException('log10 of non-positive number');
    }
    // Check if exact power of 10
    final String digits = unscaled.abs().toString().replaceAll(RegExp(r'0+$'), '');
    if (digits == '1') {
      return Cal_Decimal.fromInt(exponent10);
    }
    return (ln() / ln10).checkRange();
  }

  /// General power $x^y$.
  Cal_Decimal pow(Cal_Decimal exponent) {
    if (exponent.isZero) {
      if (isZero) throw const MathErrorException('0^0 is undefined');
      return one;
    }
    if (exponent.isInteger) {
      final BigInt expBig = exponent.toExactBigInt();
      if (expBig.abs() <= BigInt.from(10000)) {
        return powInt(expBig.toInt());
      }
    }
    if (isZero) {
      if (exponent.isNegative) {
        throw const MathErrorException('0 to negative power');
      }
      return zero;
    }
    if (isNegative) {
      // Check if exponent is a rational p/q with odd denominator q
      final BigRational? ratExp = BigRational.tryParse(exponent.toPlainString());
      if (ratExp != null && ratExp.denominator.isOdd) {
        final Cal_Decimal mag = (abs().ln() * exponent).exp();
        return ratExp.numerator.isOdd ? -mag : mag;
      }
      throw const MathErrorException('Negative base with non-integer power in Real mode');
    }
    return (ln() * exponent).exp();
  }

  /// High-precision $\sin(x)$ in [angleUnit] with exact boundary zeroes.
  Cal_Decimal sinAngle(AngleUnit angleUnit) {
    final Cal_Decimal rad = _toReducedRadian(angleUnit, outZeroCheckSin: true);
    if (rad.isZero) return zero;
    return _sinRadSeries(rad);
  }

  /// High-precision $\cos(x)$ in [angleUnit] with exact boundary zeroes.
  Cal_Decimal cosAngle(AngleUnit angleUnit) {
    final double degEquiv = _toNormalizedDegrees(angleUnit);
    if ((degEquiv - 90.0).abs() < 1e-13 || (degEquiv - 270.0).abs() < 1e-13) {
      return zero;
    }
    if (degEquiv.abs() < 1e-13) return one;
    if ((degEquiv - 180.0).abs() < 1e-13) return minusOne;

    final Cal_Decimal rad = _toReducedRadian(angleUnit, outZeroCheckSin: false);
    return _cosRadSeries(rad);
  }

  /// High-precision $\tan(x)$ in [angleUnit] with pole detection at $\pm 90^\circ, 270^\circ$.
  Cal_Decimal tanAngle(AngleUnit angleUnit) {
    final double degEquiv = _toNormalizedDegrees(angleUnit);
    if ((degEquiv - 90.0).abs() < 1e-12 || (degEquiv - 270.0).abs() < 1e-12) {
      throw const MathErrorException('tan pole at 90/270 deg');
    }
    if (degEquiv.abs() < 1e-13 || (degEquiv - 180.0).abs() < 1e-13) {
      return zero;
    }
    if ((degEquiv - 45.0).abs() < 1e-13 || (degEquiv - 225.0).abs() < 1e-13) {
      return one;
    }
    if ((degEquiv - 135.0).abs() < 1e-13 || (degEquiv - 315.0).abs() < 1e-13) {
      return minusOne;
    }
    final Cal_Decimal c = cosAngle(angleUnit);
    if (c.isZero) throw const MathErrorException('tan division by zero');
    return sinAngle(angleUnit) / c;
  }

  double _toNormalizedDegrees(AngleUnit unit) {
    final double v = toDouble();
    final double deg = switch (unit) {
      AngleUnit.degree => v,
      AngleUnit.radian => v * 180.0 / math.pi,
      AngleUnit.gradian => v * 0.9,
    };
    double mod = deg % 360.0;
    if (mod < 0) mod += 360.0;
    return mod;
  }

  Cal_Decimal _toReducedRadian(
    AngleUnit unit, {
    required bool outZeroCheckSin,
  }) {
    final Cal_Decimal twoPi = pi * two;
    Cal_Decimal rad = switch (unit) {
      AngleUnit.degree => (this * pi) / Cal_Decimal.fromInt(180),
      AngleUnit.radian => this,
      AngleUnit.gradian => (this * pi) / Cal_Decimal.fromInt(200),
    };

    // Reduce modulo 2*pi
    final int wraps = (rad.toDouble() / (2 * math.pi)).floor();
    if (wraps != 0) {
      rad = rad - (twoPi * Cal_Decimal.fromInt(wraps));
    }
    if (outZeroCheckSin) {
      final double deg = _toNormalizedDegrees(unit);
      if (deg.abs() < 1e-13 || (deg - 180.0).abs() < 1e-13) {
        return zero;
      }
    }
    return rad;
  }

  static Cal_Decimal _sinRadSeries(Cal_Decimal x) {
    Cal_Decimal sum = x;
    Cal_Decimal term = x;
    final Cal_Decimal negX2 = -(x * x);
    for (int n = 1; n <= 24; n++) {
      term = (term * negX2) / Cal_Decimal.fromInt((2 * n) * (2 * n + 1));
      if (term.isZero || term.exponent10 < -32) break;
      sum = sum + term;
    }
    return sum;
  }

  static Cal_Decimal _cosRadSeries(Cal_Decimal x) {
    Cal_Decimal sum = one;
    Cal_Decimal term = one;
    final Cal_Decimal negX2 = -(x * x);
    for (int n = 1; n <= 24; n++) {
      term = (term * negX2) / Cal_Decimal.fromInt((2 * n - 1) * (2 * n));
      if (term.isZero || term.exponent10 < -32) break;
      sum = sum + term;
    }
    return sum;
  }

  /// Converts to `double` for canvas/plotting or fast seeds.
  double toDouble() => double.parse(toPlainString());

  /// Unrounded plain or scientific string representation.
  String toPlainString() {
    if (isZero) return '0';
    final String sign = isNegative ? '-' : '';
    final String digits = unscaled.abs().toString();
    if (scale == 0) return '$sign$digits';
    if (scale < 0) {
      return '$sign$digits${'0' * (-scale)}';
    }
    if (digits.length > scale) {
      final String intPart = digits.substring(0, digits.length - scale);
      final String fracPart = digits
          .substring(digits.length - scale)
          .replaceAll(RegExp(r'0+$'), '');
      return fracPart.isEmpty ? '$sign$intPart' : '$sign$intPart.$fracPart';
    } else {
      final String zeros = '0' * (scale - digits.length);
      final String fracPart =
          '$zeros$digits'.replaceAll(RegExp(r'0+$'), '');
      return fracPart.isEmpty ? '0' : '${sign}0.$fracPart';
    }
  }

  /// Formats for the Cal_ 1100_DB_ display (10 display digits in standard float
  /// mode, while preserving up to 15 exact integer/decimal digits when exact).
  String formatCal_Display({
    NumberFormatMode numberFormat = NumberFormatMode.norm1,
    int fixSciDigits = 2,
    int displayPrecision = 10,
  }) {
    checkRange();
    if (isZero) {
      if (numberFormat == NumberFormatMode.fix && fixSciDigits > 0) {
        return '0.${'0' * fixSciDigits}';
      }
      return '0';
    }

    // If this is an exact integer up to 15 digits (e.g. 10^15 - 1 = 999999999999999),
    // return the exact integer string in Norm1/Norm2 mode.
    if (numberFormat == NumberFormatMode.norm1 ||
        numberFormat == NumberFormatMode.norm2) {
      if (isInteger) {
        final String exactIntStr = toExactBigInt().abs().toString();
        if (exactIntStr.length <= 15) {
          return isNegative ? '-$exactIntStr' : exactIntStr;
        }
      }
    }

    if (numberFormat == NumberFormatMode.fix) {
      return _formatFixed(fixSciDigits.clamp(0, 9));
    }
    if (numberFormat == NumberFormatMode.sci) {
      return _formatScientific((fixSciDigits - 1).clamp(0, 9));
    }

    final int exp = exponent10;
    final int lowThreshold = numberFormat == NumberFormatMode.norm1 ? -2 : -9;
    if (exp >= displayPrecision || exp < lowThreshold) {
      return _formatScientific(displayPrecision - 1);
    }

    // Round to displayPrecision significant digits
    final Cal_Decimal rounded = _roundToSigFigs(displayPrecision);
    if (rounded.isInteger && rounded.exponent10 < displayPrecision) {
      return rounded.toExactBigInt().toString();
    }
    return rounded.toPlainString();
  }

  Cal_Decimal _roundToSigFigs(int sigFigs) {
    if (isZero) return zero;
    final String absStr = unscaled.abs().toString();
    if (absStr.length <= sigFigs) return this;
    final int drop = absStr.length - sigFigs;
    final BigInt tenBig = BigInt.from(10);
    final BigInt divisor = tenBig.pow(drop);
    final BigInt absU = unscaled.abs();
    BigInt q = absU ~/ divisor;
    final BigInt r = absU % divisor;
    if (r * BigInt.two >= divisor) {
      q += BigInt.one;
    }
    return Cal_Decimal(isNegative ? -q : q, scale - drop, clampPrecision: false);
  }

  String _formatFixed(int decimals) {
    final BigInt tenBig = BigInt.from(10);
    BigInt scaled;
    if (scale <= decimals) {
      scaled = unscaled.abs() * tenBig.pow(decimals - scale);
    } else {
      final BigInt div = tenBig.pow(scale - decimals);
      final BigInt absU = unscaled.abs();
      scaled = absU ~/ div;
      if ((absU % div) * BigInt.two >= div) {
        scaled += BigInt.one;
      }
    }
    final String sign = (isNegative && scaled != BigInt.zero) ? '-' : '';
    if (decimals == 0) return '$sign$scaled';
    final String digits = scaled.toString().padLeft(decimals + 1, '0');
    final String intPart = digits.substring(0, digits.length - decimals);
    final String fracPart = digits.substring(digits.length - decimals);
    return '$sign$intPart.$fracPart';
  }

  String _formatScientific(int fracDigits) {
    final Cal_Decimal rounded = _roundToSigFigs(fracDigits + 1);
    final int exp = rounded.exponent10;
    final String digits = rounded.unscaled
        .abs()
        .toString()
        .replaceAll(RegExp(r'0+$'), '');
    final String sign = rounded.isNegative ? '-' : '';
    if (digits.length <= 1) {
      return '$sign${digits.isEmpty ? '0' : digits}×10^$exp';
    }
    final String mantissa = '${digits[0]}.${digits.substring(1)}';
    return '$sign$mantissa×10^$exp';
  }

  @override
  int compareTo(Cal_Decimal other) {
    final Cal_Decimal diff = this - other;
    if (diff.isZero) return 0;
    return diff.isNegative ? -1 : 1;
  }

  bool operator <(Cal_Decimal other) => compareTo(other) < 0;
  bool operator <=(Cal_Decimal other) => compareTo(other) <= 0;
  bool operator >(Cal_Decimal other) => compareTo(other) > 0;
  bool operator >=(Cal_Decimal other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is Cal_Decimal && compareTo(other) == 0;

  @override
  int get hashCode => toPlainString().hashCode;

  @override
  String toString() => toPlainString();
}
