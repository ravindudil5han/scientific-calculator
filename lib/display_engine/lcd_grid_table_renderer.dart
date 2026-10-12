import 'dart:math' as math;
import '../core/calculator_theme.dart';
import 'lcd_bitmap_font.dart';

/// Data model for the reusable 2D Matrix / Table / Spreadsheet LCD Grid Editor.
class LcdGridTableModel {
  /// Top banner title (e.g., `MatA (3×3)`, `1-Variable`, `Table [f(x), g(x)]`, `Spreadsheet`).
  final String title;

  /// Column header labels (e.g., `['1', '2', '3']`, `['x', 'Freq']`, `['A', 'B', 'C', 'D', 'E']`).
  final List<String> columnHeaders;

  /// Row header labels (e.g., `['1', '2', '3']`).
  final List<String> rowHeaders;

  /// 2D cell display strings `[row][col]`.
  final List<List<String>> cells;

  /// Active highlighted row index (0-based).
  final int activeRow;

  /// Active highlighted column index (0-based).
  final int activeCol;

  /// Bottom cell input / formula line text (e.g. `A1 = 12.5` or live editing buffer).
  final String bottomInputBarText;

  /// Whether the user is actively typing into the bottom cell input line.
  final bool isEditingCell;

  const LcdGridTableModel({
    required this.title,
    required this.columnHeaders,
    required this.rowHeaders,
    required this.cells,
    this.activeRow = 0,
    this.activeCol = 0,
    required this.bottomInputBarText,
    this.isEditingCell = false,
  });
}

