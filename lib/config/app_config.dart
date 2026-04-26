import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static const _supabaseUrlDefine = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseAnonKeyDefine =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _foodParserUrlDefine = String.fromEnvironment('FOOD_PARSER_URL');

  static String get supabaseUrl =>
      _supabaseUrlDefine.isNotEmpty ? _supabaseUrlDefine : _env('SUPABASE_URL');

  static String get supabaseAnonKey => _supabaseAnonKeyDefine.isNotEmpty
      ? _supabaseAnonKeyDefine
      : _env('SUPABASE_ANON_KEY');

  static String get foodParserUrl => _foodParserUrlDefine.isNotEmpty
      ? _foodParserUrlDefine
      : _env('FOOD_PARSER_URL');

  static bool get hasRemoteFoodParser =>
      foodParserUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static String _env(String key) => dotenv.maybeGet(key) ?? '';
}
