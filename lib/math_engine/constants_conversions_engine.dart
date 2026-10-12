import 'calculator_decimal.dart';
import 'calculator_exceptions.dart';

/// Category of a CODATA scientific constant in `CATALOG -> Sci Constants`.
enum CodataCategory {
  universal('Universal'),
  electromagnetic('Electromagnetic'),
  atomicNuclear('Atomic & Nuclear'),
  physicoChemical('Physico-Chem'),
  adoptedValues('Adopted Values');

  final String label;
  const CodataCategory(this.label);
}

/// Immutable descriptor for one of the 47 built-in CODATA physical constants.
class CodataConstant {
  final int index;
  final String id;
  final String symbol;
  final List<String> aliases;
  final String name;
  final CodataCategory category;
  final String valueString;
  final String unit;

  const CodataConstant({
    required this.index,
    required this.id,
    required this.symbol,
    this.aliases = const [],
    required this.name,
    required this.category,
    required this.valueString,
    required this.unit,
  });

  /// High-precision [Cal_Decimal] value of this constant.
  Cal_Decimal get decimalValue => Cal_Decimal.parse(valueString);

  /// Evaluatable expression string suitable for insertion into `InputToken.evalText`.
  String get evalExpression => '($valueString)';
}

/// Complete dictionary of all 47 CODATA recommended physical constants for the
/// Cal_ 1100_DB_ ClassWiz (`CATALOG -> Sci Constants`).
class CodataLibrary {
  CodataLibrary._();

