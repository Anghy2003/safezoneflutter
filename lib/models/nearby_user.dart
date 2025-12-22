class NearbyUser {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String? avatarUrl;

  NearbyUser({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.avatarUrl,
  });

  factory NearbyUser.fromJson(Map<String, dynamic> json) {
    return NearbyUser(
      id: json['id'].toString(),
      name: (json['name'] ?? 'Usuario').toString(),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }
}
