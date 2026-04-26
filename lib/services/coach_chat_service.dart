import 'dart:convert';

import 'package:http/http.dart' as http;

class CoachChatMessage {
  final CoachChatRole role;
  final String content;

  const CoachChatMessage({
    required this.role,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'content': content,
      };
}

enum CoachChatRole { user, assistant }

class CoachChatService {
  static Future<String> sendMessage({
    required String coachChatUrl,
    required String anonKey,
    required Map<String, dynamic> metrics,
    required List<CoachChatMessage> messages,
  }) async {
    late final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(coachChatUrl),
            headers: {
              'Content-Type': 'application/json',
              if (anonKey.isNotEmpty) 'apikey': anonKey,
              if (anonKey.isNotEmpty) 'Authorization': 'Bearer $anonKey',
            },
            body: jsonEncode({
              'metrics': metrics,
              'messages': messages.map((message) => message.toJson()).toList(),
            }),
          )
          .timeout(const Duration(seconds: 25));
    } catch (err) {
      throw CoachChatException('Coach request could not be reached: $err');
    }

    final decoded = _decodeResponse(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map<String, dynamic>
          ? decoded['detail'] ?? decoded['error'] ?? decoded
          : response.body;
      throw CoachChatException('Coach request failed: $detail');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const CoachChatException('Coach returned invalid JSON');
    }

    final reply = decoded['reply'];
    if (reply is! String || reply.trim().isEmpty) {
      throw const CoachChatException('Coach returned an empty reply');
    }

    return reply.trim();
  }

  static dynamic _decodeResponse(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      final preview = body.trim();
      throw CoachChatException(
        preview.isEmpty
            ? 'Coach returned an empty response'
            : 'Coach returned invalid JSON: '
                '${preview.length > 120 ? '${preview.substring(0, 120)}...' : preview}',
      );
    }
  }
}

class CoachChatException implements Exception {
  final String message;
  const CoachChatException(this.message);

  @override
  String toString() => message;
}