  static const List<CodataConstant> allConstants = [
    // =========================================================================
    // 1. Universal Constants (11)
    // =========================================================================
    CodataConstant(
      index: 1,
      id: 'c0',
      symbol: 'c₀',
      aliases: ['c0', 'c₀', 'c_0'],
      name: 'Speed of light in vacuum',
      category: CodataCategory.universal,
      valueString: '299792458',
      unit: 'm·s⁻¹',
    ),
    CodataConstant(
      index: 2,
      id: 'mu0',
      symbol: 'μ₀',
      aliases: ['mu0', 'μ0', 'μ₀', 'mu_0'],
      name: 'Magnetic constant',
      category: CodataCategory.universal,
      valueString: '1.25663706212e-6',
      unit: 'N·A⁻²',
    ),
    CodataConstant(
      index: 3,
      id: 'eps0',
      symbol: 'ε₀',
      aliases: ['eps0', 'ε0', 'ε₀', 'eps_0'],
      name: 'Electric constant',
      category: CodataCategory.universal,
      valueString: '8.8541878128e-12',
      unit: 'F·m⁻¹',
    ),
    CodataConstant(
      index: 4,
      id: 'Z0',
      symbol: 'Z₀',
      aliases: ['Z0', 'Z₀', 'Z_0'],
      name: 'Vacuum impedance',
      category: CodataCategory.universal,
      valueString: '376.730313668',
      unit: 'Ω',
    ),
    CodataConstant(
      index: 5,
      id: 'G',
      symbol: 'G',
      aliases: ['G', 'const_G'],
      name: 'Gravitational constant',
      category: CodataCategory.universal,
      valueString: '6.67430e-11',
      unit: 'm³·kg⁻¹·s⁻²',
    ),
    CodataConstant(
      index: 6,
      id: 'h',
      symbol: 'h',
      aliases: ['h', 'const_h'],
      name: 'Planck constant',
      category: CodataCategory.universal,
      valueString: '6.62607015e-34',
      unit: 'J·s',
    ),
    CodataConstant(
      index: 7,
      id: 'hbar',
      symbol: 'ℏ',
      aliases: ['hbar', 'ℏ', 'ħ'],
      name: 'Reduced Planck constant',
      category: CodataCategory.universal,
      valueString: '1.054571817e-34',
      unit: 'J·s',
    ),
    CodataConstant(
      index: 8,
      id: 'lP',
      symbol: 'lₚ',
      aliases: ['lP', 'lₚ', 'l_P'],
      name: 'Planck length',
      category: CodataCategory.universal,
      valueString: '1.616255e-35',
      unit: 'm',
    ),
    CodataConstant(
      index: 9,
      id: 'tP',
      symbol: 'tₚ',
      aliases: ['tP', 'tₚ', 't_P'],
      name: 'Planck time',
      category: CodataCategory.universal,
      valueString: '5.391247e-44',
      unit: 's',
    ),
    CodataConstant(
      index: 10,
      id: 'mP',
      symbol: 'mₚₗ',
      aliases: ['mP', 'mₚₗ', 'm_P'],
      name: 'Planck mass',
      category: CodataCategory.universal,
      valueString: '2.176434e-8',
      unit: 'kg',
    ),
    CodataConstant(
      index: 11,
      id: 'TP',
      symbol: 'Tₚ',
      aliases: ['TP', 'Tₚ', 'T_P'],
      name: 'Planck temperature',
      category: CodataCategory.universal,
      valueString: '1.416784e32',
      unit: 'K',
    ),

    // =========================================================================
    // 2. Electromagnetic Constants (7)
    // =========================================================================
    CodataConstant(
      index: 12,
      id: 'e_elem',
      symbol: 'e_c',
      aliases: ['e_elem', 'e_c', 'elem_e'],
      name: 'Elementary charge',
      category: CodataCategory.electromagnetic,
      valueString: '1.602176634e-19',
      unit: 'C',
    ),
    CodataConstant(
      index: 13,
      id: 'Phi0',
      symbol: 'Φ₀',
      aliases: ['Phi0', 'Φ0', 'Φ₀', 'Phi_0'],
      name: 'Magnetic flux quantum',
      category: CodataCategory.electromagnetic,
      valueString: '2.067833848e-15',
      unit: 'Wb',
    ),
    CodataConstant(
      index: 14,
      id: 'G0',
      symbol: 'G₀',
      aliases: ['G0', 'G₀', 'G_0'],
      name: 'Conductance quantum',
      category: CodataCategory.electromagnetic,
      valueString: '7.748091729e-5',
      unit: 'S',
    ),
    CodataConstant(
      index: 15,
      id: 'KJ',
      symbol: 'K_J',
      aliases: ['KJ', 'K_J', 'Kⱼ'],
      name: 'Josephson constant',
      category: CodataCategory.electromagnetic,
      valueString: '4.835978484e14',
      unit: 'Hz·V⁻¹',
    ),
    CodataConstant(
      index: 16,
      id: 'RK',
      symbol: 'R_K',
      aliases: ['RK', 'R_K', 'Rₖ'],
      name: 'von Klitzing constant',
      category: CodataCategory.electromagnetic,
      valueString: '25812.80745',
      unit: 'Ω',
    ),
    CodataConstant(
      index: 17,
      id: 'muB',
      symbol: 'μ_B',
      aliases: ['muB', 'μB', 'μ_B'],
      name: 'Bohr magneton',
      category: CodataCategory.electromagnetic,
      valueString: '9.2740100783e-24',
      unit: 'J·T⁻¹',
    ),
    CodataConstant(
      index: 18,
      id: 'muN',
      symbol: 'μ_N',
      aliases: ['muN', 'μN', 'μ_N'],
      name: 'Nuclear magneton',
      category: CodataCategory.electromagnetic,
      valueString: '5.0507837461e-27',
      unit: 'J·T⁻¹',
    ),

    // =========================================================================
    // 3. Atomic & Nuclear Constants (17)
    // =========================================================================
    CodataConstant(
      index: 19,
      id: 'mp',
      symbol: 'mₚ',
      aliases: ['mp', 'mₚ', 'm_p'],
      name: 'Proton mass',
      category: CodataCategory.atomicNuclear,
      valueString: '1.67262192369e-27',
      unit: 'kg',
    ),
    CodataConstant(
      index: 20,
      id: 'mn',
      symbol: 'mₙ',
      aliases: ['mn', 'mₙ', 'm_n'],
      name: 'Neutron mass',
      category: CodataCategory.atomicNuclear,
      valueString: '1.67492749804e-27',
      unit: 'kg',
    ),
    CodataConstant(
      index: 21,
      id: 'me',
      symbol: 'mₑ',
      aliases: ['me', 'mₑ', 'm_e'],
      name: 'Electron mass',
      category: CodataCategory.atomicNuclear,
      valueString: '9.1093837015e-31',
      unit: 'kg',
    ),
    CodataConstant(
      index: 22,
      id: 'mmu',
      symbol: 'm_μ',
      aliases: ['mmu', 'mμ', 'm_μ'],
      name: 'Muon mass',
      category: CodataCategory.atomicNuclear,
      valueString: '1.883531627e-28',
      unit: 'kg',
    ),
    CodataConstant(
      index: 23,
      id: 'mtau',
      symbol: 'm_τ',
      aliases: ['mtau', 'mτ', 'm_τ'],
      name: 'Tau mass',
      category: CodataCategory.atomicNuclear,
      valueString: '3.16754e-27',
      unit: 'kg',
    ),
    CodataConstant(
      index: 24,
      id: 'a0',
      symbol: 'a₀',
      aliases: ['a0', 'a₀', 'a_0'],
      name: 'Bohr radius',
      category: CodataCategory.atomicNuclear,
      valueString: '5.29177210903e-11',
      unit: 'm',
    ),
    CodataConstant(
      index: 25,
      id: 're',
      symbol: 'rₑ',
      aliases: ['re', 'rₑ', 'r_e'],
      name: 'Classical electron radius',
      category: CodataCategory.atomicNuclear,
      valueString: '2.8179403262e-15',
      unit: 'm',
    ),
    CodataConstant(
      index: 26,
      id: 'alpha',
      symbol: 'α',
      aliases: ['alpha', 'α'],
      name: 'Fine-structure constant',
      category: CodataCategory.atomicNuclear,
      valueString: '7.2973525693e-3',
      unit: '',
    ),
    CodataConstant(
      index: 27,
      id: 'Rinf',
      symbol: 'R∞',
      aliases: ['Rinf', 'R∞', 'R_inf'],
      name: 'Rydberg constant',
      category: CodataCategory.atomicNuclear,
      valueString: '10973731.568160',
      unit: 'm⁻¹',
    ),
    CodataConstant(
      index: 28,
      id: 'lambdaC',
      symbol: 'λ_C',
      aliases: ['lambdaC', 'λC', 'λ_C'],
      name: 'Compton wavelength',
      category: CodataCategory.atomicNuclear,
      valueString: '2.42631023867e-12',
      unit: 'm',
    ),
    CodataConstant(
      index: 29,
      id: 'lambdaCp',
      symbol: 'λ_Cp',
      aliases: ['lambdaCp', 'λCp', 'λ_Cp'],
      name: 'Proton Compton wavelength',
      category: CodataCategory.atomicNuclear,
      valueString: '1.32140985539e-15',
      unit: 'm',
    ),
    CodataConstant(
      index: 30,
      id: 'lambdaCn',
      symbol: 'λ_Cn',
      aliases: ['lambdaCn', 'λCn', 'λ_Cn'],
      name: 'Neutron Compton wavelength',
      category: CodataCategory.atomicNuclear,
      valueString: '1.31959090581e-15',
      unit: 'm',
    ),
    CodataConstant(
      index: 31,
      id: 'gammap',
      symbol: 'γₚ',
      aliases: ['gammap', 'γp', 'γₚ', 'γ_p'],
      name: 'Proton gyromagnetic ratio',
      category: CodataCategory.atomicNuclear,
      valueString: '2.6752218744e8',
      unit: 's⁻¹·T⁻¹',
    ),
    CodataConstant(
      index: 32,
      id: 'mup',
      symbol: 'μₚ',
      aliases: ['mup', 'μp', 'μₚ', 'μ_p'],
      name: 'Proton magnetic moment',
      category: CodataCategory.atomicNuclear,
      valueString: '1.41060679736e-26',
      unit: 'J·T⁻¹',
    ),
    CodataConstant(
      index: 33,
      id: 'mue',
      symbol: 'μₑ',
      aliases: ['mue', 'μe', 'μₑ', 'μ_e'],
      name: 'Electron magnetic moment',
      category: CodataCategory.atomicNuclear,
      valueString: '-9.2847647043e-24',
      unit: 'J·T⁻¹',
    ),
    CodataConstant(
      index: 34,
      id: 'mun',
      symbol: 'μₙ',
      aliases: ['mun', 'μn', 'μₙ', 'μ_n'],
      name: 'Neutron magnetic moment',
      category: CodataCategory.atomicNuclear,
      valueString: '-9.6623651e-27',
      unit: 'J·T⁻¹',
    ),
    CodataConstant(
      index: 35,
      id: 'mumu',
      symbol: 'μ_μ',
      aliases: ['mumu', 'μμ', 'μ_μ'],
      name: 'Muon magnetic moment',
      category: CodataCategory.atomicNuclear,
      valueString: '-4.49044830e-26',
      unit: 'J·T⁻¹',
    ),

    // =========================================================================
    // 4. Physico-Chemical Constants (9)
    // =========================================================================
    CodataConstant(
      index: 36,
      id: 'u',
      symbol: 'u',
      aliases: ['u', 'const_u'],
      name: 'Atomic mass constant',
      category: CodataCategory.physicoChemical,
      valueString: '1.66053906660e-27',
      unit: 'kg',
    ),
    CodataConstant(
      index: 37,
      id: 'NA',
      symbol: 'N_A',
      aliases: ['NA', 'N_A', 'Nₐ'],
      name: 'Avogadro constant',
      category: CodataCategory.physicoChemical,
      valueString: '6.02214076e23',
      unit: 'mol⁻¹',
    ),
    CodataConstant(
      index: 38,
      id: 'F_const',
      symbol: 'F_c',
      aliases: ['F_const', 'F_c'],
      name: 'Faraday constant',
      category: CodataCategory.physicoChemical,
      valueString: '96485.33212',
      unit: 'C·mol⁻¹',
    ),
    CodataConstant(
      index: 39,
      id: 'R_gas',
      symbol: 'R_c',
      aliases: ['R_gas', 'R_c', 'R_const'],
      name: 'Molar gas constant',
      category: CodataCategory.physicoChemical,
      valueString: '8.314462618',
      unit: 'J·mol⁻¹·K⁻¹',
    ),
    CodataConstant(
      index: 40,
      id: 'k_B',
      symbol: 'k',
      aliases: ['k_B', 'k', 'const_k'],
      name: 'Boltzmann constant',
      category: CodataCategory.physicoChemical,
      valueString: '1.380649e-23',
      unit: 'J·K⁻¹',
    ),
    CodataConstant(
      index: 41,
      id: 'Vm',
      symbol: 'Vₘ',
      aliases: ['Vm', 'Vₘ', 'V_m'],
      name: 'Molar volume of ideal gas',
      category: CodataCategory.physicoChemical,
      valueString: '0.02271095464',
      unit: 'm³·mol⁻¹',
    ),
    CodataConstant(
      index: 42,
      id: 'sigma',
      symbol: 'σ',
      aliases: ['sigma', 'σ'],
      name: 'Stefan-Boltzmann constant',
      category: CodataCategory.physicoChemical,
      valueString: '5.670374419e-8',
      unit: 'W·m⁻²·K⁻⁴',
    ),
    CodataConstant(
      index: 43,
      id: 'c1',
      symbol: 'c₁',
      aliases: ['c1', 'c₁', 'c_1'],
      name: 'First radiation constant',
      category: CodataCategory.physicoChemical,
      valueString: '3.741771852e-16',
      unit: 'W·m²',
    ),
    CodataConstant(
      index: 44,
      id: 'c2',
      symbol: 'c₂',
      aliases: ['c2', 'c₂', 'c_2'],
      name: 'Second radiation constant',
      category: CodataCategory.physicoChemical,
      valueString: '0.01438776877',
      unit: 'm·K',
    ),

    // =========================================================================
    // 5. Adopted Values & Planetary (3)
    // =========================================================================
    CodataConstant(
      index: 45,
      id: 'g',
      symbol: 'g_n',
      aliases: ['g_n', 'const_g'],
      name: 'Standard acceleration of gravity',
      category: CodataCategory.adoptedValues,
      valueString: '9.80665',
      unit: 'm·s⁻²',
    ),
    CodataConstant(
      index: 46,
      id: 'atm',
      symbol: 'atm',
      aliases: ['atm', 'const_atm'],
      name: 'Standard atmosphere',
      category: CodataCategory.adoptedValues,
      valueString: '101325',
      unit: 'Pa',
    ),
    CodataConstant(
      index: 47,
      id: 't0',
      symbol: 't₀',
      aliases: ['t0', 't₀', 't_0'],
      name: 'Celsius temperature zero point',
      category: CodataCategory.adoptedValues,
      valueString: '273.15',
      unit: 'K',
    ),
  ];

