import '../models/user_profile.dart';
import '../models/workout_split.dart';

class WorkoutPresetEngine {
  static List<WorkoutSplit> genericPresets() => const [
        WorkoutSplit(
          id: 'preset_full_body_3',
          name: '3-Day Full Body',
          exercises: [
            SplitExercise(
              name: 'Barbell Squat',
              muscles: ['Quads', 'Glutes', 'Hamstrings', 'Core'],
              sets: 4,
              reps: '6-8',
            ),
            SplitExercise(
              name: 'Bench Press',
              muscles: ['Chest', 'Triceps', 'Front Delts'],
              sets: 4,
              reps: '8-10',
            ),
            SplitExercise(
              name: 'Row',
              muscles: ['Back', 'Biceps', 'Rear Delts'],
              sets: 4,
              reps: '8-12',
            ),
          ],
        ),
        WorkoutSplit(
          id: 'preset_upper_lower_4',
          name: '4-Day Upper/Lower',
          exercises: [
            SplitExercise(
              name: 'Bench Press',
              muscles: ['Chest', 'Triceps', 'Front Delts'],
              sets: 4,
              reps: '6-10',
            ),
            SplitExercise(
              name: 'Pull-Up',
              muscles: ['Back', 'Biceps', 'Core'],
              sets: 3,
              reps: '6-10',
            ),
            SplitExercise(
              name: 'Barbell Squat',
              muscles: ['Quads', 'Glutes', 'Hamstrings', 'Core'],
              sets: 4,
              reps: '6-8',
            ),
            SplitExercise(
              name: 'Romanian Deadlift',
              muscles: ['Hamstrings', 'Glutes', 'Back'],
              sets: 3,
              reps: '8-10',
            ),
          ],
        ),
        WorkoutSplit(
          id: 'preset_ppl_5',
          name: '5-Day PPL + Upper/Lower',
          exercises: [
            SplitExercise(
              name: 'Bench Press',
              muscles: ['Chest', 'Triceps', 'Front Delts'],
              sets: 4,
              reps: '8-10',
            ),
            SplitExercise(
              name: 'Row',
              muscles: ['Back', 'Biceps', 'Rear Delts'],
              sets: 4,
              reps: '8-12',
            ),
            SplitExercise(
              name: 'Barbell Squat',
              muscles: ['Quads', 'Glutes', 'Hamstrings', 'Core'],
              sets: 4,
              reps: '6-8',
            ),
            SplitExercise(
              name: 'Overhead Press',
              muscles: ['Front Delts', 'Triceps', 'Core'],
              sets: 3,
              reps: '8-10',
            ),
          ],
        ),
        WorkoutSplit(
          id: 'preset_ppl_6',
          name: '6-Day Push/Pull/Legs',
          exercises: [
            SplitExercise(
              name: 'Bench Press',
              muscles: ['Chest', 'Triceps', 'Front Delts'],
              sets: 4,
              reps: '8-10',
            ),
            SplitExercise(
              name: 'Pull-Up',
              muscles: ['Back', 'Biceps', 'Core'],
              sets: 4,
              reps: '6-10',
            ),
            SplitExercise(
              name: 'Walking Lunge',
              muscles: ['Quads', 'Glutes', 'Hamstrings'],
              sets: 3,
              reps: '10/leg',
            ),
          ],
        ),
      ];

  static WorkoutSplit recommendedSplit(WorkoutPreferences prefs) {
    final days = prefs.gymDaysPerWeek.clamp(3, 6);
    final base = genericPresets().firstWhere(
      (split) => split.name.startsWith('$days-Day'),
      orElse: () => genericPresets()[1],
    );
    final preferredExercises = prefs.preferredExercises
        .map((exercise) => exercise.trim())
        .where((exercise) => exercise.isNotEmpty)
        .toList();
    final customExercises = preferredExercises.map(
      (name) => SplitExercise(
        name: name,
        muscles: prefs.muscleEmphases.isEmpty
            ? const ['Custom']
            : prefs.muscleEmphases,
        sets: prefs.preferredDurationMinutes >= 75 ? 4 : 3,
        reps: '8-12',
      ),
    );

    return WorkoutSplit(
      id: 'recommended_${days}_day',
      name: 'Recommended $days-Day Split',
      exercises: [
        ...customExercises,
        ...base.exercises,
      ].take(days >= 5 ? 6 : 4).toList(),
    );
  }
}
