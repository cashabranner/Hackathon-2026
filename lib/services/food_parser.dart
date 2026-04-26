import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/food_catalog.dart';
import '../models/nutrition_estimate.dart';

/// Parses free-text food descriptions into NutritionEstimate.
/// Uses a local keyword database for demo. When Supabase Edge Function
/// credentials are present, the real implementation can delegate there.
class FoodParser {
  static const int maxNutritionLabelImageBytes = 8 * 1024 * 1024;
  static const Set<String> supportedNutritionLabelMimeTypes = {
    'image/png',
    'image/jpeg',
    'image/webp',
    'image/heic',
    'image/heif',
  };

  /// Parse free-text food description; returns best-effort local estimate.
  static NutritionEstimate parseText(
    String input, {
    List<String> allergies = const [],
  }) {
    final parsed = parseTextItems(input, allergies: allergies);
    if (parsed.isNotEmpty) {
      return aggregateParsedFoodItems(parsed, foodName: input);
    }

    final lower = input.toLowerCase();
    NutritionEstimate? best;
    double bestScore = -1;

    for (final entry in _foodDatabase) {
      final score = _matchScore(lower, entry.keywords);
      if (score > bestScore) {
        bestScore = score;
        best = entry.estimate;
      }
    }

    // If nothing matched well, return a generic carb-based placeholder
    if (bestScore < 0.1) {
      return NutritionEstimate(
        foodName: input.trim().isEmpty ? 'Unknown food' : input.trim(),
        grams: 100,
        carbsG: 20,
        glucoseG: 16,
        fructoseG: 4,
        fiberG: 2,
        proteinG: 5,
        fatG: 3,
        calories: 127,
      );
    }

    return best!;
  }

  static List<ParsedFoodItem> parseTextItems(
    String input, {
    List<String> allergies = const [],
  }) {
    final lower = input.toLowerCase();
    final avoid = allergies.map((allergy) => allergy.toLowerCase()).toSet();
    final items = <ParsedFoodItem>[];

    for (final entry in foodCatalog) {
      if (_isAvoided(entry, avoid)) continue;
      final alias = _bestAlias(lower, entry.aliases);
      if (alias == null) continue;
      final quantity = _quantityBeforeAlias(lower, alias) ??
          _quantityAfterAlias(lower, alias) ??
          entry.defaultServingQty;
      items.add(
        ParsedFoodItem(
          catalogEntryId: entry.id,
          displayName: entry.displayName,
          servingQty: quantity,
          servingLabel: entry.servingLabel,
          nutritionPerServing: entry.nutritionPerServing,
        ),
      );
    }

    return items;
  }

  static String? _bestAlias(String input, List<String> aliases) {
    final matches = aliases.where((alias) => input.contains(alias)).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    return matches.isEmpty ? null : matches.first;
  }

  static bool _isAvoided(FoodCatalogEntry entry, Set<String> avoid) {
    if (avoid.isEmpty) return false;
    final text =
        '${entry.displayName} ${entry.aliases.join(' ')}'.toLowerCase();
    return avoid.any(text.contains);
  }

  static double? _quantityBeforeAlias(String input, String alias) {
    final escaped = RegExp.escape(alias);
    final match = RegExp(
      r'(?:^|[\s,])((?:\d+(?:\.\d+)?)|one|two|three|four|five|six|seven|eight|nine|ten|a|an)\s+(?:large\s+|medium\s+|small\s+)?' +
          escaped,
    ).firstMatch(input);
    return _parseQuantity(match?.group(1));
  }

  static double? _quantityAfterAlias(String input, String alias) {
    final escaped = RegExp.escape(alias);
    final match = RegExp(
      escaped +
          r'\s*(?:\(|,)?\s*((?:\d+(?:\.\d+)?)|one|two|three|four|five|six|seven|eight|nine|ten|a|an)\s*(?:servings?|cups?|slices?|tbsp|tablespoons?)?',
    ).firstMatch(input);
    return _parseQuantity(match?.group(1));
  }