  /// Looks up a [CodataConstant] by its `id`, `symbol`, or any alias.
  static CodataConstant? lookup(String key) {
    final String trimmed = key.trim();
    for (final c in allConstants) {
      if (c.id == trimmed ||
          c.symbol == trimmed ||
          c.aliases.contains(trimmed)) {
        return c;
      }
    }
    return null;
  }

  /// Returns all constants belonging to [category].
  static List<CodataConstant> byCategory(CodataCategory category) {
    return allConstants.where((c) => c.category == category).toList();
  }
}

/// Physical quantity category in `CATALOG -> Unit Conversions`.
enum UnitCategory {
  length('Length'),
  area('Area'),
  volume('Volume'),
  mass('Mass'),
  velocity('Velocity'),
  pressure('Pressure'),
  energy('Energy'),
  power('Power'),
  temperature('Temperature'),
  force('Force'),
  time('Time');

  final String label;
  const UnitCategory(this.label);
}

/// Represents a bidirectional unit conversion pair ($A \leftrightarrow B$).
class UnitConversionPair {
  final String id;
  final UnitCategory category;
  final String unitA;
  final String unitB;

  /// Exact factor $k$ such that $\text{val}_B = \text{val}_A \times k$ (for linear conversions).
  final String factorAToB;
  final bool isAffineTemperature;

