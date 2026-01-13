// lib/service/sos_hardware_service.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../routes/app_routes.dart';

class SosHardwareService {
  static const _channel = MethodChannel('safezone/background_sos');

  static GlobalKey<NavigatorState>? _navKey;

  static void bindNavigator(GlobalKey<NavigatorState> key) {
    _navKey = key;
  }

  static Future<void> init() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openQuickSos') {
        final nav = _navKey?.currentState;
        if (nav != null) {
          nav.pushNamed(
            AppRoutes.home,
            arguments: {"openQuickSos": true},
          );
        }
      }
      return;
    });
  }

  // Tu implementación real (la que ya tienes) debe quedarse aquí:
  static Future<void> enviarSOSDesdeUI() async {
    // llama a tu backend / Firestore / etc.
  }
}
