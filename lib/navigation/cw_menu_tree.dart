import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../math_engine/calculator_decimal.dart';
import '../math_engine/constants_conversions_engine.dart';
import '../state/calculator_models.dart';

/// Preference for displaying exact rational results (`ab/c` vs `d/c`).
enum FractionResultPreference {
  improper('Improper (d/c)'),
  mixed('Mixed (ab/c)');

  final String label;
  const FractionResultPreference(this.label);
}

/// Active output representation view selected via `FORMAT`.
enum OutputFormatView {
  standard,
  decimal,
  recurringDecimal,
  improperFraction,
  mixedFraction,
  engineering,
  sexagesimalDms,
  primeFactor,
}

/// Action descriptor attached to a leaf [CwMenuNode] in any ClassWiz menu.
@immutable
class CwMenuAction {
  final String type;
  final String payload;

  const CwMenuAction(this.type, [this.payload = '']);
}

/// A node in a hierarchical Cal_ 1100_DB_ menu tree (`CATALOG`, `TOOLS`,
/// `FORMAT`, `VARIABLE`, `FUNCTION`, `SETTINGS`).
@immutable
class CwMenuNode {
  final String id;
  final String label;
  final String? rightBadge;
  final List<CwMenuNode> children;
  final CwMenuAction? action;

  const CwMenuNode({
    required this.id,
    required this.label,
    this.rightBadge,
    this.children = const [],
    this.action,
  });

  bool get isSubMenu => children.isNotEmpty;
}

/// Represents one level in the active menu breadcrumb stack (`BACK` unwinds one level).
@immutable
class MenuBreadcrumbLevel {
  final String title;
  final List<CwMenuNode> items;
  final int selectedIndex;

  const MenuBreadcrumbLevel({
    required this.title,
    required this.items,
    this.selectedIndex = 0,
  });

  MenuBreadcrumbLevel copyWith({
    String? title,
    List<CwMenuNode>? items,
    int? selectedIndex,
  }) {
    return MenuBreadcrumbLevel(
      title: title ?? this.title,
      items: items ?? this.items,
      selectedIndex: selectedIndex ?? this.selectedIndex,
    );
  }
}

/// Formats numbers into Engineering notation ($m \times 10^{3k}$) and
/// Sexagesimal Degrees-Minutes-Seconds ($D^\circ M' S.SS''$).
class Cal_FormatConverter {
  static const Map<int, String> _siSymbolMap = {
    -15: 'f',
    -12: 'p',
    -9: 'n',
    -6: 'μ',
    -3: 'm',
    0: '',
    3: 'k',
    6: 'M',
    9: 'G',
    12: 'T',
    15: 'P',
    18: 'E',
  };

  /// Formats [decimalValue] in Engineering notation ($m \times 10^{3k}$),
  /// shifted by [stepShift] multiples of $3$ (e.g. pressing `◀` / `▶` in ENG mode).
  static String formatEngineering(
    Cal_Decimal decimalValue, {
    int stepShift = 0,
    bool useSiSymbols = false,
  }) {
    if (decimalValue.isZero) {
      return useSiSymbols ? '0' : '0×10^0';
    }
    final double val = decimalValue.toDouble();
    final int baseExp = (math.log(val.abs()) / math.ln10).floor();
    final int defaultEngExp = (baseExp ~/ 3) * 3 - (baseExp < 0 && baseExp % 3 != 0 ? 3 : 0);
    final int targetExp = defaultEngExp + (stepShift * 3);

    final double mantissa = val / math.pow(10.0, targetExp);
    String mantissaStr = mantissa.toStringAsPrecision(10);
    if (mantissaStr.contains('.') && !mantissaStr.contains('e')) {
      mantissaStr = mantissaStr
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }

    if (useSiSymbols && _siSymbolMap.containsKey(targetExp)) {
      final String sym = _siSymbolMap[targetExp]!;
      return sym.isEmpty ? mantissaStr : '$mantissaStr $sym';
    }
    return '$mantissaStr×10^$targetExp';
  }

  /// Formats [decimalValue] as Sexagesimal Degrees-Minutes-Seconds ($D^\circ M' S''$).
  static String formatSexagesimalDms(Cal_Decimal decimalValue) {
    final double val = decimalValue.toDouble();
    final bool isNeg = val < 0;
    final double absVal = val.abs();

    int degrees = absVal.floor();
    final double remMinutes = (absVal - degrees) * 60.0;
    int minutes = remMinutes.floor();
    double seconds = (remMinutes - minutes) * 60.0;

    // Snap rounding boundary e.g. 59.9999999 -> 60
    seconds = (seconds * 100.0).round() / 100.0;
    if (seconds >= 60.0) {
      seconds -= 60.0;
      minutes += 1;
    }
    if (minutes >= 60) {
      minutes -= 60;
      degrees += 1;
    }

    String secStr = seconds.toStringAsFixed(2);
    secStr = secStr
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');

    final String sign = isNeg ? '-' : '';
    return '$sign$degrees°$minutes\'$secStr\'\'';
  }
}

