class ReporteValidacionIA {
  final int? id;
  final int incidenteId;
  final String? modeloIa;
  final String? tipoPredicho;
  final double? confianza;
  final String? resultado;
  final String? razonDeteccion;
  final DateTime? fechaAnalisis;

  ReporteValidacionIA({
    this.id,
    required this.incidenteId,
    this.modeloIa,
    this.tipoPredicho,
    this.confianza,
    this.resultado,
    this.razonDeteccion,
    this.fechaAnalisis,
  });

  factory ReporteValidacionIA.fromJson(Map<String, dynamic> json) {
    return ReporteValidacionIA(
      id: json['id'],
      incidenteId: json['incidenteId'],
      modeloIa: json['modeloIa'],
      tipoPredicho: json['tipoPredicho'],
      confianza: json['confianza']?.toDouble(),
      resultado: json['resultado'],
      razonDeteccion: json['razonDeteccion'],
      fechaAnalisis: json['fechaAnalisis'] != null 
          ? DateTime.parse(json['fechaAnalisis']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'incidenteId': incidenteId,
      'modeloIa': modeloIa,
      'tipoPredicho': tipoPredicho,
      'confianza': confianza,
      'resultado': resultado,
      'razonDeteccion': razonDeteccion,
      'fechaAnalisis': fechaAnalisis?.toIso8601String(),
    };
  }
}