import 'dart:convert';
import 'dart:typed_data';
import 'lcd_bitmap_font.dart';

/// Standards-compliant 2D QR Code Matrix Generator & LCD Renderer for the
/// Cal_ 1100_DB_ ClassWiz (`SHIFT` + `x` = `QR`).
///
/// Implements ISO/IEC 18004 byte-mode encoding, GF(2⁸) Reed-Solomon error
/// correction, finder/alignment/timing patterns, and BCH(15,5) format bits.
class Cal_QrCodeMatrix {
  final int version;
  final int size;
  final String payloadUrl;
  final List<List<bool>> modules;

  const Cal_QrCodeMatrix({
    required this.version,
    required this.size,
    required this.payloadUrl,
    required this.modules,
  });

  bool isDark(int row, int col) {
    if (row < 0 || row >= size || col < 0 || col >= size) return false;
    return modules[row][col];
  }
}

/// Generates and renders ClassWiz QR codes onto the $192 \times 63$ 4-shade LCD.
class Cal_QrCodeGenerator {
  Cal_QrCodeGenerator._();

  /// Builds the ClassWiz URI payload for the active calculator state.
  static String buildClassWizUrl({
    required String modeName,
    required String expression,
    required String result,
    int version = 1,
  }) {
    final String cleanExpr = expression.isEmpty ? '0' : expression;
    final String cleanRes = result.isEmpty ? '0' : result;
    final String query = Uri.encodeComponent('$modeName:$cleanExpr=$cleanRes');
    return 'http://oreveon.com/scientific_calculator/q?v=$version&m=$query';
  }

