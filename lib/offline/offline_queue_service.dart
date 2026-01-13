import 'package:hive/hive.dart';
import 'offline_incident.dart';

class OfflineQueueService {
  static const _boxName = "offline_incidents";

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<String>(_boxName);
    }
  }

  Box<String> get _box => Hive.box<String>(_boxName);

  Future<void> enqueue(OfflineIncident item) async {
    await _box.put(item.clientGeneratedId, item.toJson());
  }

  List<OfflineIncident> all() {
    final list = _box.values.map(OfflineIncident.fromJson).toList();
    list.sort((a, b) => a.createdAtMillis.compareTo(b.createdAtMillis));
    return list;
  }

  Future<void> remove(String clientGeneratedId) async {
    await _box.delete(clientGeneratedId);
  }

  bool contains(String clientGeneratedId) => _box.containsKey(clientGeneratedId);

  int count() => _box.length;
}
