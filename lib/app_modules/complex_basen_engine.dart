import 'dart:math' as math;
import '../state/calculator_models.dart';
import 'linear_algebra_engine.dart';

/// Represents a complex number $z = a + bi$ in the Cal_ 1100_DB_ `Complex` app.
class ComplexNumber {
  final double real;
  final double imag;

  const ComplexNumber(this.real, [this.imag = 0.0]);

  static const ComplexNumber zero = ComplexNumber(0.0, 0.0);
  static const ComplexNumber one = ComplexNumber(1.0, 0.0);
  static const ComplexNumber i = ComplexNumber(0.0, 1.0);

  factory ComplexNumber.fromPolar(
    double r,
    double theta,
    AngleUnit angleUnit,
  ) {
    final double rad = switch (angleUnit) {
      AngleUnit.degree => theta * math.pi / 180.0,
      AngleUnit.radian => theta,
      AngleUnit.gradian => theta * math.pi / 200.0,
    };
    return ComplexNumber(r * math.cos(rad), r * math.sin(rad));
  }

  ComplexNumber operator +(ComplexNumber other) =>
      ComplexNumber(real + other.real, imag + other.imag);

  ComplexNumber operator -(ComplexNumber other) =>
      ComplexNumber(real - other.real, imag - other.imag);

  ComplexNumber operator -() => ComplexNumber(-real, -imag);

  ComplexNumber operator *(ComplexNumber other) => ComplexNumber(
        real * other.real - imag * other.imag,
        real * other.imag + imag * other.real,
      );

  ComplexNumber operator /(ComplexNumber other) {
    final double denom = other.real * other.real + other.imag * other.imag;
    if (denom < 1e-24) {
      throw const FormatException('Math ERROR');
    }
    return ComplexNumber(
      (real * other.real + imag * other.imag) / denom,
      (imag * other.real - real * other.imag) / denom,
    );
  }

  /// Modulus $|z| = \sqrt{a^2 + b^2}$ (`Abs(z)`).
  double get modulus => math.sqrt(real * real + imag * imag);

  /// Argument $\arg(z)$ in the active [AngleUnit] (`Arg(z)`).
  double argument(AngleUnit angleUnit) {
    if (real.abs() < 1e-15 && imag.abs() < 1e-15) {
      throw const FormatException('Math ERROR');
    }
    final double rad = math.atan2(imag, real);
    return switch (angleUnit) {
      AngleUnit.degree => rad * 180.0 / math.pi,
      AngleUnit.radian => rad,
      AngleUnit.gradian => rad * 200.0 / math.pi,
    };
  }

  /// Complex conjugate $\bar{z} = a - bi$ (`Conjg(z)`).
  ComplexNumber get conjugate => ComplexNumber(real, -imag);

  /// Principal square root $\sqrt{z}$.
  ComplexNumber sqrt() {
    final double r = modulus;
    final double re = math.sqrt(0.5 * (r + real));
    final double im = (imag < 0 ? -1.0 : 1.0) * math.sqrt(0.5 * math.max(0.0, r - real));
    return ComplexNumber(re, im);
  }

  /// Integer/real power $z^n$ via De Moivre's theorem.
  ComplexNumber pow(double n) {
    final double r = modulus;
    if (r < 1e-15) {
      if (n <= 0) throw const FormatException('Math ERROR');
      return ComplexNumber.zero;
    }
    final double theta = math.atan2(imag, real);
    final double rn = math.pow(r, n).toDouble();
    return ComplexNumber(rn * math.cos(n * theta), rn * math.sin(n * theta));
  }

  /// Formats in Rectangular form $a + bi$.
  String toRectangularString() {
    final double re = real.abs() < 1e-11 ? 0.0 : real;
    final double im = imag.abs() < 1e-11 ? 0.0 : imag;
    if (im == 0.0) {
      return formatCal_Scalar(re);
    }
    final String imAbs =
        (im.abs() - 1.0).abs() < 1e-11 ? '' : formatCal_Scalar(im.abs());
    if (re == 0.0) {
      return '${im < 0 ? "-" : ""}${imAbs}i';
    }
    final String sign = im >= 0 ? '+' : '-';
    return '${formatCal_Scalar(re)}$sign${imAbs}i';
  }

  /// Formats in Polar form $r \angle \theta$.
  String toPolarString(AngleUnit angleUnit) {
    final double r = modulus;
    if (r < 1e-11) return '0∠0';
    final double ang = argument(angleUnit);
    return '${formatCal_Scalar(r)}∠${formatCal_Scalar(ang)}';
  }
}

