import 'package:flutter_test/flutter_test.dart';
import 'package:fuelwindow/models/user_profile.dart';
import 'package:fuelwindow/services/workout_preset_engine.dart';

void main() {
  test('Generated workout preset matches preferred days and duration', () {
    const prefs = WorkoutPreferences(
      gymDaysPerWeek: 5,
      preferredDurationMinutes: 75,
      muscleEmphases: ['Legs', 'Back'],
      preferredExercises: ['Front squat'],
    );

    final split = WorkoutPresetEngine.recommendedSplit(prefs);

    expect(split.name, contains('5-Day'));
    expect(split.exercises.first.name, 'Front squat');
    expect(split.exercises.first.sets, 4);
    expect(split.exercises.length, lessThanOrEqualTo(6));
  });

  test('Plan options fit available days from two through six days', () {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    for (var dayCount = 2; dayCount <= 6; dayCount++) {
      final days = weekdays.take(dayCount).toList();
      final options = WorkoutPresetEngine.planOptionsForDays(days);

      expect(options, hasLength(3));
      for (final option in options) {
        expect(option.routines, isNotEmpty);
        expect(option.schedule, hasLength(dayCount));
        expect(option.schedule.first, startsWith(days.first));
      }
    }
  });
}
