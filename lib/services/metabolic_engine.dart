import '../models/food_log.dart';
import '../models/metabolic_state.dart';
import '../models/training_session.dart';
import '../models/user_profile.dart';

/// Pure-Dart metabolic model.
/// All estimates are informed physiology — not medical-grade precision.
class MetabolicEngine {
  // ─── Biometric baselines ────────────────────────────────────────────────

  /// Boer formula lean body mass in kg.
  static double leanBodyMassKg(UserProfile p) {
    if (p.sex == BiologicalSex.male) {
      return (0.407 * p.weightKg) + (0.267 * p.heightCm) - 19.2;
    } else {
      return (0.252 * p.weightKg) + (0.473 * p.heightCm) - 48.3;
    }
  }

  /// Mifflin-St Jeor BMR in kcal/day.
  static double bmrKcal(UserProfile p) {
    final base = (10 * p.weightKg) + (6.25 * p.heightCm) - (5 * p.ageYears);
    return p.sex == BiologicalSex.male ? base + 5 : base - 161;
  }

  static double tdeeKcal(UserProfile p) => bmrKcal(p) * p.activityMultiplier;

  /// Liver glycogen capacity ≈ 100 g (fixed anatomical estimate).
  static double liverCapacityG(UserProfile p) => 100.0;

  /// Muscle glycogen capacity ≈ 15 g/kg lean mass.
  static double muscleCapacityG(UserProfile p) => 15.0 * leanBodyMassKg(p);

  // ─── Compute a baseline (morning-fasted) metabolic state ────────────────

  static MetabolicState computeBaseline(UserProfile p, {DateTime? asOf}) {
    final lbm = leanBodyMassKg(p);
    final bmr = bmrKcal(p);
    final tdee = tdeeKcal(p);
    final liverCap = liverCapacityG(p);
    final muscleCap = muscleCapacityG(p);

    // Fasted starting state: liver ~40% depleted after overnight fast (~8 h).
    final liverFasted = liverCap - (8 * _restingLiverDepleteGPerHr);
    final muscleWake = muscleCap * 0.85; // minor overnight depletion

    return MetabolicState(
      userId: p.id,
      asOf: asOf ?? DateTime.now(),
      leanBodyMassKg: lbm,
      bmrKcal: bmr,
      tdeeKcal: tdee,
      liverCapacityG: liverCap,
      muscleCapacityG: muscleCap,
      liverGlycogenG: liverFasted.clamp(0, liverCap),
      muscleGlycogenG: muscleWake.clamp(0, muscleCap),
      bloodGlucosePhase: BloodGlucosePhase.fasted,
      glp1Status:
          p.usesGlp1 ? Glp1Status.mildlySuppressed : Glp1Status.notActive,
      curve: const [],
    );
  }

  // ─── Replay an entire day and produce a current state + intraday curve ──

  static MetabolicState replayDay(
    UserProfile profile,
    List<FoodLog> foodLogs,
    List<TrainingSession> sessions,
    DateTime now,
  ) {
    final windowStart = now.subtract(const Duration(hours: 16));
    final replayFloor = now.subtract(const Duration(hours: 48));
    final replayStart = profile.createdAt.isAfter(replayFloor)
        ? profile.createdAt
        : replayFloor;
    final todayStart = DateTime(now.year, now.month, now.day);

    var state = computeBaseline(profile, asOf: replayStart);
    final curve = <GlycogenPoint>[];

    final events = <_DayEvent>[
      for (final f in foodLogs)
        if (!f.loggedAt.isBefore(replayStart) && !f.loggedAt.isAfter(now))
          _FoodEvent(f.loggedAt, f),
      for (final s in sessions)
        if (!s.plannedAt.isBefore(replayStart) &&
            !s.plannedAt.isAfter(now) &&
            !s.plannedAt.add(Duration(minutes: s.durationMinutes)).isAfter(now))
          _SessionEvent(s.plannedAt, s),
    ]..sort((a, b) => a.time.compareTo(b.time));

    DateTime cursor = replayStart;

    void addPoint(DateTime time) {
      if (curve.isNotEmpty && curve.last.time.isAtSameMomentAs(time)) {
        curve.removeLast();
      }
      curve.add(GlycogenPoint(
        time: time,
        liverGlycogenG: state.liverGlycogenG,
        muscleGlycogenG: state.muscleGlycogenG,
        bloodGlucoseProxy: _bgProxy(state),
      ));
    }

    void advanceTo(DateTime target) {
      if (!target.isAfter(cursor)) return;
      if (cursor.isBefore(windowStart) && !target.isBefore(windowStart)) {
        final hoursToWindow = windowStart.difference(cursor).inMinutes / 60.0;
        state = _applyRestingDepletion(state, hoursToWindow);
        cursor = windowStart;
        addPoint(cursor);
      }
      final idleHours = target.difference(cursor).inMinutes / 60.0;
      if (idleHours > 0) {
        state = _applyRestingDepletion(state, idleHours);
        cursor = target;
      }
    }

    if (!replayStart.isBefore(windowStart)) {
      addPoint(replayStart);
    }

    for (final event in events) {
      advanceTo(event.time);

      if (event is _FoodEvent) {
        state = _applyFood(
          state,
          event.log,
          profile,
          countTotals: !event.log.loggedAt.isBefore(todayStart),
        );
      } else if (event is _SessionEvent) {
        state = _applyTrainingSession(state, event.session);
      }

      if (!cursor.isBefore(windowStart)) addPoint(cursor);
    }

    advanceTo(now);
    addPoint(now);

    return state.copyWith(asOf: now, curve: curve);
  }

