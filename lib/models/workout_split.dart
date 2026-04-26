import 'training_session.dart';

class WorkoutRoutine {
  final String id;
  final String name;
  final List<SplitExercise> exercises;

  const WorkoutRoutine({
    required this.id,
    required this.name,
    required this.exercises,
  });

  List<String> get muscles {
    return exercises.expand((exercise) => exercise.muscles).toSet().toList();
  }

  WorkoutRoutine copyWith({
    String? id,
    String? name,
    List<SplitExercise>? exercises,
  }) {
    return WorkoutRoutine(
      id: id ?? this.id,
      name: name ?? this.name,
      exercises: exercises ?? this.exercises,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
      };

  factory WorkoutRoutine.fromJson(Map<String, dynamic> json) => WorkoutRoutine(
        id: json['id'] as String,
        name: json['name'] as String,
        exercises: (json['exercises'] as List? ?? const [])
            .map((item) => SplitExercise.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}

typedef WorkoutSplit = WorkoutRoutine;

class WeeklyWorkoutAssignment {
  final String id;
  final String routineId;
  final int weekday;
  final int minuteOfDay;
  final int durationMinutes;
  final SessionIntensity intensity;

  const WeeklyWorkoutAssignment({
    required this.id,
    required this.routineId,
    required this.weekday,
    required this.minuteOfDay,
    required this.durationMinutes,
    required this.intensity,
  });

  WeeklyWorkoutAssignment copyWith({
    String? id,
    String? routineId,
    int? weekday,
    int? minuteOfDay,
    int? durationMinutes,
    SessionIntensity? intensity,
  }) {
    return WeeklyWorkoutAssignment(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      weekday: weekday ?? this.weekday,
      minuteOfDay: minuteOfDay ?? this.minuteOfDay,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      intensity: intensity ?? this.intensity,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'routine_id': routineId,
        'weekday': weekday,
        'minute_of_day': minuteOfDay,
        'duration_minutes': durationMinutes,
        'intensity': intensity.name,
      };

  factory WeeklyWorkoutAssignment.fromJson(Map<String, dynamic> json) {
    return WeeklyWorkoutAssignment(
      id: json['id'] as String,
      routineId: json['routine_id'] as String,
      weekday: (json['weekday'] as num).toInt(),
      minuteOfDay: (json['minute_of_day'] as num?)?.toInt() ?? 17 * 60,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 60,
      intensity: SessionIntensity.values.byName(
        json['intensity'] as String? ?? SessionIntensity.moderate.name,
      ),
    );
  }
}

class SplitExercise {
  final String name;
  final List<String> muscles;
  final int sets;
  final String reps;
  final String? notes;

  const SplitExercise({
    required this.name,
    required this.muscles,
    required this.sets,
    required this.reps,
    this.notes,
  });

  SplitExercise copyWith({
    String? name,
    List<String>? muscles,
    int? sets,
    String? reps,
    String? notes,
  }) {
    return SplitExercise(
      name: name ?? this.name,
      muscles: muscles ?? this.muscles,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'muscles': muscles,
        'sets': sets,
        'reps': reps,
        'notes': notes,
      };

  factory SplitExercise.fromJson(Map<String, dynamic> json) => SplitExercise(
        name: json['name'] as String,
        muscles: List<String>.from(json['muscles'] as List? ?? const []),
        sets: json['sets'] as int,
        reps: json['reps'] as String,
        notes: json['notes'] as String?,
      );
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
