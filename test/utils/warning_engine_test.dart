import 'package:flutter_test/flutter_test.dart';
import 'package:myroad/utils/warning_engine.dart';

void main() {
  test('closedOnVisit warning when spot visited outside hours', () {
    final state = ItineraryState(
      dayItems: [
        DayItemState(
          spotId: 's1',
          spotName: 'Museum',
          startTimeMinutes: 18 * 60,
          endTimeMinutes: 19 * 60,
          openingHours: [
            OpeningHoursState(day: 1, openMinutes: 9 * 60, closeMinutes: 17 * 60),
          ],
          dayOfWeek: 1,
        ),
      ],
      hotelStays: [],
    );

    final warnings = WarningEngine.computeWarnings(state);
    expect(warnings.any((w) => w.type == WarningType.closedOnVisit), isTrue);
  });

  test('closingTooSoon warning when visit ends near closing', () {
    final state = ItineraryState(
      dayItems: [
        DayItemState(
          spotId: 's1',
          spotName: 'Temple',
          startTimeMinutes: 16 * 60,
          endTimeMinutes: 16 * 60 + 50,
          openingHours: [
            OpeningHoursState(day: 1, openMinutes: 9 * 60, closeMinutes: 17 * 60),
          ],
          dayOfWeek: 1,
        ),
      ],
      hotelStays: [],
    );

    final warnings =
        WarningEngine.computeWarnings(state, closingThresholdMinutes: 30);
    expect(warnings.any((w) => w.type == WarningType.closingTooSoon), isTrue);
  });

  test('noHotelForDay warning', () {
    final state = ItineraryState(
      dayItems: [
        DayItemState(
          spotId: 's1',
          spotName: 'Park',
          startTimeMinutes: 10 * 60,
          endTimeMinutes: 12 * 60,
          openingHours: [],
          dayOfWeek: 1,
          dayNumber: 1,
        ),
      ],
      hotelStays: [],
    );

    final warnings = WarningEngine.computeWarnings(state);
    expect(warnings.any((w) => w.type == WarningType.noHotelForDay), isTrue);
  });

  test('tightConnection warning', () {
    final state = ItineraryState(
      dayItems: [
        DayItemState(
          spotId: 's1',
          spotName: 'A',
          startTimeMinutes: 10 * 60,
          endTimeMinutes: 11 * 60,
          openingHours: [],
          dayOfWeek: 1,
          transportToNextMinutes: 30,
        ),
        DayItemState(
          spotId: 's2',
          spotName: 'B',
          startTimeMinutes: 11 * 60 + 5,
          endTimeMinutes: 12 * 60,
          openingHours: [],
          dayOfWeek: 1,
        ),
      ],
      hotelStays: [],
    );

    final warnings =
        WarningEngine.computeWarnings(state, tightConnectionMinutes: 10);
    expect(warnings.any((w) => w.type == WarningType.tightConnection), isTrue);
  });

  test('no warnings when everything is fine', () {
    final state = ItineraryState(
      dayItems: [
        DayItemState(
          spotId: 's1',
          spotName: 'Cafe',
          startTimeMinutes: 10 * 60,
          endTimeMinutes: 11 * 60,
          openingHours: [
            OpeningHoursState(day: 1, openMinutes: 8 * 60, closeMinutes: 22 * 60),
          ],
          dayOfWeek: 1,
          dayNumber: 1,
        ),
      ],
      hotelStays: [HotelStayState(dayNumbers: {1})],
    );

    final warnings = WarningEngine.computeWarnings(state);
    expect(warnings, isEmpty);
  });
}
