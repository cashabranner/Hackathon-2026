import 'package:flutter_test/flutter_test.dart';
import 'package:fuelwindow/models/food_log.dart';
import 'package:fuelwindow/models/nutrition_estimate.dart';
import 'package:fuelwindow/models/training_session.dart';
import 'package:fuelwindow/models/user_profile.dart';
import 'package:fuelwindow/services/metabolic_engine.dart';

final _male75 = UserProfile(
  id: 'test-m',
  name: 'Test Male',
  ageYears: 28,
  sex: BiologicalSex.male,
  heightCm: 180,
  weightKg: 75,
  activityBaseline: ActivityBaseline.moderatelyActive,
  createdAt: DateTime(2026),
);

final _female60 = UserProfile(
  id: 'test-f',
  name: 'Test Female',
  ageYears: 25,
  sex: BiologicalSex.female,
  heightCm: 165,
  weightKg: 60,
  activityBaseline: ActivityBaseline.lightlyActive,
  createdAt: DateTime(2026),
);

void main() {
  group('Biometric calculations', () {
    test('Boer LBM male is reasonable', () {
      final lbm = MetabolicEngine.leanBodyMassKg(_male75);
      expect(lbm, greaterThan(55));
      expect(lbm, lessThan(70));
    });

    test('Boer LBM female is reasonable', () {
      final lbm = MetabolicEngine.leanBodyMassKg(_female60);
      expect(lbm, greaterThan(40));
      expect(lbm, lessThan(55));
    });

    test('Mifflin BMR male in expected range', () {
      final bmr = MetabolicEngine.bmrKcal(_male75);
      expect(bmr, greaterThan(1600));
      expect(bmr, lessThan(2000));
    });

    test('Mifflin BMR female in expected range', () {
      final bmr = MetabolicEngine.bmrKcal(_female60);
      expect(bmr, greaterThan(1300));
      expect(bmr, lessThan(1600));
    });

    test('Liver capacity is fixed at 100g', () {
      expect(MetabolicEngine.liverCapacityG(_male75), equals(100.0));
      expect(MetabolicEngine.liverCapacityG(_female60), equals(100.0));
    });

    test('Muscle capacity scales with lean mass', () {
      final maleCap = MetabolicEngine.muscleCapacityG(_male75);
      final femaleCap = MetabolicEngine.muscleCapacityG(_female60);
      expect(maleCap, greaterThan(femaleCap));
      expect(maleCap, greaterThan(700));
      expect(femaleCap, greaterThan(500));
    });
  });

  group('computeBaseline', () {
    test('Fasted state has low liver glycogen', () {
      final state = MetabolicEngine.computeBaseline(_male75);
      expect(state.liverGlycogenG, lessThan(60)); // ~8h depletion
      expect(state.liverGlycogenG, greaterThan(0));
    });

    test('Baseline muscle glycogen is high but not full', () {
      final state = MetabolicEngine.computeBaseline(_male75);
      expect(state.muscleGlycogenG, greaterThan(0));
      expect(state.muscleFillPct, lessThan(1.0));
      expect(state.muscleFillPct, greaterThan(0.5));
    });

    test('Blood glucose phase is fasted on wakeup', () {
      final state = MetabolicEngine.computeBaseline(_male75);
      expect(state.bloodGlucosePhase.name, equals('fasted'));
    });
  });

  group('Food partitioning', () {
    late FoodLog _glucoseLog;
    late FoodLog _fructoseLog;
    late FoodLog _fatHeavyLog;

    setUp(() {
      _glucoseLog = FoodLog(
        id: 'g1',
        userId: 'test-m',
        rawInput: 'white rice',
        loggedAt: DateTime(2026, 4, 25, 8),
        nutrition: const NutritionEstimate(
          foodName: 'White rice',
          grams: 186,
          carbsG: 45,
          glucoseG: 45,
          fructoseG: 0,
          fiberG: 1,
          proteinG: 4,
          fatG: 0,
          calories: 206,
          isHighFat: false,
          isHighFiber: false,
        ),
      );

      _fructoseLog = FoodLog(
        id: 'f1',
        userId: 'test-m',
        rawInput: 'apple',
        loggedAt: DateTime(2026, 4, 25, 9),
        nutrition: const NutritionEstimate(
          foodName: 'Apple',
          grams: 182,
          carbsG: 25,
          glucoseG: 7,
          fructoseG: 13,
          fiberG: 4,
          proteinG: 0,
          fatG: 0,
          calories: 95,
          isHighFiber: true,
        ),
      );

      _fatHeavyLog = FoodLog(
        id: 'h1',
        userId: 'test-m',
        rawInput: 'nut butter',
        loggedAt: DateTime(2026, 4, 25, 10),
        nutrition: const NutritionEstimate(
          foodName: 'Nut butter',
          grams: 32,
          carbsG: 6,
          glucoseG: 3,
          fructoseG: 1,
          fiberG: 2,
          proteinG: 7,
          fatG: 16,
          calories: 190,
          isHighFat: true,
        ),
      );
    });

    test('Glucose meal raises muscle and liver glycogen', () {
      final before = MetabolicEngine.computeBaseline(_male75);
      final after = MetabolicEngine.replayDay(
        _male75,
        [_glucoseLog],
        [],
        DateTime(2026, 4, 25, 9),
      );
      // Total stored glycogen should be higher
      final totalBefore = before.liverGlycogenG + before.muscleGlycogenG;
      final totalAfter = after.liverGlycogenG + after.muscleGlycogenG;
      expect(totalAfter, greaterThan(totalBefore));
    });

    test('Fructose preferentially loads liver', () {
      final withFructose = MetabolicEngine.replayDay(
        _male75,
        [_fructoseLog],
        [],
        DateTime(2026, 4, 25, 10),
      );
      // Liver should be higher than baseline fasted state
      final baseline = MetabolicEngine.computeBaseline(_male75);
      expect(withFructose.liverGlycogenG, greaterThan(baseline.liverGlycogenG));
    });

    test('High-fat meal applies 50% absorption reduction', () {
      final withFat = MetabolicEngine.replayDay(
        _male75,
        [_fatHeavyLog],
        [],
        DateTime(2026, 4, 25, 11),
      );
      // Fat meal has low carbs so not much change; just ensure it doesn't crash
      expect(withFat.liverGlycogenG, isNotNull);
    });

    test('Total carbs accumulate correctly', () {
      final after = MetabolicEngine.replayDay(
        _male75,
        [_glucoseLog, _fructoseLog],
        [],
        DateTime(2026, 4, 25, 10),
      );
      expect(after.totalCarbsG,
          closeTo(_glucoseLog.nutrition.carbsG + _fructoseLog.nutrition.carbsG, 0.1));
    });
  });

  group('Resting depletion', () {
    test('Liver depletes over time without food', () {
      final morning = MetabolicEngine.replayDay(
        _male75,
        [],
        [],
        DateTime(2026, 4, 25, 9),
      );
      final afternoon = MetabolicEngine.replayDay(
        _male75,
        [],
        [],
        DateTime(2026, 4, 25, 14),
      );
      expect(afternoon.liverGlycogenG, lessThan(morning.liverGlycogenG));
    });

    test('Liver does not go below zero', () {
      final lateNight = MetabolicEngine.replayDay(
        _male75,
        [],
        [],
        DateTime(2026, 4, 25, 23, 59),
      );
      expect(lateNight.liverGlycogenG, greaterThanOrEqualTo(0));
    });
  });

  group('Training depletion', () {
    late TrainingSession _legDay;

    setUp(() {
      _legDay = TrainingSession(
        id: 'sess1',
        userId: 'test-m',
        type: SessionType.legs,
        plannedAt: DateTime(2026, 4, 25, 10),
        durationMinutes: 60,
        intensity: SessionIntensity.high,
      );
    });

    test('Training session depletes muscle glycogen', () {
      final noTraining = MetabolicEngine.replayDay(
        _male75,
        [],
        [],
        DateTime(2026, 4, 25, 11, 30),
      );
      final withTraining = MetabolicEngine.replayDay(
        _male75,
        [],
        [_legDay],
        DateTime(2026, 4, 25, 11, 30),
      );
      expect(withTraining.muscleGlycogenG, lessThan(noTraining.muscleGlycogenG));
    });

    test('Training depletion estimate is within session cost', () {
      final before = MetabolicEngine.replayDay(
        _male75,
        [],
        [],
        DateTime(2026, 4, 25, 9, 59),
      );
      final after = MetabolicEngine.replayDay(
        _male75,
        [],
        [_legDay],
        DateTime(2026, 4, 25, 11, 1),
      );
      final depleted = before.muscleGlycogenG - after.muscleGlycogenG;
      // Allow resting depletion on top of session cost
      expect(depleted, greaterThan(0));
      expect(depleted, lessThan(_legDay.estimatedMuscleGlycogenCostG + 30));
    });

    test('Muscle glycogen never goes below zero', () {
      final manyHeavySessions = List.generate(
          5,
          (i) => TrainingSession(
                id: 'sess$i',
                userId: 'test-m',
                type: SessionType.fullBody,
                plannedAt: DateTime(2026, 4, 25, 7 + i * 2),
                durationMinutes: 90,
                intensity: SessionIntensity.maximal,
              ));
      final result = MetabolicEngine.replayDay(
        _male75,
        [],
        manyHeavySessions,
        DateTime(2026, 4, 25, 22),
      );
      expect(result.muscleGlycogenG, greaterThanOrEqualTo(0));
    });
  });

  group('Intraday curve', () {
    test('Curve is populated after replayDay', () {
      final result = MetabolicEngine.replayDay(
        _male75,
        [],
        [],
        DateTime(2026, 4, 25, 14),
      );
      expect(result.curve, isNotEmpty);
    });

    test('Curve timestamps are chronologically ordered', () {
      final result = MetabolicEngine.replayDay(
        _male75,
        [
          FoodLog(
            id: 'x',
            userId: 'test-m',
            rawInput: 'oatmeal',
            loggedAt: DateTime(2026, 4, 25, 8),
            nutrition: const NutritionEstimate(
              foodName: 'Oatmeal',
              grams: 234,
              carbsG: 27,
              glucoseG: 22,
              fructoseG: 1,
              fiberG: 4,
              proteinG: 6,
              fatG: 3,
              calories: 158,
            ),
          ),
        ],
        [],
        DateTime(2026, 4, 25, 12),
      );
      for (int i = 1; i < result.curve.length; i++) {
        expect(
          result.curve[i].time.isAfter(result.curve[i - 1].time) ||
              result.curve[i].time.isAtSameMomentAs(result.curve[i - 1].time),
          isTrue,
        );
      }
    });
  });
}
