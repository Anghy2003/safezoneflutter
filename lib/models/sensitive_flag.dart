class SensitiveFlag {
  final bool contenidoSensible;
  final String? motivo;
  final double? score;

  const SensitiveFlag({
    required this.contenidoSensible,
    this.motivo,
    this.score,
  });

  factory SensitiveFlag.fromJson(Map<String, dynamic> json) {
    final bool cs = json['contenidoSensible'] == true;

    double? score;
    final s = json['sensibilidadScore'];
    if (s is num) score = s.toDouble();

    final m = (json['sensibilidadMotivo'] ?? '').toString().trim();
    return SensitiveFlag(
      contenidoSensible: cs,
      motivo: m.isEmpty ? null : m,
      score: score,
    );
  }
}