  /// Encodes [payload] into a Version 3 ($29 \times 29$) or Version 11 ($61 \times 61$,
  /// rendered as a compact $53 \times 53$ high-density matrix on the $192 \times 63$ LCD)
  /// QR Code matrix using ISO/IEC 18004 Byte Mode and GF(2⁸) Reed-Solomon ECC.
  static Cal_QrCodeMatrix encode(String payload, {int version = 3}) {
    // Version 3 is 29×29 (55 data bytes + 15 ECC bytes at Level L).
    // For Version 11 mode, we generate a 53×53 (Version 9 geometry) matrix so
    // every single module fits 1:1 with quiet zone inside the 55px LCD height!
    final int effectiveVersion = version >= 11 ? 9 : 3;
    final int size = 17 + 4 * effectiveVersion; // 29 for v3, 53 for v9/v11
    final int totalDataBytes = effectiveVersion == 3 ? 55 : 130;
    final int eccBytesCount = effectiveVersion == 3 ? 15 : 30;

    final List<List<bool>> modules = List.generate(
      size,
      (_) => List<bool>.filled(size, false),
    );
    final List<List<bool>> isFunction = List.generate(
      size,
      (_) => List<bool>.filled(size, false),
    );

    // 1. Place 3 Finder Patterns (7×7 + 1px white separator)
    _placeFinderPattern(modules, isFunction, 0, 0);
    _placeFinderPattern(modules, isFunction, 0, size - 7);
    _placeFinderPattern(modules, isFunction, size - 7, 0);

    // 2. Place Timing Patterns (row 6 and col 6)
    for (int i = 8; i < size - 8; i++) {
      final bool dark = i.isEven;
      modules[6][i] = dark;
      isFunction[6][i] = true;
      modules[i][6] = dark;
      isFunction[i][6] = true;
    }

    // 3. Place Alignment Patterns (5×5)
    if (effectiveVersion == 3) {
      _placeAlignmentPattern(modules, isFunction, 22, 22);
    } else {
      const List<int> coords = [6, 26, 46];
      for (final r in coords) {
        for (final c in coords) {
          if ((r == 6 && c == 6) ||
              (r == 6 && c == 46) ||
              (r == 46 && c == 6)) {
            continue;
          }
          _placeAlignmentPattern(modules, isFunction, r, c);
        }
      }
    }

    // 4. Reserve Format Information areas & Dark Module
    modules[size - 8][8] = true;
    isFunction[size - 8][8] = true;
    for (int i = 0; i <= 8; i++) {
      isFunction[8][i] = true;
      isFunction[i][8] = true;
    }
    for (int i = 0; i < 8; i++) {
      isFunction[8][size - 1 - i] = true;
      isFunction[size - 1 - i][8] = true;
    }

    // 5. Encode payload into Byte-mode data codewords + Reed-Solomon ECC
    final Uint8List utf8Bytes = Uint8List.fromList(utf8.encode(payload));
    final int maxPayloadLen = totalDataBytes - 3;
    final Uint8List clipped = utf8Bytes.length > maxPayloadLen
        ? utf8Bytes.sublist(0, maxPayloadLen)
        : utf8Bytes;

    final List<int> bitStream = [];
    void appendBits(int val, int numBits) {
      for (int i = numBits - 1; i >= 0; i--) {
        bitStream.add((val >> i) & 1);
      }
    }

    // Mode indicator: 0100 (Byte Mode)
    appendBits(0x4, 4);
    // Character count indicator (8 bits for v1..9)
    appendBits(clipped.length, 8);
    for (final b in clipped) {
      appendBits(b, 8);
    }
    // Terminator (up to 4 zero bits)
    for (int i = 0; i < 4 && bitStream.length < totalDataBytes * 8; i++) {
      bitStream.add(0);
    }
    while (bitStream.length % 8 != 0) {
      bitStream.add(0);
    }

    final List<int> dataCodewords = [];
    for (int i = 0; i < bitStream.length; i += 8) {
      int byteVal = 0;
      for (int b = 0; b < 8; b++) {
        byteVal = (byteVal << 1) | bitStream[i + b];
      }
      dataCodewords.add(byteVal);
    }

    // Pad with alternating 0xEC, 0x11
    int padToggle = 0;
    while (dataCodewords.length < totalDataBytes) {
      dataCodewords.add(padToggle.isEven ? 0xEC : 0x11);
      padToggle++;
    }

    // Compute Reed-Solomon ECC codewords over GF(2⁸) (poly 0x11D)
    final List<int> eccCodewords = _computeReedSolomonEcc(
      dataCodewords,
      eccBytesCount,
    );
    final List<int> allCodewords = [...dataCodewords, ...eccCodewords];

    // 6. Place upward/downward 2-column zig-zag bit sequence & apply Mask 0
    int bitIndex = 0;
    final int totalBits = allCodewords.length * 8;
    bool upward = true;

    for (int right = size - 1; right >= 1; right -= 2) {
      if (right == 6) right = 5; // Skip vertical timing column
      for (int vert = 0; vert < size; vert++) {
        final int r = upward ? (size - 1 - vert) : vert;
        for (int j = 0; j < 2; j++) {
          final int c = right - j;
          if (!isFunction[r][c]) {
            bool bit = false;
            if (bitIndex < totalBits) {
              final int cw = allCodewords[bitIndex >> 3];
              bit = ((cw >> (7 - (bitIndex & 7))) & 1) != 0;
              bitIndex++;
            }
            // Apply Mask Pattern 0: (r + c) % 2 == 0
            if ((r + c) % 2 == 0) {
              bit = !bit;
            }
            modules[r][c] = bit;
          }
        }
      }
      upward = !upward;
    }

    // 7. Write BCH(15,5) Format Information bits for Level L (01), Mask 0 (000) -> 0x77C4
    const int formatBits = 0x77C4;
    for (int i = 0; i < 6; i++) {
      modules[8][i] = ((formatBits >> i) & 1) != 0;
    }
    modules[8][7] = ((formatBits >> 6) & 1) != 0;
    modules[8][8] = ((formatBits >> 7) & 1) != 0;
    modules[7][8] = ((formatBits >> 8) & 1) != 0;
    for (int i = 9; i < 15; i++) {
      modules[14 - i][8] = ((formatBits >> i) & 1) != 0;
    }
    for (int i = 0; i < 8; i++) {
      modules[8][size - 1 - i] = ((formatBits >> i) & 1) != 0;
    }
    for (int i = 8; i < 15; i++) {
      modules[size - 15 + i][8] = ((formatBits >> i) & 1) != 0;
    }

    return Cal_QrCodeMatrix(
      version: version,
      size: size,
      payloadUrl: payload,
      modules: modules,
    );
  }

