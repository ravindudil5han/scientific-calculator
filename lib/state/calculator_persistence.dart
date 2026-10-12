import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import '../navigation/cw_menu_tree.dart';
import 'calculator_models.dart';
import 'calculator_state.dart';

/// Manages tactile haptic feedback and optional audible membrane key-click
/// synthesis for the Cal_ 1100_DB_ keypad.
class Cal_HardwareFeedback {
  Cal_HardwareFeedback._();

  /// Triggers micro-vibration haptics and optional audible click on key-down.
  static void triggerKeyPress({
    required bool hapticEnabled,
    required bool soundEnabled,
    bool isHeavyAction = false,
  }) {
    try {
      if (ServicesBinding.rootIsolateToken == null) return;
      if (hapticEnabled) {
        if (isHeavyAction) {
          HapticFeedback.mediumImpact().ignore();
        } else {
          HapticFeedback.lightImpact().ignore();
        }
      }
      if (soundEnabled) {
        SystemSound.play(SystemSoundType.click).ignore();
      }
    } catch (_) {
      // Ignore platform channel errors in headless unit tests.
    }
  }
}

/// Persistent storage service that saves and restores calculator registers
/// (`A`–`F`, `x`, `y`, `z`, `Ans`, `PreAns`), system settings (`AngleUnit`,
/// `Fix`/`Sci`/`Norm`, `Contrast`, `LCD Invert`, `QR Version`, `Sound`, `Haptics`),
/// user-defined functions (`f(x)`, `g(x)`), and the 30-entry history stack
/// across app restarts and lifecycle transitions.
class CalculatorPersistenceStore {
  static String? _inMemoryJsonSnapshot;

  static File _resolveStorageFile() {
    final String dirPath = Directory.systemTemp.path;
    return File('$dirPath/calculator_persistent_state.json');
  }

  /// Serializes [state] into a JSON map.
  static Map<String, dynamic> toJsonMap(CalculatorState state) {
    return {
      'activeMode': state.activeMode.name,
      'angleUnit': state.angleUnit.name,
      'ioMode': state.ioMode.name,
      'numberFormat': state.numberFormat.name,
      'formatDigits': state.formatDigits,
      'engSymbolOn': state.engSymbolOn,
      'fractionPreference': state.fractionPreference.name,
      'complexPolarDisplay': state.complexPolarDisplay,
      'definedFunctionF': state.definedFunctionF,
      'definedFunctionG': state.definedFunctionG,
      'variables': state.variables,
      'lcdContrast': state.lcdContrast,
      'lcdInverted': state.lcdInverted,
      'qrVersion': state.qrVersion,
      'keyClickSoundOn': state.keyClickSoundOn,
      'hapticFeedbackOn': state.hapticFeedbackOn,
      'showPixelGrid': state.showPixelGrid,
      'resultText': state.resultText,
      'isResultDisplayed': state.isResultDisplayed,
      'inputTokens': state.inputTokens
          .map((t) => {'display': t.display, 'evalText': t.evalText})
          .toList(),
      'history': state.history
          .map(
            (h) => {
              'expressionText': h.expressionText,
              'resultText': h.resultText,
              'mode': h.mode.name,
              'tokens': h.tokens
                  .map((t) => {'display': t.display, 'evalText': t.evalText})
                  .toList(),
            },
          )
          .toList(),
    };
  }

  /// Saves [state] to persistent local storage (and in-memory cache).
  static void saveState(CalculatorState state) {
    try {
      final String encoded = jsonEncode(toJsonMap(state));
      _inMemoryJsonSnapshot = encoded;
      final File file = _resolveStorageFile();
      file.writeAsStringSync(encoded, flush: true);
    } catch (_) {
      // Fallback to in-memory snapshot if filesystem is restricted in sandboxed test
    }
  }

