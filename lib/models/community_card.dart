class CommunityCardModel {
  final int id;
  final String nombre;
  final String? fotoUrl;
  final String? estado;

  CommunityCardModel({
    required this.id,
    required this.nombre,
    this.fotoUrl,
    this.estado,
  });

  factory CommunityCardModel.fromJson(Map<String, dynamic> json) {
    return CommunityCardModel(
      id: (json["id"] as num?)?.toInt() ?? 0,
      nombre: (json["nombre"] ?? json["name"] ?? "Comunidad").toString(),
      fotoUrl: (json["fotoUrl"] ??
              json["foto_url"] ??
              json["imagenUrl"] ??
              json["imagen_url"])
          ?.toString(),
      estado: (json["estado"] ?? "").toString(),
    );
  }

  /// ✅ Necesario para cache (SharedPreferences)
  Map<String, dynamic> toJson() => {
        "id": id,
        "nombre": nombre,
        "fotoUrl": fotoUrl,
        "estado": estado,
      };
}
