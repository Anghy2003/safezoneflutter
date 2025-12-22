import 'dart:convert';
import 'package:http/http.dart' as http;

class GroqService {
  final String apiKey;

  GroqService({required this.apiKey});

  Future<String> getEmergencyAdvice({
    required String emergencyType,
    required String userMessage,
  }) async {
    final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    final systemPrompt = """
Eres Isis Ayuda, la asistente virtual de SafeZone.
Responde siempre en español, de forma empática, cercana y calmada.
No uses listas ni pasos.
No des instrucciones médicas ni técnicas.
No incites a confrontaciones.
Si el usuario pide ayuda urgente, recuérdale que puede presionar tres veces el botón de volumen para enviar una alerta SafeZone.
""";

    final body = {
      "model": "llama-3.1-8b-instant",
      "messages": [
        {"role": "system", "content": systemPrompt},
        {"role": "user", "content": userMessage}
      ],
      "temperature": 0.5,
    };

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Error Groq: ${response.body}');
    }

    final json = jsonDecode(response.body);
    return json["choices"][0]["message"]["content"];
  }
}
