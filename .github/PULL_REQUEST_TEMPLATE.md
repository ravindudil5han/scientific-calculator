## 📝 Summary of Changes
Briefly describe what this Pull Request adds, fixes, or improves.

Fixes #(issue_number)

## 🧩 Affected Subsystems
- [ ] `lib/math_engine/` (30-digit BCD, `BigRational`, Symbolic CAS, Evaluator, Constants/Conversions)
- [ ] `lib/display_engine/` (2D Visual AST, Spatial Cursor Editor, LCD FrameBuffer / Vector Painter, QR Generator)
- [ ] `lib/state/` (Controller, 13 Application Modes, Persistence, Models)
- [ ] `lib/hardware_ui/` (Chassis Shell, 48-Key Keypad Matrix, Pebble Buttons)
- [ ] `lib/navigation/` (`CATALOG`, `TOOLS`, `SETTINGS`, `FORMAT` menus)
- [ ] `test/` or Documentation

## ✅ Contributor Checklist
- [ ] **Zero External Math Dependencies**: No third-party math/CAS packages were added to `pubspec.yaml`.
- [ ] **Precision Preserved**: Uses `Cal_Decimal`, `BigRational`, or `SymbolicEngine` where appropriate instead of lossy IEEE-754 `double`.
- [ ] **Tests Added / Updated**: Added or updated unit/widget tests in `test/calculator_parity_test.dart` or `test/widget_test.dart`.
- [ ] **Offline & Zero Permissions**: No network calls or device permissions were introduced.
