class Incidente {
  final int? id;
  final String usuarioId;
  final String tipoEmergencia;
  final String? mensaje;
  final double latitud;
  final double longitud;
  final String? direccion;
  final String? imagenUrl;
  final String? estado;
  final int? prioridad;
  final int? comunidadId;
  final String? moderadoPorUid;
  final DateTime fechaCreacion;
  final DateTime? fechaResolucion;

  Incidente({
    this.id,
    required this.usuarioId,
    required this.tipoEmergencia,
    this.mensaje,
    required this.latitud,
    required this.longitud,
    this.direccion,
    this.imagenUrl,
    this.estado,
    this.prioridad,
    this.comunidadId,
    this.moderadoPorUid,
    required this.fechaCreacion,
    this.fechaResolucion,
  });

  factory Incidente.fromJson(Map<String, dynamic> json) {
    return Incidente(
      id: json['id'],
      usuarioId: json['usuarioId'],
      tipoEmergencia: json['tipoEmergencia'],
      mensaje: json['mensaje'],
      latitud: json['latitud'].toDouble(),
      longitud: json['longitud'].toDouble(),
      direccion: json['direccion'],
      imagenUrl: json['imagenUrl'],
      estado: json['estado'],
      prioridad: json['prioridad'],
      comunidadId: json['comunidadId'],
      moderadoPorUid: json['moderadoPorUid'],
      fechaCreacion: DateTime.parse(json['fechaCreacion']),
      fechaResolucion: json['fechaResolucion'] != null 
          ? DateTime.parse(json['fechaResolucion']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuarioId': usuarioId,
      'tipoEmergencia': tipoEmergencia,
      'mensaje': mensaje,
      'latitud': latitud,
      'longitud': longitud,
      'direccion': direccion,
      'imagenUrl': imagenUrl,
      'estado': estado,
      'prioridad': prioridad,
      'comunidadId': comunidadId,
      'moderadoPorUid': moderadoPorUid,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'fechaResolucion': fechaResolucion?.toIso8601String(),
    };
  }
}
