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
}
