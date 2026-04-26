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
    final response = await http.post(
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
    );

    final decoded = jsonDecode(response.body);
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
}

class CoachChatException implements Exception {
  final String message;
  const CoachChatException(this.message);

  @override
  String toString() => message;
}
