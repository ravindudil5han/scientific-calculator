import 'dart:math' as math;
import '../display_engine/math_nodes.dart';
import '../state/calculator_models.dart';
import 'calculator_decimal.dart';
import 'calculator_exceptions.dart';
import 'constants_conversions_engine.dart';
import 'symbolic_engine.dart';

// =============================================================================
// 1. Semantic AST Node Hierarchy
// =============================================================================

/// Base node in the Semantic Evaluation AST produced by [VisualToSemanticTranslator].
sealed class SemanticNode {
  const SemanticNode();

  /// Whether this subtree contains an explicit decimal literal (e.g. `0.1`).
  bool get containsDecimalLiteral;
}

/// Numeric literal (`0.1`, `42`, `10`) parsed without float loss.
class SemanticNumberNode extends SemanticNode {
  final String rawText;
  final bool hasDecimalPoint;

  const SemanticNumberNode(this.rawText, {required this.hasDecimalPoint});

  @override
  bool get containsDecimalLiteral => hasDecimalPoint;
}

/// Mathematical constant (`π` or Euler's `e`).
class SemanticConstantNode extends SemanticNode {
  final String symbol; // 'π' or 'e'

  const SemanticConstantNode(this.symbol);

  @override
  bool get containsDecimalLiteral => false;
}

/// Variable register reference (`A`–`F`, `x`, `y`, `z`, `Ans`, `PreAns`).
class SemanticVariableNode extends SemanticNode {
  final String name;

  const SemanticVariableNode(this.name);

  @override
  bool get containsDecimalLiteral => false;
}

/// Prefix unary operation (`+`, `-`).
class SemanticUnaryNode extends SemanticNode {
  final String operator;
  final SemanticNode operand;

  const SemanticUnaryNode(this.operator, this.operand);

  @override
  bool get containsDecimalLiteral => operand.containsDecimalLiteral;
}

/// Postfix unary operation (`!`, `%`, `°`, `FACT`).
class SemanticPostfixNode extends SemanticNode {
  final String operator;
  final SemanticNode operand;

  const SemanticPostfixNode(this.operator, this.operand);

  @override
  bool get containsDecimalLiteral => operand.containsDecimalLiteral;
}

/// Binary operation (`+`, `-`, `*`, `/`, `implicit*`, `^`, `nPr`, `nCr`, `mod`, `÷R`).
class SemanticBinaryNode extends SemanticNode {
  final String operator;
  final SemanticNode left;
  final SemanticNode right;

  const SemanticBinaryNode(this.operator, this.left, this.right);

  @override
  bool get containsDecimalLiteral =>
      left.containsDecimalLiteral || right.containsDecimalLiteral;
}

/// 2D Fraction semantic node ($\frac{\text{num}}{\text{den}}$ or $\text{int}\frac{\text{num}}{\text{den}}$).
class SemanticFractionNode extends SemanticNode {
  final SemanticNode? integerPart;
  final SemanticNode numerator;
  final SemanticNode denominator;

  const SemanticFractionNode({
    this.integerPart,
    required this.numerator,
    required this.denominator,
  });

  @override
  bool get containsDecimalLiteral =>
      (integerPart?.containsDecimalLiteral ?? false) ||
      numerator.containsDecimalLiteral ||
      denominator.containsDecimalLiteral;
}

/// 2D Radical semantic node ($\sqrt{\text{radicand}}$ or $\sqrt[\text{index}]{\text{radicand}}$).
class SemanticRadicalNode extends SemanticNode {
  final SemanticNode? index;
  final SemanticNode radicand;

  const SemanticRadicalNode({
    this.index,
    required this.radicand,
  });

  @override
  bool get containsDecimalLiteral =>
      (index?.containsDecimalLiteral ?? false) ||
      radicand.containsDecimalLiteral;
}

/// 2D Arbitrary-base Logarithm semantic node ($\log_{\text{base}}(\text{argument})$).
class SemanticLogBaseNode extends SemanticNode {
  final SemanticNode base;
  final SemanticNode argument;

  const SemanticLogBaseNode({
    required this.base,
    required this.argument,
  });

  @override
  bool get containsDecimalLiteral =>
      base.containsDecimalLiteral || argument.containsDecimalLiteral;
}

/// Standard or multi-argument function call (`sin`, `cos`, `gcd`, `lcm`, `nCr`, `fact`, etc.).
class SemanticFunctionNode extends SemanticNode {
  final String name;
  final List<SemanticNode> arguments;

  const SemanticFunctionNode(this.name, this.arguments);

  @override
  bool get containsDecimalLiteral =>
      arguments.any((a) => a.containsDecimalLiteral);
}

/// Calculus & functional analysis node (`deriv`, `integrate`, `sum`, `prod`, `solve`).
class SemanticCalculusNode extends SemanticNode {
  final String type; // 'deriv', 'integrate', 'sum', 'prod', 'solve'
  final SemanticNode body;
  final SemanticNode boundA;
  final SemanticNode? boundB;

  const SemanticCalculusNode({
    required this.type,
    required this.body,
    required this.boundA,
    this.boundB,
  });

  @override
  bool get containsDecimalLiteral => true;
}

/// Variable store assignment (`expr → A` or `A = expr`).
class SemanticAssignNode extends SemanticNode {
  final String targetVariable;
  final SemanticNode valueNode;

  const SemanticAssignNode({
    required this.targetVariable,
    required this.valueNode,
  });

  @override
  bool get containsDecimalLiteral => valueNode.containsDecimalLiteral;
}

// =============================================================================
// 2. Lexer Token Stream & Visual-to-Semantic AST Translator
// =============================================================================

enum _TokenKind {
  number,
  constant,
  variable,
  functionName,
  lParen,
  rParen,
  comma,
  operatorToken,
  postfixToken,
  preParsedSubtree,
}

class _LexToken {
  final _TokenKind kind;
  final String text;
  final SemanticNode? subtree;

  const _LexToken(this.kind, this.text, [this.subtree]);

  bool get isValueEnd =>
      kind == _TokenKind.number ||
      kind == _TokenKind.constant ||
      kind == _TokenKind.variable ||
      kind == _TokenKind.rParen ||
      kind == _TokenKind.postfixToken ||
      kind == _TokenKind.preParsedSubtree;

  bool get isValueStart =>
      kind == _TokenKind.number ||
      kind == _TokenKind.constant ||
      kind == _TokenKind.variable ||
      kind == _TokenKind.functionName ||
      kind == _TokenKind.lParen ||
      kind == _TokenKind.preParsedSubtree ||
      (kind == _TokenKind.operatorToken && text == '√');
}

/// Translates either a Phase 2 2D [MathContainerNode] Visual AST or a raw text
/// expression into a [SemanticNode] tree, enforcing Cal_'s 13-level operator
/// precedence, implicit multiplication rules, and auto-closing parentheses.
class VisualToSemanticTranslator {
  /// Translates a 2D [MathContainerNode] into a [SemanticNode] tree.
  static SemanticNode translateContainer(MathContainerNode container) {
    if (container.children.isEmpty) {
      throw const SyntaxErrorException('Empty container');
    }

    final List<_LexToken> rawTokens = [];
    final StringBuffer charBuffer = StringBuffer();

    void flushCharBuffer() {
      if (charBuffer.isNotEmpty) {
        rawTokens.addAll(_tokenizeTextSegment(charBuffer.toString()));
        charBuffer.clear();
      }
    }

    for (final child in container.children) {
      if (child is CharNode) {
        // Map CharNode to text segment while preserving display/eval semantics
        final String tokenStr = _normalizeCharNodeToken(child);
        charBuffer.write(tokenStr);
      } else if (child is FractionNode) {
        flushCharBuffer();
        if (child.numerator.isEmpty || child.denominator.isEmpty) {
          throw const SyntaxErrorException('Empty fraction placeholder');
        }
        SemanticNode? intSemantic;
        if (child.integerPart != null) {
          if (child.integerPart!.isEmpty) {
            throw const SyntaxErrorException('Empty mixed fraction integer');
          }
          intSemantic = translateContainer(child.integerPart!);
        }
        final numSemantic = translateContainer(child.numerator);
        final denSemantic = translateContainer(child.denominator);
        rawTokens.add(
          _LexToken(
            _TokenKind.preParsedSubtree,
            'frac',
            SemanticFractionNode(
              integerPart: intSemantic,
              numerator: numSemantic,
              denominator: denSemantic,
            ),
          ),
        );
      } else if (child is RadicalNode) {
        flushCharBuffer();
        if (child.radicand.isEmpty) {
          throw const SyntaxErrorException('Empty radicand placeholder');
        }
        SemanticNode? idxSemantic;
        if (child.index != null) {
          if (child.index!.isEmpty) {
            throw const SyntaxErrorException('Empty root index placeholder');
          }
          idxSemantic = translateContainer(child.index!);
        }
        final radSemantic = translateContainer(child.radicand);
        rawTokens.add(
          _LexToken(
            _TokenKind.preParsedSubtree,
            'rad',
            SemanticRadicalNode(
              index: idxSemantic,
              radicand: radSemantic,
            ),
          ),
        );
      } else if (child is SuperscriptNode) {
        flushCharBuffer();
        if (child.exponent.isEmpty) {
          throw const SyntaxErrorException('Empty exponent placeholder');
        }
        final expSemantic = translateContainer(child.exponent);
        if (child.base != null) {
          if (child.base!.isEmpty) {
            throw const SyntaxErrorException('Empty power base placeholder');
          }
          final baseSemantic = translateContainer(child.base!);
          rawTokens.add(
            _LexToken(
              _TokenKind.preParsedSubtree,
              'pow',
              SemanticBinaryNode('^', baseSemantic, expSemantic),
            ),
          );
        } else {
          // Attached superscript: acts as `^ (expSemantic)` on the preceding value
          rawTokens.add(const _LexToken(_TokenKind.operatorToken, '^'));
          rawTokens.add(_LexToken(_TokenKind.preParsedSubtree, 'exp', expSemantic));
        }
      } else if (child is ParenthesisNode) {
        flushCharBuffer();
        if (child.content.isEmpty) {
          throw const SyntaxErrorException('Empty parenthesis/abs placeholder');
        }
        final innerSemantic = translateContainer(child.content);
        if (child.isAbsoluteValue) {
          rawTokens.add(
            _LexToken(
              _TokenKind.preParsedSubtree,
              'abs',
              SemanticFunctionNode('abs', [innerSemantic]),
            ),
          );
        } else {
          rawTokens.add(
            _LexToken(_TokenKind.preParsedSubtree, 'paren', innerSemantic),
          );
        }
      } else if (child is LogBaseNode) {
        flushCharBuffer();
        if (child.base.isEmpty || child.argument.isEmpty) {
          throw const SyntaxErrorException('Empty log_a(b) placeholder');
        }
        rawTokens.add(
          _LexToken(
            _TokenKind.preParsedSubtree,
            'logbase',
            SemanticLogBaseNode(
              base: translateContainer(child.base),
              argument: translateContainer(child.argument),
            ),
          ),
        );
      } else if (child is IntegralNode) {
        flushCharBuffer();
        if (child.body.isEmpty || child.lower.isEmpty || child.upper.isEmpty) {
          throw const SyntaxErrorException('Empty integral placeholder');
        }
        rawTokens.add(
          _LexToken(
            _TokenKind.preParsedSubtree,
            'integral',
            SemanticCalculusNode(
              type: 'integrate',
              body: translateContainer(child.body),
              boundA: translateContainer(child.lower),
              boundB: translateContainer(child.upper),
            ),
          ),
        );
      } else if (child is SummationNode) {
        flushCharBuffer();
        if (child.body.isEmpty || child.start.isEmpty || child.end.isEmpty) {
          throw const SyntaxErrorException('Empty summation placeholder');
        }
        rawTokens.add(
          _LexToken(
            _TokenKind.preParsedSubtree,
            child.isProduct ? 'prod' : 'sum',
            SemanticCalculusNode(
              type: child.isProduct ? 'prod' : 'sum',
              body: translateContainer(child.body),
              boundA: translateContainer(child.start),
              boundB: translateContainer(child.end),
            ),
          ),
        );
      } else if (child is DerivativeNode) {
        flushCharBuffer();
        if (child.body.isEmpty || child.atValue.isEmpty) {
          throw const SyntaxErrorException('Empty derivative placeholder');
        }
        rawTokens.add(
          _LexToken(
            _TokenKind.preParsedSubtree,
            'deriv',
            SemanticCalculusNode(
              type: 'deriv',
              body: translateContainer(child.body),
              boundA: translateContainer(child.atValue),
            ),
          ),
        );
      } else if (child is MathContainerNode) {
        flushCharBuffer();
        rawTokens.add(
          _LexToken(
            _TokenKind.preParsedSubtree,
            'group',
            translateContainer(child),
          ),
        );
      }
    }

    flushCharBuffer();
    return _parseTokenStream(rawTokens);
  }

