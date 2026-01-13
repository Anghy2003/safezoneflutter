import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

import '../config/api_config.dart';

class ChatService {
  ChatService({
    this.baseUrl = ApiConfig.baseUrl,
    this.wsUrl = ApiConfig.wsUrl,
  });

  final String baseUrl;
  final String wsUrl;

  StompClient? _client;

  bool get isConnected => _client?.connected == true;

  ValueChanged<Map<String, dynamic>>? onCommunityMessage;
  ValueChanged<Map<String, dynamic>>? onNearbyMessage;

  ValueChanged<Object>? onWsError;

  void connect({
    required int comunidadId,
    required int myUserId,
    String? myPhotoUrl,
  }) {
    disconnect();

    _client = StompClient(
      config: StompConfig.SockJS(
        url: wsUrl,
        onConnect: (frame) => _onConnected(frame, comunidadId, myUserId, myPhotoUrl),
        onWebSocketError: (error) {
          debugPrint("WS ERROR: $error");
          onWsError?.call(error);
        },
        onDisconnect: (_) => debugPrint("WS DISCONNECTED"),
      ),
    );

    _client!.activate();
  }

  void disconnect() {
    try {
      _client?.deactivate();
    } catch (_) {}
    _client = null;
  }

  void _onConnected(
    StompFrame frame,
    int comunidadId,
    int myUserId,
    String? myPhotoUrl,
  ) {
    _client?.subscribe(
      destination: "/topic/comunidad-$comunidadId",
      callback: (f) {
        if (f.body == null) return;
        final msg = _parseWsMessage(f.body!, myUserId, myPhotoUrl);
        if (msg == null) return;
        onCommunityMessage?.call(msg);
      },
    );

    _client?.subscribe(
      destination: "/topic/vecinos-$comunidadId",
      callback: (f) {
        if (f.body == null) return;
        final msg = _parseWsMessage(f.body!, myUserId, myPhotoUrl);
        if (msg == null) return;
        onNearbyMessage?.call(msg);
      },
    );
  }

  Map<String, dynamic>? _parseWsMessage(String body, int myUserId, String? myPhotoUrl) {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    final data = Map<String, dynamic>.from(decoded);

    final int? senderId = (data["usuarioId"] is num)
        ? (data["usuarioId"] as num).toInt()
        : int.tryParse((data["usuarioId"] ?? "").toString());

    final bool isMe = senderId != null && senderId == myUserId;

    final String senderName = (data["usuarioNombre"] ?? "Usuario").toString();
    String? avatarUrl = _nullIfBlank(data["usuarioFotoUrl"]);
    if (isMe && (avatarUrl == null || avatarUrl.isEmpty)) avatarUrl = myPhotoUrl;

    final String text = (data["mensaje"] ?? "").toString();
    final String? imagenUrl = _nullIfBlank(data["imagenUrl"]);
    final String? videoUrl = _nullIfBlank(data["videoUrl"]);
    final String? audioUrl = _nullIfBlank(data["audioUrl"]);

    final bool hasText = text.trim().isNotEmpty;
    final bool hasAnyMedia = imagenUrl != null || videoUrl != null || audioUrl != null;
    if (!hasText && !hasAnyMedia) return null;

    String time = "";
    final fechaEnvio = data["fechaEnvio"];
    if (fechaEnvio != null) {
      try {
        final dt = DateTime.parse(fechaEnvio.toString());
        time =
            "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      } catch (_) {}
    }

    // ✅ sensible (viene del backend)
    final bool contenidoSensible = data["contenidoSensible"] == true;
    final String? sensibilidadMotivo = _nullIfBlank(data["sensibilidadMotivo"]);
    final double? sensibilidadScore = (data["sensibilidadScore"] is num)
        ? (data["sensibilidadScore"] as num).toDouble()
        : double.tryParse((data["sensibilidadScore"] ?? "").toString());

    final String canal = (data["canal"] ?? "").toString().toUpperCase();

    return {
      'sender': isMe ? 'Tú' : senderName,
      'message': text,
      'time': time,
      'isMe': isMe,
      'avatar': avatarUrl ?? '',
      'userId': senderId,

      'imagenUrl': imagenUrl,
      'videoUrl': videoUrl,
      'audioUrl': audioUrl,
      'replyToId': data['replyToId'],
      'canal': canal,
      'tipo': (data['tipo'] ?? 'texto').toString(),
      'id': data['id'],

      'contenidoSensible': contenidoSensible,
      'sensibilidadMotivo': sensibilidadMotivo,
      'sensibilidadScore': sensibilidadScore,
    };
  }

  Future<List<Map<String, dynamic>>> loadHistorial({
    required int comunidadId,
    required String canal,
    required int? myUserId,
    String? myPhotoUrl,
  }) async {
    final uri = Uri.parse("$baseUrl/mensajes-comunidad/historial").replace(
      queryParameters: {
        "comunidadId": comunidadId.toString(),
        "canal": canal,
      },
    );

    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception("Error ${resp.statusCode}: ${resp.body}");
    }

    final dynamic list = jsonDecode(resp.body);
    if (list is! List) throw Exception("Respuesta inesperada: se esperaba lista");

    final result = <Map<String, dynamic>>[];
    for (final raw in list) {
      final bubble = _mapDtoToBubble(raw, myUserId, myPhotoUrl);
      if (bubble != null) result.add(bubble);
    }
    return result;
  }