/// Renders the specialized 2D Grid/Table Editor, Multi-Line Solver Summary,
/// and Visual Number Line onto the 192 × 63 4-shade `LcdFrameBuffer`.
class LcdGridTableRenderer {
  /// Renders a 2D matrix/table/spreadsheet grid onto [fb] (`y: 9..62`) and returns
  /// `(hasLeftOverflow, hasRightOverflow, canScrollUp, canScrollDown)`.
  static ({
    bool leftOverflow,
    bool rightOverflow,
    bool upOverflow,
    bool downOverflow,
  }) renderGrid(
    LcdFrameBuffer fb,
    LcdGridTableModel model, {
    bool cursorVisible = true,
  }) {
    final int numRows = model.rowHeaders.length;
    final int numCols = model.columnHeaders.length;
    if (numRows == 0 || numCols == 0) {
      fb.drawText(model.title, 4, 12, shade: 4, bold: true);
      return (
        leftOverflow: false,
        rightOverflow: false,
        upOverflow: false,
        downOverflow: false,
      );
    }

    final int curRow = model.activeRow.clamp(0, numRows - 1);
    final int curCol = model.activeCol.clamp(0, numCols - 1);

    // Viewport geometry:
    // y: 9..17 (9px): Title + Column Headers bar
    // y: 18..49 (32px): Up to 3 visible data rows (10px each)
    // y: 51..62 (12px): Bottom cell formula / input line
    const int rowHeaderW = 20;
    const int visibleColsMax = 3;
    const int visibleRowsMax = 3;

    final int visCols = math.min(numCols, visibleColsMax);
    final int colW = (166 ~/ visCols).clamp(36, 160);

    final int colStart = curCol >= visCols ? (curCol - visCols + 1) : 0;
    final int rowStart =
        curRow >= visibleRowsMax ? (curRow - visibleRowsMax + 1) : 0;

    // 1. Top-left corner badge (shows short title or row/col corner) + Column headers
    fb.fillRect(0, 9, Cal_Theme.lcdWidth, 9, 2);
    final String cornerTag = model.title.length > 3
        ? model.title.substring(0, 3)
        : model.title;
    fb.drawText(cornerTag, 2, 10, shade: 0);
    fb.drawVLine(rowHeaderW, 9, 41, 3);

    for (int vc = 0; vc < visCols; vc++) {
      final int cIdx = colStart + vc;
      if (cIdx >= numCols) break;
      final int cellX = rowHeaderW + 1 + vc * colW;
      final String colTitle = model.columnHeaders[cIdx];
      final int textW = fb.measureText(colTitle, bold: true);
      final int tx = cellX + ((colW - textW) ~/ 2).clamp(1, colW);
      fb.drawText(colTitle, tx, 10, shade: 0, bold: true);
      fb.drawVLine(cellX + colW, 9, 41, 2);
    }

    // 2. Render visible data rows (y: 19, 29, 39)
    for (int vr = 0; vr < visibleRowsMax; vr++) {
      final int rIdx = rowStart + vr;
      if (rIdx >= numRows) break;
      final int rowY = 19 + vr * 10;

      // Row header cell on left (x: 0..rowHeaderW-1)
      fb.fillRect(0, rowY, rowHeaderW, 10, rIdx == curRow ? 3 : 1);
      fb.drawText(
        model.rowHeaders[rIdx],
        2,
        rowY + 1,
        shade: rIdx == curRow ? 0 : 4,
      );
      fb.drawHLine(0, rowY + 9, rowHeaderW + visCols * colW, 1);

      for (int vc = 0; vc < visCols; vc++) {
        final int cIdx = colStart + vc;
        if (cIdx >= numCols) break;
        final int cellX = rowHeaderW + 1 + vc * colW;
        final bool isSelected = (rIdx == curRow && cIdx == curCol);

        final String rawVal =
            (rIdx < model.cells.length && cIdx < model.cells[rIdx].length)
                ? model.cells[rIdx][cIdx]
                : '0';
        final int maxChars = (colW ~/ 6).clamp(4, 14);
        final String clipped = rawVal.length > maxChars
            ? rawVal.substring(0, maxChars)
            : rawVal;

        if (isSelected) {
          // Active highlighted cell with inverted contrast cursor
          fb.fillRect(cellX, rowY, colW - 1, 9, 4);
          fb.drawText(clipped, cellX + 2, rowY + 1, shade: 0, bold: true);
        } else {
          fb.drawText(clipped, cellX + 2, rowY + 1, shade: 4);
        }
      }
    }

    // 3. Proportional vertical scrollbar on right edge (x: 188, y: 19..48)
    fb.fillRect(188, 19, 3, 30, 1);
    final int thumbH = (30 ~/ numRows).clamp(5, 30);
    final int thumbY = 19 +
        (numRows > 1 ? (curRow * (30 - thumbH)) ~/ (numRows - 1) : 0);
    fb.fillRect(188, thumbY, 3, thumbH, 4);

    // 4. Bottom Cell Formula / Input Line (y: 50..62)
    fb.drawHLine(0, 50, Cal_Theme.lcdWidth, 3);
    fb.fillRect(0, 51, Cal_Theme.lcdWidth, 12, 0);
    final String barText = model.bottomInputBarText.length > 30
        ? '...${model.bottomInputBarText.substring(model.bottomInputBarText.length - 27)}'
        : model.bottomInputBarText;
    fb.drawText(barText, 3, 53, shade: 4, bold: model.isEditingCell);

    if (model.isEditingCell && cursorVisible) {
      final int cursorX =
          (3 + fb.measureText(barText, bold: true) + 1).clamp(3, 186);
      fb.fillRect(cursorX, 52, 2, 9, 4);
    }

    return (
      leftOverflow: colStart > 0,
      rightOverflow: (colStart + visCols) < numCols,
      upOverflow: curRow > 0,
      downOverflow: curRow < numRows - 1,
    );
  }

