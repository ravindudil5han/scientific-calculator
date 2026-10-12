# Contributing to 991CW Scientific Calculator

First off, thank you for considering contributing to this project! 🎉

Our goal is to build and maintain the most accurate, educational, and responsive open-source 2D Natural Textbook scientific calculator in Flutter and Dart—powered entirely by a transparent, dependency-free mathematical engine.

---

## 📜 Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

---

## 🛠️ Development Environment Setup

1. **Fork and clone the repository:**
   ```bash
   git clone https://github.com/<your-username>/scientific-calculator.git
   cd scientific-calculator
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Verify the test suite:**
   ```bash
   flutter test test/calculator_parity_test.dart
   flutter test test/widget_test.dart
   ```

4. **Run static analysis:**
   ```bash
   flutter analyze
   ```

---

## 🏛️ Core Architectural Principles

When designing features or submitting bug fixes, please keep the following architectural pillars in mind:

1. **Zero External Math / CAS Dependencies**
   - Do **not** add third-party expression parsers, big-number libraries, or QR packages to `pubspec.yaml`.
   - All parsing, symbolic reduction, BCD arithmetic, matrix operations, statistical distributions, and QR Reed-Solomon encoding are intentionally implemented in pure Dart under `lib/math_engine/` and `lib/display_engine/`.

2. **30-Digit BCD & Exact Symbolic Precision First**
   - Avoid standard IEEE-754 `double` arithmetic for core user-facing calculations whenever exact or 30-digit decimal precision is possible.
   - Use `Cal_Decimal` and `BigRational` (`lib/math_engine/calculator_decimal.dart`) for arbitrary-precision decimal and rational operations, and `SymbolicEngine` (`lib/math_engine/symbolic_engine.dart`) for exact surds ($\sqrt{n}$) and $\pi$ multiples.
   - Respect hardware boundary semantics: overflows at $\ge 10^{100}$ must throw `MathErrorException`, and values $< 10^{-99}$ should gracefully underflow to `0`.

3. **2D Visual AST Integrity**
   - Visual textbook structures live in `lib/display_engine/math_nodes.dart` (`FractionNode`, `RadicalNode`, `IntegralNode`, `SummationNode`, `DerivativeNode`, `SuperscriptNode`, `LogBaseNode`, `ParenthesisNode`), while cursor movement and editing operations live in `lib/display_engine/math_editor_engine.dart`.
   - When adding a new 2D math template, ensure all four directional cursor movements (`moveLeft`, `moveRight`, `moveUp`, `moveDown`) and backspace dissolution behave intuitively.

4. **100% Offline & Zero Permissions**
   - Never introduce network calls, telemetry, or additional OS permissions.

---

## 🧭 Where to Find Things in the Codebase

| Subsystem | Key Files | What to Edit Here |
| :--- | :--- | :--- |
| **Arbitrary-Precision Math** | `lib/math_engine/calculator_decimal.dart` | `BigRational`, 30-digit `Cal_Decimal`, Taylor/series trig & log functions |
| **Symbolic CAS** | `lib/math_engine/symbolic_engine.dart` | Quadratic surd simplification, radical denesting, `FACT`, exact trig |
| **AST Parser & Evaluator** | `lib/math_engine/math_expression_evaluator.dart` | Visual-to-semantic compiler, operator precedence, calculus (Simpson's rule & derivatives) |
| **Constants & Conversions** | `lib/math_engine/constants_conversions_engine.dart` | 47 CODATA constants & 47 bidirectional unit conversion pairs |
| **2D Textbook Editor & LCD** | `lib/display_engine/*` | `MathNode` visual layout, 4-way cursor navigation, $192 \times 63$ framebuffer, $768 \times 290$ vector LCD, QR code generator |
| **Hardware Chassis & Keys** | `lib/hardware_ui/*` | 48-key keypad layout, pebble keycap rendering, desktop keyboard bindings |
| **Menus & Catalog** | `lib/navigation/cw_menu_tree.dart` | `CATALOG`, `TOOLS`, `SETTINGS`, `FORMAT`, `VAR`, and `FUNC` menu trees |
| **Mode Logic & Solvers** | `lib/state/calculator_controller.dart` | State transitions and solvers for all 13 `AppMode` environments |

---

## 🌱 Good First Issues & High-Impact Ideas

Looking for a place to start? Here are several well-scoped areas:

1. **Fix QR Payload URL Test Alignment (`test/widget_test.dart`)**:
   - Align the expected URL domain in `test/widget_test.dart` with `Cal_QrCodeGenerator.buildClassWizUrl` in `lib/display_engine/qr_code_generator.dart` so all widget tests pass out of the box.
2. **Clean Up Dart Analyzer Naming Warnings**:
   - Address the 39 informational `camel_case_types` / `non_constant_identifier_names` lint notices caused by the `Cal_` prefix (either by refactoring identifiers or configuring `analysis_options.yaml`).
3. **Add iOS, macOS, and Linux Runners**:
   - Scaffold and test native desktop/mobile runners for Apple and Linux platforms.
4. **Expand Symbolic Integration & Differentiation**:
   - Add exact symbolic anti-derivatives for common polynomial/trigonometric forms alongside the existing adaptive Gauss-Kronrod / Simpson numerical integrator.
5. **Interactive Graphing View**:
   - Build an optional 2D plot view for expressions entered in `Table` (`f(x)`, `g(x)`) or `Calculate` mode.

---

## 🔄 Pull Request Process

1. **Create a feature branch** from `main`:
   ```bash
   git checkout -b feat/your-feature-name
   # or
   git checkout -b fix/issue-description
   ```
2. **Write or update tests** in `test/calculator_parity_test.dart` (for math engine changes) or `test/widget_test.dart` (for UI, menu, and mode changes).
3. **Use clear commit messages** (we recommend [Conventional Commits](https://www.conventionalcommits.org/)):
   - `feat(math): add symbolic cube root simplification`
   - `fix(sheet): handle empty range in Mean() formula`
   - `docs(readme): add architecture diagram`
4. **Open a Pull Request** against `main` and fill out the PR template.

Thank you for helping make open-source scientific computing better for everyone!