  const UnitConversionPair({
    required this.id,
    required this.category,
    required this.unitA,
    required this.unitB,
    required this.factorAToB,
    this.isAffineTemperature = false,
  });

  String get forwardToken => '$unitA►$unitB';
  String get reverseToken => '$unitB►$unitA';
}

/// Two-way unit conversion engine supporting 47 bidirectional pairs (94 directional
/// conversions) at 30-digit [Cal_Decimal] precision.
class UnitConverterEngine {
  UnitConverterEngine._();

  static const List<UnitConversionPair> allPairs = [
    // 1. Length (10 pairs)
    UnitConversionPair(
      id: 'len_in_cm',
      category: UnitCategory.length,
      unitA: 'in',
      unitB: 'cm',
      factorAToB: '2.54',
    ),
    UnitConversionPair(
      id: 'len_ft_m',
      category: UnitCategory.length,
      unitA: 'ft',
      unitB: 'm',
      factorAToB: '0.3048',
    ),
    UnitConversionPair(
      id: 'len_yd_m',
      category: UnitCategory.length,
      unitA: 'yd',
      unitB: 'm',
      factorAToB: '0.9144',
    ),
    UnitConversionPair(
      id: 'len_mile_km',
      category: UnitCategory.length,
      unitA: 'mile',
      unitB: 'km',
      factorAToB: '1.609344',
    ),
    UnitConversionPair(
      id: 'len_nmile_m',
      category: UnitCategory.length,
      unitA: 'n mile',
      unitB: 'm',
      factorAToB: '1852',
    ),
    UnitConversionPair(
      id: 'len_pc_km',
      category: UnitCategory.length,
      unitA: 'pc',
      unitB: 'km',
      factorAToB: '3.08567758149137e13',
    ),
    UnitConversionPair(
      id: 'len_au_km',
      category: UnitCategory.length,
      unitA: 'AU',
      unitB: 'km',
      factorAToB: '149597870.7',
    ),
    UnitConversionPair(
      id: 'len_ly_km',
      category: UnitCategory.length,
      unitA: 'ly',
      unitB: 'km',
      factorAToB: '9.4607304725808e12',
    ),
    UnitConversionPair(
      id: 'len_ang_m',
      category: UnitCategory.length,
      unitA: 'Å',
      unitB: 'm',
      factorAToB: '1e-10',
    ),
    UnitConversionPair(
      id: 'len_fm_m',
      category: UnitCategory.length,
      unitA: 'fm',
      unitB: 'm',
      factorAToB: '1e-15',
    ),

    // 2. Area (5 pairs)
    UnitConversionPair(
      id: 'area_acre_m2',
      category: UnitCategory.area,
      unitA: 'acre',
      unitB: 'm²',
      factorAToB: '4046.8564224',
    ),
    UnitConversionPair(
      id: 'area_ha_m2',
      category: UnitCategory.area,
      unitA: 'ha',
      unitB: 'm²',
      factorAToB: '10000',
    ),
    UnitConversionPair(
      id: 'area_in2_cm2',
      category: UnitCategory.area,
      unitA: 'in²',
      unitB: 'cm²',
      factorAToB: '6.4516',
    ),
    UnitConversionPair(
      id: 'area_ft2_m2',
      category: UnitCategory.area,
      unitA: 'ft²',
      unitB: 'm²',
      factorAToB: '0.09290304',
    ),
    UnitConversionPair(
      id: 'area_mile2_km2',
      category: UnitCategory.area,
      unitA: 'mile²',
      unitB: 'km²',
      factorAToB: '2.589988110336',
    ),

    // 3. Volume (5 pairs)
    UnitConversionPair(
      id: 'vol_galus_l',
      category: UnitCategory.volume,
      unitA: 'gal(US)',
      unitB: 'L',
      factorAToB: '3.785411784',
    ),
    UnitConversionPair(
      id: 'vol_galuk_l',
      category: UnitCategory.volume,
      unitA: 'gal(UK)',
      unitB: 'L',
      factorAToB: '4.54609',
    ),
    UnitConversionPair(
      id: 'vol_l_cm3',
      category: UnitCategory.volume,
      unitA: 'L',
      unitB: 'cm³',
      factorAToB: '1000',
    ),
    UnitConversionPair(
      id: 'vol_floz_ml',
      category: UnitCategory.volume,
      unitA: 'fl oz(US)',
      unitB: 'mL',
      factorAToB: '29.5735295625',
    ),
    UnitConversionPair(
      id: 'vol_bbl_m3',
      category: UnitCategory.volume,
      unitA: 'bbl',
      unitB: 'm³',
      factorAToB: '0.158987294928',
    ),

    // 4. Mass (7 pairs)
    UnitConversionPair(
      id: 'mass_oz_g',
      category: UnitCategory.mass,
      unitA: 'oz',
      unitB: 'g',
      factorAToB: '28.349523125',
    ),
    UnitConversionPair(
      id: 'mass_lb_kg',
      category: UnitCategory.mass,
      unitA: 'lb',
      unitB: 'kg',
      factorAToB: '0.45359237',
    ),
    UnitConversionPair(
      id: 'mass_tonus_kg',
      category: UnitCategory.mass,
      unitA: 'ton(US)',
      unitB: 'kg',
      factorAToB: '907.18474',
    ),
    UnitConversionPair(
      id: 'mass_tonuk_kg',
      category: UnitCategory.mass,
      unitA: 'ton(UK)',
      unitB: 'kg',
      factorAToB: '1016.0469088',
    ),
    UnitConversionPair(
      id: 'mass_t_kg',
      category: UnitCategory.mass,
      unitA: 't',
      unitB: 'kg',
      factorAToB: '1000',
    ),
    UnitConversionPair(
      id: 'mass_u_kg',
      category: UnitCategory.mass,
      unitA: 'u',
      unitB: 'kg',
      factorAToB: '1.66053906660e-27',
    ),
    UnitConversionPair(
      id: 'mass_carat_g',
      category: UnitCategory.mass,
      unitA: 'carat',
      unitB: 'g',
      factorAToB: '0.2',
    ),

    // 5. Velocity (5 pairs)
    UnitConversionPair(
      id: 'vel_kmh_ms',
      category: UnitCategory.velocity,
      unitA: 'm/s',
      unitB: 'km/h',
      factorAToB: '3.6',
    ),
    UnitConversionPair(
      id: 'vel_mph_ms',
      category: UnitCategory.velocity,
      unitA: 'mph',
      unitB: 'm/s',
      factorAToB: '0.44704',
    ),
    UnitConversionPair(
      id: 'vel_mileh_kmh',
      category: UnitCategory.velocity,
      unitA: 'mile/h',
      unitB: 'km/h',
      factorAToB: '1.609344',
    ),
    UnitConversionPair(
      id: 'vel_knot_ms',
      category: UnitCategory.velocity,
      unitA: 'knot',
      unitB: 'm/s',
      factorAToB: '0.514444444444444444444444444444',
    ),
    UnitConversionPair(
      id: 'vel_fts_ms',
      category: UnitCategory.velocity,
      unitA: 'ft/s',
      unitB: 'm/s',
      factorAToB: '0.3048',
    ),

    // 6. Pressure (5 pairs)
    UnitConversionPair(
      id: 'pres_atm_pa',
      category: UnitCategory.pressure,
      unitA: 'atm',
      unitB: 'Pa',
      factorAToB: '101325',
    ),
    UnitConversionPair(
      id: 'pres_mmhg_pa',
      category: UnitCategory.pressure,
      unitA: 'mmHg',
      unitB: 'Pa',
      factorAToB: '133.322387415',
    ),
    UnitConversionPair(
      id: 'pres_kgfcm2_pa',
      category: UnitCategory.pressure,
      unitA: 'kgf/cm²',
      unitB: 'Pa',
      factorAToB: '98066.5',
    ),
    UnitConversionPair(
      id: 'pres_psi_kpa',
      category: UnitCategory.pressure,
      unitA: 'lbf/in²',
      unitB: 'kPa',
      factorAToB: '6.894757293168',
    ),
    UnitConversionPair(
      id: 'pres_bar_pa',
      category: UnitCategory.pressure,
      unitA: 'bar',
      unitB: 'Pa',
      factorAToB: '100000',
    ),

    // 7. Energy (5 pairs)
    UnitConversionPair(
      id: 'eng_cal_j',
      category: UnitCategory.energy,
      unitA: 'cal',
      unitB: 'J',
      factorAToB: '4.184',
    ),
    UnitConversionPair(
      id: 'eng_btu_j',
      category: UnitCategory.energy,
      unitA: 'Btu',
      unitB: 'J',
      factorAToB: '1055.05585262',
    ),
    UnitConversionPair(
      id: 'eng_kwh_j',
      category: UnitCategory.energy,
      unitA: 'kW·h',
      unitB: 'J',
      factorAToB: '3600000',
    ),
    UnitConversionPair(
      id: 'eng_ev_j',
      category: UnitCategory.energy,
      unitA: 'eV',
      unitB: 'J',
      factorAToB: '1.602176634e-19',
    ),
    UnitConversionPair(
      id: 'eng_kgfm_j',
      category: UnitCategory.energy,
      unitA: 'kgf·m',
      unitB: 'J',
      factorAToB: '9.80665',
    ),

    // 8. Power (2 pairs)
    UnitConversionPair(
      id: 'pow_hp_kw',
      category: UnitCategory.power,
      unitA: 'hp',
      unitB: 'kW',
      factorAToB: '0.74569987158227',
    ),
    UnitConversionPair(
      id: 'pow_ps_kw',
      category: UnitCategory.power,
      unitA: 'PS',
      unitB: 'kW',
      factorAToB: '0.73549875',
    ),

    // 9. Temperature (3 affine pairs)
    UnitConversionPair(
      id: 'temp_c_f',
      category: UnitCategory.temperature,
      unitA: '°C',
      unitB: '°F',
      factorAToB: '1.8',
      isAffineTemperature: true,
    ),
    UnitConversionPair(
      id: 'temp_c_k',
      category: UnitCategory.temperature,
      unitA: '°C',
      unitB: 'K',
      factorAToB: '1',
      isAffineTemperature: true,
    ),
    UnitConversionPair(
      id: 'temp_f_k',
      category: UnitCategory.temperature,
      unitA: '°F',
      unitB: 'K',
      factorAToB: '1',
      isAffineTemperature: true,
    ),

    // 10. Force (2 pairs)
    UnitConversionPair(
      id: 'force_lbf_n',
      category: UnitCategory.force,
      unitA: 'lbf',
      unitB: 'N',
      factorAToB: '4.4482216152605',
    ),
    UnitConversionPair(
      id: 'force_kgf_n',
      category: UnitCategory.force,
      unitA: 'kgf',
      unitB: 'N',
      factorAToB: '9.80665',
    ),

    // 11. Time (2 pairs)
    UnitConversionPair(
      id: 'time_min_s',
      category: UnitCategory.time,
      unitA: 'min',
      unitB: 's',
      factorAToB: '60',
    ),
    UnitConversionPair(
      id: 'time_h_s',
      category: UnitCategory.time,
      unitA: 'h',
      unitB: 's',
      factorAToB: '3600',
    ),
  ];

