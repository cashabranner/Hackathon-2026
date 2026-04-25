import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../demo/demo_accounts.dart';
import '../models/food_log.dart';
import '../models/metabolic_state.dart';
import '../models/nutrition_estimate.dart';
import '../models/training_session.dart';
import '../models/user_profile.dart';
import '../services/food_parser.dart';
import '../services/metabolic_engine.dart';
import '../services/prescription_engine.dart';
import '../models/fuel_prescription.dart';

/// Central app state managed as a ChangeNotifier.
/// Designed so the Supabase-backed layer slots in behind the same interface.
class AppState extends ChangeNotifier {
  UserProfile? _profile;
  List<FoodLog> _foodLogs = [];
  List<TrainingSession> _sessions = [];
  MetabolicState? _metabolicState;
  FuelPrescription? _prescription;
  DateTime _now = DateTime.now();
  bool _isDemoMode = false;

  // ─── Getters ─────────────────────────────────────────────────────────────

  UserProfile? get profile => _profile;
  List<FoodLog> get foodLogs => List.unmodifiable(_foodLogs);
  List<TrainingSession> get sessions => List.unmodifiable(_sessions);
  MetabolicState? get metabolicState => _metabolicState;
  FuelPrescription? get prescription => _prescription;
  DateTime get now => _now;
  bool get isDemoMode => _isDemoMode;
  bool get hasProfile => _profile != null;

  TrainingSession? get nextSession {
    final upcoming = _sessions.where((s) => s.plannedAt.isAfter(_now)).toList()
      ..sort((a, b) => a.plannedAt.compareTo(b.plannedAt));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  // ─── Onboarding ──────────────────────────────────────────────────────────

  void saveProfile(UserProfile profile) {
    _profile = profile;
    _recompute();
    notifyListeners();
  }

  // ─── Demo mode ───────────────────────────────────────────────────────────

  void loadDemoAccount(DemoAccount demo) {
    _isDemoMode = true;
    _profile = demo.profile;
    _foodLogs = demo.foodLogs;
    _sessions = [demo.session];
    _now = demo.now;
    _recompute();
    notifyListeners();
  }

  void clearDemo() {
    _isDemoMode = false;
    _profile = null;
    _foodLogs = [];
    _sessions = [];
    _prescription = null;
    _metabolicState = null;
    _now = DateTime.now();
    notifyListeners();
  }

  // ─── Food logging ─────────────────────────────────────────────────────────

  Future<void> logFood(
    String rawInput, {
    NutritionEstimate? nutrition,
    String? source,
  }) async {
    if (_profile == null) return;

    NutritionEstimate resolvedNutrition;
    String resolvedSource;

    if (nutrition != null) {
      resolvedNutrition = nutrition;
      resolvedSource = source ?? 'local_fallback';
    } else if (AppConfig.hasRemoteFoodParser) {
      try {
        resolvedNutrition = await FoodParser.parseTextRemote(
          rawInput,
          AppConfig.foodParserUrl,
          AppConfig.supabaseAnonKey,
        );
        resolvedSource = 'edge_function';
      } catch (_) {
        resolvedNutrition = FoodParser.parseText(
          rawInput,
          allergies: _profile!.allergies,
        );
        resolvedSource = 'local_fallback';
      }
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
      loggedAt: _now,
      nutrition: resolvedNutrition,
      source: resolvedSource,
    );
    _foodLogs = [..._foodLogs, log];
    _recompute();
    notifyListeners();
  }

  void updateFoodLog(FoodLog updated) {
    _foodLogs = [
      for (final f in _foodLogs)
        if (f.id == updated.id) updated else f,
    ];
    _recompute();
    notifyListeners();
  }

  void deleteFoodLog(String id) {
    _foodLogs = _foodLogs.where((f) => f.id != id).toList();
    _recompute();
    notifyListeners();
  }

  // ─── Training session planning ────────────────────────────────────────────

  void addSession(TrainingSession session) {
    _sessions = [..._sessions, session];
    _recompute();
    notifyListeners();
  }

  void updateSession(TrainingSession updated) {
    _sessions = [
      for (final s in _sessions)
        if (s.id == updated.id) updated else s,
    ];
    _recompute();
    notifyListeners();
  }

  void deleteSession(String id) {
    _sessions = _sessions.where((s) => s.id != id).toList();
    _recompute();
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
      _prescription = PrescriptionEngine.planFuel(_metabolicState!, upcoming);
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
}
