import 'package:shared_preferences/shared_preferences.dart';

class NotificacionReadStore {
  static const _kReadIds = "sz_read_notification_ids";

  Future<Set<int>> getReadIds() async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_kReadIds) ?? [];
    return list.map((e) => int.tryParse(e)).whereType<int>().toSet();
  }

  Future<void> markRead(int id) async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_kReadIds) ?? [];
    if (!list.contains(id.toString())) {
      list.add(id.toString());
      await sp.setStringList(_kReadIds, list);
    }
  }

  Future<void> markReadMany(Iterable<int> ids) async {
    final sp = await SharedPreferences.getInstance();
    final current = (sp.getStringList(_kReadIds) ?? []).toSet();
    for (final id in ids) {
      current.add(id.toString());
    }
    await sp.setStringList(_kReadIds, current.toList());
  }

  Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kReadIds);
  }
}