  /// Translates a raw text string expression into a [SemanticNode] tree.
  static SemanticNode translateText(String expression) {
    final String trimmed = expression.trim();
    if (trimmed.isEmpty) {
      throw const SyntaxErrorException('Empty expression');
    }
    final tokens = _tokenizeTextSegment(trimmed);
    return _parseTokenStream(tokens);
  }

  static String _normalizeCharNodeToken(CharNode node) {
    final String d = node.display;
    final String e = node.evalText;
    if (d == 'sin⁻¹(' || e == 'asin(') return 'asin(';
    if (d == 'cos⁻¹(' || e == 'acos(') return 'acos(';
    if (d == 'tan⁻¹(' || e == 'atan(') return 'atan(';
    if (d == 'sinh⁻¹(' || e == 'asinh(') return 'asinh(';
    if (d == 'cosh⁻¹(' || e == 'acosh(') return 'acosh(';
    if (d == 'tanh⁻¹(' || e == 'atanh(') return 'atanh(';
    return e.isNotEmpty ? e : d;
  }

  static final List<String> _sortedUnitOperators = _buildSortedUnitOperators();
  static final List<(String, String)> _sortedCodataTokens =
      _buildSortedCodataTokens();

  static List<String> _buildSortedUnitOperators() {
    final List<String> ops = [];
    for (final pair in UnitConverterEngine.allPairs) {
      ops.add(pair.forwardToken);
      ops.add(pair.reverseToken);
    }
    ops.addAll([
      'ton(short)►kg',
      'kg►ton(short)',
      'ton(long)►kg',
      'kg►ton(long)',
    ]);
    ops.sort((a, b) => b.length.compareTo(a.length));
    return ops;
  }

  static List<(String, String)> _buildSortedCodataTokens() {
    final List<(String, String)> entries = [];
    for (final c in CodataLibrary.allConstants) {
      final Set<String> keys = {c.symbol, c.id, ...c.aliases};
      for (final k in keys) {
        if (k.isEmpty) continue;
        entries.add((k, c.id));
      }
    }
    entries.sort((a, b) => b.$1.length.compareTo(a.$1.length));
    return entries;
  }

  static List<_LexToken> _tokenizeTextSegment(String text) {
    final List<_LexToken> out = [];
    int i = 0;
    final int len = text.length;

    while (i < len) {
      final String ch = text[i];
      if (ch == ' ' || ch == '\t' || ch == '\n') {
        i++;
        continue;
      }

      // 1. Unit Conversion Postfix Operators (`►in►cm` or `in►cm` / `°C►°F`)
      if (ch == '►') {
        final String afterArrow = text.substring(i + 1);
        String? matchedOp;
        for (final op in _sortedUnitOperators) {
          if (afterArrow.startsWith(op)) {
            matchedOp = op;
            break;
          }
        }
        if (matchedOp != null) {
          out.add(_LexToken(_TokenKind.postfixToken, '►$matchedOp'));
          i += 1 + matchedOp.length;
          continue;
        }
      } else if (out.isNotEmpty && out.last.isValueEnd) {
        final String rem = text.substring(i);
        String? matchedOp;
        for (final op in _sortedUnitOperators) {
          if (rem.startsWith(op)) {
            matchedOp = op;
            break;
          }
        }
        if (matchedOp != null) {
          out.add(_LexToken(_TokenKind.postfixToken, '►$matchedOp'));
          i += matchedOp.length;
          continue;
        }
      }

      // Multi-character operators & keywords
      if (text.startsWith('×10^', i) || text.startsWith('*10^', i)) {
        out.add(const _LexToken(_TokenKind.operatorToken, '*'));
        out.add(const _LexToken(_TokenKind.number, '10'));
        out.add(const _LexToken(_TokenKind.operatorToken, '^'));
        i += 4;
        continue;
      }
      if (text.startsWith('÷R', i)) {
        out.add(const _LexToken(_TokenKind.operatorToken, '÷R'));
        i += 2;
        continue;
      }
      if (text.startsWith('⁻¹', i)) {
        out.add(const _LexToken(_TokenKind.operatorToken, '^'));
        out.add(const _LexToken(_TokenKind.lParen, '('));
        out.add(const _LexToken(_TokenKind.operatorToken, '-'));
        out.add(const _LexToken(_TokenKind.number, '1'));
        out.add(const _LexToken(_TokenKind.rParen, ')'));
        i += 2;
        continue;
      }
      if (ch == '²') {
        out.add(const _LexToken(_TokenKind.operatorToken, '^'));
        out.add(const _LexToken(_TokenKind.number, '2'));
        i++;
        continue;
      }
      if (ch == '³') {
        out.add(const _LexToken(_TokenKind.operatorToken, '^'));
        out.add(const _LexToken(_TokenKind.number, '3'));
        i++;
        continue;
      }
      if (text.startsWith('nPr', i) &&
          (i + 3 == len || text[i + 3] != '(')) {
        out.add(const _LexToken(_TokenKind.operatorToken, 'nPr'));
        i += 3;
        continue;
      }
      if (text.startsWith('nCr', i) &&
          (i + 3 == len || text[i + 3] != '(')) {
        out.add(const _LexToken(_TokenKind.operatorToken, 'nCr'));
        i += 3;
        continue;
      }
      if (text.startsWith('mod', i) &&
          (i + 3 == len || !RegExp(r'[a-zA-Z]').hasMatch(text[i + 3]))) {
        out.add(const _LexToken(_TokenKind.operatorToken, 'mod'));
        i += 3;
        continue;
      }
      if (text.startsWith('FACT', i) &&
          (i + 4 == len || text[i + 4] != '(')) {
        out.add(const _LexToken(_TokenKind.postfixToken, 'FACT'));
        i += 4;
        continue;
      }
      if (text.startsWith('PreAns', i)) {
        out.add(const _LexToken(_TokenKind.variable, 'PreAns'));
        i += 6;
        continue;
      }
      if (text.startsWith('Ans', i)) {
        out.add(const _LexToken(_TokenKind.variable, 'Ans'));
        i += 3;
        continue;
      }
      if (text.startsWith('RanInt#', i)) {
        out.add(const _LexToken(_TokenKind.functionName, 'RanInt'));
        i += 7;
        continue;
      }
      if (text.startsWith('Ran#', i)) {
        out.add(const _LexToken(_TokenKind.constant, 'Ran#'));
        i += 4;
        continue;
      }
      if (text.startsWith('►t', i)) {
        out.add(const _LexToken(_TokenKind.postfixToken, '►t'));
        i += 2;
        continue;
      }

      // Statistical multi-character variable tokens (`Σx²y`, `Σx²`, `x̄`, `σx`, `min(x)`, `Q₁`, `Med`, `x̂`, `ŷ`, etc.)
      const List<String> statVarTokens = [
        'min(x)',
        'max(x)',
        'min(y)',
        'max(y)',
        'Σx²y',
        '∑x²y',
        'Σx²',
        '∑x²',
        'Σx³',
        '∑x³',
        'Σx⁴',
        '∑x⁴',
        'Σy²',
        '∑y²',
        'Σxy',
        '∑xy',
        'Σx',
        '∑x',
        'Σy',
        '∑y',
        'x̂₁',
        'x̂₂',
        'x̂',
        'ŷ',
        'x̄',
        'ȳ',
        'σx',
        'sx',
        'σy',
        'sy',
        'Q₁',
        'Q1',
        'Med',
        'Q₃',
        'Q3',
      ];
      String? matchedStatVar;
      for (final sv in statVarTokens) {
        if (text.startsWith(sv, i)) {
          matchedStatVar = sv;
          break;
        }
      }
      if (matchedStatVar != null) {
        final String normStatVar = matchedStatVar
            .replaceAll('∑', 'Σ')
            .replaceAll('Q₁', 'Q1')
            .replaceAll('Q₃', 'Q3');
        out.add(_LexToken(_TokenKind.variable, normStatVar));
        i += matchedStatVar.length;
        continue;
      }

      // 2. Sexagesimal DMS compound literal (`2°35'6''` or `2°35°6°` or `12°30'`)
      final dmsMatch = RegExp(
        r'''^(\d+(?:\.\d+)?)°(\d+(?:\.\d+)?)(?:°|')(?:(\d+(?:\.\d+)?)(?:°|''|"|')?)?''',
      ).firstMatch(text.substring(i));
      if (dmsMatch != null) {
        final String dmsStr = dmsMatch.group(0)!;
        final BigRational? rat =
            SexagesimalDmsEngine.tryParseDmsToRational(dmsStr);
        if (rat != null) {
          out.add(
            _LexToken(
              _TokenKind.preParsedSubtree,
              dmsStr,
              SemanticFractionNode(
                numerator: SemanticNumberNode(
                  rat.numerator.toString(),
                  hasDecimalPoint: true,
                ),
                denominator: SemanticNumberNode(
                  rat.denominator.toString(),
                  hasDecimalPoint: true,
                ),
              ),
            ),
          );
          i += dmsStr.length;
          continue;
        }
      }

      // 3. Numeric literals (including `.5`, `12.34`, and scientific `6.626e-34`)
      final numMatch = RegExp(
        r'^(\d+(\.\d*)?|\.\d+)([eE][+-]\d+|E\d+)?',
      ).firstMatch(text.substring(i));
      if (numMatch != null) {
        final String numStr = numMatch.group(0)!;
        if (numStr == '.') {
          throw const SyntaxErrorException('Standalone decimal point');
        }
        out.add(_LexToken(_TokenKind.number, numStr));
        i += numStr.length;
        continue;
      }

      // Radical prefix symbol √
      if (ch == '√') {
        if (i + 1 < len && text[i + 1] == '(') {
          out.add(const _LexToken(_TokenKind.functionName, 'sqrt'));
          out.add(const _LexToken(_TokenKind.lParen, '('));
          i += 2;
        } else {
          out.add(const _LexToken(_TokenKind.operatorToken, '√'));
          i++;
        }
        continue;
      }

      // Constants (`π`)
      if (ch == 'π') {
        out.add(const _LexToken(_TokenKind.constant, 'π'));
        i++;
        continue;
      }

      // Parentheses and comma
      if (ch == '(') {
        out.add(const _LexToken(_TokenKind.lParen, '('));
        i++;
        continue;
      }
      if (ch == ')') {
        out.add(const _LexToken(_TokenKind.rParen, ')'));
        i++;
        continue;
      }
      if (ch == ',') {
        out.add(const _LexToken(_TokenKind.comma, ','));
        i++;
        continue;
      }

      // Postfix unary operators (including angle markers r and g after a value)
      if (ch == '!' || ch == '%' || ch == '°') {
        out.add(_LexToken(_TokenKind.postfixToken, ch));
        i++;
        continue;
      }
      if ((ch == 'r' || ch == 'g') &&
          out.isNotEmpty &&
          out.last.isValueEnd &&
          (i + 1 == len || text[i + 1] != '(')) {
        out.add(_LexToken(_TokenKind.postfixToken, ch));
        i++;
        continue;
      }

      // Standard binary/unary operators
      if (ch == '+' ||
          ch == '-' ||
          ch == '−' ||
          ch == '×' ||
          ch == '*' ||
          ch == '÷' ||
          ch == '/' ||
          ch == '^' ||
          ch == '=' ||
          ch == '→') {
        final String normOp = switch (ch) {
          '−' => '-',
          '×' => '*',
          '÷' => '/',
          _ => ch,
        };
        out.add(_LexToken(_TokenKind.operatorToken, normOp));
        i++;
        continue;
      }

      // Function names (followed by `(` or known prefix functions like `sin 30`)
      final fnMatch = RegExp(
        r'^(sin⁻¹|cos⁻¹|tan⁻¹|sinh⁻¹|cosh⁻¹|tanh⁻¹|asinh|acosh|atanh|sinh|cosh|tanh|asin|acos|atan|sin|cos|tan|log|ln|exp|abs|Abs|gcd|GCD|lcm|LCM|nPr|nCr|fact|FACT|integrate|deriv|sum|prod|Solve|solve|Rnd|Intg|Int|Pol|Rec|RanInt)\b',
      ).firstMatch(text.substring(i));
      if (fnMatch != null) {
        final String rawFn = fnMatch.group(0)!;
        final String canonicalFn = _canonicalFunctionName(rawFn);
        out.add(_LexToken(_TokenKind.functionName, canonicalFn));
        i += rawFn.length;
        continue;
      }

      // User-defined functions f(x), g(x) and Normal Dist P(t), Q(t), R(t)
      if ((ch == 'f' || ch == 'g' || ch == 'P' || ch == 'Q' || ch == 'R') &&
          i + 1 < len &&
          text[i + 1] == '(') {
        out.add(_LexToken(_TokenKind.functionName, ch));
        i++;
        continue;
      }

      // Single-letter infix P / C for nPr / nCr (e.g., 5P2, 5C2)
      if ((ch == 'P' || ch == 'C') &&
          out.isNotEmpty &&
          out.last.isValueEnd &&
          i + 1 < len &&
          RegExp(r'[0-9(A-Fx-z]').hasMatch(text[i + 1])) {
        out.add(_LexToken(_TokenKind.operatorToken, ch == 'P' ? 'nPr' : 'nCr'));
        i++;
        continue;
      }

      // 4. All 47 CODATA Scientific Constants
      final String remAtI = text.substring(i);
      (String, String)? matchedCodata;
      for (final entry in _sortedCodataTokens) {
        final String tokenKey = entry.$1;
        if (remAtI.startsWith(tokenKey)) {
          final int nextIdx = i + tokenKey.length;
          final bool endsAsciiLetter =
              RegExp(r'[a-zA-Z0-9_]$').hasMatch(tokenKey);
          final bool nextIsAsciiWord =
              nextIdx < len && RegExp(r'^[a-zA-Z0-9_(]').hasMatch(text[nextIdx]);
          if (endsAsciiLetter && nextIsAsciiWord) {
            continue;
          }
          matchedCodata = entry;
          break;
        }
      }
      if (matchedCodata != null) {
        out.add(_LexToken(_TokenKind.constant, matchedCodata.$2));
        i += matchedCodata.$1.length;
        continue;
      }

      // Euler's constant `e` vs variable registers (`A`..`F`, `x`, `y`, `z`, `a`, `b`, `c`, `n`, `r`)
      if (ch == 'e') {
        out.add(const _LexToken(_TokenKind.constant, 'e'));
        i++;
        continue;
      }
      if (RegExp(r'^[A-Fa-cnrx-z]$').hasMatch(ch)) {
        out.add(_LexToken(_TokenKind.variable, ch));
        i++;
        continue;
      }

      throw SyntaxErrorException('Unrecognized token at "$ch"');
    }

    return out;
  }

