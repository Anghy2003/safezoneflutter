import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ExploreOfflineCache {
  static const _kLastLocation = 'explore_last_location';
  static const _kNearby = 'explore_nearby';
  static const _kRisk = 'explore_risk';
  static const _kIncidents = 'explore_incidents';

  static const _kTsNearby = 'explore_ts_nearby';
  static const _kTsRisk = 'explore_ts_risk';
  static const _kTsIncidents = 'explore_ts_incidents';

  static Future<void> saveLastLocation({
    required double lat,
    required double lng,
    required int tsMillis,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLastLocation, jsonEncode({
      "lat": lat,
      "lng": lng,
      "ts": tsMillis,
    }));
  }

  static Future<Map<String, dynamic>?> loadLastLocation() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kLastLocation);
    if (raw == null) return null;
    final d = jsonDecode(raw);
    return (d is Map) ? Map<String, dynamic>.from(d) : null;
  }

  static Future<void> saveNearby(List<Map<String, dynamic>> list) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kNearby, jsonEncode(list));
    await sp.setInt(_kTsNearby, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<List<Map<String, dynamic>>> loadNearby() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kNearby);
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<int?> loadNearbyTs() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kTsNearby);
  }

  static Future<void> saveRisk(Map<String, dynamic> riskJson) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kRisk, jsonEncode(riskJson));
    await sp.setInt(_kTsRisk, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<Map<String, dynamic>?> loadRisk() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kRisk);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    return (decoded is Map) ? Map<String, dynamic>.from(decoded) : null;
  }

  static Future<int?> loadRiskTs() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kTsRisk);
  }

  static Future<void> saveIncidents(List<Map<String, dynamic>> list) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kIncidents, jsonEncode(list));
    await sp.setInt(_kTsIncidents, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<List<Map<String, dynamic>>> loadIncidents() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kIncidents);
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<int?> loadIncidentsTs() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kTsIncidents);
  }
}