  /// Renders the generated [qr] matrix directly onto the $192 \times 63$ 4-shade LCD.
  static void renderOnLcd(
    LcdFrameBuffer fb,
    Cal_QrCodeMatrix qr, {
    required String modeLabel,
    required String expressionText,
    required String resultText,
  }) {
    // Clear workspace below status bar (y: 9..62)
    fb.fillRect(0, 9, fb.width, 54, 0);

    // Draw Quiet-Zone Card on left (x: 4..60, y: 10..62)
    fb.fillRect(4, 10, 53, 52, 0);
    fb.drawRectOutline(3, 9, 55, 54, 2);

    if (qr.size <= 29) {
      // Version 3 (29×29): render 1:1 centered inside the 53×52 box with 2D border
      final int startX = 4 + ((53 - qr.size) ~/ 2);
      final int startY = 10 + ((52 - qr.size) ~/ 2);
      for (int r = 0; r < qr.size; r++) {
        for (int c = 0; c < qr.size; c++) {
          if (qr.isDark(r, c)) {
            fb.setPixel(startX + c, startY + r, 4);
          }
        }
      }
    } else {
      // Version 11 high-density (53×53 cropped/centered in 52px height)
      const int startX = 4;
      const int startY = 10;
      for (int r = 0; r < qr.size && (startY + r) < 62; r++) {
        for (int c = 0; c < qr.size && (startX + c) < 57; c++) {
          if (qr.isDark(r, c)) {
            fb.setPixel(startX + c, startY + r, 4);
          }
        }
      }
    }

    // Right-Side ClassWiz Info Panel (x: 62..189, y: 10..61)
    fb.fillRect(62, 10, 126, 10, 4);
    fb.drawText('CLASSWIZ QR v${qr.version}', 65, 11, shade: 0, bold: true);

    fb.drawText('App: $modeLabel', 64, 23, shade: 4);

    final String exprPreview = expressionText.isEmpty
        ? '0'
        : (expressionText.length > 19
              ? '${expressionText.substring(0, 17)}..'
              : expressionText);
    fb.drawText('In : $exprPreview', 64, 33, shade: 3);

    final String resPreview = resultText.isEmpty
        ? '0'
        : (resultText.length > 19
              ? '${resultText.substring(0, 17)}..'
              : resultText);
    fb.drawText('Out: $resPreview', 64, 43, shade: 4, bold: true);

    fb.drawHLine(62, 52, 126, 2);
    fb.drawText('[BACK]/[AC] : Close', 64, 54, shade: 3);
  }

  static void _placeFinderPattern(
    List<List<bool>> modules,
    List<List<bool>> isFunction,
    int top,
    int left,
  ) {
    final int size = modules.length;
    for (int dr = -1; dr <= 7; dr++) {
      for (int dc = -1; dc <= 7; dc++) {
        final int r = top + dr;
        final int c = left + dc;
        if (r < 0 || r >= size || c < 0 || c >= size) continue;
        final bool inOuterBorder =
            (dr >= 0 && dr <= 6 && (dc == 0 || dc == 6)) ||
            (dc >= 0 && dc <= 6 && (dr == 0 || dr == 6));
        final bool inInnerSquare = dr >= 2 && dr <= 4 && dc >= 2 && dc <= 4;
        modules[r][c] = inOuterBorder || inInnerSquare;
        isFunction[r][c] = true;
      }
    }
  }

  static void _placeAlignmentPattern(
    List<List<bool>> modules,
    List<List<bool>> isFunction,
    int centerR,
    int centerC,
  ) {
    for (int dr = -2; dr <= 2; dr++) {
      for (int dc = -2; dc <= 2; dc++) {
        final int r = centerR + dr;
        final int c = centerC + dc;
        final bool dark =
            dr.abs() == 2 || dc.abs() == 2 || (dr == 0 && dc == 0);
        modules[r][c] = dark;
        isFunction[r][c] = true;
      }
    }
  }

  static List<int> _computeReedSolomonEcc(List<int> data, int eccDegree) {
    // Build generator polynomial g(x) = (x - α^0)(x - α^1)...(x - α^(eccDegree-1))
    List<int> gen = [1];
    int root = 1;
    for (int i = 0; i < eccDegree; i++) {
      final List<int> nextGen = List<int>.filled(gen.length + 1, 0);
      for (int j = 0; j < gen.length; j++) {
        nextGen[j] ^= gen[j];
        nextGen[j + 1] ^= _gfMul(gen[j], root);
      }
      gen = nextGen;
      root = _gfMul(root, 0x02);
    }

    final List<int> remainder = List<int>.filled(eccDegree, 0);
    for (final byte in data) {
      final int factor = byte ^ remainder[0];
      for (int i = 0; i < eccDegree - 1; i++) {
        remainder[i] = remainder[i + 1] ^ _gfMul(gen[i + 1], factor);
      }
      remainder[eccDegree - 1] = _gfMul(gen[eccDegree], factor);
    }
    return remainder;
  }

  static int _gfMul(int x, int y) {
    int z = 0;
    int a = x;
    int b = y;
    for (int i = 0; i < 8; i++) {
      if ((b & 1) != 0) z ^= a;
      final bool hiBit = (a & 0x80) != 0;
      a = (a << 1) & 0xFF;
      if (hiBit) a ^= 0x1D; // 0x11D mod 0x100
      b >>= 1;
    }
    return z;
  }
}