  static String _canonicalFunctionName(String raw) {
    return switch (raw) {
      'sin⁻¹' => 'asin',
      'cos⁻¹' => 'acos',
      'tan⁻¹' => 'atan',
      'sinh⁻¹' => 'asinh',
      'cosh⁻¹' => 'acosh',
      'tanh⁻¹' => 'atanh',
      'Abs' => 'abs',
      'GCD' => 'gcd',
      'LCM' => 'lcm',
      'FACT' => 'fact',
      'Solve' => 'solve',
      _ => raw,
    };
  }

  /// Inserts implicit multiplication tokens (`implicit*` at Precedence Level 4)
  /// and automatically closes any dangling opening parentheses at the end.
  static List<_LexToken> _preprocessTokens(List<_LexToken> tokens) {
    if (tokens.isEmpty) {
      throw const SyntaxErrorException('Empty token stream');
    }

    // 1. Insert implicit multiplication between adjacent value-ending and value-starting tokens
    final List<_LexToken> withImplicit = [];
    for (int i = 0; i < tokens.length; i++) {
      final _LexToken curr = tokens[i];
      if (withImplicit.isNotEmpty) {
        final _LexToken prev = withImplicit.last;
        // Do not insert implicit* between a functionName and its opening `(`
        final bool isFnCallOpen =
            prev.kind == _TokenKind.functionName && curr.kind == _TokenKind.lParen;
        if (!isFnCallOpen && prev.isValueEnd && curr.isValueStart) {
          withImplicit.add(
            const _LexToken(_TokenKind.operatorToken, 'implicit*'),
          );
        }
      }
      withImplicit.add(curr);
    }

    // 2. Validate parenthesis balance and auto-close dangling `(` at the end
    int openBalance = 0;
    for (final tok in withImplicit) {
      if (tok.kind == _TokenKind.lParen) {
        openBalance++;
      } else if (tok.kind == _TokenKind.rParen) {
        openBalance--;
        if (openBalance < 0) {
          throw const SyntaxErrorException('Unmatched closing parenthesis');
        }
      }
    }
    while (openBalance > 0) {
      withImplicit.add(const _LexToken(_TokenKind.rParen, ')'));
      openBalance--;
    }

    return withImplicit;
  }

  static SemanticNode _parseTokenStream(List<_LexToken> rawTokens) {
    final tokens = _preprocessTokens(rawTokens);
    final parser = _RecursivePrecedenceParser(tokens);
    final root = parser.parseExpression();
    if (!parser.isAtEnd) {
      throw SyntaxErrorException(
        'Unexpected trailing token: ${parser.peek().text}',
      );
    }
    return root;
  }
}

/// Recursive-descent parser implementing Cal_ 1100_DB_ operator precedence:
/// - Level 13: Assignment (`=`, `→`)
/// - Level 9: Addition (`+`), Subtraction (`-`)
/// - Level 8: Explicit Multiplication (`*`), Division (`/`), `÷R`, `mod`
/// - Level 6: Permutation (`nPr`), Combination (`nCr`)
/// - Level 5: Prefix Unary (`+`, `-`, `√`)
/// - Level 4: Juxtaposed Implicit Multiplication (`implicit*`, e.g. `2π`, `6÷2(1+2) = 1`)
/// - Level 3: Power (`^`)
/// - Level 2: Postfix Unary (`!`, `%`, `°`, `FACT`)
/// - Level 1: Primary (`()`, literals, variables, constants, functions, 2D templates)
class _RecursivePrecedenceParser {
  final List<_LexToken> _tokens;
  int _pos = 0;

  _RecursivePrecedenceParser(this._tokens);

  bool get isAtEnd => _pos >= _tokens.length;
  _LexToken peek() => _tokens[_pos];
  _LexToken advance() => _tokens[_pos++];

  SemanticNode parseExpression() => _parseAssignment();

  SemanticNode _parseAssignment() {
    final left = _parseAddSub();
    if (!isAtEnd && peek().kind == _TokenKind.operatorToken) {
      final op = peek().text;
      if (op == '→') {
        advance();
        if (isAtEnd || peek().kind != _TokenKind.variable) {
          throw const SyntaxErrorException('Expected variable after →');
        }
        final varToken = advance();
        return SemanticAssignNode(
          targetVariable: varToken.text,
          valueNode: left,
        );
      }
      if (op == '=' && left is SemanticVariableNode) {
        advance();
        final rhs = _parseAddSub();
        return SemanticAssignNode(
          targetVariable: left.name,
          valueNode: rhs,
        );
      }
    }
    return left;
  }

  SemanticNode _parseAddSub() {
    SemanticNode left = _parseExplicitMulDiv();
    while (!isAtEnd && peek().kind == _TokenKind.operatorToken) {
      final op = peek().text;
      if (op == '+' || op == '-') {
        advance();
        final right = _parseExplicitMulDiv();
        left = SemanticBinaryNode(op, left, right);
      } else {
        break;
      }
    }
    return left;
  }

  SemanticNode _parseExplicitMulDiv() {
    SemanticNode left = _parseCombinatorics();
    while (!isAtEnd && peek().kind == _TokenKind.operatorToken) {
      final op = peek().text;
      if (op == '*' || op == '/' || op == '÷R' || op == 'mod') {
        advance();
        final right = _parseCombinatorics();
        left = SemanticBinaryNode(op, left, right);
      } else {
        break;
      }
    }
    return left;
  }

