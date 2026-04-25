import '../models/food_log.dart';
import '../models/training_session.dart';
import '../models/user_profile.dart';

/// Seeded judge scenarios for the hackathon demo.
/// Select a demo account from the onboarding screen to preload a day.
class DemoAccounts {
  static final all = [
    _fastedMorning,
    _midDayPartial,
    _preLiftFueled,
    _postLift
  ];

  // ─── 1. Fasted morning athlete ─────────────────────────────────────────

  static final _fastedMorning = DemoAccount(
    label: 'Alex — Fasted Morning',
    description: '6am wake, nothing eaten yet, leg day at 9am',
    profile: UserProfile(
      id: 'demo-alex',
      name: 'Alex',
      ageYears: 28,
      sex: BiologicalSex.male,
      heightCm: 180,
      weightKg: 82,
      activityBaseline: ActivityBaseline.moderatelyActive,
      createdAt: _epoch,
    ),
    foodLogsJson: [],
    sessionJson: {
      'id': 'demo-alex-sess',
      'user_id': 'demo-alex',
      'type': 'legs',
      'planned_at': '2026-04-25T09:00:00',
      'duration_minutes': 75,
      'intensity': 'high',
    },
    nowIso: '2026-04-25T07:15:00',
  );

  // ─── 2. Mid-day partially depleted ────────────────────────────────────

  static final _midDayPartial = DemoAccount(
    label: 'Jordan — Mid-Day Depleted',
    description: 'Breakfast eaten, lunch skipped, 5pm leg day',
    profile: UserProfile(
      id: 'demo-jordan',
      name: 'Jordan',
      ageYears: 32,
      sex: BiologicalSex.female,
      heightCm: 165,
      weightKg: 63,
      activityBaseline: ActivityBaseline.moderatelyActive,
      createdAt: _epoch,
    ),
    foodLogsJson: [
      {
        'id': 'jlog1',
        'user_id': 'demo-jordan',
        'raw_input': 'two eggs, oatmeal with blueberries, coffee with milk',
        'logged_at': '2026-04-25T08:00:00',
        'source': 'demo',
        'nutrition': {
          'food_name': 'Breakfast: eggs + oatmeal + coffee',
          'grams': 400,
          'carbs_g': 33,
          'glucose_g': 27,
          'fructose_g': 6,
          'fiber_g': 6,
          'protein_g': 22,
          'fat_g': 15,
          'calories': 352,
          'micros': {
            'magnesium_mg': 61,
            'potassium_mg': 443,
            'sodium_mg': 220,
            'iron_mg': 3.8,
            'zinc_mg': 2.4,
            'b12_mcg': 1.6,
            'vitamin_d_iu': 82,
          },
          'is_high_fat': false,
          'is_high_fiber': true,
        },
      },
    ],
    sessionJson: {
      'id': 'demo-jordan-sess',
      'user_id': 'demo-jordan',
      'type': 'legs',
      'planned_at': '2026-04-25T17:00:00',
      'duration_minutes': 60,
      'intensity': 'moderate',
    },
    nowIso: '2026-04-25T12:30:00',
  );

  // ─── 3. Pre-lift fueled (1 h out) ─────────────────────────────────────

