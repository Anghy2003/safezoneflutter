class UsuarioComunidad {
  final int? id;
  final int usuarioId;        // int, no String
  final int comunidadId;
  final String? estado;       // activo, pendiente, etc.
  final String? rol;          // vecino, admin, moderador
  final DateTime? fechaUnion;
  final int? aprobadoPor;     // id del usuario aprobadoPor (si existe)

  UsuarioComunidad({
    this.id,
    required this.usuarioId,
    required this.comunidadId,
    this.estado,
    this.rol,
    this.fechaUnion,
    this.aprobadoPor,
  });

  factory UsuarioComunidad.fromJson(Map<String, dynamic> json) {
    return UsuarioComunidad(
      id: json['id'],
      usuarioId: json['usuarioId'] ?? json['usuario']?['id'],
      comunidadId: json['comunidadId'] ?? json['comunidad']?['id'],
      estado: json['estado'],
      rol: json['rol'],
      fechaUnion: json['fechaUnion'] != null
          ? DateTime.parse(json['fechaUnion'])
          : null,
      aprobadoPor: json['aprobadoPor'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuarioId': usuarioId,
      'comunidadId': comunidadId,
      'estado': estado,
      'rol': rol,
      'fechaUnion': fechaUnion?.toIso8601String(),
      'aprobadoPor': aprobadoPor,
    };
  }
}
