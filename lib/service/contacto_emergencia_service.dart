// lib/service/contacto_emergencia_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/contacto_emergencia.dart';
import 'auth_service.dart';

class ContactoEmergenciaService {
  static String get _baseUrl => AuthService.baseUrl; // http://192.168.xx.xx:8080/api
  static Map<String, String> get _headers => AuthService.headers;

  /// 🔵 Obtener contactos SOLO del usuario actual
  static Future<List<ContactoEmergencia>> getContactosUsuarioActual() async {
    final userId = await AuthService.getCurrentUserId();
    if (userId == null) {
      throw Exception('No se encontró el usuario actual');
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/contactos-emergencia'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        final todos = data
            .map((e) => ContactoEmergencia.fromJson(e as Map<String, dynamic>))
            .toList();

        // 🔍 Filtrar solo contactos del usuario logueado (y activos)
        return todos
            .where((c) => c.usuarioId == userId && (c.activo ?? true))
            .toList();
      } else {
        throw Exception('Error al obtener contactos (${response.statusCode})');
      }
    } on SocketException {
      throw Exception('Sin conexión a internet');
    } catch (e) {
      throw Exception('Error al obtener contactos: $e');
    }
  }

  /// 🟢 Crear contacto para el usuario actual
  static Future<ContactoEmergencia?> createContacto({
    required String nombre,
    required String telefono,
    String? relacion,
    int prioridad = 1,
    String? fotoUrl,
  }) async {
    final userId = await AuthService.getCurrentUserId();
    if (userId == null) {
      throw Exception('No se encontró el usuario actual');
    }

    try {
      final contacto = ContactoEmergencia(
        id: null,
        usuarioId: userId,
        nombre: nombre,
        telefono: telefono,
        relacion: relacion,
        prioridad: prioridad,
        activo: true,
        fotoUrl: fotoUrl,
        fechaAgregado: null,
      );

      final body = jsonEncode(contacto.toJsonCreate());

      final response = await http.post(
        Uri.parse('$_baseUrl/contactos-emergencia'),
        headers: _headers,
        body: body,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ContactoEmergencia.fromJson(data);
      } else {
        throw Exception('Error al crear contacto (${response.statusCode})');
      }
    } on SocketException {
      throw Exception('Sin conexión a internet');
    } catch (e) {
      throw Exception('Error al crear contacto: $e');
    }
  }
}
