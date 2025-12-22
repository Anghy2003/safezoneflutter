// lib/models/contacto_emergencia.dart
class ContactoEmergencia {
  final int? id; // ✅ puede ser null al crear
  final int usuarioId; // ✅ lo usas para filtrar
  final String nombre;
  final String telefono;
  final String? relacion;
  final int? prioridad;
  final bool? activo;
  final DateTime? fechaAgregado;

  // ✅ NUEVO
  final String? fotoUrl;

  ContactoEmergencia({
    required this.id,
    required this.usuarioId,
    required this.nombre,
    required this.telefono,
    this.relacion,
    this.prioridad,
    this.activo,
    this.fechaAgregado,
    this.fotoUrl,
  });

  factory ContactoEmergencia.fromJson(Map<String, dynamic> json) {
    // usuarioId puede venir como "usuarioId" o dentro de "usuario": { "id": ... }
    final int parsedUsuarioId = _parseUsuarioId(json);

    return ContactoEmergencia(
      id: json['id'] == null ? null : (json['id'] as num).toInt(),
      usuarioId: parsedUsuarioId,
      nombre: (json['nombre'] ?? '').toString(),
      telefono: (json['telefono'] ?? '').toString(),
      relacion: json['relacion']?.toString(),
      prioridad: json['prioridad'] == null ? null : (json['prioridad'] as num).toInt(),
      activo: json['activo'] as bool?,
      fechaAgregado: _parseFecha(json['fechaAgregado'] ?? json['fecha_agregado']),
      // fotoUrl puede venir como "fotoUrl" (DTO) o "foto_url" (directo)
      fotoUrl: (json['fotoUrl'] ?? json['foto_url'])?.toString(),
    );
  }

  /// ✅ JSON para CREATE (lo que mandas al backend)
  /// Mantengo "usuarioId" porque tu backend actual parece que ya lo está aceptando.
  Map<String, dynamic> toJsonCreate() {
    return {
      "usuarioId": usuarioId,
      "nombre": nombre,
      "telefono": telefono,
      "relacion": relacion,
      "prioridad": prioridad ?? 1,
      "activo": activo ?? true,
      "fotoUrl": fotoUrl, // ✅ NUEVO
    };
  }

  /// JSON general (por si lo necesitas)
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "usuarioId": usuarioId,
      "nombre": nombre,
      "telefono": telefono,
      "relacion": relacion,
      "prioridad": prioridad,
      "activo": activo,
      "fechaAgregado": fechaAgregado?.toIso8601String(),
      "fotoUrl": fotoUrl,
    };
  }

  // =========================
  // Helpers
  // =========================

  static int _parseUsuarioId(Map<String, dynamic> json) {
    final direct = json['usuarioId'] ?? json['usuario_id'];
    if (direct != null) return (direct as num).toInt();

    final usuario = json['usuario'];
    if (usuario is Map<String, dynamic> && usuario['id'] != null) {
      return (usuario['id'] as num).toInt();
    }

    // Si tu backend no devuelve usuarioId, esto evita crashear,
    // pero en tu app necesitas usuarioId sí o sí para filtrar.
    return 0;
  }

  static DateTime? _parseFecha(dynamic raw) {
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString());
    } catch (_) {
      return null;
    }
  }
}