  static double? _parseQuantity(String? value) {
    if (value == null) return null;
    final numeric = double.tryParse(value);
    if (numeric != null) return numeric;
    return switch (value) {
      'a' || 'an' || 'one' => 1,
      'two' => 2,
      'three' => 3,
      'four' => 4,
      'five' => 5,
      'six' => 6,
      'seven' => 7,
      'eight' => 8,
      'nine' => 9,
      'ten' => 10,
      _ => null,
    };
  }

  static double _matchScore(String input, List<String> keywords) {
    int hits = 0;
    for (final kw in keywords) {
      if (input.contains(kw)) hits++;
    }
    return keywords.isEmpty ? 0 : hits / keywords.length;
  }

  /// Parse through the Supabase Edge Function when remote parsing is enabled.
  /// Input: free-text description or nutrition label image bytes.
  /// Output: NutritionEstimate
  ///
  /// Edge Function request shape:
  ///   {
  ///     "description": string?,
  ///     "image_base64": string?,
  ///     "mime_type": string?
  ///   }
  ///
  /// Edge Function response shape:
  ///   {
  ///     "food_name": string,
  ///     "grams": number,
  ///     "carbs_g": number,
  ///     "glucose_g": number,
  ///     "fructose_g": number,
  ///     "fiber_g": number,
  ///     "protein_g": number,
  ///     "fat_g": number,
  ///     "calories": number,
  ///     "micros": { magnesium_mg, potassium_mg, sodium_mg, iron_mg, zinc_mg, b12_mcg, vitamin_d_iu },
  ///     "is_high_fat": boolean,
  ///     "is_high_fiber": boolean
  ///   }
  static Future<NutritionEstimate> parseTextRemote(
    String input,
    String edgeFunctionUrl,
    String anonKey, {
    http.Client? client,
  }) {
    return _parseRemote(
      buildRemoteRequestBody(description: input),
      edgeFunctionUrl,
      anonKey,
      client: client,
    );
  }

  static Future<NutritionEstimate> parseNutritionLabelImageRemote({
    required List<int> bytes,
    required String mimeType,
    required String edgeFunctionUrl,
    required String anonKey,
    http.Client? client,
  }) {
    return _parseRemote(
      buildRemoteRequestBody(imageBytes: bytes, mimeType: mimeType),
      edgeFunctionUrl,
      anonKey,
      client: client,
    );
  }

  static Map<String, dynamic> buildRemoteRequestBody({
    String? description,
    List<int>? imageBytes,
    String? mimeType,
  }) {
    final payload = <String, dynamic>{};
    final trimmedDescription = description?.trim();
    if (trimmedDescription != null && trimmedDescription.isNotEmpty) {
      payload['description'] = trimmedDescription;
    }

    if (imageBytes != null) {
      if (imageBytes.length > maxNutritionLabelImageBytes) {
        throw const FoodParserException(
          'Image is too large to scan. Choose an image under 8 MB.',
        );
      }

      final normalizedMimeType = _normalizeNutritionLabelMimeType(mimeType);
      if (normalizedMimeType == null || normalizedMimeType.isEmpty) {
        throw const FoodParserException('Image MIME type is required.');
      }
      if (!isSupportedNutritionLabelMimeType(normalizedMimeType)) {
        throw const FoodParserException(
          'Unsupported image type. Use a JPEG, PNG, WEBP, HEIC, or HEIF nutrition label.',
        );
      }

      payload['image_base64'] = base64Encode(imageBytes);
      payload['mime_type'] = normalizedMimeType;
    }

    return payload;
  }

  static bool isSupportedNutritionLabelMimeType(String mimeType) {
    return supportedNutritionLabelMimeTypes.contains(
      _normalizeNutritionLabelMimeType(mimeType),
    );
  }

