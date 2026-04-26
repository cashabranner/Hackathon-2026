import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../demo/demo_accounts.dart';
import '../models/food_catalog.dart';
import '../models/food_log.dart';
import '../models/metabolic_state.dart';
import '../models/nutrition_estimate.dart';
import '../models/training_session.dart';
import '../models/user_profile.dart';
import '../models/workout_split.dart';
import '../services/food_parser.dart';
import '../services/metabolic_engine.dart';
import '../services/prescription_engine.dart';
import '../services/workout_preset_engine.dart';
import '../models/fuel_prescription.dart';

/// Central app state managed as a ChangeNotifier.
/// Designed so the Supabase-backed layer slots in behind the same interface.
class AppState extends ChangeNotifier {
  static const _storageKey = 'fuel_app_state_v1';

  UserProfile? _profile;
  List<FoodLog> _foodLogs = [];
  List<SavedFood> _savedFoods = [];
  List<TrainingSession> _sessions = [];
  List<WorkoutRoutine> _workoutRoutines = [];
  List<WeeklyWorkoutAssignment> _weeklyWorkoutAssignments = [];
  Set<String> _deletedProjectedSessionIds = {};
  MetabolicState? _metabolicState;
  FuelPrescription? _prescription;
  ThemeMode _themeMode = ThemeMode.system;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;
  bool _isHydrated = false;
  bool _pendingGreeting = false;
  bool _isDemoMode = false;

  AppState() {
    _startClock();
  }

  // ─── Getters ─────────────────────────────────────────────────────────────

  UserProfile? get profile => _profile;
  List<FoodLog> get foodLogs => List.unmodifiable(_foodLogs);
  List<SavedFood> get savedFoods => List.unmodifiable(_savedFoods);
  List<TrainingSession> get sessions => List.unmodifiable(
        _mergedSessionsBetween(
          _now.subtract(const Duration(days: 14)),
          _now.add(const Duration(days: 45)),
        ),
      );
  List<TrainingSession> get concreteSessions => List.unmodifiable(_sessions);
  List<WorkoutRoutine> get workoutRoutines =>
      List.unmodifiable(_workoutRoutines);
  List<WorkoutRoutine> get workoutSplits => workoutRoutines;
  List<WeeklyWorkoutAssignment> get weeklyWorkoutAssignments =>
      List.unmodifiable(_weeklyWorkoutAssignments);
  MetabolicState? get metabolicState => _metabolicState;
  FuelPrescription? get prescription => _prescription;
  ThemeMode get themeMode => _themeMode;
  DateTime get now => _now;
  bool get isHydrated => _isHydrated;
  bool get pendingGreeting => _pendingGreeting;
  bool get isDemoMode => _isDemoMode;
  bool get hasProfile => _profile != null;

