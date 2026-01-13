import 'package:hive/hive.dart';

/// Cache en disco del header de Home:
/// - communityName
/// - locationLabel
/// - photoUrl
/// - updatedAt
class HomeHeaderCache {
  static const String boxName = 'sz_home_header_cache';

  static const String kCommunityName = 'communityName';
  static const String kLocationLabel = 'locationLabel';
  static const String kPhotoUrl = 'photoUrl';
  static const String kUpdatedAt = 'updatedAt';

  bool _ready = false;
  Box<dynamic>? _box;

  Future<void> init() async {
    if (_ready) return;

    _box = await Hive.openBox<dynamic>(boxName);
    _ready = true;
  }

  Box<dynamic> get box {
    final b = _box;
    if (b == null) {
      throw StateError('HomeHeaderCache no inicializado. Llama init() primero.');
    }
    return b;
  }

  Map<String, dynamic> read() {
    try {
      return {
        kCommunityName: (box.get(kCommunityName) is String) ? box.get(kCommunityName) as String : null,
        kLocationLabel: (box.get(kLocationLabel) is String) ? box.get(kLocationLabel) as String : null,
        kPhotoUrl: (box.get(kPhotoUrl) is String) ? box.get(kPhotoUrl) as String : null,
        kUpdatedAt: (box.get(kUpdatedAt) is int) ? box.get(kUpdatedAt) as int : null,
      };
    } catch (_) {
      return {
        kCommunityName: null,
        kLocationLabel: null,
        kPhotoUrl: null,
        kUpdatedAt: null,
      };
    }
  }

  bool hasData() {
    try {
      final c = box.get(kCommunityName);
      final l = box.get(kLocationLabel);
      final p = box.get(kPhotoUrl);

      bool ok(String? s) => s != null && s.trim().isNotEmpty;

      return ok(c is String ? c : null) || ok(l is String ? l : null) || ok(p is String ? p : null);
    } catch (_) {
      return false;
    }
  }

  Future<void> save({
    required String? communityName,
    required String? locationLabel,
    required String? photoUrl,
  }) async {
    final c = communityName?.trim();
    final l = locationLabel?.trim();
    final p = photoUrl?.trim();

    // Evita guardar todo vacío
    final allEmpty =
        (c == null || c.isEmpty) && (l == null || l.isEmpty) && (p == null || p.isEmpty);
    if (allEmpty) return;

    await box.put(kCommunityName, c);
    await box.put(kLocationLabel, l);
    await box.put(kPhotoUrl, p);
    await box.put(kUpdatedAt, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> clear() async {
    try {
      await box.delete(kCommunityName);
      await box.delete(kLocationLabel);
      await box.delete(kPhotoUrl);
      await box.delete(kUpdatedAt);
    } catch (_) {}
  }
}
