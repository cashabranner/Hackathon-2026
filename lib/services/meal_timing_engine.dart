import '../models/training_session.dart';
import '../models/user_profile.dart';

enum MealTimingKind {
  breakfast,
  lunch,
  dinner,
  preWorkoutMeal,
  preWorkoutSnack,
  postWorkoutMeal,
}

class MealTimingRecommendation {
  final String label;
  final String detail;
  final DateTime time;
  final MealTimingKind kind;
  final TrainingSession? session;

  const MealTimingRecommendation({
    required this.label,
    required this.detail,
    required this.time,
    required this.kind,
    this.session,
  });
}

class MealTimingEngine {
  static const _defaultWakeMinute = 7 * 60;
  static const _defaultSleepMinute = 23 * 60;

  static List<MealTimingRecommendation> buildDailyPlan({
    required DateTime day,
    required List<TrainingSession> sessions,
    required UserProfile? profile,
  }) {
    final wakeAt = _dateWithMinute(
      day,
      profile?.wakeMinuteOfDay ?? _defaultWakeMinute,
    );
    var sleepAt = _dateWithMinute(
      day,
      profile?.sleepMinuteOfDay ?? _defaultSleepMinute,
    );
    if (!sleepAt.isAfter(wakeAt)) {
      sleepAt = sleepAt.add(const Duration(days: 1));
    }

    final activeMinutes = sleepAt.difference(wakeAt).inMinutes;
    final candidates = <MealTimingRecommendation>[
      _recommendation(
        label: 'Breakfast',
        detail: 'Start the day with a balanced meal.',
        time: wakeAt.add(const Duration(minutes: 45)),
        kind: MealTimingKind.breakfast,
      ),
      _recommendation(
        label: 'Lunch',
        detail: 'Midday fuel keeps glycogen moving.',
        time: wakeAt.add(Duration(minutes: (activeMinutes * 0.42).round())),
        kind: MealTimingKind.lunch,
      ),
      _recommendation(
        label: 'Dinner',
        detail: 'A final meal before the overnight fast.',
        time: sleepAt.subtract(const Duration(hours: 2, minutes: 30)),
        kind: MealTimingKind.dinner,
      ),
    ];

    for (final session in sessions) {
      if (!_sameWakingDay(session.plannedAt, wakeAt, sleepAt)) continue;
      candidates.addAll([
        _recommendation(
          label: 'Pre-workout meal',
          detail: '${session.displayName}: eat 2-3 hours before training.',
          time: session.plannedAt.subtract(const Duration(hours: 2)),
          kind: MealTimingKind.preWorkoutMeal,
          session: session,
        ),
        _recommendation(
          label: 'Pre-workout snack',
          detail: '${session.displayName}: quick carbs 30-60 minutes out.',
          time: session.plannedAt.subtract(const Duration(minutes: 45)),
          kind: MealTimingKind.preWorkoutSnack,
          session: session,
        ),
        _recommendation(
          label: 'Recovery meal',
          detail: '${session.displayName}: carbs and protein after training.',
          time: session.plannedAt
              .add(Duration(minutes: session.durationMinutes + 45)),
          kind: MealTimingKind.postWorkoutMeal,
          session: session,
        ),
      ]);
    }

    final inWindow = candidates
        .where((item) => _sameWakingDay(item.time, wakeAt, sleepAt))
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    return _mergeNearby(inWindow);
  }

  static MealTimingRecommendation _recommendation({
    required String label,
    required String detail,
    required DateTime time,
    required MealTimingKind kind,
    TrainingSession? session,
  }) {
    final roundedMinute = ((time.minute + 7) ~/ 15) * 15;
    final rounded = DateTime(time.year, time.month, time.day, time.hour)
        .add(Duration(minutes: roundedMinute));
    return MealTimingRecommendation(
      label: label,
      detail: detail,
      time: rounded,
      kind: kind,
      session: session,
    );
  }

  static List<MealTimingRecommendation> _mergeNearby(
    List<MealTimingRecommendation> recommendations,
  ) {
    final merged = <MealTimingRecommendation>[];
    for (final item in recommendations) {
      final existingIndex = merged.indexWhere(
        (existing) => existing.time.difference(item.time).inMinutes.abs() <= 35,
      );
      if (existingIndex == -1) {
        merged.add(item);
        continue;
      }

      if (_priority(item.kind) > _priority(merged[existingIndex].kind)) {
        merged[existingIndex] = item;
      }
    }
    merged.sort((a, b) => a.time.compareTo(b.time));
    return merged;
  }

  static int _priority(MealTimingKind kind) => switch (kind) {
        MealTimingKind.preWorkoutMeal => 4,
        MealTimingKind.preWorkoutSnack => 4,
        MealTimingKind.postWorkoutMeal => 4,
        MealTimingKind.breakfast => 2,
        MealTimingKind.lunch => 2,
        MealTimingKind.dinner => 2,
      };

  static DateTime _dateWithMinute(DateTime day, int minuteOfDay) {
    final clamped = minuteOfDay.clamp(0, 23 * 60 + 59).toInt();
    return DateTime(day.year, day.month, day.day, clamped ~/ 60, clamped % 60);
  }

  static bool _sameWakingDay(
    DateTime value,
    DateTime wakeAt,
    DateTime sleepAt,
  ) {
    return !value.isBefore(wakeAt) && !value.isAfter(sleepAt);
  }
}