/// Evaluates expressions in `Complex` mode supporting `i`, `∠`, `Abs(`, `Arg(`, `Conjg(`, `ReP(`, `ImP(`.
class ComplexExpressionEvaluator {
  final AngleUnit angleUnit;

  const ComplexExpressionEvaluator({this.angleUnit = AngleUnit.degree});

  ({ComplexNumber? value, String rectangularText, String polarText, String? error})
      evaluate(String rawExpression) {
    try {
      final String expr = _preprocessComplex(rawExpression);
      final ComplexNumber z = _parseAddSub(expr);
      return (
        value: z,
        rectangularText: z.toRectangularString(),
        polarText: z.toPolarString(angleUnit),
        error: null,
      );
    } on FormatException catch (e) {
      return (
        value: null,
        rectangularText: '',
        polarText: '',
        error: e.message,
      );
    } catch (_) {
      return (
        value: null,
        rectangularText: '',
        polarText: '',
        error: 'Syntax ERROR',
      );
    }
  }

  String _preprocessComplex(String raw) {
    String s = raw
        .replaceAll(' ', '')
        .replaceAll('−', '-')
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('⁻¹', '^(-1)');
    // Implicit multiplication before 'i', '(', '√'
    s = s.replaceAllMapped(
      RegExp(r'(\d|\))i'),
      (m) => '${m.group(1)}*i',
    );
    s = s.replaceAllMapped(
      RegExp(r'(\d)\('),
      (m) => '${m.group(1)}*(',
    );
    s = s.replaceAll(')(', ')*(');
    s = s.replaceAllMapped(
      RegExp(r'i(\d|\()'),
      (m) => 'i*${m.group(1)}',
    );

    // Auto-close dangling parentheses
    int open = 0;
    for (int k = 0; k < s.length; k++) {
      if (s[k] == '(') open++;
      if (s[k] == ')') open--;
    }
    while (open > 0) {
      s += ')';
      open--;
    }
    if (open < 0) throw const FormatException('Syntax ERROR');
    return s;
  }

  ComplexNumber _parseAddSub(String s) {
    final String trimmed = s.trim();
    int depth = 0;
    for (int k = trimmed.length - 1; k > 0; k--) {
      final ch = trimmed[k];
      if (ch == ')') depth++;
      if (ch == '(') depth--;
      if (depth == 0 && (ch == '+' || ch == '-')) {
        final prev = trimmed[k - 1];
        if (prev == '*' ||
            prev == '/' ||
            prev == '^' ||
            prev == '∠' ||
            prev == '(') {
          continue;
        }
        final left = _parseAddSub(trimmed.substring(0, k));
        final right = _parseMulDiv(trimmed.substring(k + 1));
        return ch == '+' ? (left + right) : (left - right);
      }
    }
    return _parseMulDiv(trimmed);
  }

  ComplexNumber _parseMulDiv(String s) {
    final String trimmed = s.trim();
    int depth = 0;
    for (int k = trimmed.length - 1; k > 0; k--) {
      final ch = trimmed[k];
      if (ch == ')') depth++;
      if (ch == '(') depth--;
      if (depth == 0 && (ch == '*' || ch == '/')) {
        final left = _parseMulDiv(trimmed.substring(0, k));
        final right = _parsePowerPolar(trimmed.substring(k + 1));
        return ch == '*' ? (left * right) : (left / right);
      }
    }
    return _parsePowerPolar(trimmed);
  }

  ComplexNumber _parsePowerPolar(String s) {
    final String trimmed = s.trim();
    if (trimmed.startsWith('-')) {
      return -_parsePowerPolar(trimmed.substring(1));
    }
    if (trimmed.startsWith('+')) {
      return _parsePowerPolar(trimmed.substring(1));
    }

    int depth = 0;
    for (int k = 0; k < trimmed.length; k++) {
      final ch = trimmed[k];
      if (ch == '(') depth++;
      if (ch == ')') depth--;
      if (depth == 0 && ch == '∠') {
        final r = _parseAtom(trimmed.substring(0, k)).real;
        final theta = _parseAtom(trimmed.substring(k + 1)).real;
        return ComplexNumber.fromPolar(r, theta, angleUnit);
      }
      if (depth == 0 && ch == '^') {
        final base = _parseAtom(trimmed.substring(0, k));
        final exp = _parsePowerPolar(trimmed.substring(k + 1));
        return base.pow(exp.real);
      }
    }
    return _parseAtom(trimmed);
  }