  /// Loads the persisted JSON snapshot from local storage, or returns `null` if none exists.
  static Map<String, dynamic>? loadRawSnapshot() {
    try {
      if (_inMemoryJsonSnapshot != null && _inMemoryJsonSnapshot!.isNotEmpty) {
        return jsonDecode(_inMemoryJsonSnapshot!) as Map<String, dynamic>;
      }
      final File file = _resolveStorageFile();
      if (file.existsSync()) {
        final String content = file.readAsStringSync();
        if (content.isNotEmpty) {
          _inMemoryJsonSnapshot = content;
          return jsonDecode(content) as Map<String, dynamic>;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Clears any persisted state on disk and in memory.
  static void clearPersistedState() {
    _inMemoryJsonSnapshot = null;
    try {
      final File file = _resolveStorageFile();
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
  }

  /// Applies a persisted JSON snapshot onto [baseState].
  static CalculatorState restoreIntoState(
    CalculatorState baseState,
    Map<String, dynamic> data,
  ) {
    final AppMode activeMode = AppMode.values.firstWhere(
      (e) => e.name == data['activeMode'],
      orElse: () => baseState.activeMode,
    );
    final AngleUnit angleUnit = AngleUnit.values.firstWhere(
      (e) => e.name == data['angleUnit'],
      orElse: () => baseState.angleUnit,
    );
    final InputOutputMode ioMode = InputOutputMode.values.firstWhere(
      (e) => e.name == data['ioMode'],
      orElse: () => baseState.ioMode,
    );
    final NumberFormatMode numberFormat = NumberFormatMode.values.firstWhere(
      (e) => e.name == data['numberFormat'],
      orElse: () => baseState.numberFormat,
    );
    final FractionResultPreference fractionPref =
        FractionResultPreference.values.firstWhere(
          (e) => e.name == data['fractionPreference'],
          orElse: () => baseState.fractionPreference,
        );

    final Map<String, String> restoredVars = Map<String, String>.from(
      baseState.variables,
    );
    if (data['variables'] is Map) {
      final Map<dynamic, dynamic> rawMap =
          data['variables'] as Map<dynamic, dynamic>;
      for (final entry in rawMap.entries) {
        restoredVars[entry.key.toString()] = entry.value.toString();
      }
    }

    final List<InputToken> restoredTokens = [];
    if (data['inputTokens'] is List) {
      for (final t in (data['inputTokens'] as List)) {
        if (t is Map) {
          restoredTokens.add(
            InputToken(
              display: (t['display'] ?? '').toString(),
              evalText: (t['evalText'] ?? '').toString(),
            ),
          );
        }
      }
    }

    final List<CalculationHistoryEntry> restoredHistory = [];
    if (data['history'] is List) {
      for (final item in (data['history'] as List)) {
        if (item is Map) {
          final List<InputToken> toks = [];
          if (item['tokens'] is List) {
            for (final t in (item['tokens'] as List)) {
              if (t is Map) {
                toks.add(
                  InputToken(
                    display: (t['display'] ?? '').toString(),
                    evalText: (t['evalText'] ?? '').toString(),
                  ),
                );
              }
            }
          }
          final AppMode histMode = AppMode.values.firstWhere(
            (e) => e.name == item['mode'],
            orElse: () => activeMode,
          );
          restoredHistory.add(
            CalculationHistoryEntry(
              tokens: toks,
              expressionText: (item['expressionText'] ?? '').toString(),
              resultText: (item['resultText'] ?? '').toString(),
              mode: histMode,
            ),
          );
        }
      }
    }

    final String fnF = (data['definedFunctionF'] ?? baseState.definedFunctionF)
        .toString();
    final String fnG = (data['definedFunctionG'] ?? baseState.definedFunctionG)
        .toString();

    return baseState.copyWith(
      activeMode: activeMode,
      angleUnit: angleUnit,
      ioMode: ioMode,
      numberFormat: numberFormat,
      formatDigits: (data['formatDigits'] as int?) ?? baseState.formatDigits,
      engSymbolOn: (data['engSymbolOn'] as bool?) ?? baseState.engSymbolOn,
      fractionPreference: fractionPref,
      complexPolarDisplay:
          (data['complexPolarDisplay'] as bool?) ??
          baseState.complexPolarDisplay,
      definedFunctionF: fnF,
      definedFunctionG: fnG,
      hasFunctionDefined: fnF.isNotEmpty || fnG.isNotEmpty,
      variables: restoredVars,
      lcdContrast: (data['lcdContrast'] as int?) ?? baseState.lcdContrast,
      lcdInverted: (data['lcdInverted'] as bool?) ?? baseState.lcdInverted,
      qrVersion: (data['qrVersion'] as int?) ?? baseState.qrVersion,
      keyClickSoundOn:
          (data['keyClickSoundOn'] as bool?) ?? baseState.keyClickSoundOn,
      hapticFeedbackOn:
          (data['hapticFeedbackOn'] as bool?) ?? baseState.hapticFeedbackOn,
      showPixelGrid:
          (data['showPixelGrid'] as bool?) ?? baseState.showPixelGrid,
      resultText: (data['resultText'] ?? baseState.resultText).toString(),
      isResultDisplayed:
          (data['isResultDisplayed'] as bool?) ?? baseState.isResultDisplayed,
      inputTokens:
          restoredTokens.isNotEmpty ? restoredTokens : baseState.inputTokens,
      history: restoredHistory,
    );
  }
}
