// lib/models/usuario.dart

class Usuario {
  final int? id;
  final String? nombre;
  final String? apellido;
  final String? email;
  final String? telefono;
  final String? fotoUrl;
  final bool? activo;

  // Datos de comunidad desde el DTO
  final int? comunidadId;
  final String? comunidadNombre;
  final String? rol;
  final String? estadoEnComunidad;

  Usuario({
    this.id,
    this.nombre,
    this.apellido,
    this.email,
    this.telefono,
    this.fotoUrl,
    this.activo,
    this.comunidadId,
    this.comunidadNombre,
    this.rol,
    this.estadoEnComunidad,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    // ✅ FIX: num -> int (para id y comunidadId)
    int? _toInt(dynamic v) => v == null ? null : (v as num).toInt();

    return Usuario(
      id: _toInt(json['id']),
      nombre: json['nombre']?.toString(),
      apellido: json['apellido']?.toString(),
      email: json['email']?.toString(),
      telefono: json['telefono']?.toString(),
      fotoUrl: json['fotoUrl']?.toString(),
      activo: json['activo'] as bool?,
      comunidadId: _toInt(json['comunidadId']),
      comunidadNombre: json['comunidadNombre']?.toString(),
      rol: json['rol']?.toString(),
      estadoEnComunidad: json['estadoEnComunidad']?.toString(),
    );
  }

  Map<String, dynamic> toJsonRegistro(String password) {
    return {
      "nombre": nombre,
      "apellido": apellido,
      "email": email,
      "telefono": telefono,
      "fotoUrl": fotoUrl,
      "passwordHash": password,
    };
  }
}

class UsuarioComunidad {
  final int? id;
  final int usuarioId;
  final int comunidadId;
  final String? estado; // activo, pendiente, etc.
  final String? rol; // vecino, admin, moderador
  final DateTime? fechaUnion;
  final int? aprobadoPor; // id del usuario aprobadoPor (si existe)

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
    // ✅ FIX: num -> int en todos los IDs
    int? _toInt(dynamic v) => v == null ? null : (v as num).toInt();

    final usuarioId = _toInt(json['usuarioId'] ?? json['usuario']?['id']);
    final comunidadId = _toInt(json['comunidadId'] ?? json['comunidad']?['id']);

    return UsuarioComunidad(
      id: _toInt(json['id']),
      usuarioId: usuarioId ?? 0,      // evita crash si viene null
      comunidadId: comunidadId ?? 0,  // evita crash si viene null
      estado: json['estado']?.toString(),
      rol: json['rol']?.toString(),
      fechaUnion: json['fechaUnion'] != null
          ? DateTime.parse(json['fechaUnion'].toString())
          : null,
      aprobadoPor: _toInt(json['aprobadoPor']),
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
