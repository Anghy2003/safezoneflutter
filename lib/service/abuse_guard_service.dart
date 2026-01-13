// lib/service/abuse_guard_service.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AbuseGuardService {
  static const String kAlertLog = "alert_log_v1";
  static const String kPenaltyUntil = "penalty_until_iso_v1";

  /// Máximo alertas en ventana
  static const int maxAlerts = 3;

  /// Ventana de tiempo
  static const Duration window = Duration(hours: 1);

  /// Penalización
  static const Duration penalty = Duration(days: 15);

  /// Devuelve true si la cuenta está penalizada (aún no vence).
  static Future<bool> isPenalized() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(kPenaltyUntil);
    if (iso == null) return false;

    final until = DateTime.tryParse(iso);
    if (until == null) return false;

    final now = DateTime.now();
    if (now.isBefore(until)) return true;

    // Ya venció -> limpiar
    await prefs.remove(kPenaltyUntil);
    return false;
  }

  /// Registra un intento de “enviar alerta”.
  /// - Si excede maxAlerts en 1 hora, aplica penalización y devuelve false.
  /// - Si está permitido, devuelve true.
  static Future<bool> registerAlertAttempt() async {
    final prefs = await SharedPreferences.getInstance();

    // Si ya está penalizado, no permitir
    if (await isPenalized()) return false;

    final now = DateTime.now();

    // Leer log
    final raw = prefs.getString(kAlertLog);
    final List<String> items = raw == null ? <String>[] : List<String>.from(jsonDecode(raw));

    // Filtrar a ventana (última hora)
    final cutoff = now.subtract(window);
    final filtered = items
        .map((s) => DateTime.tryParse(s))
        .where((dt) => dt != null && dt!.isAfter(cutoff))
        .map((dt) => dt!.toIso8601String())
        .toList();

    // Agregar este intento
    filtered.add(now.toIso8601String());

    // ¿Excede?
    if (filtered.length >= maxAlerts) {
      final until = now.add(penalty);
      await prefs.setString(kPenaltyUntil, until.toIso8601String());

      // Limpia log para evitar loops
      await prefs.remove(kAlertLog);

      return false;
    }

    // Guardar log actualizado
    await prefs.setString(kAlertLog, jsonEncode(filtered));
    return true;
  }
}
