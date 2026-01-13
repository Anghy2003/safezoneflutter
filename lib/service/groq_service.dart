import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class SafeZoneAiApi {
  static String get _base => ApiConfig.baseUrl;

  Future<String> chatIsis({
    required String emergencyType,
    required String userMessage,
    List<Map<String, String>> history = const [],
  }) async {
    final uri = Uri.parse("$_base/ai/chat");

    final body = {
      "emergencyType": emergencyType,
      "userMessage": userMessage,
      "history": history, // [{role:"user", content:"..."}, {role:"assistant", content:"..."}]
    };

    final res = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw Exception("Backend AI chat error: ${res.statusCode} ${res.body}");
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json["reply"] ?? "").toString();
  }

  Future<Map<String, dynamic>> analyzeIncident({
    required String text,
    List<String> imageUrls = const [],
    String? imageBase64DataUrl,
    String? audioTranscript,
    String? userContext,
  }) async {
    final uri = Uri.parse("$_base/ai/analyze");

    final body = {
      "text": text,
      "imageUrls": imageUrls,
      "imageBase64DataUrl": imageBase64DataUrl,
      "audioTranscript": audioTranscript,
      "userContext": userContext,
    };

    final res = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw Exception("Backend AI analyze error: ${res.statusCode} ${res.body}");
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