  SemanticNode _parseCombinatorics() {
    SemanticNode left = _parseUnitConversion();
    while (!isAtEnd && peek().kind == _TokenKind.operatorToken) {
      final op = peek().text;
      if (op == 'nPr' || op == 'nCr') {
        advance();
        final right = _parseUnitConversion();
        left = SemanticBinaryNode(op, left, right);
      } else {
        break;
      }
    }
    return left;
  }

  /// Unit conversion operators (`►in►cm`, `►°C►°F`, etc.) apply after prefix
  /// unary signs so `-40°C►°F` evaluates `(-40)` converted from `°C` to `°F` (`-40`).
  SemanticNode _parseUnitConversion() {
    SemanticNode node = _parsePrefixUnary();
    while (!isAtEnd &&
        peek().kind == _TokenKind.postfixToken &&
        peek().text.startsWith('►')) {
      final op = advance().text;
      node = SemanticPostfixNode(op, node);
    }
    return node;
  }

  SemanticNode _parsePrefixUnary() {
    if (!isAtEnd && peek().kind == _TokenKind.operatorToken) {
      final op = peek().text;
      if (op == '+' || op == '-') {
        advance();
        return SemanticUnaryNode(op, _parsePrefixUnary());
      }
    }
    return _parseJuxtaposedImplicitMul();
  }

  /// Level 4: Juxtaposed implicit multiplication binds tighter than explicit `×`/`÷`
  /// (`1÷2π = 1/(2π)` and `6÷2(1+2) = 1`), but looser than powers (`2(3)^2 = 18`).
  SemanticNode _parseJuxtaposedImplicitMul() {
    SemanticNode left = _parsePower();
    while (!isAtEnd &&
        peek().kind == _TokenKind.operatorToken &&
        peek().text == 'implicit*') {
      advance();
      final right = _parsePrefixUnary();
      left = SemanticBinaryNode('implicit*', left, right);
    }
    return left;
  }

  SemanticNode _parsePower() {
    final SemanticNode base = _parsePostfix();
    if (!isAtEnd &&
        peek().kind == _TokenKind.operatorToken &&
        peek().text == '^') {
      advance();
      // Right-associative power (allows unary sign in exponent e.g. 2^-3)
      final SemanticNode exponent = _parsePrefixUnary();
      return SemanticBinaryNode('^', base, exponent);
    }
    return base;
  }

  SemanticNode _parsePostfix() {
    if (!isAtEnd &&
        peek().kind == _TokenKind.operatorToken &&
        peek().text == '√') {
      advance();
      final SemanticNode radicand = (!isAtEnd &&
              peek().kind == _TokenKind.operatorToken &&
              (peek().text == '+' || peek().text == '-'))
          ? _parsePrefixUnary()
          : _parsePostfix();
      return SemanticRadicalNode(radicand: radicand);
    }
    SemanticNode node = _parsePrimary();
    while (!isAtEnd &&
        peek().kind == _TokenKind.postfixToken &&
        !peek().text.startsWith('►')) {
      final op = advance().text;
      node = SemanticPostfixNode(op, node);
    }
    return node;
  }

  SemanticNode _parsePrimary() {
    if (isAtEnd) {
      throw const SyntaxErrorException('Unexpected end of expression');
    }

    final _LexToken tok = advance();
    switch (tok.kind) {
      case _TokenKind.number:
        return SemanticNumberNode(
          tok.text,
          hasDecimalPoint: tok.text.contains('.'),
        );

      case _TokenKind.constant:
        return SemanticConstantNode(tok.text);

      case _TokenKind.variable:
        return SemanticVariableNode(tok.text);

      case _TokenKind.preParsedSubtree:
        return tok.subtree!;

      case _TokenKind.lParen:
        if (!isAtEnd && peek().kind == _TokenKind.rParen) {
          throw const SyntaxErrorException('Empty parentheses ()');
        }
        final inner = _parseAssignment();
        if (isAtEnd || peek().kind != _TokenKind.rParen) {
          throw const SyntaxErrorException('Expected closing parenthesis');
        }
        advance();
        return inner;

      case _TokenKind.functionName:
        final String fnName = tok.text;
        // Support both `sin(30)` and unparenthesized prefix `sin 30`
        if (!isAtEnd && peek().kind == _TokenKind.lParen) {
          advance(); // consume '('
          if (!isAtEnd && peek().kind == _TokenKind.rParen) {
            throw SyntaxErrorException('Empty argument list for $fnName()');
          }
          final List<SemanticNode> args = [_parseAssignment()];
          while (!isAtEnd && peek().kind == _TokenKind.comma) {
            advance(); // consume ','
            args.add(_parseAssignment());
          }
          if (isAtEnd || peek().kind != _TokenKind.rParen) {
            throw SyntaxErrorException('Missing ) after $fnName');
          }
          advance(); // consume ')'

          // Map special calculus functions if invoked via text
          if (fnName == 'integrate' && args.length == 3) {
            return SemanticCalculusNode(
              type: 'integrate',
              body: args[0],
              boundA: args[1],
              boundB: args[2],
            );
          }
          if (fnName == 'deriv' && args.length == 2) {
            return SemanticCalculusNode(
              type: 'deriv',
              body: args[0],
              boundA: args[1],
            );
          }
          if ((fnName == 'sum' || fnName == 'prod') && args.length == 3) {
            return SemanticCalculusNode(
              type: fnName,
              body: args[0],
              boundA: args[1],
              boundB: args[2],
            );
          }
          if (fnName == 'solve' && (args.length == 1 || args.length == 2)) {
            return SemanticCalculusNode(
              type: 'solve',
              body: args[0],
              boundA: args.length == 2
                  ? args[1]
                  : const SemanticNumberNode('0', hasDecimalPoint: false),
            );
          }
          return SemanticFunctionNode(fnName, args);
        } else {
          // Prefix function call without parens, e.g. `sin 30`
          final arg = _parsePrefixUnary();
          return SemanticFunctionNode(fnName, [arg]);
        }

      case _TokenKind.rParen:
      case _TokenKind.comma:
      case _TokenKind.operatorToken:
      case _TokenKind.postfixToken:
        throw SyntaxErrorException('Unexpected token "${tok.text}"');
    }
  }
}

// =============================================================================
// 3. High-Precision & Symbolic Dual-Pipeline Evaluator
// =============================================================================

/// Complete evaluation output for the Cal_ 1100_DB_ LCD & state store.
class Cal_EvaluationResult {
  /// Primary string shown on the bottom-right LCD result line.
  final String primaryText;

  /// High-precision decimal string (stored in `Ans` and shown in Decimal mode).
  final String decimalText;

  /// Exact symbolic string (improper fraction, surd, or $\pi$-multiple) if available.
  final String? exactText;

  /// Mixed fraction string (`int num/den`) if the result is a rational with $|p| > q > 1$.
  final String? mixedFractionText;

  /// Recurring decimal string (`0.(3)`) if the result is a repeating rational.
  final String? recurringDecimalText;

  /// Prime factorization string (`2^3×3`) if the result is a positive integer $\ge 2$.
  final String? primeFactorText;

  /// Alternate display text for quick `FORMAT` / `S⇔D` toggling.
  final String? alternateText;

  /// High-precision [Cal_Decimal] numeric value for formatting conversions (`ENG`, `DMS`).
  final Cal_Decimal? decimalValue;

  /// Optional variable name if this evaluation stored into a register (`A`–`F`, `x`, `y`, `z`).
  final String? assignedVariable;

  /// Hardware error title (`Syntax ERROR`, `Math ERROR`, `Argument ERROR`) if failed.
  final String? error;

  const Cal_EvaluationResult({
    required this.primaryText,
    required this.decimalText,
    this.exactText,
    this.mixedFractionText,
    this.recurringDecimalText,
    this.primeFactorText,
    this.alternateText,
    this.decimalValue,
    this.assignedVariable,
    this.error,
  });

  bool get isError => error != null;
}

class _InternalValue {
  final Cal_Decimal decimal;
  final SymbolicValue? symbolic;
  final String? specialDisplayOverride;

  const _InternalValue({
    required this.decimal,
    this.symbolic,
    this.specialDisplayOverride,
  });
}

/// Master Phase 3 Mathematical Evaluator for the Cal_ 1100_DB_.
class MathExpressionEvaluator {
  final AngleUnit angleUnit;
  final NumberFormatMode numberFormat;
  final int formatDigits;
  final Map<String, String> variables;
  final String definedFunctionF;
  final String definedFunctionG;

  const MathExpressionEvaluator({
    this.angleUnit = AngleUnit.degree,
    this.numberFormat = NumberFormatMode.norm1,
    this.formatDigits = 2,
    this.variables = const {},
    this.definedFunctionF = '',
    this.definedFunctionG = '',
  });

  /// Evaluates a Phase 2 2D [MathContainerNode] AST.
  Cal_EvaluationResult evaluateVisualAst(
    MathContainerNode rootNode, {
    bool forceDecimal = false,
  }) {
    try {
      final semanticRoot = VisualToSemanticTranslator.translateContainer(rootNode);
      return _evaluateSemanticRoot(semanticRoot, forceDecimal: forceDecimal);
    } on Cal_EvaluationException catch (e) {
      return Cal_EvaluationResult(
        primaryText: '',
        decimalText: '',
        error: e.errorTitle,
      );
    } catch (_) {
      return const Cal_EvaluationResult(
        primaryText: '',
        decimalText: '',
        error: 'Syntax ERROR',
      );
    }
  }

  /// Evaluates a raw string expression (for unit tests and LineI mode).
  Cal_EvaluationResult evaluateString(
    String expression, {
    bool forceDecimal = false,
  }) {
    try {
      final semanticRoot = VisualToSemanticTranslator.translateText(expression);
      return _evaluateSemanticRoot(semanticRoot, forceDecimal: forceDecimal);
    } on Cal_EvaluationException catch (e) {
      return Cal_EvaluationResult(
        primaryText: '',
        decimalText: '',
        error: e.errorTitle,
      );
    } catch (_) {
      return const Cal_EvaluationResult(
        primaryText: '',
        decimalText: '',
        error: 'Syntax ERROR',
      );
    }
  }

