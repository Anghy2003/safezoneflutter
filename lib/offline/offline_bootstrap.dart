// offline/offline_bootstrap.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../service/emergency_report_service.dart';
import 'offline_queue_service.dart';
import 'offline_sync_service.dart';

class OfflineBootstrap {
  static final OfflineQueueService queue = OfflineQueueService();
  static late final OfflineSyncService sync;

  static bool _inited = false;
  static StreamSubscription? _sub;

  static Future<void> ensureInitialized() async {
    if (_inited) return;

    await Hive.initFlutter();
    await queue.init();

    sync = OfflineSyncService(
      queue: queue,
      api: EmergencyReportService(),
    );

    // ✅ Intento inicial (si ya hay internet cuando abres la app)
    unawaited(sync.syncAll());

    // ✅ Listener: cuando vuelve conectividad, intenta sync
    _sub = Connectivity().onConnectivityChanged.listen((r) async {
      if (r != ConnectivityResult.none) {
        await sync.syncAll();
      }
    });

    _inited = true;
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _inited = false;
  }
}