  /// Renders a scrollable multi-line solver / summary screen (e.g. Polynomial roots,
  /// Simultaneous solutions, 1-VAR / 2-VAR Statistics, Distribution output, or Math Box).
  static void renderMultiLineResults(
    LcdFrameBuffer fb, {
    required String title,
    required List<String> lines,
    required int selectedIndex,
  }) {
    fb.fillRect(0, 9, Cal_Theme.lcdWidth, 10, 2);
    final String clippedTitle =
        title.length > 30 ? title.substring(0, 30) : title;
    fb.drawText(clippedTitle, 4, 10, shade: 0, bold: true);

    if (lines.isEmpty) {
      fb.drawText('Press [EXE] to solve', 24, 32, shade: 3);
      return;
    }

    final int clamped = selectedIndex.clamp(0, lines.length - 1);
    final int winStart = clamped >= 3 ? clamped - 3 : 0;

    for (int i = 0; i < 4; i++) {
      final int idx = winStart + i;
      if (idx >= lines.length) break;
      final bool isSel = idx == clamped;
      final int rowY = 20 + i * 10;
      final String text = lines[idx].length > 29
          ? lines[idx].substring(0, 29)
          : lines[idx];
      if (isSel) {
        fb.fillRect(2, rowY, 182, 10, 4);
        fb.drawText(text, 5, rowY + 1, shade: 0, bold: true);
      } else {
        fb.drawText(text, 5, rowY + 1, shade: 4);
      }
    }

    fb.fillRect(187, 20, 3, 40, 1);
    final int thumbH = (40 ~/ lines.length).clamp(6, 40);
    final int thumbY = 20 +
        (lines.length > 1
            ? (clamped * (40 - thumbH)) ~/ (lines.length - 1)
            : 0);
    fb.fillRect(187, thumbY, 3, thumbH, 4);
  }

  /// Renders the `Math Box -> Number Line` graphical interval view on the 4-shade LCD.
  static void renderNumberLine(
    LcdFrameBuffer fb, {
    required String inequalitySummary,
    required List<double> criticalPoints,
    required bool closedEndpoints,
  }) {
    fb.fillRect(0, 9, Cal_Theme.lcdWidth, 10, 2);
    fb.drawText('NUMBER LINE', 4, 10, shade: 0, bold: true);

    // Draw main horizontal number line axis at y = 38
    const int axisY = 38;
    fb.drawHLine(12, axisY, 168, 4);
    // Left and right axis arrowheads
    fb.setPixel(13, axisY - 1, 4);
    fb.setPixel(13, axisY + 1, 4);
    fb.setPixel(178, axisY - 1, 4);
    fb.setPixel(178, axisY + 1, 4);

    if (criticalPoints.isEmpty) {
      // Draw origin tick 0
      fb.drawVLine(96, axisY - 3, 7, 4);
      fb.drawText('0', 94, axisY + 5, shade: 4);
    } else {
      final int count = math.min(criticalPoints.length, 3);
      for (int i = 0; i < count; i++) {
        final int tickX = count == 1 ? 96 : (48 + i * (96 ~/ (count - 1)));
        fb.drawVLine(tickX, axisY - 2, 5, 4);

        // Draw open (○) or closed (●) interval marker at y = 27
        const int markerY = 27;
        fb.drawRectOutline(tickX - 2, markerY - 2, 5, 5, 4);
        if (closedEndpoints) {
          fb.fillRect(tickX - 1, markerY - 1, 3, 3, 4);
        }
        fb.drawVLine(tickX, markerY + 3, axisY - (markerY + 3), 3);

        final String ptStr = criticalPoints[i].toStringAsFixed(
          criticalPoints[i] == criticalPoints[i].roundToDouble() ? 0 : 1,
        );
        fb.drawText(ptStr, tickX - (ptStr.length * 3), axisY + 4, shade: 4);
      }
      // Draw ray connecting interval markers
      if (count >= 2) {
        fb.drawHLine(48, 27, 96, 4);
      } else {
        fb.drawHLine(96, 27, 65, 4);
      }
    }

    // Bottom solution summary banner
    fb.fillRect(0, 51, Cal_Theme.lcdWidth, 12, 1);
    fb.drawText(
      inequalitySummary.length > 30
          ? inequalitySummary.substring(0, 30)
          : inequalitySummary,
      4,
      53,
      shade: 4,
      bold: true,
    );
  }
}