  Cal_EvaluationResult _evaluateSemanticRoot(
    SemanticNode root, {
    required bool forceDecimal,
  }) {
    String? assignedVar;
    SemanticNode targetNode = root;
    if (root is SemanticAssignNode) {
      assignedVar = root.targetVariable;
      targetNode = root.valueNode;
    }

    final _InternalValue val = _evalNode(targetNode, variables);
    final String decStr = val.decimal.formatCal_Display(
      numberFormat: numberFormat,
      fixSciDigits: formatDigits,
    );

    if (val.specialDisplayOverride != null) {
      return Cal_EvaluationResult(
        primaryText: val.specialDisplayOverride!,
        decimalText: decStr,
        exactText: val.specialDisplayOverride,
        alternateText: decStr,
        decimalValue: val.decimal,
        assignedVariable: assignedVar,
      );
    }

    final SymbolicValue? sym = val.symbolic;
    final String? exactStr = sym?.toExactDisplayString();
    final BigRational? rat = sym?.toBigRational();
    final String? mixedStr =
        (rat != null && !rat.isInteger && rat.numerator.abs() > rat.denominator)
            ? rat.toMixedFractionString()
            : null;
    final String? recurringStr =
        (rat != null && !rat.isInteger) ? rat.toRecurringDecimalString() : null;

    String? primeFact;
    if (val.decimal.isInteger &&
        val.decimal.isPositive &&
        val.decimal.exponent10 <= 10) {
      final BigInt n = val.decimal.toExactBigInt();
      if (n >= BigInt.two) {
        primeFact = primeFactorize(n);
      }
    }

    // If the user typed explicit decimal literals (like `0.1 + 0.2`) and the
    // result is a clean terminating decimal (`0.3`), display `'0.3'` as primary
    // while keeping `'3/10'` in exactText/alternateText for FORMAT toggling!
    final bool isNumericalCalculus = targetNode is SemanticCalculusNode &&
        (targetNode.type == 'integrate' || targetNode.type == 'deriv');
    final bool preferDecimalForDecimalInput = isNumericalCalculus ||
        (targetNode.containsDecimalLiteral &&
            rat != null &&
            rat.toTerminatingDecimalString() != null);

    final bool showExact = !forceDecimal &&
        !preferDecimalForDecimalInput &&
        exactStr != null &&
        exactStr != decStr;

    final String primary = showExact ? exactStr : decStr;
    final String? alternate = showExact
        ? decStr
        : (exactStr != null && exactStr != decStr ? exactStr : mixedStr);

    return Cal_EvaluationResult(
      primaryText: primary,
      decimalText: decStr,
      exactText: exactStr,
      mixedFractionText: mixedStr,
      recurringDecimalText: recurringStr,
      primeFactorText: primeFact,
      alternateText: alternate,
      decimalValue: val.decimal,
      assignedVariable: assignedVar,
    );
  }

  _InternalValue _evalNode(
    SemanticNode node,
    Map<String, String> env,
  ) {
    switch (node) {
      case SemanticNumberNode():
        final Cal_Decimal dec = Cal_Decimal.parse(node.rawText).checkRange();
        final BigRational? rat =
            dec.isZero ? BigRational.zero : BigRational.tryParse(node.rawText);
        return _InternalValue(
          decimal: dec,
          symbolic: rat != null ? SymbolicValue.fromRational(rat) : null,
        );

      case SemanticConstantNode():
        if (node.symbol == 'π') {
          return _InternalValue(
            decimal: Cal_Decimal.pi,
            symbolic: SymbolicValue.pi,
          );
        }
        if (node.symbol == 'e') {
          return _InternalValue(
            decimal: Cal_Decimal.e,
            symbolic: null,
          );
        }
        if (node.symbol == 'Ran#') {
          final int k = math.Random().nextInt(1000);
          final BigRational rat = BigRational(BigInt.from(k), BigInt.from(1000));
          return _InternalValue(
            decimal: Cal_Decimal.fromInt(k) / Cal_Decimal.fromInt(1000),
            symbolic: SymbolicValue.fromRational(rat),
          );
        }
        final CodataConstant? codata = CodataLibrary.lookup(node.symbol);
        if (codata != null) {
          return _InternalValue(
            decimal: codata.decimalValue,
            symbolic: null,
          );
        }
        throw SyntaxErrorException('Unknown constant ${node.symbol}');

      case SemanticVariableNode():
        final String rawVal = env[node.name] ?? '0';
        final Cal_Decimal dec =
            Cal_Decimal.tryParse(rawVal) ?? Cal_Decimal.zero;
        final BigRational? rat = BigRational.tryParse(rawVal);
        return _InternalValue(
          decimal: dec,
          symbolic: rat != null ? SymbolicValue.fromRational(rat) : null,
        );

      case SemanticUnaryNode():
        final _InternalValue inner = _evalNode(node.operand, env);
        if (node.operator == '+') return inner;
        return _InternalValue(
          decimal: -inner.decimal,
          symbolic: inner.symbolic != null ? -inner.symbolic! : null,
        );

      case SemanticPostfixNode():
        final _InternalValue inner = _evalNode(node.operand, env);
        return _evalPostfix(node.operator, inner);

      case SemanticFractionNode():
        final _InternalValue numVal = _evalNode(node.numerator, env);
        final _InternalValue denVal = _evalNode(node.denominator, env);
        if (denVal.decimal.isZero) {
          throw const MathErrorException('Division by zero in fraction');
        }
        _InternalValue fracVal = _InternalValue(
          decimal: numVal.decimal / denVal.decimal,
          symbolic: (numVal.symbolic != null && denVal.symbolic != null)
              ? numVal.symbolic!.tryDivide(denVal.symbolic!)
              : null,
        );
        if (node.integerPart != null) {
          final _InternalValue intVal = _evalNode(node.integerPart!, env);
          final bool negSign = intVal.decimal.isNegative;
          final _InternalValue absInt = _InternalValue(
            decimal: intVal.decimal.abs(),
            symbolic: intVal.symbolic != null && negSign
                ? -intVal.symbolic!
                : intVal.symbolic,
          );
          final Cal_Decimal combinedDec = absInt.decimal + fracVal.decimal;
          final SymbolicValue? combinedSym =
              (absInt.symbolic != null && fracVal.symbolic != null)
                  ? absInt.symbolic!.tryAdd(fracVal.symbolic!)
                  : null;
          fracVal = _InternalValue(
            decimal: negSign ? -combinedDec : combinedDec,
            symbolic:
                (combinedSym != null && negSign) ? -combinedSym : combinedSym,
          );
        }
        return fracVal;

      case SemanticRadicalNode():
        final _InternalValue radVal = _evalNode(node.radicand, env);
        if (node.index == null) {
          return _InternalValue(
            decimal: radVal.decimal.sqrt(),
            symbolic: radVal.symbolic?.trySqrt(),
          );
        }
        final _InternalValue idxVal = _evalNode(node.index!, env);
        if (idxVal.decimal.isZero) {
          throw const MathErrorException('0-th root is undefined');
        }
        if (idxVal.decimal == Cal_Decimal.two) {
          return _InternalValue(
            decimal: radVal.decimal.sqrt(),
            symbolic: radVal.symbolic?.trySqrt(),
          );
        }
        // Check odd integer root of negative number
        if (radVal.decimal.isNegative) {
          if (!idxVal.decimal.isInteger) {
            throw const MathErrorException('Even/fractional root of negative');
          }
          final BigInt nBig = idxVal.decimal.toExactBigInt();
          if (nBig.isEven) {
            throw const MathErrorException('Even root of negative in Real mode');
          }
          final Cal_Decimal posRoot = radVal.decimal
              .abs()
              .pow(Cal_Decimal.one / idxVal.decimal);
          return _InternalValue(decimal: -posRoot);
        }
        final Cal_Decimal rootDec =
            radVal.decimal.pow(Cal_Decimal.one / idxVal.decimal);
        // Check if rootDec is an exact integer (e.g. ³√8 = 2)
        final BigInt roundedInt = BigInt.from(rootDec.toDouble().round());
        if (idxVal.decimal.isInteger &&
            idxVal.decimal.toExactBigInt() > BigInt.zero &&
            idxVal.decimal.toExactBigInt() <= BigInt.from(20)) {
          final int n = idxVal.decimal.toExactBigInt().toInt();
          if (radVal.decimal.isInteger &&
              roundedInt.pow(n) == radVal.decimal.toExactBigInt()) {
            return _InternalValue(
              decimal: Cal_Decimal.fromBigInt(roundedInt),
              symbolic: SymbolicValue.fromBigInt(roundedInt),
            );
          }
        }
        return _InternalValue(decimal: rootDec);

      case SemanticLogBaseNode():
        final _InternalValue baseVal = _evalNode(node.base, env);
        final _InternalValue argVal = _evalNode(node.argument, env);
        return _evalLogBase(baseVal, argVal);

      case SemanticBinaryNode():
        final _InternalValue left = _evalNode(node.left, env);
        final _InternalValue right = _evalNode(node.right, env);
        return _evalBinary(node.operator, left, right);

      case SemanticFunctionNode():
        final List<_InternalValue> evalArgs =
            node.arguments.map((a) => _evalNode(a, env)).toList();
        return _evalFunction(node.name, evalArgs);

      case SemanticCalculusNode():
        return _evalCalculus(node, env);

      case SemanticAssignNode():
        return _evalNode(node.valueNode, env);
    }
  }

  _InternalValue _evalPostfix(String op, _InternalValue inner) {
    if (op == '►t') {
      final Cal_Decimal meanX =
          Cal_Decimal.tryParse(variables['x̄'] ?? '0') ?? Cal_Decimal.zero;
      final Cal_Decimal sigmaX =
          Cal_Decimal.tryParse(variables['σx'] ?? '1') ?? Cal_Decimal.one;
      if (sigmaX.isZero) {
        throw const MathErrorException('σx = 0 in ►t variate conversion');
      }
      return _InternalValue(decimal: (inner.decimal - meanX) / sigmaX);
    }
    if (op.startsWith('►')) {
      final Cal_Decimal converted =
          UnitConverterEngine.applyOperator(inner.decimal, op);
      return _InternalValue(decimal: converted);
    }

    switch (op) {
      case '%':
        final SymbolicValue? sym = inner.symbolic?.tryDivide(
          SymbolicValue.fromInt(100),
        );
        return _InternalValue(
          decimal: inner.decimal / Cal_Decimal.hundred,
          symbolic: sym,
        );

      case '°':
        return switch (angleUnit) {
          AngleUnit.degree => inner,
          AngleUnit.radian => _InternalValue(
              decimal: (inner.decimal * Cal_Decimal.pi) /
                  Cal_Decimal.fromInt(180),
              symbolic: inner.symbolic
                  ?.tryMultiply(SymbolicValue.pi)
                  ?.tryDivide(SymbolicValue.fromInt(180)),
            ),
          AngleUnit.gradian => _InternalValue(
              decimal: (inner.decimal * Cal_Decimal.fromInt(10)) /
                  Cal_Decimal.fromInt(9),
              symbolic: inner.symbolic
                  ?.tryMultiply(SymbolicValue.fromInt(10))
                  ?.tryDivide(SymbolicValue.fromInt(9)),
            ),
        };

      case 'r':
        return switch (angleUnit) {
          AngleUnit.radian => inner,
          AngleUnit.degree => _InternalValue(
              decimal: (inner.decimal * Cal_Decimal.fromInt(180)) /
                  Cal_Decimal.pi,
              symbolic: inner.symbolic
                  ?.tryMultiply(SymbolicValue.fromInt(180))
                  ?.tryDivide(SymbolicValue.pi),
            ),
          AngleUnit.gradian => _InternalValue(
              decimal: (inner.decimal * Cal_Decimal.fromInt(200)) /
                  Cal_Decimal.pi,
              symbolic: inner.symbolic
                  ?.tryMultiply(SymbolicValue.fromInt(200))
                  ?.tryDivide(SymbolicValue.pi),
            ),
        };

      case 'g':
        return switch (angleUnit) {
          AngleUnit.gradian => inner,
          AngleUnit.degree => _InternalValue(
              decimal: (inner.decimal * Cal_Decimal.fromInt(9)) /
                  Cal_Decimal.fromInt(10),
              symbolic: inner.symbolic
                  ?.tryMultiply(SymbolicValue.fromInt(9))
                  ?.tryDivide(SymbolicValue.fromInt(10)),
            ),
          AngleUnit.radian => _InternalValue(
              decimal: (inner.decimal * Cal_Decimal.pi) /
                  Cal_Decimal.fromInt(200),
              symbolic: inner.symbolic
                  ?.tryMultiply(SymbolicValue.pi)
                  ?.tryDivide(SymbolicValue.fromInt(200)),
            ),
        };

      case '!':
        if (!inner.decimal.isInteger || inner.decimal.isNegative) {
          throw const ArgumentErrorException(
            'Factorial requires a non-negative integer',
          );
        }
        final BigInt nBig = inner.decimal.toExactBigInt();
        if (nBig > BigInt.from(69)) {
          throw const MathErrorException('Factorial overflow (> 69!)');
        }
        final int n = nBig.toInt();
        BigInt acc = BigInt.one;
        for (int i = 2; i <= n; i++) {
          acc *= BigInt.from(i);
        }
        return _InternalValue(
          decimal: Cal_Decimal.fromBigInt(acc),
          symbolic: acc.toString().length <= 15
              ? SymbolicValue.fromBigInt(acc)
              : null,
        );

      case 'FACT':
        if (!inner.decimal.isInteger || !inner.decimal.isPositive) {
          throw const ArgumentErrorException(
            'FACT requires a positive integer',
          );
        }
        final BigInt n = inner.decimal.toExactBigInt();
        return _InternalValue(
          decimal: inner.decimal,
          symbolic: inner.symbolic,
          specialDisplayOverride: primeFactorize(n),
        );

      default:
        throw SyntaxErrorException('Unknown postfix operator $op');
    }
  }

