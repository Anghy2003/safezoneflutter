import 'dart:convert';

import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

class WebSocketService {
  static StompClient? stompClient;

  static void connect({
    required Function(Map<String, dynamic>) onMessage,
    required int comunidadId,
  }) {
    stompClient = StompClient(
      config: StompConfig.SockJS(
        url: 'http://192.168.3.25:8080/ws',   // 👈 tu endpoint websocket
        onConnect: (StompFrame frame) {
          print("WS Conectado!");

          // Suscribirse a la comunidad
          stompClient?.subscribe(
            destination: "/topic/comunidad-$comunidadId",
            callback: (frame) {
              if (frame.body != null) {
                final data = frame.body!;
                onMessage(Map<String, dynamic>.from(
                  jsonDecode(data),
                ));
              }
            },
          );

          // Suscribirse al radar (personas cercanas)
          stompClient?.subscribe(
            destination: "/topic/vecinos-$comunidadId",
            callback: (frame) {
              if (frame.body != null) {
                onMessage(Map<String, dynamic>.from(
                  jsonDecode(frame.body!),
                ));
              }
            },
          );
        },
        onWebSocketError: (e) => print("WS error: $e"),
      ),
    );

    stompClient?.activate();
  }

  static void disconnect() {
    stompClient?.deactivate();
  }
}
