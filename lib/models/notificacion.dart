class Notificacion {
  final int? id;
  final int? incidenteId;
  final int usuarioDestinoId;
  final String? tipoNotificacion;
  final String mensaje;
  final bool? enviado;
  final DateTime? fechaEnvio;
  final DateTime? fechaLectura;

  Notificacion({
    this.id,
    this.incidenteId,
    required this.usuarioDestinoId,
    this.tipoNotificacion,
    required this.mensaje,
    this.enviado,
    this.fechaEnvio,
    this.fechaLectura,
  });

  factory Notificacion.fromJson(Map<String, dynamic> json) {
    return Notificacion(
      id: json['id'],
      incidenteId: json['incidenteId'],
      usuarioDestinoId: json['usuarioDestinoId'],
      tipoNotificacion: json['tipoNotificacion'],
      mensaje: json['mensaje'] ?? '',
      enviado: json['enviado'],
      fechaEnvio:
          json['fechaEnvio'] != null ? DateTime.parse(json['fechaEnvio']) : null,
      fechaLectura: json['fechaLectura'] != null
          ? DateTime.parse(json['fechaLectura'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'incidenteId': incidenteId,
      'usuarioDestinoId': usuarioDestinoId,
      'tipoNotificacion': tipoNotificacion,
      'mensaje': mensaje,
      'enviado': enviado,
      'fechaEnvio': fechaEnvio?.toIso8601String(),
      'fechaLectura': fechaLectura?.toIso8601String(),
    };
  }
}