  static String? _normalizeNutritionLabelMimeType(String? mimeType) {
    final normalized = mimeType?.trim().toLowerCase();
    if (normalized == 'image/jpg') return 'image/jpeg';
    return normalized;
  }

  static Future<NutritionEstimate> _parseRemote(
    Map<String, dynamic> payload,
    String edgeFunctionUrl,
    String anonKey, {
    http.Client? client,
  }) async {
    final uri = Uri.parse(edgeFunctionUrl);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (anonKey.isNotEmpty) 'apikey': anonKey,
      if (anonKey.isNotEmpty) 'Authorization': 'Bearer $anonKey',
    };

    final body = jsonEncode(payload);
    late final http.Response response;
    try {
      response = await (client == null
              ? http.post(uri, headers: headers, body: body)
              : client.post(uri, headers: headers, body: body))
          .timeout(const Duration(seconds: 25));
    } on FoodParserException {
      rethrow;
    } catch (err) {
      throw FoodParserException(
          'Remote food parser could not be reached: $err');
    }

    final decoded = _decodeResponse(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map<String, dynamic>
          ? decoded['detail'] ?? decoded['error'] ?? decoded
          : response.body;
      throw FoodParserException('Remote food parser failed: $detail');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FoodParserException(
        'Remote food parser returned invalid JSON',
      );
    }

    if (decoded['error'] != null) {
      throw FoodParserException(
        'Remote food parser failed: ${decoded['error']}',
      );
    }

    return NutritionEstimate.fromJson(decoded);
  }

  static dynamic _decodeResponse(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      final preview = body.trim();
      throw FoodParserException(
        preview.isEmpty
            ? 'Remote food parser returned an empty response'
            : 'Remote food parser returned invalid JSON: '
                '${preview.length > 120 ? '${preview.substring(0, 120)}...' : preview}',
      );
    }
  }
}

class FoodParserException implements Exception {
  final String message;
  const FoodParserException(this.message);

  @override
  String toString() => message;
}

// ─── Local food database ─────────────────────────────────────────────────────

class _FoodEntry {
  final List<String> keywords;
  final NutritionEstimate estimate;
  const _FoodEntry(this.keywords, this.estimate);
}