/// Builds the hierarchical menu trees for App Startup Wizards, `CATALOG`,
/// `TOOLS`, `FORMAT`, `VARIABLE`, `FUNCTION`, and `SETTINGS`.
class CwMenuTreeBuilder {
  /// Builds the authentic Cal_ 1100_DB_ initial selection menu when entering
  /// `Distribution`, `Statistics`, `Equation`, `Inequality`, `Ratio`, or
  /// `Math Box` from the `HOME` screen (or when unwinding via `BACK`).
  static MenuBreadcrumbLevel? buildAppStartupMenu(AppMode activeMode) {
    switch (activeMode) {
      case AppMode.distribution:
        // Exact Cal_ 1100_DB_ Distribution menu order:
        // 1. Binomial PD, 2. Binomial CD, 3. Normal PD, 4. Normal CD,
        // 5. Inverse Normal, 6. Poisson PD, 7. Poisson CD
        return MenuBreadcrumbLevel(
          title: 'Select Type',
          items: [
            _buildDistStartupItem('binomialPd', 'Binomial PD', hasList: true),
            _buildDistStartupItem('binomialCd', 'Binomial CD', hasList: true),
            _buildDistStartupItem('normalPd', 'Normal PD', hasList: true),
            _buildDistStartupItem('normalCd', 'Normal CD', hasList: false),
            _buildDistStartupItem(
              'inverseNormal',
              'Inverse Normal',
              hasList: false,
            ),
            _buildDistStartupItem('poissonPd', 'Poisson PD', hasList: true),
            _buildDistStartupItem('poissonCd', 'Poisson CD', hasList: true),
          ],
          selectedIndex: 0,
        );

      case AppMode.statistics:
        return const MenuBreadcrumbLevel(
          title: 'Select Type',
          items: [
            CwMenuNode(
              id: 'st_start_1var',
              label: '1-Variable',
              action: CwMenuAction('stat_model', 'oneVar'),
            ),
            CwMenuNode(
              id: 'st_start_2var_sub',
              label: '2-Variable',
              rightBadge: '▸',
              children: [
                CwMenuNode(
                  id: 'st_sub_lin',
                  label: 'y = a + bx',
                  action: CwMenuAction('stat_model', 'linear'),
                ),
                CwMenuNode(
                  id: 'st_sub_quad',
                  label: 'y = a + bx + cx²',
                  action: CwMenuAction('stat_model', 'quadratic'),
                ),
                CwMenuNode(
                  id: 'st_sub_log',
                  label: 'y = a + b·ln(x)',
                  action: CwMenuAction('stat_model', 'logarithmic'),
                ),
                CwMenuNode(
                  id: 'st_sub_eexp',
                  label: 'y = a·e^(bx)',
                  action: CwMenuAction('stat_model', 'eExponential'),
                ),
                CwMenuNode(
                  id: 'st_sub_abexp',
                  label: 'y = a·b^x',
                  action: CwMenuAction('stat_model', 'abExponential'),
                ),
                CwMenuNode(
                  id: 'st_sub_pow',
                  label: 'y = a·x^b',
                  action: CwMenuAction('stat_model', 'power'),
                ),
                CwMenuNode(
                  id: 'st_sub_inv',
                  label: 'y = a + b/x',
                  action: CwMenuAction('stat_model', 'inverse'),
                ),
              ],
            ),
            CwMenuNode(
              id: 'st_start_lin',
              label: 'y = a + bx',
              action: CwMenuAction('stat_model', 'linear'),
            ),
            CwMenuNode(
              id: 'st_start_quad',
              label: 'y = a + bx + cx²',
              action: CwMenuAction('stat_model', 'quadratic'),
            ),
            CwMenuNode(
              id: 'st_start_log',
              label: 'y = a + b·ln(x)',
              action: CwMenuAction('stat_model', 'logarithmic'),
            ),
            CwMenuNode(
              id: 'st_start_eexp',
              label: 'y = a·e^(bx)',
              action: CwMenuAction('stat_model', 'eExponential'),
            ),
            CwMenuNode(
              id: 'st_start_abexp',
              label: 'y = a·b^x',
              action: CwMenuAction('stat_model', 'abExponential'),
            ),
            CwMenuNode(
              id: 'st_start_pow',
              label: 'y = a·x^b',
              action: CwMenuAction('stat_model', 'power'),
            ),
            CwMenuNode(
              id: 'st_start_inv',
              label: 'y = a + b/x',
              action: CwMenuAction('stat_model', 'inverse'),
            ),
          ],
          selectedIndex: 0,
        );

      case AppMode.equation:
        return const MenuBreadcrumbLevel(
          title: 'Equation',
          items: [
            CwMenuNode(
              id: 'eq_start_simul',
              label: 'Simul Equation',
              rightBadge: '▸',
              children: [
                CwMenuNode(
                  id: 'eq_sim_2',
                  label: '2 Unknowns',
                  action: CwMenuAction('eq_simul', '2'),
                ),
                CwMenuNode(
                  id: 'eq_sim_3',
                  label: '3 Unknowns',
                  action: CwMenuAction('eq_simul', '3'),
                ),
                CwMenuNode(
                  id: 'eq_sim_4',
                  label: '4 Unknowns',
                  action: CwMenuAction('eq_simul', '4'),
                ),
              ],
            ),
            CwMenuNode(
              id: 'eq_start_poly',
              label: 'Polynomial',
              rightBadge: '▸',
              children: [
                CwMenuNode(
                  id: 'eq_poly_2',
                  label: 'ax²+bx+c',
                  action: CwMenuAction('eq_poly', '2'),
                ),
                CwMenuNode(
                  id: 'eq_poly_3',
                  label: 'ax³+bx²+cx+d',
                  action: CwMenuAction('eq_poly', '3'),
                ),
                CwMenuNode(
                  id: 'eq_poly_4',
                  label: 'ax⁴+bx³+cx²+dx+e',
                  action: CwMenuAction('eq_poly', '4'),
                ),
              ],
            ),
            CwMenuNode(
              id: 'eq_start_solver',
              label: 'Solver',
              action: CwMenuAction('eq_solver_start'),
            ),
          ],
          selectedIndex: 0,
        );

      case AppMode.inequality:
        return const MenuBreadcrumbLevel(
          title: 'Polynomial',
          items: [
            CwMenuNode(
              id: 'ineq_start_d2',
              label: 'ax²+bx+c',
              rightBadge: '▸',
              children: [
                CwMenuNode(
                  id: 'in2_gt',
                  label: 'ax²+bx+c > 0',
                  action: CwMenuAction('ineq_setup', '2|>'),
                ),
                CwMenuNode(
                  id: 'in2_lt',
                  label: 'ax²+bx+c < 0',
                  action: CwMenuAction('ineq_setup', '2|<'),
                ),
                CwMenuNode(
                  id: 'in2_ge',
                  label: 'ax²+bx+c ≥ 0',
                  action: CwMenuAction('ineq_setup', '2|≥'),
                ),
                CwMenuNode(
                  id: 'in2_le',
                  label: 'ax²+bx+c ≤ 0',
                  action: CwMenuAction('ineq_setup', '2|≤'),
                ),
              ],
            ),
            CwMenuNode(
              id: 'ineq_start_d3',
              label: 'ax³+bx²+cx+d',
              rightBadge: '▸',
              children: [
                CwMenuNode(
                  id: 'in3_gt',
                  label: 'ax³+bx²+cx+d > 0',
                  action: CwMenuAction('ineq_setup', '3|>'),
                ),
                CwMenuNode(
                  id: 'in3_lt',
                  label: 'ax³+bx²+cx+d < 0',
                  action: CwMenuAction('ineq_setup', '3|<'),
                ),
                CwMenuNode(
                  id: 'in3_ge',
                  label: 'ax³+bx²+cx+d ≥ 0',
                  action: CwMenuAction('ineq_setup', '3|≥'),
                ),
                CwMenuNode(
                  id: 'in3_le',
                  label: 'ax³+bx²+cx+d ≤ 0',
                  action: CwMenuAction('ineq_setup', '3|≤'),
                ),
              ],
            ),
            CwMenuNode(
              id: 'ineq_start_d4',
              label: 'ax⁴+bx³+cx²+dx+e',
              rightBadge: '▸',
              children: [
                CwMenuNode(
                  id: 'in4_gt',
                  label: 'ax⁴+bx³+cx²+dx+e > 0',
                  action: CwMenuAction('ineq_setup', '4|>'),
                ),
                CwMenuNode(
                  id: 'in4_lt',
                  label: 'ax⁴+bx³+cx²+dx+e < 0',
                  action: CwMenuAction('ineq_setup', '4|<'),
                ),
                CwMenuNode(
                  id: 'in4_ge',
                  label: 'ax⁴+bx³+cx²+dx+e ≥ 0',
                  action: CwMenuAction('ineq_setup', '4|≥'),
                ),
                CwMenuNode(
                  id: 'in4_le',
                  label: 'ax⁴+bx³+cx²+dx+e ≤ 0',
                  action: CwMenuAction('ineq_setup', '4|≤'),
                ),
              ],
            ),
          ],
          selectedIndex: 0,
        );

      case AppMode.ratio:
        return const MenuBreadcrumbLevel(
          title: 'Select Type',
          items: [
            CwMenuNode(
              id: 'rat_start_xd',
              label: 'A : B = X : D',
              action: CwMenuAction('ratio_type', 'X_D'),
            ),
            CwMenuNode(
              id: 'rat_start_cx',
              label: 'A : B = C : X',
              action: CwMenuAction('ratio_type', 'C_X'),
            ),
          ],
          selectedIndex: 0,
        );

      case AppMode.mathBox:
        return const MenuBreadcrumbLevel(
          title: 'Math Box',
          items: [
            CwMenuNode(
              id: 'mb_start_dice',
              label: 'Dice Roll',
              action: CwMenuAction('mathbox_select', 'dice'),
            ),
            CwMenuNode(
              id: 'mb_start_coin',
              label: 'Coin Toss',
              action: CwMenuAction('mathbox_select', 'coin'),
            ),
            CwMenuNode(
              id: 'mb_start_line',
              label: 'Number Line',
              action: CwMenuAction('mathbox_select', 'line'),
            ),
            CwMenuNode(
              id: 'mb_start_circle',
              label: 'Circle',
              rightBadge: '▸',
              children: [
                CwMenuNode(
                  id: 'mb_cir_unit',
                  label: 'Unit Circle',
                  action: CwMenuAction('mathbox_select', 'unit_circle'),
                ),
                CwMenuNode(
                  id: 'mb_cir_clock',
                  label: 'Clock',
                  action: CwMenuAction('mathbox_select', 'clock'),
                ),
              ],
            ),
          ],
          selectedIndex: 0,
        );

      default:
        return null;
    }
  }

  static CwMenuNode _buildDistStartupItem(
    String distName,
    String label, {
    required bool hasList,
  }) {
    if (!hasList) {
      return CwMenuNode(
        id: 'dist_start_$distName',
        label: label,
        action: CwMenuAction('dist_select', distName),
      );
    }
    return CwMenuNode(
      id: 'dist_start_$distName',
      label: label,
      rightBadge: '▸',
      children: [
        CwMenuNode(
          id: 'dist_${distName}_list',
          label: 'List',
          action: CwMenuAction('dist_select_list', distName),
        ),
        CwMenuNode(
          id: 'dist_${distName}_var',
          label: 'Variable',
          action: CwMenuAction('dist_select', distName),
        ),
      ],
    );
  }

