import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
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
  List<WorkoutSplit> _workoutSplits = [];
  MetabolicState? _metabolicState;
  FuelPrescription? _prescription;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;
  StreamSubscription<AuthState>? _authSubscription;
  String? _authUserId;
  String? _authUserEmail;
  bool _isHydrated = false;
  bool _pendingGreeting = false;
  bool _isDemoMode = false;

  AppState() {
    _startAuthListener();
    _startClock();
  }

  // ─── Getters ─────────────────────────────────────────────────────────────

  UserProfile? get profile => _profile;
  List<FoodLog> get foodLogs => List.unmodifiable(_foodLogs);
  List<SavedFood> get savedFoods => List.unmodifiable(_savedFoods);
  List<TrainingSession> get sessions => List.unmodifiable(_sessions);
  List<WorkoutSplit> get workoutSplits => List.unmodifiable(_workoutSplits);
  MetabolicState? get metabolicState => _metabolicState;
  FuelPrescription? get prescription => _prescription;
  DateTime get now => _now;
  bool get isHydrated => _isHydrated;
  bool get pendingGreeting => _pendingGreeting;
  bool get isDemoMode => _isDemoMode;
  bool get hasProfile => _profile != null;
  bool get authEnabled => AppConfig.hasSupabase;
  bool get isAuthenticated => !authEnabled || _authUserId != null;
  String? get authUserEmail => _authUserEmail;

  String get _activeStorageKey =>
      _authUserId == null ? _storageKey : '${_storageKey}_$_authUserId';

  TrainingSession? get nextSession {
    final upcoming = _sessions.where((s) => s.plannedAt.isAfter(_now)).toList()
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
    if (authEnabled && _authUserId == null) {
      _clearLocalState();
      _now = DateTime.now();
      _isHydrated = true;
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activeStorageKey);
    _clearLocalState();
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
      _workoutSplits = (json['workout_splits'] as List? ?? const [])
          .map((item) => WorkoutSplit.fromJson(item as Map<String, dynamic>))
          .toList();
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
      _activeStorageKey,
      jsonEncode({
        'profile': _profile?.toJson(),
        'food_logs': _foodLogs.map((log) => log.toJson()).toList(),
        'saved_foods': _savedFoods.map((food) => food.toJson()).toList(),
        'sessions': _sessions.map((session) => session.toJson()).toList(),
        'workout_splits':
            _workoutSplits.map((split) => split.toJson()).toList(),
        'is_demo_mode': _isDemoMode,
      }),
    );
  }

  void _persistState() {
    unawaited(persistState());
  }

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    _setAuthUser(response.session?.user ?? response.user);
    await loadPersistedState();
  }

  Future<bool> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    final response = await Supabase.instance.client.auth.signUp(
      email: email,
      password: password,
    );
    _setAuthUser(response.session?.user);
    if (response.session != null) {
      await loadPersistedState();
    }
    return response.session == null;
  }

  Future<void> signOut() async {
    if (!authEnabled) return;
    await Supabase.instance.client.auth.signOut();
    _setAuthUser(null);
    _clearLocalState();
    notifyListeners();
  }

  void consumeGreeting() {
    if (!_pendingGreeting) return;
    _pendingGreeting = false;
    notifyListeners();
  }

  // ─── Onboarding ──────────────────────────────────────────────────────────

  void saveProfile(UserProfile profile) {
    _profile = _withAuthUserId(profile);
    _isDemoMode = false;
    _pendingGreeting = false;
    addWorkoutPresetsFromPreferences(notify: false);
    _recompute();
    _persistState();
    notifyListeners();
  }

  void updateProfile(UserProfile profile) {
    _profile = _withAuthUserId(profile);
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
    _workoutSplits = demo.workoutSplits;
    _pendingGreeting = true;
    _now = DateTime.now();
    _recompute();
    _persistState();
    notifyListeners();
  }

  void clearDemo() {
    _isDemoMode = false;
    _clearLocalState();
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
    _sessions = [
      for (final s in _sessions)
        if (s.id == updated.id) updated else s,
    ];
    _recompute();
    _persistState();
    notifyListeners();
  }

  void deleteSession(String id) {
    _sessions = _sessions.where((s) => s.id != id).toList();
    _recompute();
    _persistState();
    notifyListeners();
  }

  // ─── Custom workout splits ───────────────────────────────────────────────

  void saveWorkoutSplit(WorkoutSplit split) {
    final index = _workoutSplits.indexWhere((s) => s.id == split.id);
    if (index == -1) {
      _workoutSplits = [..._workoutSplits, split];
    } else {
      _workoutSplits = [
        for (final existing in _workoutSplits)
          if (existing.id == split.id) split else existing,
      ];
    }
    _persistState();
    notifyListeners();
  }

  void addWorkoutPresetsFromPreferences({bool notify = true}) {
    final profile = _profile;
    if (profile == null) return;
    final presets = [
      WorkoutPresetEngine.recommendedSplit(profile.workoutPreferences),
      ...WorkoutPresetEngine.genericPresets(),
    ];
    for (final preset in presets) {
      if (!_workoutSplits.any((split) => split.id == preset.id)) {
        _workoutSplits = [..._workoutSplits, preset];
      }
    }
    _persistState();
    if (notify) notifyListeners();
  }

  void deleteWorkoutSplit(String id) {
    _workoutSplits = _workoutSplits.where((s) => s.id != id).toList();
    _persistState();
    notifyListeners();
  }

  // ─── Recompute metabolic state + prescription ────────────────────────────

  void _recompute() {
    if (_profile == null) return;

    _metabolicState = MetabolicEngine.replayDay(
      _profile!,
      _foodLogs,
      _sessions,
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

  void _startAuthListener() {
    if (!authEnabled) return;
    final auth = Supabase.instance.client.auth;
    _setAuthUser(auth.currentUser);
    _authSubscription = auth.onAuthStateChange.listen((data) {
      final previousUserId = _authUserId;
      _setAuthUser(data.session?.user);
      if (previousUserId != _authUserId) {
        unawaited(loadPersistedState());
      } else {
        notifyListeners();
      }
    });
  }

  void _setAuthUser(User? user) {
    _authUserId = user?.id;
    _authUserEmail = user?.email;
  }

  UserProfile _withAuthUserId(UserProfile profile) {
    final authUserId = _authUserId;
    if (authUserId == null) return profile;
    return profile.copyWith(id: authUserId);
  }

  void _clearLocalState() {
    _profile = null;
    _foodLogs = [];
    _savedFoods = [];
    _sessions = [];
    _workoutSplits = [];
    _prescription = null;
    _metabolicState = null;
    _pendingGreeting = false;
    _isDemoMode = false;
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }
}
