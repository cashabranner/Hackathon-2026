import 'package:flutter_test/flutter_test.dart';
import 'package:fuelwindow/models/training_session.dart';
import 'package:fuelwindow/models/user_profile.dart';
import 'package:fuelwindow/services/meal_timing_engine.dart';

UserProfile _profile({int? wakeMinuteOfDay, int? sleepMinuteOfDay}) {
  return UserProfile(
    id: 'u',
    name: 'Athlete',
    ageYears: 28,
    sex: BiologicalSex.male,
    heightCm: 180,
    weightKg: 80,
    activityBaseline: ActivityBaseline.moderatelyActive,
    wakeMinuteOfDay: wakeMinuteOfDay,
    sleepMinuteOfDay: sleepMinuteOfDay,
    createdAt: DateTime(2026),
  );
}

TrainingSession _session(DateTime plannedAt) {
  return TrainingSession(
    id: 's',
    userId: 'u',
    type: SessionType.legs,
    plannedAt: plannedAt,
    durationMinutes: 60,
    intensity: SessionIntensity.moderate,
  );
}

void main() {
  test('Builds daily meals inside the user wake and sleep window', () {
    final plan = MealTimingEngine.buildDailyPlan(
      day: DateTime(2026, 4, 26),
      sessions: const [],
      profile: _profile(wakeMinuteOfDay: 6 * 60, sleepMinuteOfDay: 22 * 60),
    );

    expect(plan.map((item) => item.label), containsAll(['Breakfast', 'Lunch']));
    expect(plan.first.time.hour, greaterThanOrEqualTo(6));
    expect(plan.last.time.hour, lessThanOrEqualTo(22));
  });

  test('Adds workout-relative meal timing recommendations', () {
    final plan = MealTimingEngine.buildDailyPlan(
      day: DateTime(2026, 4, 26),
      sessions: [_session(DateTime(2026, 4, 26, 17))],
      profile: _profile(wakeMinuteOfDay: 7 * 60, sleepMinuteOfDay: 23 * 60),
    );

    final byKind = {for (final item in plan) item.kind: item};
    expect(byKind[MealTimingKind.preWorkoutMeal]?.time.hour, 15);
    expect(byKind[MealTimingKind.preWorkoutSnack]?.time.hour, 16);
    expect(byKind[MealTimingKind.postWorkoutMeal]?.time.hour, 18);
  });
}