const foodCatalog = [
  FoodCatalogEntry(
    id: 'egg',
    displayName: 'Egg',
    aliases: ['egg', 'eggs'],
    servingLabel: 'large egg',
    nutritionPerServing: NutritionEstimate(
      foodName: 'Egg',
      grams: 50,
      carbsG: 0.5,
      glucoseG: 0.5,
      fructoseG: 0,
      fiberG: 0,
      proteinG: 6.5,
      fatG: 5,
      calories: 72,
      isHighFat: true,
      micros: MicroNutrients(
        b12Mcg: 0.55,
        ironMg: 0.9,
        zincMg: 0.65,
        vitaminDIu: 41,
      ),
    ),
    cookingTimeMinutes: 8,
  ),
  FoodCatalogEntry(
    id: 'oatmeal',
    displayName: 'Oatmeal',
    aliases: ['oatmeal', 'oats', 'oat', 'porridge'],
    servingLabel: 'cup cooked',
    nutritionPerServing: NutritionEstimate(
      foodName: 'Oatmeal',
      grams: 234,
      carbsG: 27,
      glucoseG: 22,
      fructoseG: 1,
      fiberG: 4,
      proteinG: 6,
      fatG: 3,
      calories: 158,
      isHighFiber: true,
      micros: MicroNutrients(magnesiumMg: 57, potassiumMg: 143, ironMg: 2),
    ),
    cookingTimeMinutes: 7,
  ),
  FoodCatalogEntry(
    id: 'banana',
    displayName: 'Banana',
    aliases: ['banana', 'bananas'],
    servingLabel: 'medium banana',
    nutritionPerServing: NutritionEstimate(
      foodName: 'Banana',
      grams: 118,
      carbsG: 27,
      glucoseG: 10,
      fructoseG: 9,
      fiberG: 3,
      proteinG: 1,
      fatG: 0,
      calories: 105,
      micros: MicroNutrients(potassiumMg: 422, magnesiumMg: 32),
    ),
    cookingTimeMinutes: 0,
  ),
  FoodCatalogEntry(
    id: 'white_rice',
    displayName: 'White rice',
    aliases: ['white rice', 'rice'],
    servingLabel: 'cup cooked',
    nutritionPerServing: NutritionEstimate(
      foodName: 'White rice',
      grams: 186,
      carbsG: 45,
      glucoseG: 45,
      fructoseG: 0,
      fiberG: 1,
      proteinG: 4,
      fatG: 0,
      calories: 206,
      micros: MicroNutrients(magnesiumMg: 19, potassiumMg: 55),
    ),
    cookingTimeMinutes: 20,
  ),
  FoodCatalogEntry(
    id: 'chicken_breast',
    displayName: 'Chicken breast',
    aliases: ['chicken breast', 'grilled chicken', 'chicken'],
    servingLabel: '150g serving',
    nutritionPerServing: NutritionEstimate(
      foodName: 'Chicken breast',
      grams: 150,
      carbsG: 0,
      glucoseG: 0,
      fructoseG: 0,
      fiberG: 0,
      proteinG: 46,
      fatG: 5,
      calories: 231,
      micros: MicroNutrients(zincMg: 2.1, b12Mcg: 0.5, potassiumMg: 448),
    ),
    cookingTimeMinutes: 25,
  ),
  FoodCatalogEntry(
    id: 'greek_yogurt',
    displayName: 'Greek yogurt',
    aliases: ['greek yogurt', 'yogurt', 'yoghurt', 'dairy'],
    servingLabel: '200g serving',
    nutritionPerServing: NutritionEstimate(
      foodName: 'Greek yogurt',
      grams: 200,
      carbsG: 9,
      glucoseG: 9,
      fructoseG: 0,
      fiberG: 0,
      proteinG: 20,
      fatG: 1,
      calories: 123,
      micros: MicroNutrients(b12Mcg: 1.5, potassiumMg: 282, zincMg: 1.1),
    ),
    cookingTimeMinutes: 0,
  ),
  FoodCatalogEntry(
    id: 'protein_shake',
    displayName: 'Protein shake',
    aliases: ['protein shake', 'whey', 'protein powder'],
    servingLabel: 'shake',
    nutritionPerServing: NutritionEstimate(
      foodName: 'Protein shake',
      grams: 300,
      carbsG: 8,
      glucoseG: 8,
      fructoseG: 0,
      fiberG: 1,
      proteinG: 25,
      fatG: 2,
      calories: 150,
      micros: MicroNutrients(magnesiumMg: 40, zincMg: 2.5, b12Mcg: 1.2),
    ),
    cookingTimeMinutes: 2,
  ),
  FoodCatalogEntry(
    id: 'whole_wheat_bread',
    displayName: 'Whole wheat bread',
    aliases: ['whole wheat bread', 'whole grain bread', 'bread', 'toast'],
    servingLabel: '2 slices',
    nutritionPerServing: NutritionEstimate(
      foodName: 'Whole wheat bread',
      grams: 56,
      carbsG: 24,
      glucoseG: 20,
      fructoseG: 1,
      fiberG: 3,
      proteinG: 5,
      fatG: 1,
      calories: 124,
      isHighFiber: true,
      micros: MicroNutrients(magnesiumMg: 42, ironMg: 2, zincMg: 1.2),
    ),
    cookingTimeMinutes: 2,
  ),
  FoodCatalogEntry(
    id: 'sports_drink',
    displayName: 'Sports drink',
    aliases: ['sports drink', 'gatorade', 'electrolyte drink'],
    servingLabel: '16 oz',
    nutritionPerServing: NutritionEstimate(
      foodName: 'Sports drink',
      grams: 480,
      carbsG: 28,
      glucoseG: 28,
      fructoseG: 0,
      fiberG: 0,
      proteinG: 0,
      fatG: 0,
      calories: 110,
    ),
    cookingTimeMinutes: 0,
  ),
];

