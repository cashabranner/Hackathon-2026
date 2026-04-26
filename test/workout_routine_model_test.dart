import 'package:flutter_test/flutter_test.dart';
import 'package:fuelwindow/models/training_session.dart';
import 'package:fuelwindow/models/workout_split.dart';

void main() {
  test('WorkoutRoutine loads legacy split JSON shape', () {
    final routine = WorkoutRoutine.fromJson(const {
      'id': 'legacy-push',
      'name': 'Push Day',
      'exercises': [
        {
          'name': 'Bench Press',
          'muscles': ['Chest', 'Triceps'],
          'sets': 4,
          'reps': '8-10',
          'notes': null,
        },
      ],
    });

    expect(routine.id, 'legacy-push');
    expect(routine.name, 'Push Day');
    expect(routine.exercises.single.sets, 4);
  });

  test('WeeklyWorkoutAssignment serializes and restores intensity', () {
    const assignment = WeeklyWorkoutAssignment(
      id: 'assign-1',
      routineId: 'push',
      weekday: DateTime.monday,
      minuteOfDay: 18 * 60,
      durationMinutes: 75,
      intensity: SessionIntensity.high,
    );

    final restored = WeeklyWorkoutAssignment.fromJson(assignment.toJson());

    expect(restored.id, assignment.id);
    expect(restored.routineId, assignment.routineId);
    expect(restored.weekday, DateTime.monday);
    expect(restored.minuteOfDay, 18 * 60);
    expect(restored.intensity, SessionIntensity.high);
  });
}
