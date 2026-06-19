enum WarningType {
  closedOnVisit,
  closingTooSoon,
  tightConnection,
  noHotelForDay,
}

enum WarningSeverity { error, warning }

class Warning {
  final WarningType type;
  final WarningSeverity severity;
  final String spotId;
  final String spotName;
  final String message;

  Warning({
    required this.type,
    required this.severity,
    required this.spotId,
    required this.spotName,
    required this.message,
  });
}

class DayItemState {
  final String spotId;
  final String spotName;
  final int? startTimeMinutes;
  final int? endTimeMinutes;
  final List<OpeningHoursState> openingHours;
  final int dayOfWeek;
  final int? dayNumber;
  final int? transportToNextMinutes;

  DayItemState({
    required this.spotId,
    required this.spotName,
    this.startTimeMinutes,
    this.endTimeMinutes,
    required this.openingHours,
    required this.dayOfWeek,
    this.dayNumber,
    this.transportToNextMinutes,
  });
}

class OpeningHoursState {
  final int day;
  final int openMinutes;
  final int closeMinutes;

  OpeningHoursState({
    required this.day,
    required this.openMinutes,
    required this.closeMinutes,
  });
}

class HotelStayState {
  final Set<int> dayNumbers;

  HotelStayState({required this.dayNumbers});
}

class ItineraryState {
  final List<DayItemState> dayItems;
  final List<HotelStayState> hotelStays;

  ItineraryState({required this.dayItems, required this.hotelStays});
}

class WarningEngine {
  static List<Warning> computeWarnings(
    ItineraryState state, {
    int closingThresholdMinutes = 30,
    int tightConnectionMinutes = 10,
  }) {
    final warnings = <Warning>[];

    for (final item in state.dayItems) {
      if (item.startTimeMinutes == null || item.endTimeMinutes == null) continue;

      final todayHours =
          item.openingHours.where((h) => h.day == item.dayOfWeek);
      for (final hours in todayHours) {
        if (item.startTimeMinutes! < hours.openMinutes ||
            item.endTimeMinutes! > hours.closeMinutes) {
          warnings.add(Warning(
            type: WarningType.closedOnVisit,
            severity: WarningSeverity.error,
            spotId: item.spotId,
            spotName: item.spotName,
            message: '${item.spotName} scheduled outside opening hours',
          ));
        } else if (hours.closeMinutes - item.endTimeMinutes! <
            closingThresholdMinutes) {
          warnings.add(Warning(
            type: WarningType.closingTooSoon,
            severity: WarningSeverity.warning,
            spotId: item.spotId,
            spotName: item.spotName,
            message:
                '${item.spotName} visit ends within ${closingThresholdMinutes}min of closing',
          ));
        }
      }
    }

    for (var i = 0; i < state.dayItems.length - 1; i++) {
      final current = state.dayItems[i];
      final next = state.dayItems[i + 1];
      if (current.endTimeMinutes == null || next.startTimeMinutes == null) {
        continue;
      }
      if (current.transportToNextMinutes == null) continue;

      final arrivalTime =
          current.endTimeMinutes! + current.transportToNextMinutes!;
      final gap = next.startTimeMinutes! - arrivalTime;
      if (gap < tightConnectionMinutes) {
        warnings.add(Warning(
          type: WarningType.tightConnection,
          severity: WarningSeverity.warning,
          spotId: next.spotId,
          spotName: next.spotName,
          message: 'Only ${gap}min gap before ${next.spotName} after transport',
        ));
      }
    }

    final dayNumbers = state.dayItems
        .where((i) => i.dayNumber != null)
        .map((i) => i.dayNumber!)
        .toSet();
    final hotelDays = state.hotelStays.expand((h) => h.dayNumbers).toSet();
    for (final day in dayNumbers) {
      if (!hotelDays.contains(day)) {
        warnings.add(Warning(
          type: WarningType.noHotelForDay,
          severity: WarningSeverity.warning,
          spotId: '',
          spotName: '',
          message: 'No hotel assigned for day $day',
        ));
      }
    }

    return warnings;
  }
}
