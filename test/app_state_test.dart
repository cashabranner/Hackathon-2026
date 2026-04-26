import 'package:flutter_test/flutter_test.dart';
import 'package:fuelwindow/demo/demo_accounts.dart';
import 'package:fuelwindow/models/nutrition_estimate.dart';
import 'package:fuelwindow/models/training_session.dart';
import 'package:fuelwindow/repositories/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Demo accounts seed recent relative history', () {
    final state = AppState();
    try {
      final demo = DemoAccounts.all[1];

      state.loadDemoAccount(demo);

      expect(state.foodLogs, isNotEmpty);
      expect(state.savedFoods, isNotEmpty);
      expect(state.sessions.length, greaterThanOrEqualTo(2));
      expect(state.workoutSplits, isNotEmpty);
      expect(state.nextSession, isNotNull);
      expect(
        state.foodLogs.every(
          (log) => state.now.difference(log.loggedAt).inHours <= 48,
        ),
        isTrue,
      );
    } finally {
      state.dispose();
    }
  });

  test('Persists and restores profile, meals, sessions, and presets', () async {
    final state = AppState();
    try {
      state.loadDemoAccount(DemoAccounts.all.first);
      state.saveMeal(
        const NutritionEstimate(
          foodName: 'Test meal',
          grams: 100,
          carbsG: 20,
          glucoseG: 15,
          fructoseG: 2,
          fiberG: 3,
          proteinG: 10,
          fatG: 5,
          calories: 165,
        ),
      );
      await state.persistState();
    } finally {
      state.dispose();
    }

    final restored = AppState();
    try {
      await restored.loadPersistedState();
      expect(restored.profile, isNotNull);
      expect(restored.foodLogs, isNotEmpty);
      expect(restored.savedFoods, isNotEmpty);
      expect(restored.sessions, isNotEmpty);
      expect(restored.workoutSplits, isNotEmpty);
    } finally {
      restored.dispose();
    }
  });

  test('Tracks pending post-workout summaries after the two hour reminder', () {
    final state = AppState();
    try {
      final session = TrainingSession(
        id: 'session-1',
        userId: 'user-1',
        type: SessionType.fullBody,
        plannedAt: state.now.subtract(const Duration(hours: 3)),
        durationMinutes: 60,
        intensity: SessionIntensity.moderate,
      );

      state.addSession(session);

      expect(state.pendingPostWorkoutSummary?.id, session.id);

      state.updateSession(
        session.copyWith(
          postWorkoutFeelingRating: 8,
          postWorkoutIntensity: 7,
          postWorkoutSummaryAt: state.now,
        ),
      );

      expect(state.pendingPostWorkoutSummary, isNull);
    } finally {
      state.dispose();
    }
  });
}
