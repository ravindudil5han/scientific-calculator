/// Canonical Cal_ 1100_DB_ evaluation error exceptions.
///
/// Maps directly to the hardware modal error dialogs:
/// - `Syntax ERROR`: Malformed grammar, unexpected operators, empty 2D boxes.
/// - `Math ERROR`: Division by zero, domain violations ($\ln \le 0$, $\sqrt{-x}$
///   in real mode), overflow ($\ge 10^{100}$), or non-convergent calculus.
/// - `Argument ERROR`: Invalid discrete/combinatorial arguments (e.g., negative
///   or fractional $n!$, $nCr$, $nPr$, `GCD`, `LCM`, or $\sum$ bounds).
abstract class Cal_EvaluationException implements Exception {
  final String errorTitle;
  final String detail;

  const Cal_EvaluationException(this.errorTitle, [this.detail = '']);

  @override
  String toString() => detail.isEmpty ? errorTitle : '$errorTitle: $detail';
}

/// Thrown when expression syntax or 2D template structure is incomplete/malformed.
class SyntaxErrorException extends Cal_EvaluationException {
  const SyntaxErrorException([String detail = ''])
      : super('Syntax ERROR', detail);
}

/// Thrown when an operation violates mathematical domain or exceeds $\pm 10^{99}$.
class MathErrorException extends Cal_EvaluationException {
  const MathErrorException([String detail = '']) : super('Math ERROR', detail);
}

/// Thrown when function arguments violate integer/combinatorial constraints.
class ArgumentErrorException extends Cal_EvaluationException {
  const ArgumentErrorException([String detail = ''])
      : super('Argument ERROR', detail);
}
