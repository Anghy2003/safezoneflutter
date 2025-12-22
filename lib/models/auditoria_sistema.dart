class AuditoriaSistema {
  final int? id;
  final String? usuarioUid;
  final String accion;
  final String? descripcion;
  final String? entidad;
  final int? entidadId;
  final DateTime fecha;

  AuditoriaSistema({
    this.id,
    this.usuarioUid,
    required this.accion,
    this.descripcion,
    this.entidad,
    this.entidadId,
    required this.fecha,
  });

  factory AuditoriaSistema.fromJson(Map<String, dynamic> json) {
    return AuditoriaSistema(
      id: json['id'],
      usuarioUid: json['usuarioUid'],
      accion: json['accion'],
      descripcion: json['descripcion'],
      entidad: json['entidad'],
      entidadId: json['entidadId'],
      fecha: DateTime.parse(json['fecha']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuarioUid': usuarioUid,
      'accion': accion,
      'descripcion': descripcion,
      'entidad': entidad,
      'entidadId': entidadId,
      'fecha': fecha.toIso8601String(),
    };
  }
}