  static final _preLiftFueled = DemoAccount(
    label: 'Sam — Pre-Lift Fueled',
    description: 'Good meals all day, HIIT in 1 hour',
    profile: UserProfile(
      id: 'demo-sam',
      name: 'Sam',
      ageYears: 24,
      sex: BiologicalSex.male,
      heightCm: 175,
      weightKg: 75,
      activityBaseline: ActivityBaseline.veryActive,
      createdAt: _epoch,
    ),
    foodLogsJson: [
      {
        'id': 'slog1',
        'user_id': 'demo-sam',
        'raw_input': 'oatmeal, banana, protein shake',
        'logged_at': '2026-04-25T07:30:00',
        'source': 'demo',
        'nutrition': {
          'food_name': 'Breakfast: oatmeal + banana + shake',
          'grams': 550,
          'carbs_g': 70,
          'glucose_g': 52,
          'fructose_g': 12,
          'fiber_g': 7,
          'protein_g': 32,
          'fat_g': 6,
          'calories': 462,
          'micros': {
            'magnesium_mg': 120,
            'potassium_mg': 600,
            'b12_mcg': 1.2,
            'iron_mg': 3
          },
          'is_high_fat': false,
          'is_high_fiber': true,
        },
      },
      {
        'id': 'slog2',
        'user_id': 'demo-sam',
        'raw_input': 'rice, chicken, sweet potato',
        'logged_at': '2026-04-25T12:00:00',
        'source': 'demo',
        'nutrition': {
          'food_name': 'Lunch: rice + chicken + sweet potato',
          'grams': 480,
          'carbs_g': 72,
          'glucose_g': 67,
          'fructose_g': 3,
          'fiber_g': 5,
          'protein_g': 48,
          'fat_g': 5,
          'calories': 533,
          'micros': {
            'magnesium_mg': 52,
            'potassium_mg': 989,
            'zinc_mg': 3.4,
            'b12_mcg': 0.5
          },
          'is_high_fat': false,
          'is_high_fiber': false,
        },
      },
    ],
    sessionJson: {
      'id': 'demo-sam-sess',
      'user_id': 'demo-sam',
      'type': 'hiit',
      'planned_at': '2026-04-25T16:00:00',
      'duration_minutes': 45,
      'intensity': 'maximal',
    },
    nowIso: '2026-04-25T15:00:00',
  );

  // ─── 4. Post-lift refuel ──────────────────────────────────────────────

  static final _postLift = DemoAccount(
    label: 'Riley — Post-Lift Refuel',
    description: 'Just finished full-body session, glycogen depleted',
    profile: UserProfile(
      id: 'demo-riley',
      name: 'Riley',
      ageYears: 30,
      sex: BiologicalSex.female,
      heightCm: 170,
      weightKg: 68,
      activityBaseline: ActivityBaseline.veryActive,
      createdAt: _epoch,
    ),
    foodLogsJson: [
      {
        'id': 'rlog1',
        'user_id': 'demo-riley',
        'raw_input': 'coffee, banana',
        'logged_at': '2026-04-25T06:30:00',
        'source': 'demo',
        'nutrition': {
          'food_name': 'Pre-workout: coffee + banana',
          'grams': 358,
          'carbs_g': 27,
          'glucose_g': 10,
          'fructose_g': 9,
          'fiber_g': 3,
          'protein_g': 1,
          'fat_g': 0,
          'calories': 107,
          'micros': {'potassium_mg': 538, 'magnesium_mg': 39},
          'is_high_fat': false,
          'is_high_fiber': false,
        },
      },
    ],
    sessionJson: {
      'id': 'demo-riley-sess',
      'user_id': 'demo-riley',
      'type': 'fullBody',
      'planned_at': '2026-04-25T07:30:00',
      'duration_minutes': 70,
      'intensity': 'high',
    },
    nowIso: '2026-04-25T09:00:00',
  );

  static final DateTime _epoch = DateTime(2026, 1, 1);
}

class DemoAccount {
  final String label;
  final String description;
  final UserProfile profile;
  final List<Map<String, dynamic>> foodLogsJson;
  final Map<String, dynamic> sessionJson;
  final String nowIso;

  const DemoAccount({
    required this.label,
    required this.description,
    required this.profile,
    required this.foodLogsJson,
    required this.sessionJson,
    required this.nowIso,
  });

  DateTime get now => DateTime.parse(nowIso);

  List<FoodLog> get foodLogs =>
      foodLogsJson.map((j) => FoodLog.fromJson(j)).toList();

  TrainingSession get session => TrainingSession.fromJson(sessionJson);
}
