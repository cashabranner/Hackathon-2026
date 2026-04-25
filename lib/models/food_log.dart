import 'nutrition_estimate.dart';

class FoodLog {
  final String id;
  final String userId;
  final String rawInput;
  final DateTime loggedAt;
  final NutritionEstimate nutrition;
  final String source; // 'local_fallback' | 'edge_function' | 'manual'

  const FoodLog({
    required this.id,
    required this.userId,
    required this.rawInput,
    required this.loggedAt,
    required this.nutrition,
    this.source = 'local_fallback',
  });

  FoodLog copyWith({
    String? id,
    String? userId,
    String? rawInput,
    DateTime? loggedAt,
    NutritionEstimate? nutrition,
    String? source,
  }) {
    return FoodLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      rawInput: rawInput ?? this.rawInput,
      loggedAt: loggedAt ?? this.loggedAt,
      nutrition: nutrition ?? this.nutrition,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'raw_input': rawInput,
        'logged_at': loggedAt.toIso8601String(),
        'nutrition': nutrition.toJson(),
        'source': source,
      };

  factory FoodLog.fromJson(Map<String, dynamic> j) => FoodLog(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        rawInput: j['raw_input'] as String,
        loggedAt: DateTime.parse(j['logged_at'] as String),
        nutrition:
            NutritionEstimate.fromJson(j['nutrition'] as Map<String, dynamic>),
        source: j['source'] as String? ?? 'local_fallback',
      );
}