  /// Returns all conversion pairs in [category].
  static List<UnitConversionPair> byCategory(UnitCategory category) {
    return allPairs.where((p) => p.category == category).toList();
  }

  /// Converts [value] from [fromUnit] to [toUnit] at 30-digit [Cal_Decimal] precision.
  static Cal_Decimal convert(
    Cal_Decimal value,
    String fromUnit,
    String toUnit,
  ) {
    final String uFrom = _normalizeUnitName(fromUnit);
    final String uTo = _normalizeUnitName(toUnit);
    if (uFrom == uTo) return value;

    // 1. Handle non-linear affine Temperature conversions
    if (_isTempUnit(uFrom) && _isTempUnit(uTo)) {
      return _convertTemperature(value, uFrom, uTo);
    }

    // 2. Special exact rational handling for knot <-> m/s (1852 / 3600)
    if (uFrom == 'knot' && uTo == 'm/s') {
      return (value * Cal_Decimal.fromInt(1852)) / Cal_Decimal.fromInt(3600);
    }
    if (uFrom == 'm/s' && uTo == 'knot') {
      return (value * Cal_Decimal.fromInt(3600)) / Cal_Decimal.fromInt(1852);
    }

    // 3. Standard linear conversion lookup
    for (final pair in allPairs) {
      if (pair.isAffineTemperature) continue;
      if (pair.unitA == uFrom && pair.unitB == uTo) {
        return value * Cal_Decimal.parse(pair.factorAToB);
      }
      if (pair.unitB == uFrom && pair.unitA == uTo) {
        return value / Cal_Decimal.parse(pair.factorAToB);
      }
    }

    throw SyntaxErrorException('Unsupported unit conversion: $fromUnit►$toUnit');
  }

