import 'dart:convert';

class OfflineIncident {
  final String clientGeneratedId;
  final String tipo;
  final String descripcion;
  final String nivelPrioridad;
  final int usuarioId;
  final int comunidadId;
  final double? lat;
  final double? lng;

  // Adjuntos: rutas locales (NO URLs)
  final String? localImagePath;
  final String? localVideoPath;
  final String? localAudioPath;

  // IA guardada (opcional)
  final Map<String, dynamic>? ai;

  // Meta offline
  final String canalEnvio; // OFFLINE_SMS | OFFLINE_QUEUE
  final bool smsEnviadoPorCliente;
  final int createdAtMillis;

  OfflineIncident({
    required this.clientGeneratedId,
    required this.tipo,
    required this.descripcion,
    required this.nivelPrioridad,
    required this.usuarioId,
    required this.comunidadId,
    required this.lat,
    required this.lng,
    required this.localImagePath,
    required this.localVideoPath,
    required this.localAudioPath,
    required this.ai,
    required this.canalEnvio,
    required this.smsEnviadoPorCliente,
    required this.createdAtMillis,
  });

  Map<String, dynamic> toMap() => {
        "clientGeneratedId": clientGeneratedId,
        "tipo": tipo,
        "descripcion": descripcion,
        "nivelPrioridad": nivelPrioridad,
        "usuarioId": usuarioId,
        "comunidadId": comunidadId,
        "lat": lat,
        "lng": lng,
        "localImagePath": localImagePath,
        "localVideoPath": localVideoPath,
        "localAudioPath": localAudioPath,
        "ai": ai,
        "canalEnvio": canalEnvio,
        "smsEnviadoPorCliente": smsEnviadoPorCliente,
        "createdAtMillis": createdAtMillis,
      };

  String toJson() => jsonEncode(toMap());

  static OfflineIncident fromJson(String s) {
    final m = jsonDecode(s) as Map<String, dynamic>;
    return OfflineIncident(
      clientGeneratedId: (m["clientGeneratedId"] ?? "").toString(),
      tipo: (m["tipo"] ?? "").toString(),
      descripcion: (m["descripcion"] ?? "").toString(),
      nivelPrioridad: (m["nivelPrioridad"] ?? "MEDIA").toString(),
      usuarioId: (m["usuarioId"] as num).toInt(),
      comunidadId: (m["comunidadId"] as num).toInt(),
      lat: (m["lat"] as num?)?.toDouble(),
      lng: (m["lng"] as num?)?.toDouble(),
      localImagePath: m["localImagePath"]?.toString(),
      localVideoPath: m["localVideoPath"]?.toString(),
      localAudioPath: m["localAudioPath"]?.toString(),
      ai: (m["ai"] is Map) ? (m["ai"] as Map).cast<String, dynamic>() : null,
      canalEnvio: (m["canalEnvio"] ?? "OFFLINE_QUEUE").toString(),
      smsEnviadoPorCliente: m["smsEnviadoPorCliente"] == true,
      createdAtMillis: (m["createdAtMillis"] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}