  ComplexNumber _parseAtom(String s) {
    final String trimmed = s.trim();
    if (trimmed.isEmpty) throw const FormatException('Syntax ERROR');
    if (_isEnclosedByOuterParens(trimmed)) {
      return _parseAddSub(trimmed.substring(1, trimmed.length - 1));
    }
    if (trimmed == 'i') return ComplexNumber.i;

    for (final fn in ['Abs(', 'Arg(', 'Conjg(', 'ReP(', 'ImP(', '√(']) {
      if (trimmed.startsWith(fn) && trimmed.endsWith(')')) {
        final inner = _parseAddSub(
          trimmed.substring(fn.length, trimmed.length - 1),
        );
        return switch (fn) {
          'Abs(' => ComplexNumber(inner.modulus, 0.0),
          'Arg(' => ComplexNumber(inner.argument(angleUnit), 0.0),
          'Conjg(' => inner.conjugate,
          'ReP(' => ComplexNumber(inner.real, 0.0),
          'ImP(' => ComplexNumber(inner.imag, 0.0),
          '√(' => inner.sqrt(),
          _ => inner,
        };
      }
    }

    final double? val = double.tryParse(trimmed);
    if (val != null) {
      return ComplexNumber(val, 0.0);
    }
    throw const FormatException('Syntax ERROR');
  }

  bool _isEnclosedByOuterParens(String s) {
    if (s.length < 2 || !s.startsWith('(') || !s.endsWith(')')) return false;
    int depth = 0;
    for (int i = 0; i < s.length - 1; i++) {
      if (s[i] == '(') depth++;
      if (s[i] == ')') depth--;
      if (depth == 0) return false;
    }
    return depth == 1;
  }
}

/// Active radix in the `Base-N` app (`DEC`, `HEX`, `BIN`, `OCT`).
enum NumberBase {
  dec(10, 'DEC', 'Dec'),
  hex(16, 'HEX', 'Hex'),
  bin(2, 'BIN', 'Bin'),
  oct(8, 'OCT', 'Oct');

  final int radix;
  final String badge;
  final String title;
  const NumberBase(this.radix, this.badge, this.title);
}

/// 32-Bit Signed Two's Complement Integer & Bitwise Engine for the `Base-N` app.
class BaseNEngine {
  /// Converts any Dart `int` into a 32-bit signed two's complement integer
  /// in the range $[-2^{31}, 2^{31} - 1]$.
  static int toSigned32(int value) {
    return value.toSigned(32);
  }

  /// Converts a 32-bit signed integer into its unsigned 32-bit pattern $[0, 2^{32}-1]$.
  static int toUnsigned32(int value) {
    return value.toUnsigned(32);
  }

  /// Formats [value] in [targetBase] using Cal_ 1100_DB_ 32-bit two's complement rules.
  static String formatInBase(int value, NumberBase targetBase) {
    final int s32 = toSigned32(value);
    if (targetBase == NumberBase.dec) {
      return s32.toString();
    }
    final int u32 = toUnsigned32(s32);
    return switch (targetBase) {
      NumberBase.dec => s32.toString(),
      NumberBase.hex => u32.toRadixString(16).toUpperCase(),
      NumberBase.oct => u32.toRadixString(8),
      NumberBase.bin => u32.toRadixString(2),
    };
  }

  /// Parses a literal in [activeBase] (or with an explicit prefix `d`, `h`, `b`, `o`).
  static int parseLiteral(String rawToken, NumberBase activeBase) {
    String token = rawToken.trim().toUpperCase();
    if (token.isEmpty) throw const FormatException('Syntax ERROR');

    bool isNegative = false;
    if (token.startsWith('-')) {
      isNegative = true;
      token = token.substring(1);
    }

    NumberBase base = activeBase;
    if (token.length > 1) {
      final first = token[0];
      if (first == 'D' && activeBase != NumberBase.hex) {
        base = NumberBase.dec;
        token = token.substring(1);
      } else if (first == 'H') {
        base = NumberBase.hex;
        token = token.substring(1);
      } else if (first == 'B' && activeBase != NumberBase.hex) {
        base = NumberBase.bin;
        token = token.substring(1);
      } else if (first == 'O') {
        base = NumberBase.oct;
        token = token.substring(1);
      }
    }

    final int? parsed = int.tryParse(token, radix: base.radix);
    if (parsed == null) {
      throw const FormatException('Syntax ERROR');
    }
    final int signedVal = isNegative ? -parsed : parsed;
    return toSigned32(signedVal);
  }

