# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-10-12

### Added
- **2D Natural Textbook Display & Spatial Editor (`lib/display_engine/`)**:
  - Visual Abstract Syntax Tree (`FractionNode`, `RadicalNode`, `IntegralNode`, `DerivativeNode`, `SummationNode`, `LogBaseNode`, `SuperscriptNode`, `ParenthesisNode`).
  - 4-way directional cursor navigation (`moveLeft`, `moveRight`, `moveUp`, `moveDown`), operand auto-wrapping, and structural template backspace dissolution.
- **Arbitrary-Precision BCD & Symbolic CAS Engine (`lib/math_engine/`)**:
  - `Cal_Decimal` (30-digit decimal floating-point) and `BigRational` ($p/q$ exact rational reduction) eliminating IEEE-754 binary rounding drift.
  - `SymbolicEngine` supporting quadratic surds ($\frac{\sum c_r \sqrt{r}}{d} \pi^k$), nested radical denesting, denominator rationalization, prime factorization (`FACT`), and exact trigonometric multiples of $15^\circ$.
  - Numerical calculus: adaptive Simpson/Gauss-Kronrod definite integration ($\int_a^b f(x)\,dx$), central-difference derivatives ($\frac{d}{dx}$), summations ($\sum$), and products ($\prod$).
- **All 13 Application Modes (`lib/state/calculator_controller.dart`)**:
  - `Calculate`, `Complex`, `Base-N`, `Matrix` (up to $4 \times 4$), `Vector` (2D/3D), `Statistics` (1-Var & 7 regression models), `Distribution` (Normal, Binomial, Poisson), `Spreadsheet` ($5 \times 45$ reactive sheet), `Table` ($f(x), g(x)$), `Equation` (2–4 linear systems, degree 2–4 polynomials, Newton-Raphson `Solver`), `Inequality` (degree 2–4), `Ratio`, and `Math Box` (Dice Roll, Coin Toss, Number Line).
- **Constants & Unit Conversions (`lib/math_engine/constants_conversions_engine.dart`)**:
  - 47 CODATA physical constants across 5 categories.
  - 47 bidirectional unit conversion pairs (94 total conversions) across 11 categories.
- **Hardware Chassis & Dual LCD Renderer (`lib/hardware_ui/`, `lib/display_engine/`)**:
  - $192 \times 63$ 4-shade FSTN logical framebuffer (`LcdFrameBuffer`) and $768 \times 290$ high-resolution vector textbook painter.
  - 16-level hardware contrast adjustment (`0..15`), scanline/pixel grid toggle, and LCD display inversion.
  - 48-key tactile hardware keypad with circular pebble buttons, sculpted 5-way D-pad, page rocker, haptic feedback, and desktop keyboard shortcuts.
- **Pure-Dart QR Code Generator (`lib/display_engine/qr_code_generator.dart`)**:
  - ISO/IEC 18004 Byte Mode QR encoder with $\text{GF}(2^8)$ Reed-Solomon error correction.
- **Comprehensive Test Suite (`test/`)**:
  - `test/calculator_parity_test.dart` covering BCD precision, PEMDAS precedence, calculus, continued fractions, and randomized fuzzing.
  - `test/widget_test.dart` covering UI interaction across all 13 calculator modes.