  /// Applies a directional operator token such as `'in►cm'`, `'►in►cm'`, `'°C►°F'`, or `'°F►K'`.
  static Cal_Decimal applyOperator(Cal_Decimal value, String operatorToken) {
    String clean = operatorToken.trim();
    if (clean.startsWith('►')) {
      clean = clean.substring(1).trim();
    }
    final int arrowIdx = clean.indexOf('►');
    if (arrowIdx <= 0 || arrowIdx >= clean.length - 1) {
      throw SyntaxErrorException('Invalid unit conversion token "$operatorToken"');
    }
    final String fromUnit = clean.substring(0, arrowIdx).trim();
    final String toUnit = clean.substring(arrowIdx + 1).trim();
    return convert(value, fromUnit, toUnit);
  }

  static String _normalizeUnitName(String unit) {
    final String u = unit.trim();
    if (u == 'ton(short)') return 'ton(US)';
    if (u == 'ton(long)') return 'ton(UK)';
    if (u == 'psi') return 'lbf/in²';
    if (u == 'C') return '°C';
    if (u == 'F') return '°F';
    return u;
  }

  static bool _isTempUnit(String u) => u == '°C' || u == '°F' || u == 'K';

  static Cal_Decimal _convertTemperature(
    Cal_Decimal val,
    String fromUnit,
    String toUnit,
  ) {
    final Cal_Decimal five = Cal_Decimal.fromInt(5);
    final Cal_Decimal nine = Cal_Decimal.fromInt(9);
    final Cal_Decimal thirtyTwo = Cal_Decimal.fromInt(32);
    final Cal_Decimal zeroK = Cal_Decimal.parse('273.15');

    // Convert input to Celsius first
    final Cal_Decimal celsius = switch (fromUnit) {
      '°C' => val,
      '°F' => ((val - thirtyTwo) * five) / nine,
      'K' => val - zeroK,
      _ => val,
    };

    // Convert Celsius to target unit
    return switch (toUnit) {
      '°C' => celsius,
      '°F' => ((celsius * nine) / five) + thirtyTwo,
      'K' => celsius + zeroK,
      _ => celsius,
    };
  }
}

