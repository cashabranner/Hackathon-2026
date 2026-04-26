import 'package:flutter_test/flutter_test.dart';
import 'package:fuelwindow/models/fuel_prescription.dart';
import 'package:fuelwindow/models/metabolic_state.dart';
import 'package:fuelwindow/models/training_session.dart';
import 'package:fuelwindow/models/user_profile.dart';
import 'package:fuelwindow/services/metabolic_engine.dart';
import 'package:fuelwindow/services/prescription_engine.dart';

final _profile = UserProfile(
  id: 'test',
  name: 'Test',
  ageYears: 28,
  sex: BiologicalSex.male,
  heightCm: 180,
  weightKg: 80,
  activityBaseline: ActivityBaseline.moderatelyActive,
  createdAt: DateTime(2026),
);

MetabolicState _baseState(DateTime now,
    {double liverPct = 0.7, double musclePct = 0.75}) {
  final baseline = MetabolicEngine.computeBaseline(_profile);
  return baseline.copyWith(
    asOf: now,
    liverGlycogenG: baseline.liverCapacityG * liverPct,
    muscleGlycogenG: baseline.muscleCapacityG * musclePct,
  );
}

TrainingSession _session({
  required DateTime plannedAt,
  SessionType type = SessionType.legs,
  SessionIntensity intensity = SessionIntensity.moderate,
  int durationMinutes = 60,
}) {
  return TrainingSession(
    id: 'sess',
    userId: 'test',
    type: type,
    plannedAt: plannedAt,
    durationMinutes: durationMinutes,
    intensity: intensity,
  );
}

void main() {
  group('Fasted morning user — 2 hours before leg day', () {
    late FuelPrescription rx;
    setUp(() {
      final now = DateTime(2026, 4, 25, 7, 0);
      final state =
          _baseState(now, liverPct: 0.2, musclePct: 0.55); // low stores
      final session = _session(plannedAt: DateTime(2026, 4, 25, 9, 0));
      rx = PrescriptionEngine.planFuel(state, session);
    });

    test('Returns preLift timing', () {
      expect(rx.timing, equals(PrescriptionTiming.preLift));
    });

    test('Has pre-lift meals', () {
      expect(rx.preLiftMeals, isNotEmpty);
    });

    test('Recommends elevated carbs for low stores', () {
      expect(rx.targetCarbsG, greaterThanOrEqualTo(50));
    });

    test('Has a why explanation', () {
      expect(rx.whyExplanation, isNotEmpty);
      expect(rx.whyExplanation.length, greaterThan(100));
    });
  });

  group('Mid-day partially depleted user — 2.5 hours before legs', () {
    late FuelPrescription rx;
    setUp(() {
      final now = DateTime(2026, 4, 25, 14, 30);
      final state = _baseState(now, liverPct: 0.45, musclePct: 0.60);
      final session = _session(plannedAt: DateTime(2026, 4, 25, 17, 0));
      rx = PrescriptionEngine.planFuel(state, session);
    });

    test('Returns preLift timing', () {
      expect(rx.timing, equals(PrescriptionTiming.preLift));
    });

    test('Headline is non-empty', () {
      expect(rx.headline, isNotEmpty);
    });

    test('Target carbs are reasonable for partial depletion', () {
      expect(rx.targetCarbsG, greaterThan(20));
      expect(rx.targetCarbsG, lessThan(100));
    });
  });

  group('Pre-lift fueled user — 30 min before HIIT', () {
    late FuelPrescription rx;
    setUp(() {
      final now = DateTime(2026, 4, 25, 15, 30);
      final state = _baseState(now, liverPct: 0.65, musclePct: 0.80);
      final session = _session(
        plannedAt: DateTime(2026, 4, 25, 16, 0),
        type: SessionType.hiit,
        intensity: SessionIntensity.maximal,
        durationMinutes: 45,
      );
      rx = PrescriptionEngine.planFuel(state, session);
    });

    test('Returns immediatelyPre timing', () {
      expect(rx.timing, equals(PrescriptionTiming.immediatelyPre));
    });

    test('No heavy meals — only fast carbs', () {
      // Pre-lift meals should be light
      for (final item in rx.preLiftMeals) {
        expect(item.fatG, lessThanOrEqualTo(5));
      }
    });

    test('Fast carb target is modest', () {
      expect(rx.targetCarbsG, lessThanOrEqualTo(30));
    });
  });

  group('Post-lift refuel guidance', () {
    late FuelPrescription rx;
    setUp(() {
      final now = DateTime(2026, 4, 25, 11, 0);
      final state =
          _baseState(now, liverPct: 0.25, musclePct: 0.15); // critically low
      final session = _session(
        plannedAt: DateTime(2026, 4, 25, 9, 0), // session was in the past
        durationMinutes: 75,
        intensity: SessionIntensity.high,
      );
      rx = PrescriptionEngine.planFuel(state, session);
    });

    test('Returns postLift timing', () {
      expect(rx.timing, equals(PrescriptionTiming.postLift));
    });

    test('Post-lift meals are recommended', () {
      expect(rx.postLiftMeals, isNotEmpty);
    });

    test('High carb target for recovery', () {
      expect(rx.targetCarbsG, greaterThanOrEqualTo(60));
    });

    test('Protein target supports muscle repair', () {
      expect(rx.targetProteinG, greaterThanOrEqualTo(25));
    });

    test('Urgent refuel flag is set when muscle glycogen critically low', () {
      expect(rx.urgentRefuel, isTrue);
    });
  });

  group('Rest day / far-out session', () {
    late FuelPrescription rx;
    setUp(() {
      final now = DateTime(2026, 4, 25, 8, 0);
      final state = _baseState(now);
      final session =
          _session(plannedAt: DateTime(2026, 4, 25, 18, 0)); // 10h away
      rx = PrescriptionEngine.planFuel(state, session);
    });

    test('Returns restDay timing', () {
      expect(rx.timing, equals(PrescriptionTiming.restDay));
    });

    test('No specific meals listed', () {
      expect(rx.preLiftMeals, isEmpty);
      expect(rx.postLiftMeals, isEmpty);
    });

    test('Carb target based on TDEE', () {
      expect(rx.targetCarbsG, greaterThan(100));
    });
  });

  group('During-session fueling', () {
    test('No during-session fuels for short session', () {
      final now = DateTime(2026, 4, 25, 14, 0);
      final state = _baseState(now);
      final session = _session(
        plannedAt: DateTime(2026, 4, 25, 16, 0),
        durationMinutes: 45,
      );
      final rx = PrescriptionEngine.planFuel(state, session);
      expect(rx.duringLiftFuels, isEmpty);
    });

    test('During-session fuels recommended for long session', () {
      final now = DateTime(2026, 4, 25, 14, 0);
      final state = _baseState(now);
      final session = _session(
        plannedAt: DateTime(2026, 4, 25, 16, 0),
        durationMinutes: 90,
      );
      final rx = PrescriptionEngine.planFuel(state, session);
      expect(rx.duringLiftFuels, isNotEmpty);
    });
  });
}