  _InternalValue _evalBinary(
    String op,
    _InternalValue left,
    _InternalValue right,
  ) {
    switch (op) {
      case '+':
        return _InternalValue(
          decimal: left.decimal + right.decimal,
          symbolic: (left.symbolic != null && right.symbolic != null)
              ? left.symbolic!.tryAdd(right.symbolic!)
              : null,
        );

      case '-':
        return _InternalValue(
          decimal: left.decimal - right.decimal,
          symbolic: (left.symbolic != null && right.symbolic != null)
              ? left.symbolic!.trySubtract(right.symbolic!)
              : null,
        );

      case '*':
      case 'implicit*':
        return _InternalValue(
          decimal: left.decimal * right.decimal,
          symbolic: (left.symbolic != null && right.symbolic != null)
              ? left.symbolic!.tryMultiply(right.symbolic!)
              : null,
        );

      case '/':
        if (right.decimal.isZero) {
          throw const MathErrorException('Division by zero');
        }
        return _InternalValue(
          decimal: left.decimal / right.decimal,
          symbolic: (left.symbolic != null && right.symbolic != null)
              ? left.symbolic!.tryDivide(right.symbolic!)
              : null,
        );

      case '÷R':
        if (right.decimal.isZero) {
          throw const MathErrorException('Division by zero in ÷R');
        }
        if (!left.decimal.isInteger || !right.decimal.isInteger) {
          throw const ArgumentErrorException('÷R requires integer operands');
        }
        final BigInt a = left.decimal.toExactBigInt();
        final BigInt b = right.decimal.toExactBigInt();
        final BigInt q = a ~/ b;
        final BigInt r = a % b;
        return _InternalValue(
          decimal: Cal_Decimal.fromBigInt(q),
          symbolic: SymbolicValue.fromBigInt(q),
          specialDisplayOverride: '$q, R=$r',
        );

      case 'mod':
        if (right.decimal.isZero) {
          throw const MathErrorException('Modulo by zero');
        }
        if (left.decimal.isInteger && right.decimal.isInteger) {
          final BigInt a = left.decimal.toExactBigInt();
          final BigInt b = right.decimal.toExactBigInt();
          final BigInt rem = a % b;
          return _InternalValue(
            decimal: Cal_Decimal.fromBigInt(rem),
            symbolic: SymbolicValue.fromBigInt(rem),
          );
        }
        final Cal_Decimal q = Cal_Decimal.fromInt(
          (left.decimal / right.decimal).toDouble().floor(),
        );
        return _InternalValue(
          decimal: left.decimal - (q * right.decimal),
        );

      case '^':
        final SymbolicValue? symPow =
            (left.symbolic != null && right.symbolic != null)
                ? left.symbolic!.tryPow(right.symbolic!)
                : null;
        final Cal_Decimal decPow = symPow != null
            ? symPow.toCal_Decimal().checkRange()
            : left.decimal.pow(right.decimal);
        return _InternalValue(
          decimal: decPow,
          symbolic: symPow,
        );

      case 'nPr':
        return _evalPermutation(left, right);

      case 'nCr':
        return _evalCombination(left, right);

      default:
        throw SyntaxErrorException('Unsupported binary operator $op');
    }
  }

  _InternalValue _evalPermutation(_InternalValue nVal, _InternalValue rVal) {
    if (!nVal.decimal.isInteger || !rVal.decimal.isInteger) {
      throw const ArgumentErrorException('nPr requires integer arguments');
    }
    final BigInt n = nVal.decimal.toExactBigInt();
    final BigInt r = rVal.decimal.toExactBigInt();
    if (n < BigInt.zero || r < BigInt.zero || r > n) {
      throw const ArgumentErrorException('Invalid nPr domain');
    }
    if (n > BigInt.from(100000)) {
      throw const MathErrorException('nPr overflow');
    }
    BigInt acc = BigInt.one;
    for (BigInt i = BigInt.zero; i < r; i += BigInt.one) {
      acc *= (n - i);
    }
    final Cal_Decimal dec = Cal_Decimal.fromBigInt(acc).checkRange();
    return _InternalValue(
      decimal: dec,
      symbolic: acc.toString().length <= 15
          ? SymbolicValue.fromBigInt(acc)
          : null,
    );
  }

  _InternalValue _evalCombination(_InternalValue nVal, _InternalValue rVal) {
    if (!nVal.decimal.isInteger || !rVal.decimal.isInteger) {
      throw const ArgumentErrorException('nCr requires integer arguments');
    }
    final BigInt n = nVal.decimal.toExactBigInt();
    final BigInt rOrig = rVal.decimal.toExactBigInt();
    if (n < BigInt.zero || rOrig < BigInt.zero || rOrig > n) {
      throw const ArgumentErrorException('Invalid nCr domain');
    }
    final BigInt r = (rOrig > n - rOrig) ? (n - rOrig) : rOrig;
    if (r > BigInt.from(10000)) {
      throw const MathErrorException('nCr overflow');
    }
    BigInt acc = BigInt.one;
    for (BigInt i = BigInt.one; i <= r; i += BigInt.one) {
      acc = (acc * (n - r + i)) ~/ i;
    }
    final Cal_Decimal dec = Cal_Decimal.fromBigInt(acc).checkRange();
    return _InternalValue(
      decimal: dec,
      symbolic: acc.toString().length <= 15
          ? SymbolicValue.fromBigInt(acc)
          : null,
    );
  }

  _InternalValue _evalLogBase(_InternalValue baseVal, _InternalValue argVal) {
    if (baseVal.decimal.isZero ||
        baseVal.decimal.isNegative ||
        baseVal.decimal == Cal_Decimal.one ||
        argVal.decimal.isZero ||
        argVal.decimal.isNegative) {
      throw const MathErrorException('Invalid domain for log_a(b)');
    }
    // Check exact integer power base^k == arg
    if (baseVal.decimal.isInteger && argVal.decimal.isInteger) {
      final BigInt b = baseVal.decimal.toExactBigInt();
      final BigInt x = argVal.decimal.toExactBigInt();
      if (b > BigInt.one && x >= BigInt.one) {
        BigInt cur = BigInt.one;
        for (int k = 0; k <= 64; k++) {
          if (cur == x) {
            return _InternalValue(
              decimal: Cal_Decimal.fromInt(k),
              symbolic: SymbolicValue.fromInt(k),
            );
          }
          if (cur > x) break;
          cur *= b;
        }
      }
    }
    final Cal_Decimal res = argVal.decimal.ln() / baseVal.decimal.ln();
    return _InternalValue(decimal: res);
  }

