import '../models/user_profile.dart';
import '../models/workout_split.dart';

class RoutinePlanOption {
  final String id;
  final String name;
  final String description;
  final List<WorkoutRoutine> routines;
  final List<String> schedule;

  const RoutinePlanOption({
    required this.id,
    required this.name,
    required this.description,
    required this.routines,
    required this.schedule,
  });
}

class WorkoutPresetEngine {
  static List<WorkoutRoutine> genericPresets() => const [
        WorkoutRoutine(
          id: 'preset_full_body_3',
          name: 'Full Body Routine',
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
        WorkoutRoutine(
          id: 'preset_upper_lower_4',
          name: 'Upper/Lower Routine',
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
        WorkoutRoutine(
          id: 'preset_ppl_5',
          name: 'Push/Pull/Legs Routine',
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
        WorkoutRoutine(
          id: 'preset_ppl_6',
          name: 'Push/Pull/Legs High Frequency',
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

  static WorkoutRoutine recommendedSplit(WorkoutPreferences prefs) {
    return recommendedRoutine(prefs);
  }

  static WorkoutRoutine recommendedRoutine(WorkoutPreferences prefs) {
    final days = prefs.gymDaysPerWeek.clamp(3, 6);
    final base = genericPresets().firstWhere(
      (routine) => routine.id.contains('_$days'),
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

    return WorkoutRoutine(
      id: 'recommended_${days}_day',
      name: 'Recommended $days-Day Routine',
      exercises: [
        ...customExercises,
        ...base.exercises,
      ].take(days >= 5 ? 6 : 4).toList(),
    );
  }

  static List<RoutinePlanOption> planOptionsForDays(List<String> weekdays) {
    final days = weekdays.isEmpty ? const ['Mon', 'Wed', 'Fri'] : weekdays;
    final count = days.length.clamp(2, 6);
    return [
      RoutinePlanOption(
        id: 'balanced_$count',
        name: 'Balanced Full Body',
        description: 'Simple repeatable sessions that train the whole body.',
        routines: _balancedRoutines(count),
        schedule: _roundRobin(days, _balancedRoutines(count)),
      ),
      RoutinePlanOption(
        id: 'upper_lower_$count',
        name: count <= 3 ? 'Full Body + Focus' : 'Upper / Lower',
        description: 'Alternates upper and lower emphasis for recovery.',
        routines: _upperLowerRoutines(count),
        schedule: _roundRobin(days, _upperLowerRoutines(count)),
      ),
      RoutinePlanOption(
        id: 'ppl_$count',
        name: count <= 3 ? 'Push Pull Legs' : 'Push Pull Legs Repeat',
        description: 'Classic muscle-group structure for clear progression.',
        routines: _pplRoutines(count),
        schedule: _roundRobin(days, _pplRoutines(count)),
      ),
    ];
  }

  static List<String> _roundRobin(
    List<String> weekdays,
    List<WorkoutRoutine> routines,
  ) {
    return [
      for (var i = 0; i < weekdays.length; i++)
        '${weekdays[i]}: ${routines[i % routines.length].name}',
    ];
  }

  static List<WorkoutRoutine> _balancedRoutines(int count) => [
        const WorkoutRoutine(
          id: 'generated_full_body_a',
          name: 'Full Body A',
          exercises: [
            SplitExercise(
              name: 'Barbell Squat',
              muscles: ['Quads', 'Glutes', 'Hamstrings', 'Core'],
              sets: 3,
              reps: '6-8',
            ),
            SplitExercise(
              name: 'Bench Press',
              muscles: ['Chest', 'Triceps', 'Front Delts'],
              sets: 3,
              reps: '8-10',
            ),
            SplitExercise(
              name: 'Row',
              muscles: ['Back', 'Biceps', 'Rear Delts'],
              sets: 3,
              reps: '8-12',
            ),
          ],
        ),
        const WorkoutRoutine(
          id: 'generated_full_body_b',
          name: 'Full Body B',
          exercises: [
            SplitExercise(
              name: 'Romanian Deadlift',
              muscles: ['Hamstrings', 'Glutes', 'Back'],
              sets: 3,
              reps: '8-10',
            ),
            SplitExercise(
              name: 'Overhead Press',
              muscles: ['Front Delts', 'Triceps', 'Core'],
              sets: 3,
              reps: '8-10',
            ),
            SplitExercise(
              name: 'Pull-Up',
              muscles: ['Back', 'Biceps', 'Core'],
              sets: 3,
              reps: '6-10',
            ),
          ],
        ),
      ];

  static List<WorkoutRoutine> _upperLowerRoutines(int count) => [
        const WorkoutRoutine(
          id: 'generated_upper',
          name: 'Upper Routine',
          exercises: [
            SplitExercise(
              name: 'Bench Press',
              muscles: ['Chest', 'Triceps', 'Front Delts'],
              sets: 4,
              reps: '6-10',
            ),
            SplitExercise(
              name: 'Row',
              muscles: ['Back', 'Biceps', 'Rear Delts'],
              sets: 4,
              reps: '8-12',
            ),
            SplitExercise(
              name: 'Overhead Press',
              muscles: ['Front Delts', 'Triceps', 'Core'],
              sets: 3,
              reps: '8-10',
            ),
          ],
        ),
        const WorkoutRoutine(
          id: 'generated_lower',
          name: 'Lower Routine',
          exercises: [
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
            SplitExercise(
              name: 'Walking Lunge',
              muscles: ['Quads', 'Glutes', 'Hamstrings'],
              sets: 3,
              reps: '10/leg',
            ),
          ],
        ),
      ];

  static List<WorkoutRoutine> _pplRoutines(int count) => [
        const WorkoutRoutine(
          id: 'generated_push',
          name: 'Push Routine',
          exercises: [
            SplitExercise(
              name: 'Bench Press',
              muscles: ['Chest', 'Triceps', 'Front Delts'],
              sets: 4,
              reps: '8-10',
            ),
            SplitExercise(
              name: 'Overhead Press',
              muscles: ['Front Delts', 'Triceps', 'Core'],
              sets: 3,
              reps: '8-10',
            ),
          ],
        ),
        const WorkoutRoutine(
          id: 'generated_pull',
          name: 'Pull Routine',
          exercises: [
            SplitExercise(
              name: 'Pull-Up',
              muscles: ['Back', 'Biceps', 'Core'],
              sets: 4,
              reps: '6-10',
            ),
            SplitExercise(
              name: 'Row',
              muscles: ['Back', 'Biceps', 'Rear Delts'],
              sets: 4,
              reps: '8-12',
            ),
          ],
        ),
        const WorkoutRoutine(
          id: 'generated_legs',
          name: 'Legs Routine',
          exercises: [
            SplitExercise(
              name: 'Barbell Squat',
              muscles: ['Quads', 'Glutes', 'Hamstrings', 'Core'],
              sets: 4,
              reps: '6-8',
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
}
