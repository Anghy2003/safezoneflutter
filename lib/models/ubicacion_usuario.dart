class UbicacionUsuario {
  final int? id;
  final String usuarioId;
  final double latitud;
  final double longitud;
  final int? precisionMetros;
  final DateTime fechaActualizacion;

  UbicacionUsuario({
    this.id,
    required this.usuarioId,
    required this.latitud,
    required this.longitud,
    this.precisionMetros,
    required this.fechaActualizacion,
  });

  factory UbicacionUsuario.fromJson(Map<String, dynamic> json) {
    return UbicacionUsuario(
      id: json['id'],
      usuarioId: json['usuarioId'],
      latitud: json['latitud'].toDouble(),
      longitud: json['longitud'].toDouble(),
      precisionMetros: json['precisionMetros'],
      fechaActualizacion: DateTime.parse(json['fechaActualizacion']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuarioId': usuarioId,
      'latitud': latitud,
      'longitud': longitud,
      'precisionMetros': precisionMetros,
      'fechaActualizacion': fechaActualizacion.toIso8601String(),
    };
  }
}
