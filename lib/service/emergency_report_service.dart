import 'dart:convert';
import 'package:http/http.dart' as http;

import '../service/auth_service.dart';
import '../config/api_config.dart';

class AiAnalysisResult {
  final String category;
  final String priority;
  final bool possibleFake;
  final double? confidence;
  final List<dynamic> reasons;
  final List<dynamic> riskFlags;
  final String? recommendedAction;

  AiAnalysisResult({
    required this.category,
    required this.priority,
    required this.possibleFake,
    required this.confidence,
    required this.reasons,
    required this.riskFlags,
    required this.recommendedAction,
  });

  factory AiAnalysisResult.fromJson(
    Map<String, dynamic> j, {
    required String fallbackCategory,
  }) {
    if (!j.containsKey("possibleFake") && j.containsKey("possible_fake")) {
      j["possibleFake"] = j["possible_fake"];
    }
    if (!j.containsKey("risk_flags") && j.containsKey("riskFlags")) {
      j["risk_flags"] = j["riskFlags"];
    }

    return AiAnalysisResult(
      category: (j["category"] ?? fallbackCategory).toString(),
      priority: (j["priority"] ?? "MEDIA").toString(),
      possibleFake: (j["possibleFake"] ?? false) == true,
      confidence: j["confidence"] is num ? (j["confidence"] as num).toDouble() : null,
      reasons: (j["reasons"] is List)
          ? (j["reasons"] as List).cast<dynamic>()
          : const <dynamic>[],
      riskFlags: (j["risk_flags"] is List)
          ? (j["risk_flags"] as List).cast<dynamic>()
          : const <dynamic>[],
      recommendedAction: (j["recommended_action"] ?? j["recommendedAction"])?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        "category": category,
        "priority": priority,
        "possibleFake": possibleFake,
        "confidence": confidence,
        "reasons": reasons,
        "risk_flags": riskFlags,
        "recommended_action": recommendedAction,
      };
}

class EmergencyReportService {
  Map<String, String> get _jsonHeaders => {
        ...AuthService.headers,
        'Content-Type': 'application/json',
      };

  bool shouldBlockPublish({required bool possibleFake, required String priority}) {
    final pr = priority.toUpperCase().trim();
    return possibleFake == true || pr == "BAJA";
  }

  String resolveChatCanal(String? source) {
    final src = (source ?? "").toUpperCase().trim();
    if (src == "VECINOS") return "VECINOS";
    if (src == "COMUNIDAD") return "COMUNIDAD";
    return "COMUNIDAD";
  }

  String buildSosTipo(String emergencyType) {
    final norm = emergencyType
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return "SOS_$norm";
  }

  Future<Map<String, dynamic>> analyzeWithIA({
    required String descripcion,
    String? imagenUrl,
    String? videoThumbUrl,
    String? audioTranscripcion,
    required int? usuarioId,
  }) async {
    final payload = {
      "text": descripcion,
      "imageUrls": [
        if (imagenUrl != null) imagenUrl,
        if (videoThumbUrl != null) videoThumbUrl,
      ],
      "audioTranscript": audioTranscripcion,
      "userContext": usuarioId == null ? null : "usuario $usuarioId",
    }..removeWhere((k, v) => v == null);

    final resp = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/ai/analyze-incident"),
      headers: _jsonHeaders,
      body: jsonEncode(payload),
    );

    if (resp.statusCode != 200) {
      throw Exception("Error IA ${resp.statusCode}: ${resp.body}");
    }

    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<String> createIncident({
    required String tipo,
    required String descripcion,
    required String nivelPrioridad,
    required int usuarioId,
    required int comunidadId,
    required double? lat,
    required double? lng,
    String? imagenUrl,
    String? videoUrl,
    String? audioUrl,

    AiAnalysisResult? ai,

    // ✅ NUEVO: idempotencia y meta offline
    String? clientGeneratedId,
    String? canalEnvio,
    bool? smsEnviadoPorCliente,
  }) async {
    final body = <String, dynamic>{
      "tipo": tipo,
      "descripcion": descripcion,
      "nivelPrioridad": nivelPrioridad,
      "imagenUrl": imagenUrl,
      "videoUrl": videoUrl,
      "audioUrl": audioUrl,
      "usuarioId": usuarioId,
      "comunidadId": comunidadId,
      "lat": lat,
      "lng": lng,

      // extras offline
      "clientGeneratedId": clientGeneratedId,
      "canalEnvio": canalEnvio,
      "smsEnviadoPorCliente": smsEnviadoPorCliente,

      if (ai != null) ...{
        "aiCategoria": ai.category,
        "aiPrioridad": ai.priority,
        "aiConfianza": ai.confidence,
        "aiPosibleFalso": ai.possibleFake,
        "aiMotivos": jsonEncode(ai.reasons),
        "aiRiesgos": jsonEncode(ai.riskFlags),
        "aiAccionRecomendada": ai.recommendedAction,
      }
    }..removeWhere((k, v) => v == null);

    final resp = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/incidentes"),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );

    if (resp.statusCode != 201 && resp.statusCode != 200) {
      throw Exception("Error creando incidente: ${resp.body}");
    }

    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return (decoded["id"] ?? "").toString();
  }

  Future<void> postIncidentToChat({
    required int usuarioId,
    required int comunidadId,
    required String canal,
    required String descripcion,
    required String incidenteId,
    String? imagenUrl,
    String? videoUrl,
    String? audioUrl,
  }) async {
    final payload = <String, dynamic>{
      "usuarioId": usuarioId,
      "comunidadId": comunidadId,
      "canal": canal,
      "tipo": "incidente",
      "mensaje": descripcion,
      "imagenUrl": imagenUrl,
      "videoUrl": videoUrl,
      "audioUrl": audioUrl,
      "incidenteId": incidenteId,
      "replyToId": null,
    }..removeWhere((k, v) => v == null);

    final resp = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/mensajes-comunidad/enviar"),
      headers: _jsonHeaders,
      body: jsonEncode(payload),
    );

    if (resp.statusCode != 201 && resp.statusCode != 200) {
      throw Exception("Error chat ${resp.statusCode}: ${resp.body}");
    }
  }
}