const _foodDatabase = [
  _FoodEntry(
    ['oatmeal', 'oat', 'porridge'],
    NutritionEstimate(
      foodName: 'Oatmeal (1 cup cooked)',
      grams: 234,
      carbsG: 27,
      glucoseG: 22,
      fructoseG: 1,
      fiberG: 4,
      proteinG: 6,
      fatG: 3,
      calories: 158,
      isHighFiber: true,
      micros: MicroNutrients(magnesiumMg: 57, potassiumMg: 143, ironMg: 2),
    ),
  ),
  _FoodEntry(
    ['blueberr'],
    NutritionEstimate(
      foodName: 'Blueberries (1/2 cup)',
      grams: 74,
      carbsG: 11,
      glucoseG: 5,
      fructoseG: 6,
      fiberG: 2,
      proteinG: 1,
      fatG: 0,
      calories: 42,
      micros: MicroNutrients(potassiumMg: 57, magnesiumMg: 4),
    ),
  ),
  _FoodEntry(
    ['egg', 'eggs'],
    NutritionEstimate(
      foodName: 'Eggs (2 large)',
      grams: 100,
      carbsG: 1,
      glucoseG: 1,
      fructoseG: 0,
      fiberG: 0,
      proteinG: 13,
      fatG: 10,
      calories: 143,
      isHighFat: true,
      micros: MicroNutrients(
        b12Mcg: 1.1,
        ironMg: 1.8,
        zincMg: 1.3,
        vitaminDIu: 82,
      ),
    ),
  ),
  _FoodEntry(
    ['coffee', 'espresso', 'americano'],
    NutritionEstimate(
      foodName: 'Coffee (black)',
      grams: 240,
      carbsG: 0,
      glucoseG: 0,
      fructoseG: 0,
      fiberG: 0,
      proteinG: 0,
      fatG: 0,
      calories: 2,
      micros: MicroNutrients(potassiumMg: 116, magnesiumMg: 7),
    ),
  ),
  _FoodEntry(
    ['coffee', 'milk', 'latte', 'cappuccino'],
    NutritionEstimate(
      foodName: 'Coffee with milk',
      grams: 250,
      carbsG: 5,
      glucoseG: 5,
      fructoseG: 0,
      fiberG: 0,
      proteinG: 3,
      fatG: 2,
      calories: 47,
      micros: MicroNutrients(potassiumMg: 150, b12Mcg: 0.5),
    ),
  ),
  _FoodEntry(
    ['banana'],
    NutritionEstimate(
      foodName: 'Banana (medium)',
      grams: 118,
      carbsG: 27,
      glucoseG: 10,
      fructoseG: 9,
      fiberG: 3,
      proteinG: 1,
      fatG: 0,
      calories: 105,
      micros: MicroNutrients(potassiumMg: 422, magnesiumMg: 32),
    ),
  ),
  _FoodEntry(
    ['rice', 'white rice'],
    NutritionEstimate(
      foodName: 'White rice (1 cup cooked)',
      grams: 186,
      carbsG: 45,
      glucoseG: 45,
      fructoseG: 0,
      fiberG: 1,
      proteinG: 4,
      fatG: 0,
      calories: 206,
      micros: MicroNutrients(magnesiumMg: 19, potassiumMg: 55),
    ),
  ),
  _FoodEntry(
    ['sweet potato', 'yam'],
    NutritionEstimate(
      foodName: 'Sweet potato (medium)',
      grams: 130,
      carbsG: 27,
      glucoseG: 22,
      fructoseG: 3,
      fiberG: 4,
      proteinG: 2,
      fatG: 0,
      calories: 112,
      isHighFiber: true,
      micros: MicroNutrients(potassiumMg: 541, magnesiumMg: 33, vitaminDIu: 0),
    ),
  ),
  _FoodEntry(
    ['chicken', 'breast', 'grilled chicken'],
    NutritionEstimate(
      foodName: 'Chicken breast (150g)',
      grams: 150,
      carbsG: 0,
      glucoseG: 0,
      fructoseG: 0,
      fiberG: 0,
      proteinG: 46,
      fatG: 5,
      calories: 231,
      micros: MicroNutrients(zincMg: 2.1, b12Mcg: 0.5, potassiumMg: 448),
    ),
  ),
  _FoodEntry(
    ['salmon', 'fish'],
    NutritionEstimate(
      foodName: 'Salmon (150g)',
      grams: 150,
      carbsG: 0,
      glucoseG: 0,
      fructoseG: 0,
      fiberG: 0,
      proteinG: 34,
      fatG: 13,
      calories: 262,
      isHighFat: true,
      micros: MicroNutrients(
        b12Mcg: 3.2,
        vitaminDIu: 570,
        potassiumMg: 628,
        zincMg: 0.9,
      ),
    ),
  ),
  _FoodEntry(
    ['protein shake', 'whey', 'protein powder'],
    NutritionEstimate(
      foodName: 'Protein shake',
      grams: 300,
      carbsG: 8,
      glucoseG: 8,
      fructoseG: 0,
      fiberG: 1,
      proteinG: 25,
      fatG: 2,
      calories: 150,
      micros: MicroNutrients(magnesiumMg: 40, zincMg: 2.5, b12Mcg: 1.2),
    ),
  ),
  _FoodEntry(
    ['greek yogurt', 'yogurt', 'yoghurt'],
    NutritionEstimate(
      foodName: 'Greek yogurt (200g)',
      grams: 200,
      carbsG: 9,
      glucoseG: 9,
      fructoseG: 0,
      fiberG: 0,
      proteinG: 20,
      fatG: 1,
      calories: 123,
      micros: MicroNutrients(b12Mcg: 1.5, potassiumMg: 282, zincMg: 1.1),
    ),
  ),
  _FoodEntry(
    ['bread', 'toast', 'whole wheat', 'whole grain'],
    NutritionEstimate(
      foodName: 'Whole wheat bread (2 slices)',
      grams: 56,
      carbsG: 24,
      glucoseG: 20,
      fructoseG: 1,
      fiberG: 3,
      proteinG: 5,
      fatG: 1,
      calories: 124,
      isHighFiber: true,
      micros: MicroNutrients(magnesiumMg: 42, ironMg: 2, zincMg: 1.2),
    ),
  ),
  _FoodEntry(
    ['pasta', 'noodle', 'spaghetti'],
    NutritionEstimate(
      foodName: 'Pasta (1 cup cooked)',
      grams: 140,
      carbsG: 43,
      glucoseG: 43,
      fructoseG: 0,
      fiberG: 2,
      proteinG: 8,
      fatG: 1,
      calories: 220,
      micros: MicroNutrients(ironMg: 2.3, magnesiumMg: 25),
    ),
  ),
  _FoodEntry(
    ['apple'],
    NutritionEstimate(
      foodName: 'Apple (medium)',
      grams: 182,
      carbsG: 25,
      glucoseG: 7,
      fructoseG: 13,
      fiberG: 4,
      proteinG: 0,
      fatG: 0,
      calories: 95,
      isHighFiber: true,
      micros: MicroNutrients(potassiumMg: 195),
    ),
  ),
  _FoodEntry(
    ['almond', 'nuts', 'nut butter', 'peanut butter'],
    NutritionEstimate(
      foodName: 'Nut butter (2 tbsp)',
      grams: 32,
      carbsG: 6,
      glucoseG: 3,
      fructoseG: 1,
      fiberG: 2,
      proteinG: 7,
      fatG: 16,
      calories: 190,
      isHighFat: true,
      micros: MicroNutrients(magnesiumMg: 49, potassiumMg: 208),
    ),
  ),
];