  /// Evaluates a Base-N expression supporting `+`, `-`, `*`, `/`, `AND`, `OR`,
  /// `XOR`, `XNOR`, `Not(`, and `Neg(`.
  static ({int? value, String formatted, String? error}) evaluate(
    String rawExpr,
    NumberBase activeBase,
  ) {
    try {
      String expr = rawExpr
          .replaceAll(' ', '')
          .replaceAll('−', '-')
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('XNOR', '~')
          .replaceAll('XOR', '^')
          .replaceAll('AND', '&')
          .replaceAll('OR', '|');

      int open = 0;
      for (int i = 0; i < expr.length; i++) {
        if (expr[i] == '(') open++;
        if (expr[i] == ')') open--;
      }
      while (open > 0) {
        expr += ')';
        open--;
      }
      if (open < 0) throw const FormatException('Syntax ERROR');

      final int res = _evalOrXor(expr, activeBase);
      return (
        value: res,
        formatted: formatInBase(res, activeBase),
        error: null,
      );
    } on FormatException catch (e) {
      return (value: null, formatted: '', error: e.message);
    } catch (_) {
      return (value: null, formatted: '', error: 'Syntax ERROR');
    }
  }

  static int _evalOrXor(String s, NumberBase base) {
    final String cur = _stripParens(s);
    int depth = 0;
    for (int i = cur.length - 1; i > 0; i--) {
      final ch = cur[i];
      if (ch == ')') depth++;
      if (ch == '(') depth--;
      if (depth == 0 && (ch == '|' || ch == '^' || ch == '~')) {
        final left = _evalOrXor(cur.substring(0, i), base);
        final right = _evalAnd(cur.substring(i + 1), base);
        return switch (ch) {
          '|' => toSigned32(left | right),
          '^' => toSigned32(left ^ right),
          '~' => toSigned32(~(left ^ right)), // XNOR
          _ => left,
        };
      }
    }
    return _evalAnd(cur, base);
  }

  static int _evalAnd(String s, NumberBase base) {
    final String cur = _stripParens(s);
    int depth = 0;
    for (int i = cur.length - 1; i > 0; i--) {
      final ch = cur[i];
      if (ch == ')') depth++;
      if (ch == '(') depth--;
      if (depth == 0 && ch == '&') {
        final left = _evalAnd(cur.substring(0, i), base);
        final right = _evalAddSub(cur.substring(i + 1), base);
        return toSigned32(left & right);
      }
    }
    return _evalAddSub(cur, base);
  }

  static int _evalAddSub(String s, NumberBase base) {
    final String cur = _stripParens(s);
    int depth = 0;
    for (int i = cur.length - 1; i > 0; i--) {
      final ch = cur[i];
      if (ch == ')') depth++;
      if (ch == '(') depth--;
      if (depth == 0 && (ch == '+' || ch == '-')) {
        final left = _evalAddSub(cur.substring(0, i), base);
        final right = _evalMulDiv(cur.substring(i + 1), base);
        return toSigned32(ch == '+' ? (left + right) : (left - right));
      }
    }
    return _evalMulDiv(cur, base);
  }

  static int _evalMulDiv(String s, NumberBase base) {
    final String cur = _stripParens(s);
    int depth = 0;
    for (int i = cur.length - 1; i > 0; i--) {
      final ch = cur[i];
      if (ch == ')') depth++;
      if (ch == '(') depth--;
      if (depth == 0 && (ch == '*' || ch == '/')) {
        final left = _evalMulDiv(cur.substring(0, i), base);
        final right = _evalUnary(cur.substring(i + 1), base);
        if (ch == '/') {
          if (right == 0) throw const FormatException('Math ERROR');
          return toSigned32(left ~/ right);
        }
        return toSigned32(left * right);
      }
    }
    return _evalUnary(cur, base);
  }

  static int _evalUnary(String s, NumberBase base) {
    final String cur = _stripParens(s);
    if (cur.startsWith('Not(') && cur.endsWith(')')) {
      final inner = _evalOrXor(cur.substring(4, cur.length - 1), base);
      return toSigned32(~inner);
    }
    if (cur.startsWith('Neg(') && cur.endsWith(')')) {
      final inner = _evalOrXor(cur.substring(4, cur.length - 1), base);
      return toSigned32(-inner);
    }
    if (cur.startsWith('-')) {
      return toSigned32(-_evalUnary(cur.substring(1), base));
    }
    return parseLiteral(cur, base);
  }

  static String _stripParens(String s) {
    String cur = s.trim();
    while (cur.startsWith('(') && cur.endsWith(')')) {
      int depth = 0;
      bool outer = true;
      for (int i = 0; i < cur.length - 1; i++) {
        if (cur[i] == '(') depth++;
        if (cur[i] == ')') depth--;
        if (depth == 0) {
          outer = false;
          break;
        }
      }
      if (outer) {
        cur = cur.substring(1, cur.length - 1).trim();
      } else {
        break;
      }
    }
    return cur;
  }
}