  TrainingSession? get nextSession {
    final upcoming = sessions.where((s) => s.plannedAt.isAfter(_now)).toList()
      ..sort((a, b) => a.plannedAt.compareTo(b.plannedAt));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  TrainingSession? get pendingPostWorkoutSummary {
    final due = _sessions
        .where((session) => session.postWorkoutSummaryDue(_now))
        .toList()
      ..sort((a, b) => a.plannedAt.compareTo(b.plannedAt));
    return due.isEmpty ? null : due.first;
  }

  Future<void> loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _profile = json['profile'] == null
          ? null
          : UserProfile.fromJson(json['profile'] as Map<String, dynamic>);
      _foodLogs = (json['food_logs'] as List? ?? const [])
          .map((item) => FoodLog.fromJson(item as Map<String, dynamic>))
          .toList();
      _savedFoods = (json['saved_foods'] as List? ?? const [])
          .map((item) => SavedFood.fromJson(item as Map<String, dynamic>))
          .toList();
      _sessions = (json['sessions'] as List? ?? const [])
          .map((item) => TrainingSession.fromJson(item as Map<String, dynamic>))
          .toList();
      _workoutRoutines = (json['workout_routines'] as List? ??
              json['workout_splits'] as List? ??
              const [])
          .map((item) => WorkoutRoutine.fromJson(item as Map<String, dynamic>))
          .toList();
      _weeklyWorkoutAssignments =
          (json['weekly_workout_assignments'] as List? ?? const [])
              .map((item) => WeeklyWorkoutAssignment.fromJson(
                    item as Map<String, dynamic>,
                  ))
              .toList();
      _deletedProjectedSessionIds = Set<String>.from(
        json['deleted_projected_session_ids'] as List? ?? const [],
      );
      _themeMode = ThemeMode.values.byName(
        json['theme_mode'] as String? ?? ThemeMode.system.name,
      );
      _isDemoMode = json['is_demo_mode'] as bool? ?? false;
      _pendingGreeting = _profile != null;
    }
    _now = DateTime.now();
    _isHydrated = true;
    _recompute();
    notifyListeners();
  }

  Future<void> persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode({
        'profile': _profile?.toJson(),
        'food_logs': _foodLogs.map((log) => log.toJson()).toList(),
        'saved_foods': _savedFoods.map((food) => food.toJson()).toList(),
        'sessions': _sessions.map((session) => session.toJson()).toList(),
        'workout_routines':
            _workoutRoutines.map((routine) => routine.toJson()).toList(),
        'workout_splits':
            _workoutRoutines.map((routine) => routine.toJson()).toList(),
        'weekly_workout_assignments': _weeklyWorkoutAssignments
            .map((assignment) => assignment.toJson())
            .toList(),
        'deleted_projected_session_ids': _deletedProjectedSessionIds.toList(),
        'is_demo_mode': _isDemoMode,
        'theme_mode': _themeMode.name,
      }),
    );
  }

  void _persistState() {
    unawaited(persistState());
  }

  void consumeGreeting() {
    if (!_pendingGreeting) return;
    _pendingGreeting = false;
    notifyListeners();
  }

  // ─── Onboarding ──────────────────────────────────────────────────────────

  void saveProfile(UserProfile profile) {
    _profile = profile;
    _isDemoMode = false;
    _pendingGreeting = false;
    addWorkoutPresetsFromPreferences(notify: false);
    _recompute();
    _persistState();
    notifyListeners();
  }

  void updateProfile(UserProfile profile) {
    _profile = profile;
    addWorkoutPresetsFromPreferences(notify: false);
    _recompute();
    _persistState();
    notifyListeners();
  }

  // ─── Demo mode ───────────────────────────────────────────────────────────

  void loadDemoAccount(DemoAccount demo) {
    _isDemoMode = true;
    _profile = demo.profile.copyWith(
      createdAt: DateTime.now().subtract(const Duration(hours: 48)),
    );
    _foodLogs = demo.foodLogs;
    _savedFoods = demo.savedFoods;
    _sessions = demo.sessions;
    _workoutRoutines = demo.workoutSplits;
    _weeklyWorkoutAssignments = [];
    _deletedProjectedSessionIds = {};
    _pendingGreeting = true;
    _now = DateTime.now();
    _recompute();
    _persistState();
    notifyListeners();
  }

  void clearDemo() {
    _isDemoMode = false;
    _profile = null;
    _foodLogs = [];
    _savedFoods = [];
    _sessions = [];
    _workoutRoutines = [];
    _weeklyWorkoutAssignments = [];
    _deletedProjectedSessionIds = {};
    _prescription = null;
    _metabolicState = null;
    _now = DateTime.now();
    _persistState();
    notifyListeners();
  }

  // ─── Food logging ─────────────────────────────────────────────────────────

  Future<void> logFood(
    String rawInput, {
    NutritionEstimate? nutrition,
    String? source,
    DateTime? loggedAt,
  }) async {
    if (_profile == null) return;

    NutritionEstimate resolvedNutrition;
    String resolvedSource;

    if (nutrition != null) {
      resolvedNutrition = nutrition;
      resolvedSource = source ?? 'local_fallback';
    } else {
      resolvedNutrition = FoodParser.parseText(
        rawInput,
        allergies: _profile!.allergies,
      );
      resolvedSource = 'local_fallback';
    }

    final log = FoodLog(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      userId: _profile!.id,
      rawInput: rawInput,
      loggedAt: loggedAt ?? _now,
      nutrition: resolvedNutrition,
      source: resolvedSource,
    );
    _foodLogs = [..._foodLogs, log];
    saveFoodFromNutrition(resolvedNutrition);
    _recompute();
    _persistState();
    notifyListeners();
  }

  Future<void> logSavedFood(SavedFood food) {
    return logFood(food.name, nutrition: food.nutrition, source: 'saved_food');
  }

  void saveFoodFromNutrition(NutritionEstimate nutrition) {
    if (nutrition.foodName.trim().isEmpty ||
        nutrition.carbsG + nutrition.proteinG + nutrition.fatG <= 0) {
      return;
    }
    final existing = _savedFoods.indexWhere(
      (food) => food.name.toLowerCase() == nutrition.foodName.toLowerCase(),
    );
    final saved = SavedFood(
      id: existing == -1
          ? 'saved-${DateTime.now().millisecondsSinceEpoch}'
          : _savedFoods[existing].id,
      name: nutrition.foodName,
      servingLabel: 'serving',
      nutrition: nutrition,
    );
    if (existing == -1) {
      _savedFoods = [saved, ..._savedFoods].take(8).toList();
    } else {
      _savedFoods = [
        saved,
        for (var i = 0; i < _savedFoods.length; i++)
          if (i != existing) _savedFoods[i],
      ];
    }
  }

  void saveMeal(NutritionEstimate nutrition, {String source = 'generated'}) {
    saveFoodFromNutrition(nutrition);
    _persistState();
    notifyListeners();
  }

  void seedGenericMealsIfNeeded() {
    if (_savedFoods.isNotEmpty) return;
    for (final nutrition in _genericMeals) {
      saveFoodFromNutrition(nutrition);
    }
    _persistState();
    notifyListeners();
  }

  static const List<NutritionEstimate> _genericMeals = [
    NutritionEstimate(
      foodName: 'Eggs and Toast',
      grams: 260,
      carbsG: 32,
      glucoseG: 25,
      fructoseG: 2,
      fiberG: 4,
      proteinG: 24,
      fatG: 18,
      calories: 386,
      isHighFat: true,
      isHighFiber: false,
    ),
    NutritionEstimate(
      foodName: 'Greek Yogurt and Banana',
      grams: 330,
      carbsG: 42,
      glucoseG: 25,
      fructoseG: 10,
      fiberG: 3,
      proteinG: 26,
      fatG: 2,
      calories: 290,
      isHighFat: false,
      isHighFiber: false,
    ),
    NutritionEstimate(
      foodName: 'Rice and Chicken Bowl',
      grams: 430,
      carbsG: 58,
      glucoseG: 54,
      fructoseG: 1,
      fiberG: 3,
      proteinG: 42,
      fatG: 7,
      calories: 463,
      isHighFat: false,
      isHighFiber: false,
    ),
  ];

  void updateFoodLog(FoodLog updated) {
    _foodLogs = [
      for (final f in _foodLogs)
        if (f.id == updated.id) updated else f,
    ];
    _recompute();
    _persistState();
    notifyListeners();
  }

  void deleteFoodLog(String id) {
    _foodLogs = _foodLogs.where((f) => f.id != id).toList();
    _recompute();
    _persistState();
    notifyListeners();
  }

  // ─── Training session planning ────────────────────────────────────────────

  void addSession(TrainingSession session) {
    _sessions = [..._sessions, session];
    _recompute();
    _persistState();
    notifyListeners();
  }

  void updateSession(TrainingSession updated) {
    final index = _sessions.indexWhere((s) => s.id == updated.id);
    if (index == -1) {
      _sessions = [..._sessions, updated];
    } else {
      _sessions = [
        for (final s in _sessions)
          if (s.id == updated.id) updated else s,
      ];
    }
    _deletedProjectedSessionIds.remove(updated.id);
    _recompute();
    _persistState();
    notifyListeners();
  }

  void deleteSession(String id) {
    if (id.startsWith('weekly-')) {
      _deletedProjectedSessionIds = {..._deletedProjectedSessionIds, id};
    }
    _sessions = _sessions.where((s) => s.id != id).toList();
    _recompute();
    _persistState();
    notifyListeners();
  }

  // ─── Custom workout routines ─────────────────────────────────────────────

  void saveWorkoutRoutine(WorkoutRoutine routine) {
    final index = _workoutRoutines.indexWhere((s) => s.id == routine.id);
    if (index == -1) {
      _workoutRoutines = [..._workoutRoutines, routine];
    } else {
      _workoutRoutines = [
        for (final existing in _workoutRoutines)
          if (existing.id == routine.id) routine else existing,
      ];
    }
    _recompute();
    _persistState();
    notifyListeners();
  }

  void saveWorkoutSplit(WorkoutRoutine split) => saveWorkoutRoutine(split);

  void addWorkoutPresetsFromPreferences({bool notify = true}) {
    final profile = _profile;
    if (profile == null) return;
    final presets = [
      WorkoutPresetEngine.recommendedRoutine(profile.workoutPreferences),
      ...WorkoutPresetEngine.genericPresets(),
    ];
    for (final preset in presets) {
      if (!_workoutRoutines.any((routine) => routine.id == preset.id)) {
        _workoutRoutines = [..._workoutRoutines, preset];
      }
    }
    _persistState();
    if (notify) notifyListeners();
  }

  void deleteWorkoutRoutine(String id) {
    _workoutRoutines = _workoutRoutines.where((s) => s.id != id).toList();
    _weeklyWorkoutAssignments =
        _weeklyWorkoutAssignments.where((a) => a.routineId != id).toList();
    _recompute();
    _persistState();
    notifyListeners();
  }

  void deleteWorkoutSplit(String id) => deleteWorkoutRoutine(id);

  void saveWeeklyWorkoutAssignment(WeeklyWorkoutAssignment assignment) {
    final index =
        _weeklyWorkoutAssignments.indexWhere((a) => a.id == assignment.id);
    if (index == -1) {
      _weeklyWorkoutAssignments = [..._weeklyWorkoutAssignments, assignment];
    } else {
      _weeklyWorkoutAssignments = [
        for (final existing in _weeklyWorkoutAssignments)
          if (existing.id == assignment.id) assignment else existing,
      ];
    }
    _recompute();
    _persistState();
    notifyListeners();
  }

  void replaceWeeklyWorkoutAssignments(
    List<WeeklyWorkoutAssignment> assignments,
  ) {
    _weeklyWorkoutAssignments = List.of(assignments);
    _deletedProjectedSessionIds = {};
    _recompute();
    _persistState();
    notifyListeners();
  }

  void applyRoutinePlan({
    required List<WorkoutRoutine> routines,
    required List<WeeklyWorkoutAssignment> assignments,
  }) {
    for (final routine in routines) {
      final index = _workoutRoutines.indexWhere((r) => r.id == routine.id);
      if (index == -1) {
        _workoutRoutines = [..._workoutRoutines, routine];
      } else {
        _workoutRoutines[index] = routine;
      }
    }
    _weeklyWorkoutAssignments = List.of(assignments);
    _deletedProjectedSessionIds = {};
    _recompute();
    _persistState();
    notifyListeners();
  }

  List<TrainingSession> projectedSessionsBetween(DateTime start, DateTime end) {
    return _projectedSessionsBetween(start, end);
  }

  List<TrainingSession> sessionsBetween(DateTime start, DateTime end) {
    return List.unmodifiable(_mergedSessionsBetween(start, end));
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _persistState();
    notifyListeners();
  }

  // ─── Recompute metabolic state + prescription ────────────────────────────

  void _recompute() {
    if (_profile == null) return;

    _metabolicState = MetabolicEngine.replayDay(
      _profile!,
      _foodLogs,
      sessions,
      _now,
    );

    final upcoming = nextSession;
    if (upcoming != null && _metabolicState != null) {
      _prescription = PrescriptionEngine.planFuel(
        _metabolicState!,
        upcoming,
        profile: _profile,
      );
    } else {
      _prescription = null;
    }
  }

  List<TrainingSession> _mergedSessionsBetween(DateTime start, DateTime end) {
    final projected = _projectedSessionsBetween(start, end);
    final concreteIds = _sessions.map((s) => s.id).toSet();
    final all = [
      ..._sessions.where(
        (session) =>
            !session.plannedAt.isBefore(start) &&
            !session.plannedAt.isAfter(end),
      ),
      ...projected.where((session) => !concreteIds.contains(session.id)),
    ]..sort((a, b) => a.plannedAt.compareTo(b.plannedAt));
    return all;
  }

  List<TrainingSession> _projectedSessionsBetween(
      DateTime start, DateTime end) {
    final profile = _profile;
    if (profile == null || _weeklyWorkoutAssignments.isEmpty) return const [];
    final sessions = <TrainingSession>[];
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    for (var day = startDay;
        !day.isAfter(endDay);
        day = day.add(const Duration(days: 1))) {
      for (final assignment in _weeklyWorkoutAssignments) {
        if (assignment.weekday != day.weekday) continue;
        final routine = _routineById(assignment.routineId);
        if (routine == null) continue;
        final plannedAt = DateTime(
          day.year,
          day.month,
          day.day,
          assignment.minuteOfDay ~/ 60,
          assignment.minuteOfDay % 60,
        );
        if (plannedAt.isBefore(start) || plannedAt.isAfter(end)) continue;
        final id = _projectedSessionId(assignment.id, plannedAt);
        if (_deletedProjectedSessionIds.contains(id)) continue;
        sessions.add(
          TrainingSession(
            id: id,
            userId: profile.id,
            type: SessionType.fullBody,
            plannedAt: plannedAt,
            durationMinutes: assignment.durationMinutes,
            intensity: assignment.intensity,
            customName: routine.name,
            customSplitId: routine.id,
            plannedExercises: List.of(routine.exercises),
            notes: '${routine.exercises.length} routine exercises',
          ),
        );
      }
    }
    return sessions;
  }

  WorkoutRoutine? _routineById(String id) {
    for (final routine in _workoutRoutines) {
      if (routine.id == id) return routine;
    }
    return null;
  }

  String _projectedSessionId(String assignmentId, DateTime plannedAt) {
    final yyyy = plannedAt.year.toString().padLeft(4, '0');
    final mm = plannedAt.month.toString().padLeft(2, '0');
    final dd = plannedAt.day.toString().padLeft(2, '0');
    return 'weekly-$assignmentId-$yyyy$mm$dd';
  }

  /// Advance simulated time (useful for live demos).
  void advanceTime(Duration delta) {
    _now = _now.add(delta);
    _recompute();
    notifyListeners();
  }

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _now = DateTime.now();
      _recompute();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }
}
