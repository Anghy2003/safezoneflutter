import 'package:hive/hive.dart';

/// Cache en disco para:
/// - Usuario (Map<String, dynamic>)
/// - Stats (total + last7Days)
/// - updatedAt (timestamp ms)
class ProfileCache {
  static const String boxName = 'sz_profile_cache';

  static const String kUser = 'user';
  static const String kStats = 'stats';
  static const String kUpdatedAt = 'updatedAt';

  bool _ready = false;
  Box<dynamic>? _box;

  Future<void> init() async {
    if (_ready) return;

    // Abre el box (persistente en disco)
    _box = await Hive.openBox<dynamic>(boxName);
    _ready = true;
  }

  Box<dynamic> get box {
    final b = _box;
    if (b == null) {
      // Si llaman sin init() primero, esto ayuda a detectar el problema.
      throw StateError('ProfileCache no inicializado. Llama init() primero.');
    }
    return b;
  }

  bool hasUser() {
    try {
      return box.containsKey(kUser) && box.get(kUser) != null;
    } catch (_) {
      return false;
    }
  }

  bool hasStats() {
    try {
      return box.containsKey(kStats) && box.get(kStats) != null;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic>? readUser() {
    try {
      final v = box.get(kUser);
      if (v is Map) return Map<String, dynamic>.from(v);
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Retorna:
  /// { "total": int, "last7Days": List<int> }
  Map<String, dynamic>? readStats() {
    try {
      final v = box.get(kStats);
      if (v is Map) return Map<String, dynamic>.from(v);
      return null;
    } catch (_) {
      return null;
    }
  }

  int? readUpdatedAt() {
    try {
      final v = box.get(kUpdatedAt);
      return (v is int) ? v : null;
    } catch (_) {
      return null;
    }
  }

  /// Helpers: lectura tipada de stats
  int readTotalOrZero() {
    final s = readStats();
    final t = s?['total'];
    return (t is int) ? t : 0;
  }

  List<int> readLast7OrZero() {
    final s = readStats();
    final raw = s?['last7Days'];

    if (raw is List) {
      final list = raw.map((e) => e is int ? e : int.tryParse('$e') ?? 0).toList();
      if (list.length == 7) return list;
    }
    return List<int>.filled(7, 0);
  }

  Future<void> save({
    required Map<String, dynamic> userJson,
    required int total,
    required List<int> last7Days,
  }) async {
    // last7Days siempre 7
    final safe7 = (last7Days.length == 7) ? last7Days : List<int>.filled(7, 0);

    await box.put(kUser, userJson);
    await box.put(kStats, {
      'total': total,
      'last7Days': safe7,
    });
    await box.put(kUpdatedAt, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> clear() async {
    try {
      await box.delete(kUser);
      await box.delete(kStats);
      await box.delete(kUpdatedAt);
    } catch (_) {}
  }
}
