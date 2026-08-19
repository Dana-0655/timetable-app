import 'package:flutter/material.dart';

/// Shared palette + color-assignment logic for swapped periods.
/// Colors are assigned by encounter order (not by hashing swap_id),
/// so unrelated swaps don't collide, and it's computed ONCE per
/// timetable fetch so the grid and bars views agree on colors.
class SwapColorPalette {
  static const List<Color> fill = [
    Color(0xFFB3E5FC),
    Color(0xFFC8E6C9),
    Color(0xFFFFF9C4),
    Color(0xFFF8BBD0),
    Color(0xFFD1C4E9),
    Color(0xFFFFCCBC),
    Color(0xFFB2DFDB),
    Color(0xFFDCEDC8),
  ];

  static const List<Color> border = [
    Color(0xFF81D4FA),
    Color(0xFFA5D6A7),
    Color(0xFFFFF59D),
    Color(0xFFF48FB1),
    Color(0xFFB39DDB),
    Color(0xFFFFAB91),
    Color(0xFF80CBC4),
    Color(0xFFC5E1A5),
  ];
}

const List<String> kWeekDays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

/// Walks entries in a fixed day order (then by period_no ascending) and
/// assigns each distinct swap_id the next palette index the first time
/// it's encountered. Call this once per timetable fetch in the parent
/// screen and pass the resulting map down to both the grid and bars
/// widgets so they render swaps with identical colors.
Map<int, int> buildSwapColorIndex(List<dynamic> entries) {
  final Map<int, int> index = {};

  for (final day in kWeekDays) {
    final dayEntries = entries.where((e) => e['day_of_week'] == day).toList()
      ..sort(
        (a, b) => (a['period_no'] as int? ?? 0).compareTo(
          b['period_no'] as int? ?? 0,
        ),
      );

    for (final entry in dayEntries) {
      if (entry['status_color'] == 'swapped' && entry['swap_id'] != null) {
        final swapId = entry['swap_id'] as int;
        if (!index.containsKey(swapId)) {
          index[swapId] = index.length % SwapColorPalette.fill.length;
        }
      }
    }
  }

  return index;
}

Color swapFillColor(
  Map<int, int> swapColorIndex,
  int swapId, {
  Color? fallback,
}) {
  final idx = swapColorIndex[swapId];
  return idx != null
      ? SwapColorPalette.fill[idx]
      : (fallback ?? Colors.blue.shade50);
}

Color swapBorderColor(
  Map<int, int> swapColorIndex,
  int swapId, {
  Color? fallback,
}) {
  final idx = swapColorIndex[swapId];
  return idx != null
      ? SwapColorPalette.border[idx]
      : (fallback ?? Colors.blue.shade300);
}