  _InternalValue _evalFunction(String name, List<_InternalValue> args) {
    if (args.isEmpty) {
      throw SyntaxErrorException('Function $name requires arguments');
    }
    final _InternalValue first = args[0];

    switch (name) {
      case 'f':
      case 'g':
        final String formula = name == 'f' ? definedFunctionF : definedFunctionG;
        if (formula.trim().isEmpty) {
          throw const MathErrorException('Undefined function f(x)/g(x)');
        }
        final localVars = Map<String, String>.from(variables);
        localVars['x'] = first.decimal.toPlainString();
        final subEval = MathExpressionEvaluator(
          angleUnit: angleUnit,
          numberFormat: numberFormat,
          formatDigits: formatDigits,
          variables: localVars,
          definedFunctionF: definedFunctionF,
          definedFunctionG: definedFunctionG,
        );
        final subRoot = VisualToSemanticTranslator.translateText(formula);
        return subEval._evalNode(subRoot, localVars);

      case 'Int':
        final double d = first.decimal.toDouble();
        final int trunc = d.truncate();
        return _InternalValue(
          decimal: Cal_Decimal.fromInt(trunc),
          symbolic: SymbolicValue.fromInt(trunc),
        );

      case 'Intg':
        final double d = first.decimal.toDouble();
        final int flr = d.floor();
        return _InternalValue(
          decimal: Cal_Decimal.fromInt(flr),
          symbolic: SymbolicValue.fromInt(flr),
        );

      case 'sqrt':
        return _InternalValue(
          decimal: first.decimal.sqrt(),
          symbolic: first.symbolic?.trySqrt(),
        );

      case 'abs':
        final SymbolicValue? sym = first.symbolic != null
            ? (first.decimal.isNegative ? -first.symbolic! : first.symbolic)
            : null;
        return _InternalValue(
          decimal: first.decimal.abs(),
          symbolic: sym,
        );

      case 'sin':
        final SymbolicValue? symSin = first.symbolic != null
            ? SymbolicTrigEngine.trySin(first.symbolic!, angleUnit)
            : null;
        return _InternalValue(
          decimal: symSin != null
              ? symSin.toCal_Decimal()
              : first.decimal.sinAngle(angleUnit),
          symbolic: symSin,
        );

      case 'cos':
        final SymbolicValue? symCos = first.symbolic != null
            ? SymbolicTrigEngine.tryCos(first.symbolic!, angleUnit)
            : null;
        return _InternalValue(
          decimal: symCos != null
              ? symCos.toCal_Decimal()
              : first.decimal.cosAngle(angleUnit),
          symbolic: symCos,
        );

      case 'tan':
        final SymbolicValue? symTan = first.symbolic != null
            ? SymbolicTrigEngine.tryTan(first.symbolic!, angleUnit)
            : null;
        return _InternalValue(
          decimal: symTan != null
              ? symTan.toCal_Decimal()
              : first.decimal.tanAngle(angleUnit),
          symbolic: symTan,
        );

      case 'asin':
        final double vAsin = first.decimal.toDouble();
        if (vAsin < -1.0 - 1e-15 || vAsin > 1.0 + 1e-15) {
          throw const MathErrorException('asin domain error (|x| > 1)');
        }
        final SymbolicValue? symAsin = first.symbolic != null
            ? SymbolicTrigEngine.tryAsin(first.symbolic!, angleUnit)
            : null;
        if (symAsin != null) {
          return _InternalValue(
            decimal: symAsin.toCal_Decimal(),
            symbolic: symAsin,
          );
        }
        final double radAsin = math.asin(vAsin.clamp(-1.0, 1.0));
        return _InternalValue(decimal: _radToAngleDecimal(radAsin));

      case 'acos':
        final double vAcos = first.decimal.toDouble();
        if (vAcos < -1.0 - 1e-15 || vAcos > 1.0 + 1e-15) {
          throw const MathErrorException('acos domain error (|x| > 1)');
        }
        final SymbolicValue? symAcos = first.symbolic != null
            ? SymbolicTrigEngine.tryAcos(first.symbolic!, angleUnit)
            : null;
        if (symAcos != null) {
          return _InternalValue(
            decimal: symAcos.toCal_Decimal(),
            symbolic: symAcos,
          );
        }
        final double radAcos = math.acos(vAcos.clamp(-1.0, 1.0));
        return _InternalValue(decimal: _radToAngleDecimal(radAcos));

      case 'atan':
        final SymbolicValue? symAtan = first.symbolic != null
            ? SymbolicTrigEngine.tryAtan(first.symbolic!, angleUnit)
            : null;
        if (symAtan != null) {
          return _InternalValue(
            decimal: symAtan.toCal_Decimal(),
            symbolic: symAtan,
          );
        }
        final double radAtan = math.atan(first.decimal.toDouble());
        return _InternalValue(decimal: _radToAngleDecimal(radAtan));

      case 'sinh':
        final Cal_Decimal ep = first.decimal.exp();
        final Cal_Decimal em = (-first.decimal).exp();
        return _InternalValue(decimal: (ep - em) / Cal_Decimal.two);

      case 'cosh':
        final Cal_Decimal ep = first.decimal.exp();
        final Cal_Decimal em = (-first.decimal).exp();
        return _InternalValue(decimal: (ep + em) / Cal_Decimal.two);

      case 'tanh':
        final double x = first.decimal.toDouble();
        if (x > 40) return _InternalValue(decimal: Cal_Decimal.one);
        if (x < -40) return _InternalValue(decimal: Cal_Decimal.minusOne);
        final Cal_Decimal ep = first.decimal.exp();
        final Cal_Decimal em = (-first.decimal).exp();
        return _InternalValue(decimal: (ep - em) / (ep + em));

      case 'asinh':
        // asinh(x) = ln(x + sqrt(x^2 + 1))
        final Cal_Decimal inside =
            first.decimal + (first.decimal * first.decimal + Cal_Decimal.one).sqrt();
        return _InternalValue(decimal: inside.ln());

      case 'acosh':
        // acosh(x) = ln(x + sqrt(x^2 - 1)), requires x >= 1
        if (first.decimal < Cal_Decimal.one) {
          throw const MathErrorException('acosh domain error (x < 1)');
        }
        final Cal_Decimal inside =
            first.decimal + (first.decimal * first.decimal - Cal_Decimal.one).sqrt();
        return _InternalValue(decimal: inside.ln());

      case 'atanh':
        // atanh(x) = 0.5 * ln((1 + x) / (1 - x)), requires |x| < 1
        if (first.decimal.abs() >= Cal_Decimal.one) {
          throw const MathErrorException('atanh domain error (|x| >= 1)');
        }
        final Cal_Decimal ratio =
            (Cal_Decimal.one + first.decimal) / (Cal_Decimal.one - first.decimal);
        return _InternalValue(decimal: ratio.ln() / Cal_Decimal.two);

      case 'ln':
        if (first.decimal == Cal_Decimal.one) {
          return _InternalValue(
            decimal: Cal_Decimal.zero,
            symbolic: SymbolicValue.zero,
          );
        }
        return _InternalValue(decimal: first.decimal.ln());

      case 'log':
        if (args.length == 2) {
          return _evalLogBase(args[0], args[1]);
        }
        final Cal_Decimal res = first.decimal.log10();
        return _InternalValue(
          decimal: res,
          symbolic: res.isInteger
              ? SymbolicValue.fromBigInt(res.toExactBigInt())
              : null,
        );

      case 'exp':
        if (first.decimal.isZero) {
          return _InternalValue(
            decimal: Cal_Decimal.one,
            symbolic: SymbolicValue.one,
          );
        }
        return _InternalValue(decimal: first.decimal.exp());

      case 'gcd':
        if (args.length < 2) {
          throw const ArgumentErrorException('GCD requires 2 arguments');
        }
        BigInt g = _requireIntegerArg(args[0], 'GCD').abs();
        for (int i = 1; i < args.length; i++) {
          final BigInt next = _requireIntegerArg(args[i], 'GCD').abs();
          g = (g == BigInt.zero && next == BigInt.zero)
              ? BigInt.zero
              : bigIntGcd(g, next);
        }
        return _InternalValue(
          decimal: Cal_Decimal.fromBigInt(g),
          symbolic: SymbolicValue.fromBigInt(g),
        );

      case 'lcm':
        if (args.length < 2) {
          throw const ArgumentErrorException('LCM requires 2 arguments');
        }
        BigInt l = _requireIntegerArg(args[0], 'LCM').abs();
        for (int i = 1; i < args.length; i++) {
          final BigInt next = _requireIntegerArg(args[i], 'LCM').abs();
          l = bigIntLcm(l, next);
        }
        return _InternalValue(
          decimal: Cal_Decimal.fromBigInt(l),
          symbolic: SymbolicValue.fromBigInt(l),
        );

      case 'nPr':
        if (args.length != 2) {
          throw const ArgumentErrorException('nPr requires 2 arguments');
        }
        return _evalPermutation(args[0], args[1]);

      case 'nCr':
        if (args.length != 2) {
          throw const ArgumentErrorException('nCr requires 2 arguments');
        }
        return _evalCombination(args[0], args[1]);

      case 'fact':
        if (!first.decimal.isInteger || !first.decimal.isPositive) {
          throw const ArgumentErrorException(
            'FACT requires a positive integer',
          );
        }
        final BigInt n = first.decimal.toExactBigInt();
        return _InternalValue(
          decimal: first.decimal,
          symbolic: first.symbolic,
          specialDisplayOverride: primeFactorize(n),
        );

      case 'Rnd':
        final String formatted = first.decimal.formatCal_Display(
          numberFormat: numberFormat,
          fixSciDigits: formatDigits,
        );
        final Cal_Decimal rounded = Cal_Decimal.parse(formatted);
        return _InternalValue(
          decimal: rounded,
          symbolic: BigRational.tryParse(formatted) != null
              ? SymbolicValue.fromRational(BigRational.tryParse(formatted)!)
              : null,
        );

      case 'P':
      case 'Q':
      case 'R':
        final double t = first.decimal.toDouble();
        final double phi = _standardNormalCdf(t);
        final double prob = switch (name) {
          'P' => phi,
          'Q' => (phi - 0.5).abs(),
          _ => (1.0 - phi).clamp(0.0, 1.0),
        };
        return _InternalValue(decimal: Cal_Decimal.fromDouble(prob));

      case 'Pol':
        if (args.length != 2) {
          throw const ArgumentErrorException('Pol(x, y) requires 2 arguments');
        }
        final Cal_Decimal x = args[0].decimal;
        final Cal_Decimal y = args[1].decimal;
        final Cal_Decimal r = (x * x + y * y).sqrt();
        final double thetaRad = math.atan2(y.toDouble(), x.toDouble());
        final Cal_Decimal theta = _radToAngleDecimal(thetaRad);
        final String rStr = r.formatCal_Display(
          numberFormat: numberFormat,
          fixSciDigits: formatDigits,
        );
        final String tStr = theta.formatCal_Display(
          numberFormat: numberFormat,
          fixSciDigits: formatDigits,
        );
        return _InternalValue(
          decimal: r,
          specialDisplayOverride: 'r=$rStr, θ=$tStr',
        );

      case 'Rec':
        if (args.length != 2) {
          throw const ArgumentErrorException('Rec(r, θ) requires 2 arguments');
        }
        final Cal_Decimal r = args[0].decimal;
        final Cal_Decimal theta = args[1].decimal;
        final Cal_Decimal xOut = r * theta.cosAngle(angleUnit);
        final Cal_Decimal yOut = r * theta.sinAngle(angleUnit);
        final String xStr = xOut.formatCal_Display(
          numberFormat: numberFormat,
          fixSciDigits: formatDigits,
        );
        final String yStr = yOut.formatCal_Display(
          numberFormat: numberFormat,
          fixSciDigits: formatDigits,
        );
        return _InternalValue(
          decimal: xOut,
          specialDisplayOverride: 'X=$xStr, Y=$yStr',
        );

      case 'RanInt':
        if (args.length != 2) {
          throw const ArgumentErrorException('RanInt#(a, b) requires 2 arguments');
        }
        final BigInt a = _requireIntegerArg(args[0], 'RanInt');
        final BigInt b = _requireIntegerArg(args[1], 'RanInt');
        if (a > b) {
          throw const ArgumentErrorException('RanInt requires a <= b');
        }
        final BigInt span = b - a + BigInt.one;
        final BigInt offset = span <= BigInt.from(1000000)
            ? BigInt.from(math.Random().nextInt(span.toInt()))
            : (a + b) ~/ BigInt.two - a;
        final BigInt chosen = a + offset;
        return _InternalValue(
          decimal: Cal_Decimal.fromBigInt(chosen),
          symbolic: SymbolicValue.fromBigInt(chosen),
        );

      default:
        throw SyntaxErrorException('Unknown function $name');
    }
  }

