class NotificacionApi {
  final int id;
  final String tipoNotificacion;
  final String titulo;
  final String mensaje;

  final int? comunidadId;
  final int? incidenteId;
  final DateTime? fecha;

  NotificacionApi({
    required this.id,
    required this.tipoNotificacion,
    required this.titulo,
    required this.mensaje,
    this.comunidadId,
    this.incidenteId,
    this.fecha,
  });

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  factory NotificacionApi.fromJson(Map<String, dynamic> json) {
    final comunidadId = _asInt(json["comunidadId"]) ??
        _asInt((json["comunidad"] is Map) ? (json["comunidad"]["id"]) : null);

    final incidenteId = _asInt(json["incidenteId"]) ??
        _asInt((json["incidente"] is Map) ? (json["incidente"]["id"]) : null);

    return NotificacionApi(
      id: _asInt(json["id"]) ?? 0,
      tipoNotificacion: (json["tipoNotificacion"] ?? "").toString(),
      titulo: (json["titulo"] ?? "").toString(),
      mensaje: (json["mensaje"] ?? "").toString(),
      comunidadId: comunidadId,
      incidenteId: incidenteId,
      fecha: _asDate(json["fechaCreacion"] ?? json["fechaEnvio"]),
    );
  }
}