  // ─── Internal helpers ───────────────────────────────────────────────────

  static const double _restingLiverDepleteGPerHr = 7.0; // 5–10 g/hr midpoint

  static MetabolicState _applyRestingDepletion(MetabolicState s, double hours) {
    final depleted = (s.liverGlycogenG - _restingLiverDepleteGPerHr * hours)
        .clamp(0.0, s.liverCapacityG);
    final phase = depleted < s.liverCapacityG * 0.2
        ? BloodGlucosePhase.fasted
        : s.bloodGlucosePhase == BloodGlucosePhase.elevated
            ? BloodGlucosePhase.stable
            : s.bloodGlucosePhase;
    return s.copyWith(liverGlycogenG: depleted, bloodGlucosePhase: phase);
  }

  static MetabolicState _applyFood(
    MetabolicState s,
    FoodLog log,
    UserProfile profile, {
    bool countTotals = true,
  }) {
    final n = log.nutrition;

    // Glucose/starch → blood glucose → partitioned to muscle then liver
    double glucose = n.glucoseG;

    // High-fat or high-fiber meal slows absorption — spread over 2 h
    // (for simulation purposes we treat a fraction as "pending")
    final absorptionFactor = (n.isHighFat || n.isHighFiber) ? 0.5 : 1.0;
    glucose *= absorptionFactor;

    // Priority: top up muscle first (if depleted), then liver
    final muscleDeficit = s.muscleCapacityG - s.muscleGlycogenG;
    final toMuscle = glucose.clamp(0.0, muscleDeficit);
    glucose -= toMuscle;

    final liverDeficit = s.liverCapacityG - s.liverGlycogenG;
    final toLiver = (glucose + n.fructoseG).clamp(0.0, liverDeficit);

    final newMuscle =
        (s.muscleGlycogenG + toMuscle).clamp(0.0, s.muscleCapacityG);
    final newLiver = (s.liverGlycogenG + toLiver).clamp(0.0, s.liverCapacityG);

    final phase =
        n.carbsG > 20 ? BloodGlucosePhase.postPrandial : s.bloodGlucosePhase;

    return s.copyWith(
      muscleGlycogenG: newMuscle,
      liverGlycogenG: newLiver,
      bloodGlucosePhase: phase,
      totalCarbsG: s.totalCarbsG + (countTotals ? n.carbsG : 0),
      totalProteinG: s.totalProteinG + (countTotals ? n.proteinG : 0),
      totalFatG: s.totalFatG + (countTotals ? n.fatG : 0),
      totalCalories: s.totalCalories + (countTotals ? n.calories : 0),
      totalFiberG: s.totalFiberG + (countTotals ? n.fiberG : 0),
    );
  }

  static MetabolicState _applyTrainingSession(
      MetabolicState s, TrainingSession session) {
    final cost = session.estimatedMuscleGlycogenCostG;
    final newMuscle = (s.muscleGlycogenG - cost).clamp(0.0, s.muscleCapacityG);

    // Training also taps some liver glycogen for blood glucose maintenance
    final liverCost = session.durationMinutes * 0.3;
    final newLiver =
        (s.liverGlycogenG - liverCost).clamp(0.0, s.liverCapacityG);

    return s.copyWith(
      muscleGlycogenG: newMuscle,
      liverGlycogenG: newLiver,
      bloodGlucosePhase: BloodGlucosePhase.stable,
    );
  }

  static double _bgProxy(MetabolicState s) {
    // 0–100 index mapping liver fill % → rough blood glucose proxy
    return (s.liverFillPct * 80 + 10).clamp(0.0, 100.0);
  }
}

// ─── Private event types for replay ────────────────────────────────────────

abstract class _DayEvent {
  final DateTime time;
  const _DayEvent(this.time);
}

class _FoodEvent extends _DayEvent {
  final FoodLog log;
  const _FoodEvent(super.time, this.log);
}

class _SessionEvent extends _DayEvent {
  final TrainingSession session;
  const _SessionEvent(super.time, this.session);
}
