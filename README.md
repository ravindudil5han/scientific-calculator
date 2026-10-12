# 991CW Scientific Calculator (`Cal_ 1100_DB_`)

[![Flutter](https://img.shields.io/badge/Flutter-3.13%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-Pure%20CAS%20%26%20BCD-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Privacy](https://img.shields.io/badge/Privacy-Zero%20Permissions%20%7C%20100%25%20Offline-success)](#privacy--security)

A high-precision **2D Natural Textbook Scientific Calculator** inspired by the modern ClassWiz (`fx-991CW`) architecture—built **100% from scratch in pure Flutter and Dart** with **zero third-party math or CAS dependencies**.

Every subsystem—from the 30-digit Binary-Coded Decimal (BCD) arithmetic engine and exact symbolic surd simplifier to the 2D spatial formula editor, 4-shade FSTN dot-matrix LCD renderer, and Reed-Solomon QR code generator—is implemented natively in Dart.

---

## ✨ Key Highlights

- **📐 2D Natural Textbook Display & Spatial Editor**: Construct and navigate deeply nested mathematical expressions using a true visual Abstract Syntax Tree (`FractionNode`, `RadicalNode`, `IntegralNode`, `DerivativeNode`, `SummationNode`, `LogBaseNode`, `SuperscriptNode`, `ParenthesisNode`) with 4-way directional cursor traversal (`▲`, `▼`, `◀`, `▶`).
- **🔬 30-Digit Arbitrary-Precision BCD & Symbolic CAS**:
  - **Zero Binary Floating-Point Drift**: Custom `Cal_Decimal` ($m \times 10^{-s}$, 30-digit precision) and `BigRational` ($p/q$ exact fractions) guarantee exact decimal arithmetic ($0.1 + 0.2 = 0.3$ and $10^{15} - 1 = 999999999999999$).
  - **Exact Symbolic Engine**: Simplifies quadratic surds in canonical form $\frac{\sum c_r \sqrt{r}}{d} \pi^k$, denests nested radicals (e.g., $\sqrt{3 + 2\sqrt{2}} \rightarrow \sqrt{2} + 1$), rationalizes denominators, computes exact trigonometric values for all multiples of $15^\circ$, and performs prime factorization (`FACT`).
- **🧮 13 Full-Featured Application Modes**: Calculate, Complex, Base-N, Matrix, Vector, Statistics, Distribution, Spreadsheet, Table, Equation, Inequality, Ratio, and Math Box.
- **🖥️ Dual-Layer FSTN LCD Rendering Engine**:
  - **Logical Dot-Matrix Framebuffer**: Authentic $192 \times 63$ 4-shade monochrome FSTN buffer (`#DCE4DC`, `#A6B0A6`, `#6E766E`, `#363C36`, `#101410`) with custom $5 \times 7$ and $3 \times 5$ bitmap fonts and FNV-1a dirty-frame hashing.
  - **High-Resolution Vector Renderer**: Crisp $768 \times 290$ virtual canvas with 16-level hardware contrast interpolation (`0..15`), optional pixel-grid/scanline overlay, and inverted display mode.
- **⌨️ 48-Key Tactile Hardware Interface**: Molded matte chassis with a 3-zone 48-key layout, circular pebble keycaps, metallic gold `SHIFT` modifier, sculpted 5-way D-pad, page rocker, haptic feedback, and desktop keyboard navigation.
- **📱 Built-in ISO/IEC 18004 QR Code Generator**: Pure-Dart Galois Field $\text{GF}(2^8)$ Reed-Solomon error-correcting QR generator (`SHIFT` + `x`) for sharing formulas and state.
- **🔒 100% Offline & Zero Permissions**: Requires zero network or device permissions on Android, Web, and Desktop.

---

## 🧭 All 13 Calculator Modes

Press the **`HOME`** key to switch between any of the 13 built-in mathematical environments:

| # | Mode | Code | Capabilities |
| :-: | :--- | :---: | :--- |
| 1 | **Calculate** | `CALC` | General arithmetic, exact fractions & radicals, numerical definite integrals $\int_a^b f(x)\,dx$, derivatives $\left.\frac{d}{dx}f(x)\right\vert_{x=a}$, summations $\sum$, and products $\prod$. |
| 2 | **Complex** | `CMPLX` | Complex number arithmetic in Rectangular ($a + bi$) and Polar ($r\angle\theta$) forms, modulus (`Abs`), argument (`Arg`), and complex conjugate (`Conjg`). |
| 3 | **Base-N** | `BASE` | 32-bit two's complement integer conversions and arithmetic in Decimal (`DEC`), Hexadecimal (`HEX`), Binary (`BIN`), and Octal (`OCT`), plus bitwise `AND`, `OR`, `XOR`, `XNOR`, `NOT`, and `NEG`. |
| 4 | **Matrix** | `MAT` | Up to $4 \times 4$ matrices across `MatA`–`MatD` and `MatAns`. Supports addition, multiplication, scalar scaling, determinant (`Det`), Gauss-Jordan inverse ($A^{-1}$), transpose ($A^T$), trace (`Tr`), and powers ($A^2, A^3$). |
| 5 | **Vector** | `VCT` | 2D and 3D vectors across `VctA`–`VctD` and `VctAns`. Supports dot product ($u \cdot v$), cross product ($u \times v$), magnitude (`Abs`), inter-vector angle (`Angle`), and unit vector normalization (`UnitV`). |
| 6 | **Statistics** | `STAT` | **1-Variable** ($\bar{x}, \sum x, \sum x^2, \sigma_x, s_x, n, \min, Q_1, \text{Med}, Q_3, \max$) and **2-Variable Regressions** (Linear, Quadratic, Logarithmic, $e$-Exponential, $ab$-Exponential, Power, Inverse) with $\hat{x}$ and $\hat{y}$ estimators. |
| 7 | **Distribution** | `DIST` | Probability distributions: Normal PD, Normal CD, Inverse Normal, Binomial PD, Binomial CD, Poisson PD, and Poisson CD (supports both single-value `Variable` and batch `List` evaluation). |
| 8 | **Spreadsheet** | `SHEET` | Interactive 5-column (`A`–`E`) $\times$ 45-row (`1`–`45`) reactive spreadsheet with cell formulas (`=A1+B1`), relative & absolute (`$A$1`) references, range functions (`Sum`, `Mean`, `Min`, `Max`), and circular reference detection. |
| 9 | **Table** | `TABLE` | Dual-function numerical table generator evaluating $f(x)$ and $g(x)$ across user-defined `[Start, End, Step]` intervals. |
| 10 | **Equation** | `EQN` | **Simultaneous Linear Equations** (2, 3, or 4 unknowns), **Polynomial Root Solver** (degrees 2, 3, and 4 with real/complex roots and local extrema), and general **Newton-Raphson Numerical Solver** (`Solver`). |
| 11 | **Inequality** | `INEQ` | Solves quadratic, cubic, and quartic polynomial inequalities ($>, <, \ge, \le$) and formats solutions in exact symbolic interval notation. |
| 12 | **Ratio** | `RATIO` | Solves proportional relationships of the form $A : B = X : D$ or $A : B = C : X$. |
| 13 | **Math Box** | `MBOX` | Probability and number intuition tools: **Dice Roll** simulator (1–3 dice, up to 250 trials), **Coin Toss** simulator (1–3 coins, up to 250 trials), and interactive **Number Line** graphing. |

---

## 📚 Built-in Constants & Unit Conversions

Accessible via the **`CATALOG`** menu:

- **47 CODATA Physical Constants** organized across 5 domains (*Universal*, *Electromagnetic*, *Atomic & Nuclear*, *Physico-Chemical*, and *Adopted Values*), including $c_0, g_n, G, h, \hbar, e, m_e, m_p, m_n, N_A, k, R, F, \sigma, \alpha$, and more.
- **47 Bidirectional Unit Conversion Pairs (94 Total Conversions)** across 11 categories (*Length*, *Area*, *Volume*, *Mass*, *Velocity*, *Pressure*, *Energy*, *Power*, *Temperature* with exact affine $^{\circ}\text{C} \leftrightarrow {}^{\circ}\text{F} \leftrightarrow \text{K}$ transforms, *Force*, and *Angle/Time*).

---

## 🏗️ Architecture & Project Structure

The codebase is modularized into six self-contained layers under `lib/`:

```text
991CW/
├── lib/
│   ├── main.dart                                # App entrypoint, orientation & system overlay setup
│   ├── core/
│   │   └── calculator_theme.dart                # 4-shade FSTN LCD palette, 16-step contrast & chassis colors
│   ├── hardware_ui/
│   │   ├── calculator_chassis_shell.dart        # Handheld casing, solar header & desktop keyboard handler
│   │   ├── calculator_keypad_matrix.dart        # 48-key physical matrix, 5-way D-pad & page rocker
│   │   └── pebble_key_button.dart               # Sculpted keycaps & custom vector glyph painters
│   ├── display_engine/
│   │   ├── lcd_bitmap_font.dart                 # 192×63 4-shade framebuffer, 5×7 / 3×5 fonts & FNV-1a hash
│   │   ├── lcd_display_widget.dart              # 768×290 high-res vector LCD painter & status bar
│   │   ├── lcd_grid_table_renderer.dart         # 2D table/grid renderer for Matrix, Spreadsheet & Stats
│   │   ├── math_editor_engine.dart              # Spatial 4-way cursor movement & AST editing operations
│   │   ├── math_nodes.dart                      # 2D Natural Textbook Visual AST node definitions
│   │   └── qr_code_generator.dart               # Pure-Dart ISO/IEC 18004 QR & Reed-Solomon ECC engine
│   ├── math_engine/
│   │   ├── calculator_decimal.dart              # BigRational & 30-digit BCD Cal_Decimal + series functions
│   │   ├── calculator_exceptions.dart           # Hardware-accurate error types (Math, Syntax, Dimension, etc.)
│   │   ├── constants_conversions_engine.dart    # 47 CODATA constants & 47 bidirectional unit pairs
│   │   ├── math_expression_evaluator.dart       # Visual-to-Semantic AST compiler & recursive parser
│   │   └── symbolic_engine.dart                 # Exact quadratic surds, denesting, rationalization & FACT
│   ├── navigation/
│   │   └── cw_menu_tree.dart                    # Hierarchical menus (CATALOG, TOOLS, FORMAT, CONFIG, VAR)
│   └── state/
│       ├── calculator_controller.dart           # Central state machine, mode router & solver dispatcher
│       ├── calculator_models.dart               # Enums, history entries & domain models
│       ├── calculator_persistence.dart          # Haptic feedback & local JSON state persistence
│       └── calculator_state.dart                # Immutable calculator state snapshot
└── test/
    ├── calculator_parity_test.dart              # BCD precision, PEMDAS, calculus & symbolic parity suite
    └── widget_test.dart                         # Full-stack UI & 13-mode integration test suite
```

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`^3.13.0` or newer)
- Dart SDK (bundled with Flutter)

### Installation & Running

1. **Clone the repository:**
   ```bash
   git clone https://github.com/ravindudil5han/scientific-calculator.git
   cd scientific-calculator
   ```

2. **Fetch dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the application:**
   ```bash
   # Run on connected Android device or emulator
   flutter run -d android

   # Run on Windows desktop
   flutter run -d windows

   # Run in Chrome / Web browser
   flutter run -d chrome
   ```

4. **Run the test suites:**
   ```bash
   # Run the mathematical parity & precision test suite
   flutter test test/calculator_parity_test.dart

   # Run the full test suite
   flutter test
   ```

---

## ⌨️ Desktop Keyboard Shortcuts

When running on Windows or Web, you can use your physical keyboard alongside on-screen clicks:

| Physical Key | Calculator Action |
| :--- | :--- |
| `0` – `9`, `.` | Numeric & decimal point entry |
| `+`, `-`, `*`, `/` | Basic arithmetic operators (`+`, `−`, `×`, `÷`) |
| `^` | Power / Exponent template ($x^{\square}$) |
| `(`, `)` | Open / Close parentheses |
| `Arrow Keys` (`▲`, `▼`, `◀`, `▶`) | 4-way spatial cursor & menu navigation |
| `PageUp` / `PageDown` | Page scroll up / down in menus and tables |
| `Enter` or `=` | Execute (`EXE` / `=`) |
| `Backspace` | Delete (`⌫`) |
| `Escape` or `Delete` | All Clear (`AC`) |
| `Home` | Open the 13-Mode Home Screen (`HOME`) |
| `x` | Insert independent variable $x$ |

---

## 🤝 Contributing & Community Roadmap

We welcome contributions from developers, mathematicians, educators, and students! Whether you want to fix a bug, optimize an algorithm, or build a new mode, please check out our [**Contributing Guide**](CONTRIBUTING.md) to get started.

### 🌟 Open Areas for Community Development

- **🍎🐧 Additional Platform Runners**: Add out-of-the-box support for **iOS**, **macOS**, and **Linux** (`flutter create . --platforms=ios,macos,linux`).
- **📈 Interactive 2D Function Plotter**: Extend the `Table` / `Calculate` modes or QR viewer with an interactive Cartesian graph canvas for $f(x)$ and $g(x)$.
- **🔊 Synthesized Key Click Audio**: Implement optional low-latency PCM piezo-click audio feedback in `Cal_Persistence` alongside haptic vibrations.
- **🎨 Hardware Faceplate Themes**: Add selectable hardware skins (e.g., classic dark carbon weave, light pearl edition, or classic `fx-991EX` key legends).
- **🌐 Localization (i18n)**: Translate the `CATALOG`, `SETTINGS`, and application mode menus into multiple languages.
- **🧹 Codebase & Test Polish**: Resolve informational lint naming warnings (`Cal_` prefix conventions) and expand property-based fuzz testing across edge-case symbolic integrals and matrices.

---

## 🔒 Privacy & Security

This calculator runs **100% locally and offline**. It contains no analytics, no telemetry, no advertisements, and requests **zero device permissions** in `AndroidManifest.xml`. See [SECURITY.md](SECURITY.md) for details.

---

## 📄 License & Disclaimer

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for full license text.

> **Disclaimer:** This project is an independent open-source educational software implementation and is **not** affiliated with, authorized by, endorsed by, or in any way officially connected with Casio Computer Co., Ltd. "Casio" and "ClassWiz" are registered trademarks of their respective owners.
