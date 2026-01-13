// offline/offline_sync_service.dart
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../service/cloudinary_service.dart';
import '../service/emergency_report_service.dart';
import 'offline_queue_service.dart';

class OfflineSyncService {
  final OfflineQueueService queue;
  final EmergencyReportService api;

  bool _syncing = false;

  OfflineSyncService({
    required this.queue,
    required this.api,
  });

  /// ✅ PRO: no basta con "hay wifi", validamos internet real con DNS lookup.
  /// (No añade nuevas deps; solo dart:io)
  Future<bool> hasInternet() async {
    final r = await Connectivity().checkConnectivity();
    if (r == ConnectivityResult.none) return false;

    try {
      // DNS rápido para confirmar salida real a internet
      final result = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> syncAll() async {
    if (_syncing) return;
    _syncing = true;

    try {
      if (!await hasInternet()) return;

      // copia ordenada (tu queue.all() ya ordena por createdAtMillis)
      final items = queue.all();

      for (final item in items) {
        try {
          // si se perdió internet a mitad del sync, corta
          if (!await hasInternet()) return;

          String? imagenUrl;
          String? videoUrl;
          String? audioUrl;

          // ======================
          // subir adjuntos si existen
          // ======================
          if (item.localImagePath != null) {
            final f = File(item.localImagePath!);
            if (f.existsSync()) {
              imagenUrl = await CloudinaryService.uploadImage(f);
            }
          }

          if (item.localVideoPath != null) {
            final f = File(item.localVideoPath!);
            if (f.existsSync()) {
              videoUrl = await CloudinaryService.uploadVideo(f);
            }
          }

          if (item.localAudioPath != null) {
            final f = File(item.localAudioPath!);
            if (f.existsSync()) {
              audioUrl = await CloudinaryService.uploadAudio(f);
            }
          }

          AiAnalysisResult? ai;
          if (item.ai != null) {
            ai = AiAnalysisResult.fromJson(
              item.ai!,
              fallbackCategory: item.tipo,
            );
          }

          // ✅ MUY IMPORTANTE:
          // Si el item se marcó como SMS enviado por el cliente,
          // al backend debe ir smsEnviadoPorCliente=true para NO duplicar Twilio.
          final bool smsCliente = item.smsEnviadoPorCliente;

          // canal real que registras en backend
          final String canal = smsCliente ? "OFFLINE_SMS" : item.canalEnvio;

          // ✅ crea incidente (idealmente idempotente por clientGeneratedId)
          final String incidenteId = await api.createIncident(
            tipo: item.tipo,
            descripcion: item.descripcion,
            nivelPrioridad: item.nivelPrioridad,
            usuarioId: item.usuarioId,
            comunidadId: item.comunidadId,
            lat: item.lat,
            lng: item.lng,
            imagenUrl: imagenUrl,
            videoUrl: videoUrl,
            audioUrl: audioUrl,
            ai: ai,

            // ✅ idempotencia + anti-duplicados de SMS
            clientGeneratedId: item.clientGeneratedId,
            canalEnvio: canal,
            smsEnviadoPorCliente: smsCliente,
          );

          // ✅ Publicar en chat (si tu backend dedupe por incidenteId, perfecto)
          await api.postIncidentToChat(
            usuarioId: item.usuarioId,
            comunidadId: item.comunidadId,
            canal: "COMUNIDAD",
            descripcion: item.descripcion,
            incidenteId: incidenteId,
            imagenUrl: imagenUrl,
            videoUrl: videoUrl,
            audioUrl: audioUrl,
          );

          // ✅ si todo salió bien, elimina de cola
          await queue.remove(item.clientGeneratedId);
        } catch (_) {
          // se queda en cola para reintento
        }
      }
    } finally {
      _syncing = false;
    }
  }
}
