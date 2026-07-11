import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Ratchet test, not a ban: hardcoded width/height literals are how the
// builder-view day-column drift bug happened (see cf9dfd6) — a pitch value
// duplicated across widgets silently went out of sync. Most width/height
// literals are harmless one-off spacers though, so this only stops the
// count from growing, and gets lowered as real duplicates get cleaned up:
//   194 -> 174  spot_detail_screen.dart preview/thumbnail/swatch sizes
//   174 -> 173  transport_edit_sheet.dart's copy-pasted mode dropdown
//               (merged into _ModeDropdown, also de-duped _modeIcon)
//   173 -> 168  itinerary_builder_stage.dart's pass-dialog field gaps
//   168 -> 166  hotel_config_stage.dart's hotel-bar track/overlay height
//               (this file also had a real bug: bar position/width were
//               computed from MediaQuery screen width minus a guessed 64px
//               of chrome instead of the widget's actual LayoutBuilder
//               constraints — fixed alongside, not counted by this regex)
//   166 -> 168  transport_edit_sheet.dart's map route button gap (+1),
//               spot_detail_screen.dart's spot-link field gap (+1)
void main() {
  test('width/height magic number literals in lib/ do not increase', () {
    final pattern = RegExp(r'(width|height): ?[0-9]+(\.[0-9]+)?');
    var count = 0;
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart') || entity.path.endsWith('.g.dart'))
        continue;
      count += pattern.allMatches(entity.readAsStringSync()).length;
    }

    const baseline = 168;
    expect(
      count,
      lessThanOrEqualTo(baseline),
      reason:
          'New hardcoded width/height literal(s) in lib/ (found $count, baseline $baseline). '
          'One-off spacer? Bump the baseline. Needs to stay in sync with another '
          "widget's layout (a day-column pitch, a rail width)? Extract a shared "
          'constant instead of a new literal.',
    );
  });
}
