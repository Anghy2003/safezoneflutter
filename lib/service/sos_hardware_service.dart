// lib/service/sos_hardware_service.dart
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/incidente.dart';
import 'auth_service.dart';

class SosHardwareService {
  // 🔴 Debe coincidir con el canal definido en Kotlin
  static const _channel = MethodChannel('safezone/background_sos');

  /// Llamar esto al iniciar la app (ej. en main)
  static Future<void> init() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onHardwareSOS') {
        // Evento que viene del servicio nativo (botón físico)
        await _enviarSOS(origen: 'BOTON_FISICO');
      }
      return;
    });
  }

  /// Arrancar servicio nativo
  static Future<void> startNativeService() async {
    try {
      await _channel.invokeMethod('startVolumeService');
    } catch (e) {}
  }

  /// Detener servicio nativo
  static Future<void> stopNativeService() async {
    try {
      await _channel.invokeMethod('stopVolumeService');
    } catch (e) {}
  }

  /// Usar desde la UI
  static Future<void> enviarSOSDesdeUI() async {
    await _enviarSOS(origen: 'BOTON_UI');
  }

  /// Lógica para enviar el reporte al backend
  static Future<void> _enviarSOS({required String origen}) async {
    try {
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final incidente = Incidente(
        id: null,
        usuarioId: userId.toString(),
        tipoEmergencia: 'SOS_$origen',
        mensaje: 'SOS enviado automáticamente desde $origen',
        latitud: pos.latitude,
        longitud: pos.longitude,
        direccion: null,
        imagenUrl: null,
        estado: 'PENDIENTE',
        prioridad: 1,
        comunidadId: null,
        moderadoPorUid: null,
        fechaCreacion: DateTime.now(),
        fechaResolucion: null,
      );

      final body = jsonEncode(incidente.toJson());

      final url = Uri.parse('${AuthService.baseUrl}/incidentes');
      final res = await http.post(
        url,
        headers: AuthService.headers,
        body: body,
      );

      // print('SOS enviado: ${res.statusCode}');
    } catch (e) {
      // print('Error SOS: $e');
    }
  }
}