  Map<String, dynamic>? _mapDtoToBubble(dynamic raw, int? myUserId, String? myPhotoUrl) {
    if (raw is! Map) return null;
    final data = Map<String, dynamic>.from(raw);

    final int? senderId = (data["usuarioId"] is num)
        ? (data["usuarioId"] as num).toInt()
        : int.tryParse((data["usuarioId"] ?? "").toString());

    final bool isMe = myUserId != null && senderId != null && myUserId == senderId;

    String? avatarUrl = _nullIfBlank(data["usuarioFotoUrl"]);
    if (isMe && (avatarUrl == null || avatarUrl.isEmpty)) avatarUrl = myPhotoUrl;

    final String text = (data["mensaje"] ?? "").toString();

    final String? imagenUrl = _nullIfBlank(data["imagenUrl"]);
    final String? videoUrl = _nullIfBlank(data["videoUrl"]);
    final String? audioUrl = _nullIfBlank(data["audioUrl"]);

    final bool hasText = text.trim().isNotEmpty;
    final bool hasAnyMedia = imagenUrl != null || videoUrl != null || audioUrl != null;
    if (!hasText && !hasAnyMedia) return null;

    String time = "";
    final fechaEnvio = data["fechaEnvio"];
    if (fechaEnvio != null) {
      try {
        final dt = DateTime.parse(fechaEnvio.toString());
        time =
            "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      } catch (_) {}
    }

    final bool contenidoSensible = data["contenidoSensible"] == true;
    final String? sensibilidadMotivo = _nullIfBlank(data["sensibilidadMotivo"]);
    final double? sensibilidadScore = (data["sensibilidadScore"] is num)
        ? (data["sensibilidadScore"] as num).toDouble()
        : double.tryParse((data["sensibilidadScore"] ?? "").toString());

    return {
      'sender': isMe ? 'Tú' : (data["usuarioNombre"] ?? "Usuario").toString(),
      'message': text,
      'time': time,
      'isMe': isMe,
      'avatar': avatarUrl ?? '',
      'userId': senderId,

      'imagenUrl': imagenUrl,
      'videoUrl': videoUrl,
      'audioUrl': audioUrl,
      'replyToId': data['replyToId'],
      'canal': (data['canal'] ?? '').toString(),
      'tipo': (data['tipo'] ?? 'texto').toString(),
      'id': data['id'],

      'contenidoSensible': contenidoSensible,
      'sensibilidadMotivo': sensibilidadMotivo,
      'sensibilidadScore': sensibilidadScore,
    };
  }

  void sendTextMessage({
    required int myUserId,
    required int comunidadId,
    required bool vecinos,
    required String text,
  }) {
    if (_client == null || _client?.connected != true) {
      throw Exception("WS no conectado");
    }

    final msg = {
      "usuarioId": myUserId,
      "comunidadId": comunidadId,
      "canal": vecinos ? "VECINOS" : "COMUNIDAD",
      "tipo": "texto",
      "mensaje": text,
      "imagenUrl": null,
      "videoUrl": null,
      "audioUrl": null,
      "replyToId": null,
      // ✅ NO enviar flags: backend los define si hay adjuntos.
    };

    _client!.send(
      destination: vecinos ? "/app/chat/vecinos" : "/app/chat/comunidad",
      body: jsonEncode(msg),
    );
  }

  String? _nullIfBlank(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}
