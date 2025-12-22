class ContactoEmergencia {
  final int? id;
  final int usuarioId;
  final String nombre;
  final String telefono;
  final String? relacion;
  final int prioridad;
  final bool? activo;
  final DateTime? fechaAgregado;

  ContactoEmergencia({
    this.id,
    required this.usuarioId,
    required this.nombre,
    required this.telefono,
    this.relacion,
    this.prioridad = 1,
    this.activo,
    this.fechaAgregado,
  });

  factory ContactoEmergencia.fromJson(Map<String, dynamic> json) {
    return ContactoEmergencia(
      id: json['id'] as int?,
      
      // 👇 Soporta tanto usuarioId simple como objeto usuario
      usuarioId: json['usuarioId'] ??
          (json['usuario'] != null ? json['usuario']['id'] : null),

      nombre: json['nombre'] ?? '',
      telefono: json['telefono'] ?? '',
      relacion: json['relacion'],
      prioridad: json['prioridad'] ?? 1,
      activo: json['activo'],
      fechaAgregado: json['fechaAgregado'] != null
          ? DateTime.parse(json['fechaAgregado'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,

      // 👇 siempre enviamos usuario como objeto — el backend lo acepta
      'usuario': {'id': usuarioId},

      'nombre': nombre,
      'telefono': telefono,
      'relacion': relacion,
      'prioridad': prioridad,
      'activo': activo,
      if (fechaAgregado != null)
        'fechaAgregado': fechaAgregado!.toIso8601String(),
    };
  }

  Map<String, dynamic> toJsonCreate() {
    return {
      'usuario': {'id': usuarioId},
      'nombre': nombre,
      'telefono': telefono,
      if (relacion != null && relacion!.isNotEmpty) 'relacion': relacion,
      'prioridad': prioridad,
      'activo': true,
    };
  }
}
