import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'offline_incident.dart';
import 'offline_queue_service.dart';
import 'offline_sms_service.dart';
import 'emergency_contacts_cache.dart';

class OfflineReportHandler {
  final OfflineQueueService queue;
  final OfflineSmsService sms;
  final EmergencyContactsCache contactsCache;

  OfflineReportHandler({
    required this.queue,
    required this.sms,
    required this.contactsCache,
  });

  Future<String> handleOffline({
    required String tipo,
    required String descripcion,
    required String nivelPrioridad,
    required int usuarioId,
    required int comunidadId,
    required double? lat,
    required double? lng,
    String? localImagePath,
    String? localVideoPath,
    String? localAudioPath,
    bool trySendSms = true,
  }) async {
    final clientId = const Uuid().v4();

    // ✅ Copiar archivos a carpeta persistente (no temp) para que no se borren
    final savedImage = await _copyToOfflineDir(localImagePath);
    final savedVideo = await _copyToOfflineDir(localVideoPath);
    final savedAudio = await _copyToOfflineDir(localAudioPath);

    bool smsSent = false;
    String canal = "OFFLINE_QUEUE";

    if (trySendSms) {
      await contactsCache.init();
      final phones = await contactsCache.getPhones();

      final msg = _buildSmsMessage(
        tipo: tipo,
        descripcion: descripcion,
        nivelPrioridad: nivelPrioridad,
        lat: lat,
        lng: lng,
        clientId: clientId,
      );

      smsSent = await sms.sendSmsToMany(phones: phones, message: msg);
      canal = smsSent ? "OFFLINE_SMS" : "OFFLINE_QUEUE";
    }

    final item = OfflineIncident(
      clientGeneratedId: clientId,
      tipo: tipo,
      descripcion: descripcion,
      nivelPrioridad: nivelPrioridad,
      usuarioId: usuarioId,
      comunidadId: comunidadId,
      lat: lat,
      lng: lng,
      localImagePath: savedImage,
      localVideoPath: savedVideo,
      localAudioPath: savedAudio,
      ai: null, // offline: no IA
      canalEnvio: canal,
      smsEnviadoPorCliente: smsSent,
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
    );

    await queue.enqueue(item);
    return clientId;
  }

  String _buildSmsMessage({
    required String tipo,
    required String descripcion,
    required String nivelPrioridad,
    required double? lat,
    required double? lng,
    required String clientId,
  }) {
    final loc = (lat != null && lng != null)
        ? "Ubicación: https://maps.google.com/?q=$lat,$lng"
        : "Ubicación: no disponible";

    return "SAFEZONE ALERTA [$nivelPrioridad]\n"
        "Tipo: $tipo\n"
        "$descripcion\n"
        "$loc\n"
        "ID: $clientId";
  }

  Future<String?> _copyToOfflineDir(String? path) async {
    if (path == null) return null;
    final f = File(path);
    if (!f.existsSync()) return null;

    final dir = await getApplicationDocumentsDirectory();
    final offlineDir = Directory("${dir.path}/safezone_offline");
    if (!offlineDir.existsSync()) offlineDir.createSync(recursive: true);

    final name = path.split(Platform.pathSeparator).last;
    final target =
        File("${offlineDir.path}/${DateTime.now().millisecondsSinceEpoch}_$name");

    try {
      await f.copy(target.path);
      return target.path;
    } catch (_) {
      // si no puede copiar, al menos conserva el path original
      return path;
    }
  }
}
