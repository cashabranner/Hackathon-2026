class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const foodParserUrl = String.fromEnvironment('FOOD_PARSER_URL');

  static bool get hasRemoteFoodParser =>
      foodParserUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