  static double _standardNormalCdf(double z) {
    if (z < -8.5) return 0.0;
    if (z > 8.5) return 1.0;
    final double x = z / math.sqrt2;
    if (x == 0.0) return 0.5;
    final double sign = x < 0 ? -1.0 : 1.0;
    final double ax = x.abs();
    const double twoOverSqrtPi = 1.1283791670955126;
    double erfVal;
    if (ax < 3.0) {
      final double x2 = ax * ax;
      double term = ax;
      double sum = ax;
      for (int k = 1; k <= 80; k++) {
        term *= (2.0 * x2) / (2 * k + 1);
        sum += term;
        if (term <= sum * 1e-16) break;
      }
      erfVal = sign * (twoOverSqrtPi * math.exp(-x2) * sum).clamp(0.0, 1.0);
    } else {
      double f = 0.0;
      for (int k = 40; k >= 1; k--) {
        f = (0.5 * k) / (ax + f);
      }
      final double erfc =
          (0.5 * twoOverSqrtPi * math.exp(-ax * ax)) / (ax + f);
      erfVal = sign * (1.0 - erfc).clamp(0.0, 1.0);
    }
    return 0.5 * (1.0 + erfVal);
  }

  BigInt _requireIntegerArg(_InternalValue val, String fnName) {
    if (!val.decimal.isInteger) {
      throw ArgumentErrorException('$fnName requires integer arguments');
    }
    return val.decimal.toExactBigInt();
  }

  Cal_Decimal _radToAngleDecimal(double rad) {
    final double converted = switch (angleUnit) {
      AngleUnit.degree => rad * 180.0 / math.pi,
      AngleUnit.radian => rad,
      AngleUnit.gradian => rad * 200.0 / math.pi,
    };
    return Cal_Decimal.fromDouble(converted);
  }

  // ===========================================================================
  // 4. Calculus Primitives (Richardson Extrapolation & Gauss-Kronrod G7-K15)
  // ===========================================================================

  _InternalValue _evalCalculus(
    SemanticCalculusNode node,
    Map<String, String> env,
  ) {
    double evalBodyDouble(double xVal) {
      final localEnv = Map<String, String>.from(env);
      localEnv['x'] = xVal.toStringAsPrecision(16);
      final res = _evalNode(node.body, localEnv);
      final d = res.decimal.toDouble();
      if (d.isNaN || d.isInfinite) {
        throw const MathErrorException('Non-finite value in calculus evaluation');
      }
      return d;
    }

    switch (node.type) {
      case 'deriv':
        final double a = _evalNode(node.boundA, env).decimal.toDouble();
        final double derivVal = _richardsonDerivative(evalBodyDouble, a);
        final Cal_Decimal dec = _snapNearIntegerOrCleanDecimal(derivVal);
        return _InternalValue(
          decimal: dec,
          symbolic: _trySnapCleanRational(derivVal),
        );

      case 'integrate':
        if (node.boundB == null) {
          throw const SyntaxErrorException('Missing upper integration bound');
        }
        final double a = _evalNode(node.boundA, env).decimal.toDouble();
        final double b = _evalNode(node.boundB!, env).decimal.toDouble();
        if (a == b) {
          return _InternalValue(
            decimal: Cal_Decimal.zero,
            symbolic: SymbolicValue.zero,
          );
        }
        final double sign = b >= a ? 1.0 : -1.0;
        final double low = math.min(a, b);
        final double high = math.max(a, b);
        final double integralVal = sign *
            _adaptiveGaussKronrod15(
              evalBodyDouble,
              low,
              high,
              1e-11,
              0,
            );
        final Cal_Decimal dec = _snapNearIntegerOrCleanDecimal(integralVal);
        return _InternalValue(
          decimal: dec,
          symbolic: _trySnapCleanRational(integralVal),
        );

      case 'sum':
      case 'prod':
        if (node.boundB == null) {
          throw const SyntaxErrorException('Missing upper bound in sum/prod');
        }
        final _InternalValue startVal = _evalNode(node.boundA, env);
        final _InternalValue endVal = _evalNode(node.boundB!, env);
        if (!startVal.decimal.isInteger || !endVal.decimal.isInteger) {
          throw const ArgumentErrorException(
            'Summation/Product bounds must be integers',
          );
        }
        final int start = startVal.decimal.toExactBigInt().toInt();
        final int end = endVal.decimal.toExactBigInt().toInt();
        if (end < start) {
          throw const ArgumentErrorException('Upper bound < lower bound');
        }
        if (end - start > 10000) {
          throw const MathErrorException('Summation range exceeds limit');
        }

        final bool isSum = node.type == 'sum';
        Cal_Decimal accDec = isSum ? Cal_Decimal.zero : Cal_Decimal.one;
        SymbolicValue? accSym = isSum ? SymbolicValue.zero : SymbolicValue.one;

        for (int k = start; k <= end; k++) {
          final localEnv = Map<String, String>.from(env);
          localEnv['x'] = k.toString();
          final _InternalValue stepVal = _evalNode(node.body, localEnv);
          if (isSum) {
            accDec = accDec + stepVal.decimal;
            accSym = (accSym != null && stepVal.symbolic != null)
                ? accSym.tryAdd(stepVal.symbolic!)
                : null;
          } else {
            accDec = accDec * stepVal.decimal;
            accSym = (accSym != null && stepVal.symbolic != null)
                ? accSym.tryMultiply(stepVal.symbolic!)
                : null;
          }
        }
        return _InternalValue(decimal: accDec, symbolic: accSym);

      case 'solve':
        final double guess = _evalNode(node.boundA, env).decimal.toDouble();
        final double root = _hybridNewtonSecantSolve(evalBodyDouble, guess);
        return _InternalValue(
          decimal: _snapNearIntegerOrCleanDecimal(root),
        );

      default:
        throw SyntaxErrorException('Unknown calculus form ${node.type}');
    }
  }

  /// Central Finite Difference with 4-step Richardson Extrapolation ($O(h^8)$).
  static double _richardsonDerivative(
    double Function(double) f,
    double x,
  ) {
    const int levels = 4;
    final List<List<double>> d = List.generate(
      levels,
      (_) => List.filled(levels, 0.0),
    );

    double h = math.max(x.abs(), 1.0) * 0.01;
    for (int i = 0; i < levels; i++) {
      final double fPlus = f(x + h);
      final double fMinus = f(x - h);
      d[i][0] = (fPlus - fMinus) / (2.0 * h);

      double factor = 4.0;
      for (int j = 1; j <= i; j++) {
        d[i][j] = d[i][j - 1] + (d[i][j - 1] - d[i - 1][j - 1]) / (factor - 1.0);
        factor *= 4.0;
      }
      h *= 0.5;
    }

    final double best = d[levels - 1][levels - 1];
    final double prev = d[levels - 2][levels - 2];
    if (best.isNaN ||
        best.isInfinite ||
        (best - prev).abs() > math.max(1.0, best.abs()) * 1e-2) {
      throw const MathErrorException('Derivative did not converge');
    }
    return best;
  }

  /// 15-point Gauss-Kronrod (G7-K15) nodes and weights on $[-1, 1]$.
  static const List<double> _xgk = [
    0.9914553711208126,
    0.9491079123427585,
    0.8648644233597691,
    0.7415311855993945,
    0.5860872354676911,
    0.4058451513773972,
    0.2077849550078985,
    0.0000000000000000,
  ];

  static const List<double> _wgk = [
    0.02293532201052922,
    0.06309209262997856,
    0.1047900103222502,
    0.1406532597155259,
    0.1690047266392679,
    0.1903505780647854,
    0.2044329400752989,
    0.2094821410847278,
  ];

  static const List<double> _wg = [
    0.1294849661688697,
    0.2797053914892767,
    0.3818300505051189,
    0.4179591836734694,
  ];

  static double _adaptiveGaussKronrod15(
    double Function(double) f,
    double a,
    double b,
    double tol,
    int depth,
  ) {
    final double center = 0.5 * (a + b);
    final double halfLength = 0.5 * (b - a);
    final double fCenter = f(center);

    double resG = _wg[3] * fCenter;
    double resK = _wgk[7] * fCenter;

    for (int j = 0; j < 7; j++) {
      final double abscissa = halfLength * _xgk[j];
      final double fval1 = f(center - abscissa);
      final double fval2 = f(center + abscissa);
      final double fsum = fval1 + fval2;
      resK += _wgk[j] * fsum;
      if (j.isOdd) {
        resG += _wg[j ~/ 2] * fsum;
      }
    }

    resK *= halfLength;
    resG *= halfLength;
    final double err = (resK - resG).abs();

    if (resK.isNaN || resK.isInfinite) {
      throw const MathErrorException('Singularity in definite integral');
    }
    if (err <= tol || depth >= 12) {
      if (depth >= 12 && err > math.max(1e-3, resK.abs() * 1e-2)) {
        throw const MathErrorException('Integral failed to converge');
      }
      return resK;
    }

    return _adaptiveGaussKronrod15(f, a, center, tol * 0.5, depth + 1) +
        _adaptiveGaussKronrod15(f, center, b, tol * 0.5, depth + 1);
  }

  static double _hybridNewtonSecantSolve(
    double Function(double) f,
    double initialGuess,
  ) {
    double x = initialGuess;
    for (int iter = 0; iter < 60; iter++) {
      final double fx = f(x);
      if (fx.abs() < 1e-12) return x;
      final double h = math.max(x.abs(), 1.0) * 1e-6;
      final double dfx = (f(x + h) - f(x - h)) / (2.0 * h);
      if (dfx.abs() < 1e-14) {
        x += 0.1;
        continue;
      }
      final double nextX = x - fx / dfx;
      if ((nextX - x).abs() < 1e-12) return nextX;
      x = nextX;
    }
    if (f(x).abs() < 1e-6) return x;
    throw const MathErrorException('Solver did not converge');
  }

  static Cal_Decimal _snapNearIntegerOrCleanDecimal(double v) {
    if (v.abs() < 1e-12) return Cal_Decimal.zero;
    final double rounded = v.roundToDouble();
    if ((v - rounded).abs() < 1e-9 && rounded.abs() < 1e12) {
      return Cal_Decimal.fromInt(rounded.round());
    }
    return Cal_Decimal.parse(v.toStringAsPrecision(12));
  }

  static SymbolicValue? _trySnapCleanRational(double v) {
    if (!v.isFinite || v.abs() > 1e8) return null;
    if (v.abs() < 1e-12) return SymbolicValue.zero;
    final int nearInt = v.round();
    if ((v - nearInt).abs() < 1e-9) {
      return SymbolicValue.fromInt(nearInt);
    }
    // Continued fraction rational approximation with small denominator <= 1000
    final bool neg = v < 0;
    double x = v.abs();
    int h1 = 1, h2 = 0;
    int k1 = 0, k2 = 1;
    double b = x;
    for (int i = 0; i < 16; i++) {
      final int a = b.floor();
      final int h = a * h1 + h2;
      final int k = a * k1 + k2;
      if (k > 1000) break;
      h2 = h1;
      h1 = h;
      k2 = k1;
      k1 = k;
      if (k1 > 0 && (x - (h1 / k1)).abs() < 1e-9) {
        return SymbolicValue.fromInt(neg ? -h1 : h1, k1);
      }
      final double rem = b - a;
      if (rem.abs() < 1e-11) break;
      b = 1.0 / rem;
    }
    return null;
  }
}