/// Sexagesimal Degrees-Minutes-Seconds ($D^\circ M' S''$) parser and converter.
class SexagesimalDmsEngine {
  SexagesimalDmsEngine._();

  /// Parses a sexagesimal string such as `'2°35\'6\'\''`, `'2°35°6°'`, or `'12°30\''`
  /// into an exact [BigRational] ($\text{deg} + \frac{\text{min}}{60} + \frac{\text{sec}}{3600}$).
  static BigRational? tryParseDmsToRational(String raw) {
    final String s = raw.trim();
    final RegExp dmsPattern = RegExp(
      r'''^(-?)(\d+(?:\.\d+)?)°(\d+(?:\.\d+)?)(?:°|')(\d+(?:\.\d+)?)?(?:°|''|"|')?$''',
    );
    final match = dmsPattern.firstMatch(s);
    if (match == null) return null;

    final bool isNeg = match.group(1) == '-';
    final BigRational? deg = BigRational.tryParse(match.group(2)!);
    final BigRational? min = BigRational.tryParse(match.group(3)!);
    final BigRational? sec = match.group(4) != null
        ? BigRational.tryParse(match.group(4)!)
        : BigRational.zero;

    if (deg == null || min == null || sec == null) return null;

    final BigRational total = deg +
        (min / BigRational.fromInt(60)) +
        (sec / BigRational.fromInt(3600));
    return isNeg ? -total : total;
  }

  /// Converts Degrees, Minutes, and Seconds into a 30-digit [Cal_Decimal].
  static Cal_Decimal fromDms(
    Cal_Decimal degrees,
    Cal_Decimal minutes, [
    Cal_Decimal? seconds,
  ]) {
    final Cal_Decimal sec = seconds ?? Cal_Decimal.zero;
    final bool isNeg = degrees.isNegative;
    final Cal_Decimal absDeg = degrees.abs();
    final Cal_Decimal total = absDeg +
        (minutes / Cal_Decimal.fromInt(60)) +
        (sec / Cal_Decimal.fromInt(3600));
    return isNeg ? -total : total;
  }
}
