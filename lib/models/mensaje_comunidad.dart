class MensajeComunidad {
  final int? id;
  final int comunidadId;
  final String usuarioId;
  final String mensaje;
  final String? imagenUrl;
  final String? tipo;
  final bool? moderado;
  final String? moderadoPorUid;
  final DateTime fechaEnvio;

  MensajeComunidad({
    this.id,
    required this.comunidadId,
    required this.usuarioId,
    required this.mensaje,
    this.imagenUrl,
    this.tipo,
    this.moderado,
    this.moderadoPorUid,
    required this.fechaEnvio,
  });

  factory MensajeComunidad.fromJson(Map<String, dynamic> json) {
    return MensajeComunidad(
      id: json['id'],
      comunidadId: json['comunidadId'],
      usuarioId: json['usuarioId'],
      mensaje: json['mensaje'],
      imagenUrl: json['imagenUrl'],
      tipo: json['tipo'],
      moderado: json['moderado'],
      moderadoPorUid: json['moderadoPorUid'],
      fechaEnvio: DateTime.parse(json['fechaEnvio']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'comunidadId': comunidadId,
      'usuarioId': usuarioId,
      'mensaje': mensaje,
      'imagenUrl': imagenUrl,
      'tipo': tipo,
      'moderado': moderado,
      'moderadoPorUid': moderadoPorUid,
      'fechaEnvio': fechaEnvio.toIso8601String(),
    };
  }
}
