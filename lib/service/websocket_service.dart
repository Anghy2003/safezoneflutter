import 'dart:convert';

import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

import '../config/api_config.dart';

class WebSocketService {
  static StompClient? stompClient;

  static void connect({
    required void Function(Map<String, dynamic>) onMessage,
    required int comunidadId,
    void Function(String message)? onConnectionIssue,
  }) {
    try {
      stompClient?.deactivate();
    } catch (_) {}

    stompClient = StompClient(
      config: StompConfig.SockJS(
        url: ApiConfig.wsUrl,
        onConnect: (StompFrame frame) {
          stompClient?.subscribe(
            destination: "/topic/comunidad-$comunidadId",
            callback: (frame) => _handleFrame(frame, onMessage),
          );

          stompClient?.subscribe(
            destination: "/topic/vecinos-$comunidadId",
            callback: (frame) => _handleFrame(frame, onMessage),
          );
        },
        onWebSocketError: (e) {
          onConnectionIssue?.call(
            "Sin conexión a internet. Los mensajes se enviarán cuando vuelva la red.",
          );
        },
        onDisconnect: (_) {
          onConnectionIssue?.call(
            "Conexión perdida. Verifica tu internet.",
          );
        },
      ),
    );

    stompClient?.activate();
  }

  static void disconnect() {
    try {
      stompClient?.deactivate();
    } catch (_) {}
    stompClient = null;
  }

  static void _handleFrame(
    StompFrame frame,
    void Function(Map<String, dynamic>) onMessage,
  ) {
    final body = frame.body;
    if (body == null || body.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return;

      final msg = Map<String, dynamic>.from(decoded);

      // ✅ NO “forzar” sensible aquí. Debe venir del backend.
      // Si algún día quieres fallback, hazlo opcional por feature-flag.

      onMessage(msg);
    } catch (_) {
      // Ignorar JSON inválido
    }
  }
}
