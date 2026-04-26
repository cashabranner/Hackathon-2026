class WorkoutSplit {
  final String id;
  final String name;
  final List<SplitExercise> exercises;

  const WorkoutSplit({
    required this.id,
    required this.name,
    required this.exercises,
  });

  List<String> get muscles {
    return exercises.expand((exercise) => exercise.muscles).toSet().toList();
  }

  WorkoutSplit copyWith({
    String? id,
    String? name,
    List<SplitExercise>? exercises,
  }) {
    return WorkoutSplit(
      id: id ?? this.id,
      name: name ?? this.name,
      exercises: exercises ?? this.exercises,
    );
  }
}

class SplitExercise {
  final String name;
  final List<String> muscles;
  final int sets;
  final String reps;

  const SplitExercise({
    required this.name,
    required this.muscles,
    required this.sets,
    required this.reps,
  });

  SplitExercise copyWith({
    String? name,
    List<String>? muscles,
    int? sets,
    String? reps,
  }) {
    return SplitExercise(
      name: name ?? this.name,
      muscles: muscles ?? this.muscles,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
    );
  }
}

class ExerciseTemplate {
  final String name;
  final List<String> muscles;
  final int defaultSets;
  final String defaultReps;

  const ExerciseTemplate({
    required this.name,
    required this.muscles,
    this.defaultSets = 3,
    this.defaultReps = '8-12',
  });
}

const exerciseTemplates = [
  ExerciseTemplate(
    name: 'Bench Press',
    muscles: ['Chest', 'Triceps', 'Front Delts'],
    defaultSets: 4,
    defaultReps: '8-10',
  ),
  ExerciseTemplate(
    name: 'Barbell Squat',
    muscles: ['Quads', 'Glutes', 'Hamstrings', 'Core'],
    defaultSets: 4,
    defaultReps: '6-8',
  ),
  ExerciseTemplate(
    name: 'Deadlift',
    muscles: ['Back', 'Glutes', 'Hamstrings', 'Core', 'Traps'],
    defaultSets: 3,
    defaultReps: '5',
  ),
  ExerciseTemplate(
    name: 'Overhead Press',
    muscles: ['Front Delts', 'Triceps', 'Core'],
    defaultSets: 4,
    defaultReps: '6-8',
  ),
  ExerciseTemplate(
    name: 'Pull-Up',
    muscles: ['Back', 'Biceps', 'Core'],
    defaultSets: 3,
    defaultReps: '6-10',
  ),
  ExerciseTemplate(
    name: 'Romanian Deadlift',
    muscles: ['Hamstrings', 'Glutes', 'Back'],
    defaultSets: 3,
    defaultReps: '8-10',
  ),
  ExerciseTemplate(
    name: 'Walking Lunge',
    muscles: ['Quads', 'Glutes', 'Hamstrings'],
    defaultSets: 3,
    defaultReps: '10/leg',
  ),
  ExerciseTemplate(
    name: 'Row',
    muscles: ['Back', 'Biceps', 'Rear Delts'],
    defaultSets: 4,
    defaultReps: '8-12',
  ),
];