  /// Builds the full hierarchical `CATALOG` command tree.
  static MenuBreadcrumbLevel buildCatalogRoot(
    AppMode activeMode, {
    bool isVerifyMode = false,
  }) {
    final List<CwMenuNode> rootItems = [
      const CwMenuNode(
        id: 'cat_func_analysis',
        label: 'Func Analysis',
        rightBadge: '▸',
        children: [
          CwMenuNode(
            id: 'fn_deriv',
            label: 'Derivative (d/dx)',
            action: CwMenuAction('insert_template', 'deriv'),
          ),
          CwMenuNode(
            id: 'fn_integral',
            label: 'Integral (∫)',
            action: CwMenuAction('insert_template', 'integral'),
          ),
          CwMenuNode(
            id: 'fn_sum',
            label: 'Summation (∑)',
            action: CwMenuAction('insert_template', 'sum'),
          ),
          CwMenuNode(
            id: 'fn_prod',
            label: 'Product (∏)',
            action: CwMenuAction('insert_template', 'prod'),
          ),
          CwMenuNode(
            id: 'fn_logbase',
            label: 'Logarithm (logₐb)',
            action: CwMenuAction('insert_template', 'logbase'),
          ),
        ],
      ),
      const CwMenuNode(
        id: 'cat_probability',
        label: 'Probability',
        rightBadge: '▸',
        children: [
          CwMenuNode(
            id: 'prob_pct',
            label: '% (Percent)',
            action: CwMenuAction('insert_op', '%|%'),
          ),
          CwMenuNode(
            id: 'prob_fact',
            label: '! (Factorial)',
            action: CwMenuAction('insert_op', '!|!'),
          ),
          CwMenuNode(
            id: 'prob_npr',
            label: 'P (Permutation)',
            action: CwMenuAction('insert_op', 'P|nPr'),
          ),
          CwMenuNode(
            id: 'prob_ncr',
            label: 'C (Combination)',
            action: CwMenuAction('insert_op', 'C|nCr'),
          ),
          CwMenuNode(
            id: 'prob_ran',
            label: 'Random# (Ran#)',
            action: CwMenuAction('insert_token', 'Ran#|Ran#'),
          ),
          CwMenuNode(
            id: 'prob_ranint',
            label: 'Random Int (RanInt#)',
            action: CwMenuAction('insert_token', 'RanInt#(|RanInt('),
          ),
        ],
      ),
      const CwMenuNode(
        id: 'cat_numeric',
        label: 'Numeric Calc',
        rightBadge: '▸',
        children: [
          CwMenuNode(
            id: 'num_gcd',
            label: 'GCD (Greatest Common)',
            action: CwMenuAction('insert_token', 'GCD(|gcd('),
          ),
          CwMenuNode(
            id: 'num_lcm',
            label: 'LCM (Least Common)',
            action: CwMenuAction('insert_token', 'LCM(|lcm('),
          ),
          CwMenuNode(
            id: 'num_mod',
            label: 'Mod (Modulo)',
            action: CwMenuAction('insert_op', 'mod|mod'),
          ),
          CwMenuNode(
            id: 'num_abs',
            label: 'Absolute Value (|x|)',
            action: CwMenuAction('insert_template', 'abs'),
          ),
          CwMenuNode(
            id: 'num_int',
            label: 'Integer Part (Int)',
            action: CwMenuAction('insert_token', 'Int(|Int('),
          ),
          CwMenuNode(
            id: 'num_intg',
            label: 'Largest Integer (Intg)',
            action: CwMenuAction('insert_token', 'Intg(|Intg('),
          ),
          CwMenuNode(
            id: 'num_rnd',
            label: 'Round (Rnd)',
            action: CwMenuAction('insert_token', 'Rnd(|Rnd('),
          ),
          CwMenuNode(
            id: 'num_divr',
            label: '÷R (Quotient & Rem)',
            action: CwMenuAction('insert_op', '÷R|÷R'),
          ),
        ],
      ),
      const CwMenuNode(
        id: 'cat_angle',
        label: 'Angle/Coord/Sexa',
        rightBadge: '▸',
        children: [
          CwMenuNode(
            id: 'ang_deg',
            label: '° (Degrees)',
            action: CwMenuAction('insert_op', '°|°'),
          ),
          CwMenuNode(
            id: 'ang_rad',
            label: 'r (Radians)',
            action: CwMenuAction('insert_op', 'r|r'),
          ),
          CwMenuNode(
            id: 'ang_gra',
            label: 'g (Gradians)',
            action: CwMenuAction('insert_op', 'g|g'),
          ),
          CwMenuNode(
            id: 'ang_dms',
            label: '° \' \'\' (DMS)',
            action: CwMenuAction('insert_op', '°|°'),
          ),
          CwMenuNode(
            id: 'ang_pol',
            label: 'Pol(',
            action: CwMenuAction('insert_token', 'Pol(|Pol('),
          ),
          CwMenuNode(
            id: 'ang_rec',
            label: 'Rec(',
            action: CwMenuAction('insert_token', 'Rec(|Rec('),
          ),
        ],
      ),
      const CwMenuNode(
        id: 'cat_hyp',
        label: 'Hyperbolic/Trig',
        rightBadge: '▸',
        children: [
          CwMenuNode(
            id: 'hyp_sinh',
            label: 'sinh(',
            action: CwMenuAction('insert_token', 'sinh(|sinh('),
          ),
          CwMenuNode(
            id: 'hyp_cosh',
            label: 'cosh(',
            action: CwMenuAction('insert_token', 'cosh(|cosh('),
          ),
          CwMenuNode(
            id: 'hyp_tanh',
            label: 'tanh(',
            action: CwMenuAction('insert_token', 'tanh(|tanh('),
          ),
          CwMenuNode(
            id: 'hyp_asinh',
            label: 'sinh⁻¹(',
            action: CwMenuAction('insert_token', 'sinh⁻¹(|asinh('),
          ),
          CwMenuNode(
            id: 'hyp_acosh',
            label: 'cosh⁻¹(',
            action: CwMenuAction('insert_token', 'cosh⁻¹(|acosh('),
          ),
          CwMenuNode(
            id: 'hyp_atanh',
            label: 'tanh⁻¹(',
            action: CwMenuAction('insert_token', 'tanh⁻¹(|atanh('),
          ),
        ],
      ),
      const CwMenuNode(
        id: 'cat_eng_sym',
        label: 'Engineer Symbol',
        rightBadge: '▸',
        children: [
          CwMenuNode(
            id: 'eng_m',
            label: 'm (Milli 10⁻³)',
            action: CwMenuAction('insert_op', 'm|×10^(-3)'),
          ),
          CwMenuNode(
            id: 'eng_u',
            label: 'μ (Micro 10⁻⁶)',
            action: CwMenuAction('insert_op', 'μ|×10^(-6)'),
          ),
          CwMenuNode(
            id: 'eng_n',
            label: 'n (Nano 10⁻⁹)',
            action: CwMenuAction('insert_op', 'n|×10^(-9)'),
          ),
          CwMenuNode(
            id: 'eng_p',
            label: 'p (Pico 10⁻¹²)',
            action: CwMenuAction('insert_op', 'p|×10^(-12)'),
          ),
          CwMenuNode(
            id: 'eng_f',
            label: 'f (Femto 10⁻¹⁵)',
            action: CwMenuAction('insert_op', 'f|×10^(-15)'),
          ),
          CwMenuNode(
            id: 'eng_k',
            label: 'k (Kilo 10³)',
            action: CwMenuAction('insert_op', 'k|×10^(3)'),
          ),
          CwMenuNode(
            id: 'eng_M',
            label: 'M (Mega 10⁶)',
            action: CwMenuAction('insert_op', 'M|×10^(6)'),
          ),
          CwMenuNode(
            id: 'eng_G',
            label: 'G (Giga 10⁹)',
            action: CwMenuAction('insert_op', 'G|×10^(9)'),
          ),
          CwMenuNode(
            id: 'eng_T',
            label: 'T (Tera 10¹²)',
            action: CwMenuAction('insert_op', 'T|×10^(12)'),
          ),
          CwMenuNode(
            id: 'eng_P',
            label: 'P (Peta 10¹⁵)',
            action: CwMenuAction('insert_op', 'P|×10^(15)'),
          ),
          CwMenuNode(
            id: 'eng_E',
            label: 'E (Exa 10¹⁸)',
            action: CwMenuAction('insert_op', 'E|×10^(18)'),
          ),
        ],
      ),
      CwMenuNode(
        id: 'cat_sci_const',
        label: 'Sci Constants',
        rightBadge: '▸',
        children: [
          for (final cat in CodataCategory.values)
            CwMenuNode(
              id: 'sci_cat_${cat.name}',
              label: cat.label,
              rightBadge: '▸',
              children: [
                for (final c in CodataLibrary.byCategory(cat))
                  CwMenuNode(
                    id: 'const_${c.id}',
                    label: '${c.symbol} (${c.name})',
                    action: CwMenuAction('insert_token', '${c.symbol}|${c.id}'),
                  ),
              ],
            ),
        ],
      ),
      CwMenuNode(
        id: 'cat_unit_conv',
        label: 'Unit Convert',
        rightBadge: '▸',
        children: [
          for (final uCat in UnitCategory.values)
            CwMenuNode(
              id: 'u_cat_${uCat.name}',
              label: uCat.label,
              rightBadge: '▸',
              children: [
                for (final pair in UnitConverterEngine.byCategory(uCat)) ...[
                  CwMenuNode(
                    id: '${pair.id}_fwd',
                    label: pair.forwardToken,
                    action: CwMenuAction(
                      'insert_op',
                      '►${pair.forwardToken}|►${pair.forwardToken}',
                    ),
                  ),
                  CwMenuNode(
                    id: '${pair.id}_rev',
                    label: pair.reverseToken,
                    action: CwMenuAction(
                      'insert_op',
                      '►${pair.reverseToken}|►${pair.reverseToken}',
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    ];

    final CwMenuNode? verifyCategory = isVerifyMode
        ? const CwMenuNode(
            id: 'cat_verify',
            label: 'Verify',
            rightBadge: '▸',
            children: [
              CwMenuNode(
                id: 'ver_eq',
                label: '= (Equal)',
                action: CwMenuAction('insert_op', '=|='),
              ),
              CwMenuNode(
                id: 'ver_neq',
                label: '≠ (Not Equal)',
                action: CwMenuAction('insert_op', '≠|≠'),
              ),
              CwMenuNode(
                id: 'ver_gt',
                label: '> (Greater Than)',
                action: CwMenuAction('insert_op', '>|>'),
              ),
              CwMenuNode(
                id: 'ver_lt',
                label: '< (Less Than)',
                action: CwMenuAction('insert_op', '<|<'),
              ),
              CwMenuNode(
                id: 'ver_ge',
                label: '≥ (Greater or Equal)',
                action: CwMenuAction('insert_op', '≥|≥'),
              ),
              CwMenuNode(
                id: 'ver_le',
                label: '≤ (Less or Equal)',
                action: CwMenuAction('insert_op', '≤|≤'),
              ),
            ],
          )
        : null;

    final CwMenuNode? appSpecificCategory = switch (activeMode) {
      AppMode.complex => const CwMenuNode(
          id: 'cat_complex',
          label: 'Complex',
          rightBadge: '▸',
          children: [
            CwMenuNode(
              id: 'cmp_i',
              label: 'i (Imaginary Unit)',
              action: CwMenuAction('insert_token', 'i|i'),
            ),
            CwMenuNode(
              id: 'cmp_ang',
              label: '∠ (Polar Angle)',
              action: CwMenuAction('insert_op', '∠|∠'),
            ),
            CwMenuNode(
              id: 'cmp_abs',
              label: 'Absolute Value (Abs)',
              action: CwMenuAction('insert_token', 'Abs(|Abs('),
            ),
            CwMenuNode(
              id: 'cmp_arg',
              label: 'Argument (Arg)',
              action: CwMenuAction('insert_token', 'Arg(|Arg('),
            ),
            CwMenuNode(
              id: 'cmp_conjg',
              label: 'Conjugate (Conjg)',
              action: CwMenuAction('insert_token', 'Conjg(|Conjg('),
            ),
            CwMenuNode(
              id: 'cmp_rep',
              label: 'Real Part (ReP)',
              action: CwMenuAction('insert_token', 'ReP(|ReP('),
            ),
            CwMenuNode(
              id: 'cmp_imp',
              label: 'Imaginary Part (ImP)',
              action: CwMenuAction('insert_token', 'ImP(|ImP('),
            ),
            CwMenuNode(
              id: 'cmp_to_pol',
              label: '►r∠θ (Polar Form)',
              action: CwMenuAction('complex_format', 'polar'),
            ),
            CwMenuNode(
              id: 'cmp_to_rect',
              label: '►a+bi (Rectangular)',
              action: CwMenuAction('complex_format', 'rect'),
            ),
          ],
        ),
      AppMode.baseN => const CwMenuNode(
          id: 'cat_basen',
          label: 'Base-N Logic',
          rightBadge: '▸',
          children: [
            CwMenuNode(
              id: 'bn_and',
              label: 'AND (Bitwise)',
              action: CwMenuAction('insert_op', 'AND|AND'),
            ),
            CwMenuNode(
              id: 'bn_or',
              label: 'OR (Bitwise)',
              action: CwMenuAction('insert_op', 'OR|OR'),
            ),
            CwMenuNode(
              id: 'bn_xor',
              label: 'XOR (Bitwise)',
              action: CwMenuAction('insert_op', 'XOR|XOR'),
            ),
            CwMenuNode(
              id: 'bn_xnor',
              label: 'XNOR (Bitwise)',
              action: CwMenuAction('insert_op', 'XNOR|XNOR'),
            ),
            CwMenuNode(
              id: 'bn_not',
              label: 'Not (Bitwise NOT)',
              action: CwMenuAction('insert_token', 'Not(|Not('),
            ),
            CwMenuNode(
              id: 'bn_neg',
              label: 'Neg (Two\'s Comp)',
              action: CwMenuAction('insert_token', 'Neg(|Neg('),
            ),
            CwMenuNode(
              id: 'bn_pfx',
              label: 'Base Prefix',
              rightBadge: '▸',
              children: [
                CwMenuNode(
                  id: 'bn_pfx_d',
                  label: 'd (Decimal)',
                  action: CwMenuAction('basen_set_base', 'dec'),
                ),
                CwMenuNode(
                  id: 'bn_pfx_h',
                  label: 'h (Hexadecimal)',
                  action: CwMenuAction('basen_set_base', 'hex'),
                ),
                CwMenuNode(
                  id: 'bn_pfx_b',
                  label: 'b (Binary)',
                  action: CwMenuAction('basen_set_base', 'bin'),
                ),
                CwMenuNode(
                  id: 'bn_pfx_o',
                  label: 'o (Octal)',
                  action: CwMenuAction('basen_set_base', 'oct'),
                ),
              ],
            ),
          ],
        ),
      AppMode.matrix => const CwMenuNode(
          id: 'cat_matrix',
          label: 'Matrix',
          rightBadge: '▸',
          children: [
            CwMenuNode(
              id: 'mat_calc_sub',
              label: 'Matrix Calc',
              rightBadge: '▸',
              children: [
                CwMenuNode(
                  id: 'mc_det',
                  label: 'Determinant (Det)',
                  action: CwMenuAction('insert_token', 'Det(|Det('),
                ),
                CwMenuNode(
                  id: 'mc_trn',
                  label: 'Transpose (Trn)',
                  action: CwMenuAction('insert_token', 'Trn(|Trn('),
                ),
                CwMenuNode(
                  id: 'mc_id',
                  label: 'Identity Matrix',
                  action: CwMenuAction('insert_token', 'Identity(|Identity('),
                ),
                CwMenuNode(
                  id: 'mc_ref',
                  label: 'Row Echelon (Ref)',
                  action: CwMenuAction('insert_token', 'Ref(|Ref('),
                ),
                CwMenuNode(
                  id: 'mc_rref',
                  label: 'Reduced Echelon (Rref)',
                  action: CwMenuAction('insert_token', 'Rref(|Rref('),
                ),
                CwMenuNode(
                  id: 'mc_sq',
                  label: 'Mat² (Squared)',
                  action: CwMenuAction('insert_op', '²|²'),
                ),
                CwMenuNode(
                  id: 'mc_cb',
                  label: 'Mat³ (Cubed)',
                  action: CwMenuAction('insert_op', '³|³'),
                ),
                CwMenuNode(
                  id: 'mc_inv',
                  label: 'Mat⁻¹ (Inverse)',
                  action: CwMenuAction('insert_op', '⁻¹|⁻¹'),
                ),
              ],
            ),
            CwMenuNode(
              id: 'mat_a',
              label: 'MatA',
              action: CwMenuAction('insert_token', 'MatA|MatA'),
            ),
            CwMenuNode(
              id: 'mat_b',
              label: 'MatB',
              action: CwMenuAction('insert_token', 'MatB|MatB'),
            ),
            CwMenuNode(
              id: 'mat_c',
              label: 'MatC',
              action: CwMenuAction('insert_token', 'MatC|MatC'),
            ),
            CwMenuNode(
              id: 'mat_d',
              label: 'MatD',
              action: CwMenuAction('insert_token', 'MatD|MatD'),
            ),
            CwMenuNode(
              id: 'mat_ans',
              label: 'MatAns',
              action: CwMenuAction('insert_token', 'MatAns|MatAns'),
            ),
            CwMenuNode(
              id: 'mat_det',
              label: 'Determinant (Det)',
              action: CwMenuAction('insert_token', 'Det(|Det('),
            ),
            CwMenuNode(
              id: 'mat_trn',
              label: 'Transpose (Trn)',
              action: CwMenuAction('insert_token', 'Trn(|Trn('),
            ),
            CwMenuNode(
              id: 'mat_id',
              label: 'Identity Matrix',
              action: CwMenuAction('insert_token', 'Identity(|Identity('),
            ),
            CwMenuNode(
              id: 'mat_ref',
              label: 'Row Echelon (Ref)',
              action: CwMenuAction('insert_token', 'Ref(|Ref('),
            ),
            CwMenuNode(
              id: 'mat_rref',
              label: 'Reduced Echelon (Rref)',
              action: CwMenuAction('insert_token', 'Rref(|Rref('),
            ),
            CwMenuNode(
              id: 'mat_inv',
              label: 'Mat⁻¹ (Inverse)',
              action: CwMenuAction('insert_op', '⁻¹|⁻¹'),
            ),
          ],
        ),
      AppMode.vector => const CwMenuNode(
          id: 'cat_vector',
          label: 'Vector',
          rightBadge: '▸',
          children: [
            CwMenuNode(
              id: 'vct_a',
              label: 'VctA',
              action: CwMenuAction('insert_token', 'VctA|VctA'),
            ),
            CwMenuNode(
              id: 'vct_b',
              label: 'VctB',
              action: CwMenuAction('insert_token', 'VctB|VctB'),
            ),
            CwMenuNode(
              id: 'vct_c',
              label: 'VctC',
              action: CwMenuAction('insert_token', 'VctC|VctC'),
            ),
            CwMenuNode(
              id: 'vct_d',
              label: 'VctD',
              action: CwMenuAction('insert_token', 'VctD|VctD'),
            ),
            CwMenuNode(
              id: 'vct_ans',
              label: 'VctAns',
              action: CwMenuAction('insert_token', 'VctAns|VctAns'),
            ),
            CwMenuNode(
              id: 'vct_dot',
              label: 'Dot Product (u · v)',
              action: CwMenuAction('insert_op', '·|·'),
            ),
            CwMenuNode(
              id: 'vct_cross',
              label: 'Cross Product (u × v)',
              action: CwMenuAction('insert_op', '×|×'),
            ),
            CwMenuNode(
              id: 'vct_angle',
              label: 'Angle (Between Vcts)',
              action: CwMenuAction('insert_token', 'Angle(|Angle('),
            ),
            CwMenuNode(
              id: 'vct_unit',
              label: 'Unit Vector (UnitV)',
              action: CwMenuAction('insert_token', 'UnitV(|UnitV('),
            ),
            CwMenuNode(
              id: 'vct_abs',
              label: 'Magnitude (Abs)',
              action: CwMenuAction('insert_token', 'Abs(|Abs('),
            ),
          ],
        ),
      AppMode.statistics => const CwMenuNode(
          id: 'cat_statistics',
          label: 'Statistics',
          rightBadge: '▸',
          children: [
            CwMenuNode(
              id: 'st_cat_sum',
              label: 'Summation',
              rightBadge: '▸',
              children: [
                CwMenuNode(
                  id: 'stv_sx',
                  label: 'Σx',
                  action: CwMenuAction('insert_token', 'Σx|Σx'),
                ),
                CwMenuNode(
                  id: 'stv_sx2',
                  label: 'Σx²',
                  action: CwMenuAction('insert_token', 'Σx²|Σx²'),
                ),
                CwMenuNode(
                  id: 'stv_sy',
                  label: 'Σy',
                  action: CwMenuAction('insert_token', 'Σy|Σy'),
                ),
                CwMenuNode(
                  id: 'stv_sy2',
                  label: 'Σy²',
                  action: CwMenuAction('insert_token', 'Σy²|Σy²'),
                ),
                CwMenuNode(
                  id: 'stv_sxy',
                  label: 'Σxy',
                  action: CwMenuAction('insert_token', 'Σxy|Σxy'),
                ),
                CwMenuNode(
                  id: 'stv_sx3',
                  label: 'Σx³',
                  action: CwMenuAction('insert_token', 'Σx³|Σx³'),
                ),
                CwMenuNode(
                  id: 'stv_sx4',
                  label: 'Σx⁴',
                  action: CwMenuAction('insert_token', 'Σx⁴|Σx⁴'),
                ),
                CwMenuNode(
                  id: 'stv_sx2y',
                  label: 'Σx²y',
                  action: CwMenuAction('insert_token', 'Σx²y|Σx²y'),
                ),
              ],
            ),
            CwMenuNode(
              id: 'st_cat_var',
              label: 'Variable',
              rightBadge: '▸',
              children: [
                CwMenuNode(
                  id: 'stv_meanx',
                  label: 'x̄ (Mean x)',
                  action: CwMenuAction('insert_token', 'x̄|x̄'),
                ),
                CwMenuNode(
                  id: 'stv_sigx',
                  label: 'σx (Pop StdDev x)',
                  action: CwMenuAction('insert_token', 'σx|σx'),
                ),
                CwMenuNode(
                  id: 'stv_sx_s',
                  label: 'sx (Sample StdDev x)',
                  action: CwMenuAction('insert_token', 'sx|sx'),
                ),
                CwMenuNode(
                  id: 'stv_n',
                  label: 'n (Count)',
                  action: CwMenuAction('insert_token', 'n|n'),
                ),
                CwMenuNode(
                  id: 'stv_meany',
                  label: 'ȳ (Mean y)',
                  action: CwMenuAction('insert_token', 'ȳ|ȳ'),
                ),
                CwMenuNode(
                  id: 'stv_sigy',
                  label: 'σy (Pop StdDev y)',
                  action: CwMenuAction('insert_token', 'σy|σy'),
                ),
                CwMenuNode(
                  id: 'stv_sy_s',
                  label: 'sy (Sample StdDev y)',
                  action: CwMenuAction('insert_token', 'sy|sy'),
                ),
              ],
            ),
            CwMenuNode(
              id: 'st_cat_mmq',
              label: 'Min/Max/Quartile',
              rightBadge: '▸',
              children: [
                CwMenuNode(
                  id: 'stv_minx',
                  label: 'min(x)',
                  action: CwMenuAction('insert_token', 'min(x)|min(x)'),
                ),
                CwMenuNode(
                  id: 'stv_q1',
                  label: 'Q₁ (First Quartile)',
                  action: CwMenuAction('insert_token', 'Q₁|Q1'),
                ),
                CwMenuNode(
                  id: 'stv_med',
                  label: 'Med (Median)',
                  action: CwMenuAction('insert_token', 'Med|Med'),
                ),
                CwMenuNode(
                  id: 'stv_q3',
                  label: 'Q₃ (Third Quartile)',
                  action: CwMenuAction('insert_token', 'Q₃|Q3'),
                ),
                CwMenuNode(
                  id: 'stv_maxx',
                  label: 'max(x)',
                  action: CwMenuAction('insert_token', 'max(x)|max(x)'),
                ),
                CwMenuNode(
                  id: 'stv_miny',
                  label: 'min(y)',
                  action: CwMenuAction('insert_token', 'min(y)|min(y)'),
                ),
                CwMenuNode(
                  id: 'stv_maxy',
                  label: 'max(y)',
                  action: CwMenuAction('insert_token', 'max(y)|max(y)'),
                ),
              ],
            ),
            CwMenuNode(
              id: 'st_cat_reg',
              label: 'Regression',
              rightBadge: '▸',
              children: [
                CwMenuNode(
                  id: 'stv_a',
                  label: 'a (Intercept)',
                  action: CwMenuAction('insert_token', 'a|a'),
                ),
                CwMenuNode(
                  id: 'stv_b',
                  label: 'b (Slope)',
                  action: CwMenuAction('insert_token', 'b|b'),
                ),
                CwMenuNode(
                  id: 'stv_c',
                  label: 'c (Quadratic Coeff)',
                  action: CwMenuAction('insert_token', 'c|c'),
                ),
                CwMenuNode(
                  id: 'stv_r',
                  label: 'r (Correlation)',
                  action: CwMenuAction('insert_token', 'r|r'),
                ),
                CwMenuNode(
                  id: 'stv_xhat',
                  label: 'x̂ (Estimated x)',
                  action: CwMenuAction('insert_token', 'x̂|x̂'),
                ),
                CwMenuNode(
                  id: 'stv_xhat1',
                  label: 'x̂₁',
                  action: CwMenuAction('insert_token', 'x̂₁|x̂₁'),
                ),
                CwMenuNode(
                  id: 'stv_xhat2',
                  label: 'x̂₂',
                  action: CwMenuAction('insert_token', 'x̂₂|x̂₂'),
                ),
                CwMenuNode(
                  id: 'stv_yhat',
                  label: 'ŷ (Estimated y)',
                  action: CwMenuAction('insert_token', 'ŷ|ŷ'),
                ),
              ],
            ),
            CwMenuNode(
              id: 'st_cat_ndist',
              label: 'Normal Dist',
              rightBadge: '▸',
              children: [
                CwMenuNode(
                  id: 'stv_np',
                  label: 'P(t) (Lower Tail)',
                  action: CwMenuAction('insert_token', 'P(|P('),
                ),
                CwMenuNode(
                  id: 'stv_nq',
                  label: 'Q(t) (Center 0 to t)',
                  action: CwMenuAction('insert_token', 'Q(|Q('),
                ),
                CwMenuNode(
                  id: 'stv_nr',
                  label: 'R(t) (Upper Tail)',
                  action: CwMenuAction('insert_token', 'R(|R('),
                ),
                CwMenuNode(
                  id: 'stv_nt',
                  label: '►t (Standard Variate)',
                  action: CwMenuAction('insert_op', '►t|►t'),
                ),
              ],
            ),
          ],
        ),
      AppMode.spreadsheet => const CwMenuNode(
          id: 'cat_sheet',
          label: 'Spreadsheet',
          rightBadge: '▸',
          children: [
            CwMenuNode(
              id: 'sh_grab',
              label: 'Grab (Cell Ref)',
              action: CwMenuAction('sheet_insert', '=A1'),
            ),
            CwMenuNode(
              id: 'sh_dollar',
              label: '\$ (Absolute Ref)',
              action: CwMenuAction('sheet_insert', '=\$A\$1'),
            ),
            CwMenuNode(
              id: 'sh_colon',
              label: ': (Range)',
              action: CwMenuAction('sheet_insert', '=Sum(A1:A5)'),
            ),
            CwMenuNode(
              id: 'sh_min',
              label: 'Min(A1:A5)',
              action: CwMenuAction('sheet_insert', '=Min(A1:B1)'),
            ),
            CwMenuNode(
              id: 'sh_max',
              label: 'Max(A1:A5)',
              action: CwMenuAction('sheet_insert', '=Max(A1:B1)'),
            ),
            CwMenuNode(
              id: 'sh_mean',
              label: 'Mean(A1:A5)',
              action: CwMenuAction('sheet_insert', '=Mean(A1:B1)'),
            ),
            CwMenuNode(
              id: 'sh_sum',
              label: 'Sum(A1:A5)',
              action: CwMenuAction('sheet_insert', '=Sum(A1:B1)'),
            ),
          ],
        ),
      _ => null,
    };

    return MenuBreadcrumbLevel(
      title: 'CATALOG',
      items: [
        ?verifyCategory,
        ?appSpecificCategory,
        ...rootItems,
      ],
      selectedIndex: 0,
    );
  }

  /// Builds the `VARIABLE` inspector drawer with live register values and
  /// sub-menus for `Recall`, `Store (Ans → Var)`, and `Edit Value (Var =)`.
  static MenuBreadcrumbLevel buildVariableDrawer(
    Map<String, String> variables,
  ) {
    const registers = ['A', 'B', 'C', 'D', 'E', 'F', 'x', 'y', 'z'];
    final List<CwMenuNode> items = [
      for (final reg in registers)
        CwMenuNode(
          id: 'var_$reg',
          label: '$reg = ${variables[reg] ?? "0"}',
          rightBadge: '▸',
          children: [
            CwMenuNode(
              id: 'var_${reg}_recall',
              label: 'Recall ($reg)',
              action: CwMenuAction('var_recall', reg),
            ),
            CwMenuNode(
              id: 'var_${reg}_store',
              label: 'Store (Ans → $reg)',
              action: CwMenuAction('var_store_ans', reg),
            ),
            CwMenuNode(
              id: 'var_${reg}_edit',
              label: 'Edit ($reg = ...)',
              action: CwMenuAction('var_edit_prompt', reg),
            ),
          ],
        ),
    ];
    return MenuBreadcrumbLevel(
      title: 'VARIABLE',
      items: items,
      selectedIndex: 0,
    );
  }

  /// Builds the `FUNCTION` manager menu (`f(x)`, `g(x)`, `Define f(x)`, `Define g(x)`).
  static MenuBreadcrumbLevel buildFunctionMenu({
    required String definedF,
    required String definedG,
  }) {
    final String fBadge = definedF.isNotEmpty ? '●' : '';
    final String gBadge = definedG.isNotEmpty ? '●' : '';
    return MenuBreadcrumbLevel(
      title: 'FUNCTION',
      items: [
        CwMenuNode(
          id: 'fn_use_f',
          label: 'f(x)',
          rightBadge: fBadge,
          action: const CwMenuAction('fn_insert', 'f('),
        ),
        CwMenuNode(
          id: 'fn_use_g',
          label: 'g(x)',
          rightBadge: gBadge,
          action: const CwMenuAction('fn_insert', 'g('),
        ),
        CwMenuNode(
          id: 'fn_def_f',
          label: 'Define f(x)',
          rightBadge: definedF.isNotEmpty ? '[$definedF]' : null,
          action: const CwMenuAction('fn_define', 'f'),
        ),
        CwMenuNode(
          id: 'fn_def_g',
          label: 'Define g(x)',
          rightBadge: definedG.isNotEmpty ? '[$definedG]' : null,
          action: const CwMenuAction('fn_define', 'g'),
        ),
      ],
      selectedIndex: 0,
    );
  }

  /// Builds the `FORMAT` output representation switcher menu.
  static MenuBreadcrumbLevel buildFormatMenu() {
    return const MenuBreadcrumbLevel(
      title: 'FORMAT',
      items: [
        CwMenuNode(
          id: 'fmt_std',
          label: 'Standard',
          action: CwMenuAction('format_select', 'standard'),
        ),
        CwMenuNode(
          id: 'fmt_dec',
          label: 'Decimal',
          action: CwMenuAction('format_select', 'decimal'),
        ),
        CwMenuNode(
          id: 'fmt_rec',
          label: 'Recurring Decimal',
          action: CwMenuAction('format_select', 'recurring'),
        ),
        CwMenuNode(
          id: 'fmt_imp',
          label: 'Improper Fraction',
          action: CwMenuAction('format_select', 'improper'),
        ),
        CwMenuNode(
          id: 'fmt_mix',
          label: 'Mixed Fraction',
          action: CwMenuAction('format_select', 'mixed'),
        ),
        CwMenuNode(
          id: 'fmt_eng',
          label: 'ENG Notation',
          action: CwMenuAction('format_select', 'eng'),
        ),
        CwMenuNode(
          id: 'fmt_dms',
          label: 'Sexagesimal (DMS)',
          action: CwMenuAction('format_select', 'dms'),
        ),
        CwMenuNode(
          id: 'fmt_fact',
          label: 'Prime Factor (FACT)',
          action: CwMenuAction('format_select', 'fact'),
        ),
      ],
      selectedIndex: 0,
    );
  }

  /// Builds the context-aware `TOOLS` menu for the active app mode.
  static MenuBreadcrumbLevel buildToolsMenu({
    required AppMode activeMode,
    required bool isVerifyMode,
  }) {
    final List<CwMenuNode> items = switch (activeMode) {
      AppMode.calculate => [
          const CwMenuNode(
            id: 'tools_undo',
            label: 'Undo',
            action: CwMenuAction('tools_undo'),
          ),
          CwMenuNode(
            id: 'tools_verify',
            label: isVerifyMode ? 'Verify OFF' : 'Verify ON',
            rightBadge: isVerifyMode ? '●' : '○',
            action: const CwMenuAction('tools_toggle_verify'),
          ),
          const CwMenuNode(
            id: 'tools_clear_hist',
            label: 'Clear History',
            action: CwMenuAction('tools_clear_history'),
          ),
        ],
      AppMode.complex => const [
          CwMenuNode(
            id: 'cmp_rect',
            label: 'Rectangular (a+bi)',
            action: CwMenuAction('complex_format', 'rect'),
          ),
          CwMenuNode(
            id: 'cmp_pol',
            label: 'Polar (r∠θ)',
            action: CwMenuAction('complex_format', 'polar'),
          ),
          CwMenuNode(
            id: 'tools_clear_hist',
            label: 'Clear History',
            action: CwMenuAction('tools_clear_history'),
          ),
        ],
      AppMode.baseN => const [
          CwMenuNode(
            id: 'bn_dec',
            label: 'Decimal (DEC)',
            action: CwMenuAction('basen_set_base', 'dec'),
          ),
          CwMenuNode(
            id: 'bn_hex',
            label: 'Hexadecimal (HEX)',
            action: CwMenuAction('basen_set_base', 'hex'),
          ),
          CwMenuNode(
            id: 'bn_bin',
            label: 'Binary (BIN)',
            action: CwMenuAction('basen_set_base', 'bin'),
          ),
          CwMenuNode(
            id: 'bn_oct',
            label: 'Octal (OCT)',
            action: CwMenuAction('basen_set_base', 'oct'),
          ),
        ],
      AppMode.matrix => const [
          CwMenuNode(
            id: 'mat_calc_mode',
            label: 'Matrix Calc Screen',
            action: CwMenuAction('matrix_view', 'calc'),
          ),
          CwMenuNode(
            id: 'mat_edit_a',
            label: 'Edit MatA',
            action: CwMenuAction('matrix_edit', 'MatA'),
          ),
          CwMenuNode(
            id: 'mat_edit_b',
            label: 'Edit MatB',
            action: CwMenuAction('matrix_edit', 'MatB'),
          ),
          CwMenuNode(
            id: 'mat_edit_c',
            label: 'Edit MatC',
            action: CwMenuAction('matrix_edit', 'MatC'),
          ),
          CwMenuNode(
            id: 'mat_edit_d',
            label: 'Edit MatD',
            action: CwMenuAction('matrix_edit', 'MatD'),
          ),
          CwMenuNode(
            id: 'mat_resize',
            label: 'Dimensions (m×n)',
            rightBadge: '▸',
            children: [
              CwMenuNode(
                id: 'dim_2x2',
                label: '2 × 2',
                action: CwMenuAction('matrix_resize', '2x2'),
              ),
              CwMenuNode(
                id: 'dim_3x3',
                label: '3 × 3',
                action: CwMenuAction('matrix_resize', '3x3'),
              ),
              CwMenuNode(
                id: 'dim_4x4',
                label: '4 × 4',
                action: CwMenuAction('matrix_resize', '4x4'),
              ),
            ],
          ),
        ],
      AppMode.vector => const [
          CwMenuNode(
            id: 'vct_calc_mode',
            label: 'Vector Calc Screen',
            action: CwMenuAction('vector_view', 'calc'),
          ),
          CwMenuNode(
            id: 'vct_edit_a',
            label: 'Edit VctA',
            action: CwMenuAction('vector_edit', 'VctA'),
          ),
          CwMenuNode(
            id: 'vct_edit_b',
            label: 'Edit VctB',
            action: CwMenuAction('vector_edit', 'VctB'),
          ),
          CwMenuNode(
            id: 'vct_edit_c',
            label: 'Edit VctC',
            action: CwMenuAction('vector_edit', 'VctC'),
          ),
          CwMenuNode(
            id: 'vct_edit_d',
            label: 'Edit VctD',
            action: CwMenuAction('vector_edit', 'VctD'),
          ),
          CwMenuNode(
            id: 'vct_dim_2d',
            label: 'Set 2D Vector',
            action: CwMenuAction('vector_resize', '2'),
          ),
          CwMenuNode(
            id: 'vct_dim_3d',
            label: 'Set 3D Vector',
            action: CwMenuAction('vector_resize', '3'),
          ),
        ],
      AppMode.statistics => const [
          CwMenuNode(
            id: 'stat_compute',
            label: 'Stat Summary Results',
            action: CwMenuAction('stat_action', 'summary'),
          ),
          CwMenuNode(
            id: 'stat_calc_scr',
            label: 'Statistics Calc',
            action: CwMenuAction('stat_action', 'calc_screen'),
          ),
          CwMenuNode(
            id: 'stat_table',
            label: 'Data Table Editor',
            action: CwMenuAction('stat_action', 'table'),
          ),
          CwMenuNode(
            id: 'stat_type',
            label: 'Select Type',
            rightBadge: '▸',
            children: [
              CwMenuNode(
                id: 'st_1var',
                label: '1-Variable',
                action: CwMenuAction('stat_model', 'oneVar'),
              ),
              CwMenuNode(
                id: 'st_lin',
                label: 'y = a + bx',
                action: CwMenuAction('stat_model', 'linear'),
              ),
              CwMenuNode(
                id: 'st_quad',
                label: 'y = a + bx + cx²',
                action: CwMenuAction('stat_model', 'quadratic'),
              ),
              CwMenuNode(
                id: 'st_log',
                label: 'y = a + b·ln(x)',
                action: CwMenuAction('stat_model', 'logarithmic'),
              ),
              CwMenuNode(
                id: 'st_eexp',
                label: 'y = a·e^(bx)',
                action: CwMenuAction('stat_model', 'eExponential'),
              ),
              CwMenuNode(
                id: 'st_abexp',
                label: 'y = a·b^x',
                action: CwMenuAction('stat_model', 'abExponential'),
              ),
              CwMenuNode(
                id: 'st_pow',
                label: 'y = a·x^b',
                action: CwMenuAction('stat_model', 'power'),
              ),
              CwMenuNode(
                id: 'st_inv',
                label: 'y = a + b/x',
                action: CwMenuAction('stat_model', 'inverse'),
              ),
            ],
          ),
          CwMenuNode(
            id: 'stat_sort_asc',
            label: 'Sort Ascending',
            action: CwMenuAction('stat_action', 'sort_asc'),
          ),
          CwMenuNode(
            id: 'stat_sort_desc',
            label: 'Sort Descending',
            action: CwMenuAction('stat_action', 'sort_desc'),
          ),
          CwMenuNode(
            id: 'stat_clear',
            label: 'Delete All',
            action: CwMenuAction('stat_action', 'clear'),
          ),
        ],
      AppMode.distribution => [
          _buildDistStartupItem('binomialPd', 'Binomial PD', hasList: true),
          _buildDistStartupItem('binomialCd', 'Binomial CD', hasList: true),
          _buildDistStartupItem('normalPd', 'Normal PD', hasList: true),
          _buildDistStartupItem('normalCd', 'Normal CD', hasList: false),
          _buildDistStartupItem(
            'inverseNormal',
            'Inverse Normal',
            hasList: false,
          ),
          _buildDistStartupItem('poissonPd', 'Poisson PD', hasList: true),
          _buildDistStartupItem('poissonCd', 'Poisson CD', hasList: true),
        ],
      AppMode.table => const [
          CwMenuNode(
            id: 'tbl_gen',
            label: 'Generate Table',
            action: CwMenuAction('table_action', 'generate'),
          ),
          CwMenuNode(
            id: 'tbl_def_f',
            label: 'Define f(x)',
            action: CwMenuAction('fn_define', 'f'),
          ),
          CwMenuNode(
            id: 'tbl_def_g',
            label: 'Define g(x)',
            action: CwMenuAction('fn_define', 'g'),
          ),
        ],
      AppMode.spreadsheet => const [
          CwMenuNode(
            id: 'sh_clear',
            label: 'Delete All',
            action: CwMenuAction('sheet_action', 'clear'),
          ),
          CwMenuNode(
            id: 'sh_sum',
            label: 'Insert =Sum(A1:A5)',
            action: CwMenuAction('sheet_insert', '=Sum(A1:A5)'),
          ),
          CwMenuNode(
            id: 'sh_mean',
            label: 'Insert =Mean(A1:A5)',
            action: CwMenuAction('sheet_insert', '=Mean(A1:A5)'),
          ),
        ],
      AppMode.equation => const [
          CwMenuNode(
            id: 'eq_solve',
            label: 'Solve Equation',
            action: CwMenuAction('eq_action', 'solve'),
          ),
          CwMenuNode(
            id: 'eq_simul',
            label: 'Simul Equation',
            rightBadge: '▸',
            children: [
              CwMenuNode(
                id: 'sim_2',
                label: '2 Unknowns',
                action: CwMenuAction('eq_simul', '2'),
              ),
              CwMenuNode(
                id: 'sim_3',
                label: '3 Unknowns',
                action: CwMenuAction('eq_simul', '3'),
              ),
              CwMenuNode(
                id: 'sim_4',
                label: '4 Unknowns',
                action: CwMenuAction('eq_simul', '4'),
              ),
            ],
          ),
          CwMenuNode(
            id: 'eq_poly',
            label: 'Polynomial',
            rightBadge: '▸',
            children: [
              CwMenuNode(
                id: 'poly_2',
                label: 'ax²+bx+c',
                action: CwMenuAction('eq_poly', '2'),
              ),
              CwMenuNode(
                id: 'poly_3',
                label: 'ax³+bx²+cx+d',
                action: CwMenuAction('eq_poly', '3'),
              ),
              CwMenuNode(
                id: 'poly_4',
                label: 'ax⁴+bx³+cx²+dx+e',
                action: CwMenuAction('eq_poly', '4'),
              ),
            ],
          ),
          CwMenuNode(
            id: 'eq_solver_tool',
            label: 'Solver (LHS = RHS)',
            action: CwMenuAction('eq_solver_start'),
          ),
        ],
      AppMode.inequality => const [
          CwMenuNode(
            id: 'ineq_solve',
            label: 'Solve Inequality',
            action: CwMenuAction('ineq_action', 'solve'),
          ),
          CwMenuNode(
            id: 'ineq_deg',
            label: 'Select Degree',
            rightBadge: '▸',
            children: [
              CwMenuNode(
                id: 'ind_2',
                label: 'ax²+bx+c',
                action: CwMenuAction('ineq_deg', '2'),
              ),
              CwMenuNode(
                id: 'ind_3',
                label: 'ax³+bx²+cx+d',
                action: CwMenuAction('ineq_deg', '3'),
              ),
              CwMenuNode(
                id: 'ind_4',
                label: 'ax⁴+bx³+cx²+dx+e',
                action: CwMenuAction('ineq_deg', '4'),
              ),
            ],
          ),
          CwMenuNode(
            id: 'ineq_sign',
            label: 'Orientation (> < ≥ ≤)',
            rightBadge: '▸',
            children: [
              CwMenuNode(
                id: 'ins_gt',
                label: 'P(x) > 0',
                action: CwMenuAction('ineq_sign', '>'),
              ),
              CwMenuNode(
                id: 'ins_lt',
                label: 'P(x) < 0',
                action: CwMenuAction('ineq_sign', '<'),
              ),
              CwMenuNode(
                id: 'ins_ge',
                label: 'P(x) ≥ 0',
                action: CwMenuAction('ineq_sign', '≥'),
              ),
              CwMenuNode(
                id: 'ins_le',
                label: 'P(x) ≤ 0',
                action: CwMenuAction('ineq_sign', '≤'),
              ),
            ],
          ),
        ],
      AppMode.ratio => const [
          CwMenuNode(
            id: 'rat_solve',
            label: 'Solve Ratio',
            action: CwMenuAction('ratio_action', 'solve'),
          ),
          CwMenuNode(
            id: 'rat_t1',
            label: 'A : B = X : D',
            action: CwMenuAction('ratio_type', 'X_D'),
          ),
          CwMenuNode(
            id: 'rat_t2',
            label: 'A : B = C : X',
            action: CwMenuAction('ratio_type', 'C_X'),
          ),
        ],
      AppMode.mathBox => const [
          CwMenuNode(
            id: 'mb_dice',
            label: 'Dice Roll',
            action: CwMenuAction('mathbox_select', 'dice'),
          ),
          CwMenuNode(
            id: 'mb_coin',
            label: 'Coin Toss',
            action: CwMenuAction('mathbox_select', 'coin'),
          ),
          CwMenuNode(
            id: 'mb_line',
            label: 'Number Line',
            action: CwMenuAction('mathbox_select', 'line'),
          ),
          CwMenuNode(
            id: 'mb_circle',
            label: 'Circle',
            rightBadge: '▸',
            children: [
              CwMenuNode(
                id: 'mb_unit_cir',
                label: 'Unit Circle',
                action: CwMenuAction('mathbox_select', 'unit_circle'),
              ),
              CwMenuNode(
                id: 'mb_clock_cir',
                label: 'Clock',
                action: CwMenuAction('mathbox_select', 'clock'),
              ),
            ],
          ),
          CwMenuNode(
            id: 'mb_view_list',
            label: 'Trial List View',
            action: CwMenuAction('mathbox_view', 'list'),
          ),
          CwMenuNode(
            id: 'mb_view_freq',
            label: 'Relative Freq View',
            action: CwMenuAction('mathbox_view', 'freq'),
          ),
        ],
    };

    return MenuBreadcrumbLevel(
      title: 'TOOLS (${activeMode.shortBadge})',
      items: items,
      selectedIndex: 0,
    );
  }

  /// Builds the hierarchical `SETTINGS` menu (`Calc Settings`, `System Settings`, `Reset`).
  static MenuBreadcrumbLevel buildSettingsRoot({
    required InputOutputMode ioMode,
    required AngleUnit angleUnit,
    required NumberFormatMode numberFormat,
    required int formatDigits,
    required bool engSymbolOn,
    required FractionResultPreference fractionPref,
    required int lcdContrast,
    required bool showPixelGrid,
    bool lcdInverted = false,
    int qrVersion = 3,
    bool keyClickSoundOn = false,
    bool hapticFeedbackOn = true,
    bool complexPolarDisplay = false,
    bool statFreqOn = true,
    bool decimalMarkComma = false,
    bool digitSeparatorOn = false,
    bool smallMultiLineFont = false,
    int autoPowerOffMinutes = 10,
  }) {
    return MenuBreadcrumbLevel(
      title: 'SETTINGS',
      items: [
        CwMenuNode(
          id: 'set_calc',
          label: 'Calc Settings',
          rightBadge: '▸',
          children: [
            CwMenuNode(
              id: 'set_io',
              label: 'Input/Output',
              rightBadge: '▸',
              children: [
                CwMenuNode(
                  id: 'io_mm',
                  label: 'MathI/MathO',
                  rightBadge: ioMode == InputOutputMode.mathIMathO ? '●' : '○',
                  action: const CwMenuAction('set_io', 'mathIMathO'),
                ),
                CwMenuNode(
                  id: 'io_md',
                  label: 'MathI/DecimalO',
                  rightBadge:
                      ioMode == InputOutputMode.mathIDecimalO ? '●' : '○',
                  action: const CwMenuAction('set_io', 'mathIDecimalO'),
                ),
                CwMenuNode(
                  id: 'io_ll',
                  label: 'LineI/LineO',
                  rightBadge: ioMode == InputOutputMode.lineILineO ? '●' : '○',
                  action: const CwMenuAction('set_io', 'lineILineO'),
                ),
                CwMenuNode(
                  id: 'io_ld',
                  label: 'LineI/DecimalO',
                  rightBadge:
                      ioMode == InputOutputMode.lineIDecimalO ? '●' : '○',
                  action: const CwMenuAction('set_io', 'lineIDecimalO'),
                ),
              ],
            ),
            CwMenuNode(
              id: 'set_angle',
              label: 'Angle Unit',
              rightBadge: '▸',
              children: [
                CwMenuNode(
                  id: 'ang_d',
                  label: 'Degree',
                  rightBadge: angleUnit == AngleUnit.degree ? '●' : '○',
                  action: const CwMenuAction('set_angle', 'degree'),
                ),
                CwMenuNode(
                  id: 'ang_r',
                  label: 'Radian',
                  rightBadge: angleUnit == AngleUnit.radian ? '●' : '○',
                  action: const CwMenuAction('set_angle', 'radian'),
                ),
                CwMenuNode(
                  id: 'ang_g',
                  label: 'Gradian',
                  rightBadge: angleUnit == AngleUnit.gradian ? '●' : '○',
                  action: const CwMenuAction('set_angle', 'gradian'),
                ),
              ],
            ),
            CwMenuNode(
              id: 'set_numfmt',
              label: 'Number Format',
              rightBadge: '▸',
              children: [
                CwMenuNode(
                  id: 'fmt_fix',
                  label: 'Fix (0-9)',
                  rightBadge: '▸',
                  children: [
                    for (int d = 0; d <= 9; d++)
                      CwMenuNode(
                        id: 'fix_$d',
                        label: 'Fix $d',
                        rightBadge: (numberFormat == NumberFormatMode.fix &&
                                formatDigits == d)
                            ? '●'
                            : '○',
                        action: CwMenuAction('set_fix', '$d'),
                      ),
                  ],
                ),
                CwMenuNode(
                  id: 'fmt_sci',
                  label: 'Sci (0-9)',
                  rightBadge: '▸',
                  children: [
                    for (int d = 0; d <= 9; d++)
                      CwMenuNode(
                        id: 'sci_$d',
                        label: 'Sci $d',
                        rightBadge: (numberFormat == NumberFormatMode.sci &&
                                formatDigits == d)
                            ? '●'
                            : '○',
                        action: CwMenuAction('set_sci', '$d'),
                      ),
                  ],
                ),
                CwMenuNode(
                  id: 'fmt_norm',
                  label: 'Norm',
                  rightBadge: '▸',
                  children: [
                    CwMenuNode(
                      id: 'norm_1',
                      label: 'Norm 1',
                      rightBadge:
                          numberFormat == NumberFormatMode.norm1 ? '●' : '○',
                      action: const CwMenuAction('set_norm', '1'),
                    ),
                    CwMenuNode(
                      id: 'norm_2',
                      label: 'Norm 2',
                      rightBadge:
                          numberFormat == NumberFormatMode.norm2 ? '●' : '○',
                      action: const CwMenuAction('set_norm', '2'),
                    ),
                  ],
                ),
              ],
            ),
            CwMenuNode(
              id: 'set_eng_sym',
              label: 'Engineer Symbol',
              rightBadge: '▸',
              children: [
                CwMenuNode(
                  id: 'eng_on',
                  label: 'On',
                  rightBadge: engSymbolOn ? '●' : '○',
                  action: const CwMenuAction('set_eng_sym', 'on'),
                ),
                CwMenuNode(
                  id: 'eng_off',
                  label: 'Off',
                  rightBadge: !engSymbolOn ? '●' : '○',
                  action: const CwMenuAction('set_eng_sym', 'off'),
                ),
              ],
            ),
            CwMenuNode(
              id: 'set_frac_res',
              label: 'Fraction Result',
              rightBadge: '▸',
              children: [
                CwMenuNode(
                  id: 'frac_mixed',
                  label: 'Mixed Fraction',
                  rightBadge:
                      fractionPref == FractionResultPreference.mixed ? '●' : '○',
                  action: const CwMenuAction('set_frac_pref', 'mixed'),
                ),
                CwMenuNode(
                  id: 'frac_improper',
                  label: 'Improper Fraction',
                  rightBadge:
                      fractionPref == FractionResultPreference.improper
                          ? '●'
                          : '○',
                  action: const CwMenuAction('set_frac_pref', 'improper'),
                ),
              ],
            ),
            CwMenuNode(
              id: 'set_cmplx_res',
              label: 'Complex Result',
              rightBadge: '▸',
              children: [
                CwMenuNode(
                  id: 'cmplx_rect',
                  label: 'a+bi',
                  rightBadge: !complexPolarDisplay ? '●' : '○',
                  action: const CwMenuAction('complex_format', 'rect'),
                ),
                CwMenuNode(
                  id: 'cmplx_pol',
                  label: 'r∠θ',
                  rightBadge: complexPolarDisplay ? '●' : '○',
                  action: const CwMenuAction('complex_format', 'polar'),
                ),
              ],
            ),
            CwMenuNode(
              id: 'set_stat_disp',
              label: 'Statistical Disp',
              rightBadge: '▸',
              children: [
                CwMenuNode(
                  id: 'stat_freq_on',
                  label: 'On',
                  rightBadge: statFreqOn ? '●' : '○',
                  action: const CwMenuAction('set_stat_freq', 'on'),
                ),
                CwMenuNode(
                  id: 'stat_freq_off',
                  label: 'Off',
                  rightBadge: !statFreqOn ? '●' : '○',
                  action: const CwMenuAction('set_stat_freq', 'off'),
                ),
              ],
            ),
            CwMenuNode(
              id: 'set_dec_mark',
              label: 'Decimal Mark',
              rightBadge: '▸',
              children: [
                CwMenuNode(
                  id: 'dec_dot',
                  label: 'Dot (.)',
                  rightBadge: !decimalMarkComma ? '●' : '○',
                  action: const CwMenuAction('set_dec_mark', 'dot'),
                ),
                CwMenuNode(
                  id: 'dec_comma',
                  label: 'Comma (,)',
                  rightBadge: decimalMarkComma ? '●' : '○',
                  action: const CwMenuAction('set_dec_mark', 'comma'),
                ),
              ],
            ),
            CwMenuNode(
              id: 'set_digit_sep',
              label: 'Digit Separator',
              rightBadge: '▸',
              children: [
                CwMenuNode(
                  id: 'sep_on',
                  label: 'On',
                  rightBadge: digitSeparatorOn ? '●' : '○',
                  action: const CwMenuAction('set_digit_sep', 'on'),
                ),
                CwMenuNode(
                  id: 'sep_off',
                  label: 'Off',
                  rightBadge: !digitSeparatorOn ? '●' : '○',
                  action: const CwMenuAction('set_digit_sep', 'off'),
                ),
              ],
            ),
          ],
        ),
        CwMenuNode(
          id: 'set_system',
          label: 'System Settings',
          rightBadge: '▸',
          children: [
            CwMenuNode(
              id: 'sys_contrast',
              label: 'Contrast (Lv $lcdContrast)',
              rightBadge: '▸',
              children: const [
                CwMenuNode(
                  id: 'con_light',
                  label: 'Light (Level 4)',
                  action: CwMenuAction('set_contrast', '4'),
                ),
                CwMenuNode(
                  id: 'con_norm',
                  label: 'Normal (Level 8)',
                  action: CwMenuAction('set_contrast', '8'),
                ),
                CwMenuNode(
                  id: 'con_dark',
                  label: 'Dark (Level 13)',
                  action: CwMenuAction('set_contrast', '13'),
                ),
              ],
            ),
            CwMenuNode(
              id: 'sys_autopower',
              label: 'Auto Power Off',
              rightBadge: '▸',
              children: [
                CwMenuNode(
                  id: 'apo_10',
                  label: '10 Min',
                  rightBadge: autoPowerOffMinutes == 10 ? '●' : '○',
                  action: const CwMenuAction('set_auto_power', '10'),
                ),
                CwMenuNode(
                  id: 'apo_60',
                  label: '60 Min',
                  rightBadge: autoPowerOffMinutes == 60 ? '●' : '○',
                  action: const CwMenuAction('set_auto_power', '60'),
                ),
              ],
            ),
            CwMenuNode(
              id: 'sys_mlfont',
              label: 'MultiLine Font',
              rightBadge: '▸',
              children: [
                CwMenuNode(
                  id: 'mlf_norm',
                  label: 'Normal Font',
                  rightBadge: !smallMultiLineFont ? '●' : '○',
                  action: const CwMenuAction('set_multiline_font', 'normal'),
                ),
                CwMenuNode(
                  id: 'mlf_small',
                  label: 'Small Font',
                  rightBadge: smallMultiLineFont ? '●' : '○',
                  action: const CwMenuAction('set_multiline_font', 'small'),
                ),
              ],
            ),
            CwMenuNode(
              id: 'sys_qr',
              label: 'QR Code (Ver.$qrVersion)',
              rightBadge: '▸',
              children: [
                CwMenuNode(
                  id: 'qr_v3',
                  label: 'Version 3 (29×29)',
                  rightBadge: qrVersion == 3 ? '●' : '○',
                  action: const CwMenuAction('set_qr_version', '3'),
                ),
                CwMenuNode(
                  id: 'qr_v11',
                  label: 'Version 11 (Dense)',
                  rightBadge: qrVersion == 11 ? '●' : '○',
                  action: const CwMenuAction('set_qr_version', '11'),
                ),
              ],
            ),
            CwMenuNode(
              id: 'sys_invert',
              label: 'LCD Invert',
              rightBadge: lcdInverted ? 'ON' : 'OFF',
              action: const CwMenuAction('toggle_lcd_invert'),
            ),
            CwMenuNode(
              id: 'sys_sound',
              label: 'Key Click Sound',
              rightBadge: keyClickSoundOn ? 'ON' : 'OFF',
              action: const CwMenuAction('toggle_key_sound'),
            ),
            CwMenuNode(
              id: 'sys_haptic',
              label: 'Haptic Feedback',
              rightBadge: hapticFeedbackOn ? 'ON' : 'OFF',
              action: const CwMenuAction('toggle_haptics'),
            ),
            CwMenuNode(
              id: 'sys_grid',
              label: 'Pixel Grid',
              rightBadge: showPixelGrid ? 'ON' : 'OFF',
              action: const CwMenuAction('toggle_pixel_grid'),
            ),
          ],
        ),
        const CwMenuNode(
          id: 'set_reset',
          label: 'Reset',
          rightBadge: '▸',
          children: [
            CwMenuNode(
              id: 'rst_setup',
              label: 'Settings & Data',
              action: CwMenuAction('reset_variables'),
            ),
            CwMenuNode(
              id: 'rst_vars',
              label: 'Variable Memory',
              action: CwMenuAction('reset_variables'),
            ),
            CwMenuNode(
              id: 'rst_all',
              label: 'Initialize All',
              action: CwMenuAction('reset_initialize_all'),
            ),
          ],
        ),
      ],
      selectedIndex: 0,
    );
  }
}
