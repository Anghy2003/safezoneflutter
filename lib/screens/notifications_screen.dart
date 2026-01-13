// lib/screens/notifications_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/notificacion_api.dart';
import '../service/notificaciones_service.dart';
import '../service/notificacion_read_store.dart';

class NotificationsScreen extends StatefulWidget {
  final int comunidadId;

  const NotificationsScreen({
    super.key,
    required this.comunidadId,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const int _maxItems = 10; // ✅ SOLO ÚLTIMOS 10

  final _service = NotificacionesService();
  final _store = NotificacionReadStore();

  bool _loading = true;
  bool _offline = false;

  List<NotificacionApi> _items = [];
  Set<int> _read = {};

  DateTime? _lastSync;

  String get _cacheKey => 'notif_cache_v2_${widget.comunidadId}';
  String get _lastSyncKey => 'notif_last_sync_v2_${widget.comunidadId}';

  @override
  void initState() {
    super.initState();
    _bootstrapLoad();
  }

  // =========================
  // OFFLINE-FIRST: cache -> online refresh
  // =========================
  Future<void> _bootstrapLoad() async {
    setState(() => _loading = true);

    // 1) Cargar cache local si existe
    await _loadFromCache();

    // 2) Cargar ids leídos (local)
    final read = await _store.getReadIds();
    if (mounted) setState(() => _read = read);

    // 3) Intentar refrescar desde API (online)
    await _loadOnline(showSpinnerIfNoCache: _items.isEmpty);
  }

  // =========================
  // CACHE
  // =========================
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final lastSyncIso = prefs.getString(_lastSyncKey);
      if (lastSyncIso != null && lastSyncIso.trim().isNotEmpty) {
        _lastSync = DateTime.tryParse(lastSyncIso);
      }

      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.trim().isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final cached = <NotificacionApi>[];
      for (final it in decoded) {
        if (it is Map<String, dynamic>) {
          final n = _fromCacheMap(it);
          if (n != null) cached.add(n);
        } else if (it is Map) {
          final n = _fromCacheMap(Map<String, dynamic>.from(it));
          if (n != null) cached.add(n);
        }
      }

      final limited = _takeLastNByDate(cached, _maxItems);

      if (!mounted) return;
      setState(() {
        _items = limited;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveToCache(List<NotificacionApi> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // guardamos un poco más por si acaso, pero igual la UI solo muestra 10
      final toStore = _takeLastNByDate(items, 30);

      final list = toStore.map(_toCacheMap).toList();
      await prefs.setString(_cacheKey, jsonEncode(list));

      final now = DateTime.now();
      _lastSync = now;
      await prefs.setString(_lastSyncKey, now.toIso8601String());
    } catch (_) {}
  }

  // =========================
  // ONLINE
  // =========================
  Future<void> _loadOnline({required bool showSpinnerIfNoCache}) async {
    if (showSpinnerIfNoCache) {
      if (mounted) setState(() => _loading = true);
    }

    try {
      final items = await _service.listarPorComunidad(
        comunidadId: widget.comunidadId,
      );

      final limited = _takeLastNByDate(items, _maxItems);

      final read = await _store.getReadIds();

      await _saveToCache(items);

      if (!mounted) return;
      setState(() {
        _items = limited;
        _read = read;
        _loading = false;
        _offline = false;
      });
    } on SocketException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _offline = true;
      });

      if (_items.isNotEmpty) {
        _snack("Sin conexión. Mostrando las últimas $_maxItems guardadas.");
      } else {
        _snack("Sin conexión. No hay notificaciones guardadas aún.");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _offline = true;
      });

      if (_items.isNotEmpty) {
        _snack("No se pudo actualizar. Mostrando guardadas. ($e)");
      } else {
        _snack("No se pudieron cargar las notificaciones: $e");
      }
    }
  }

  Future<void> _onPullToRefresh() async {
    await _loadOnline(showSpinnerIfNoCache: false);
  }

  // =========================
  // READ / OPEN
  // =========================
  Future<void> _markAllRead() async {
    // marca solo las que estás mostrando (últimas 10)
    await _store.markReadMany(_items.map((e) => e.id));
    final read = await _store.getReadIds();
    if (!mounted) return;
    setState(() => _read = read);
  }

  Future<void> _open(NotificacionApi n) async {
    await _store.markRead(n.id);
    final read = await _store.getReadIds();
    if (!mounted) return;
    setState(() => _read = read);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final night = Theme.of(context).brightness == Brightness.dark;
        final cardBg = night ? const Color(0xFF13151D) : Colors.white;
        final cardText = night ? Colors.white : const Color(0xFF222222);
        final subtleText = night ? Colors.white70 : Colors.grey.shade700;

        final titulo =
            n.titulo.trim().isNotEmpty ? n.titulo.trim() : "Notificación";
        final mensaje =
            n.mensaje.trim().isNotEmpty ? n.mensaje.trim() : "Sin contenido";

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(night ? 0.55 : 0.18),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _colorFor(n).withOpacity(night ? 0.20 : 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_iconFor(n), color: _colorFor(n)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        titulo,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: cardText,
                        ),
                      ),
                    ),
                    Text(
                      _timeLabel(n.fecha),
                      style: TextStyle(fontSize: 11, color: subtleText),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  mensaje,
                  style: TextStyle(
                    fontSize: 13,
                    color: subtleText,
                    height: 1.35,
                  ),
                ),
                if (n.incidenteId != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    "Incidente #${n.incidenteId}",
                    style: TextStyle(fontSize: 12, color: subtleText),
                  ),
                ],
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Cerrar",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFF5A5F),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;

    final scaffoldBg =
        night ? const Color(0xFF050509) : const Color(0xFFFDF7F7);
    final cardBg = night ? const Color(0xFF13151D) : Colors.white;
    final cardText = night ? Colors.white : const Color(0xFF222222);
    final subtleText = night ? Colors.white70 : Colors.grey.shade700;

    // ya vienen limitadas a 10 y ordenadas por fecha
    final Map<String, List<NotificacionApi>> grouped = {};
    for (final n in _items) {
      final key = _sectionLabel(n.fecha);
      grouped.putIfAbsent(key, () => []).add(n);
    }

    final sectionKeys = grouped.keys.toList();
    sectionKeys.sort((a, b) {
      if (a == "Hoy") return -1;
      if (b == "Hoy") return 1;
      if (a == "Ayer") return -1;
      if (b == "Ayer") return 1;
      return b.compareTo(a);
    });

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: subtleText,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "Notificaciones",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: cardText,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _items.isEmpty ? null : _markAllRead,
                    child: Text(
                      "Marcar leído",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: _items.isEmpty
                            ? subtleText.withOpacity(0.45)
                            : const Color(0xFFFF5A5F),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Banner offline/online
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _offline
                  ? _statusBanner(
                      night: night,
                      text:
                          "Sin conexión. Mostrando últimos $_maxItems${_lastSync != null ? " • Última sync: ${_fmtDateTime(_lastSync!)}" : ""}",
                      icon: Icons.wifi_off_rounded,
                    )
                  : (_lastSync != null
                      ? _statusBanner(
                          night: night,
                          text: "Actualizado: ${_fmtDateTime(_lastSync!)}",
                          icon: Icons.cloud_done_rounded,
                        )
                      : const SizedBox.shrink()),
            ),

            const SizedBox(height: 6),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _onPullToRefresh,
                child: _loading
                    ? ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        itemCount: 6,
                        itemBuilder: (_, __) => Container(
                          height: 78,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: cardBg.withOpacity(night ? 0.75 : 0.90),
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      )
                    : (_items.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 40),
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withOpacity(night ? 0.40 : 0.10),
                                      blurRadius: 18,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      _offline
                                          ? Icons.wifi_off_rounded
                                          : Icons.notifications_off_outlined,
                                      color: subtleText,
                                      size: 34,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      _offline
                                          ? "Sin conexión"
                                          : "Aún no tienes notificaciones",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: cardText,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _offline
                                          ? "Conéctate para sincronizar.\nDesliza hacia abajo para reintentar."
                                          : "Cuando ocurra un incidente en tu comunidad, aparecerá aquí.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: subtleText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            children: [
                              for (final key in sectionKeys) ...[
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 10, bottom: 8),
                                  child: Text(
                                    key,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: subtleText,
                                    ),
                                  ),
                                ),
                                for (final n in grouped[key]!)
                                  _tile(n, night, cardBg, cardText, subtleText),
                              ],
                              const SizedBox(height: 12),
                            ],
                          )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBanner({
    required bool night,
    required String text,
    required IconData icon,
  }) {
    final bg = night ? const Color(0xFF111827) : const Color(0xFFFFF1F2);
    final border = night
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.06);
    final fg = night ? Colors.white70 : const Color(0xFF374151);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    NotificacionApi n,
    bool night,
    Color cardBg,
    Color cardText,
    Color subtleText,
  ) {
    final isUnread = !_read.contains(n.id);
    final accent = _colorFor(n);
    final icon = _iconFor(n);

    final titulo =
        n.titulo.trim().isNotEmpty ? n.titulo.trim() : "Notificación";
    final mensaje =
        n.mensaje.trim().isNotEmpty ? n.mensaje.trim() : "Sin contenido";

    return InkWell(
      onTap: () => _open(n),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: night
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(night ? 0.40 : 0.10),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withOpacity(night ? 0.20 : 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: cardText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mensaje,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: subtleText,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _timeLabel(n.fecha),
                  style: TextStyle(fontSize: 10, color: subtleText),
                ),
                const SizedBox(height: 8),
                if (isUnread)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF5A5F),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===================== LIMIT + SORT =====================

  List<NotificacionApi> _takeLastNByDate(List<NotificacionApi> items, int n) {
    final copy = List<NotificacionApi>.from(items);

    // DESC por fecha (null al final)
    copy.sort((a, b) {
      final da = a.fecha;
      final db = b.fecha;
      if (da == null && db == null) return 0;
      if (da == null) return 1; // a va después
      if (db == null) return -1; // b va después
      return db.compareTo(da); // más reciente primero
    });

    if (copy.length <= n) return copy;
    return copy.take(n).toList();
  }

  // ===================== Cache mapping =====================

  Map<String, dynamic> _toCacheMap(NotificacionApi n) {
    return {
      'id': n.id,
      'titulo': n.titulo,
      'mensaje': n.mensaje,
      'tipoNotificacion': n.tipoNotificacion,
      'fecha': n.fecha?.toIso8601String(),
      'incidenteId': n.incidenteId,
    };
  }

  NotificacionApi? _fromCacheMap(Map<String, dynamic> m) {
    try {
      final id = (m['id'] as num?)?.toInt();
      if (id == null) return null;

      final String titulo = (m['titulo'] ?? '').toString();
      final String mensaje = (m['mensaje'] ?? '').toString();
      final String tipo = (m['tipoNotificacion'] ?? '').toString();

      final String? fechaIso = (m['fecha'] as String?);
      final DateTime? fecha = (fechaIso != null && fechaIso.trim().isNotEmpty)
          ? DateTime.tryParse(fechaIso)
          : null;

      final int? incidenteId = (m['incidenteId'] as num?)?.toInt();

      return NotificacionApi(
        id: id,
        titulo: titulo,
        mensaje: mensaje,
        tipoNotificacion: tipo,
        fecha: fecha,
        incidenteId: incidenteId,
      );
    } catch (_) {
      return null;
    }
  }

  // ===================== Helpers =====================

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmtDateTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} $hh:$mm";
  }

  String _sectionLabel(DateTime? dt) {
    if (dt == null) return "Sin fecha";
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return "Hoy";
    if (d == today.subtract(const Duration(days: 1))) return "Ayer";
    return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
  }

  String _timeLabel(DateTime? dt) {
    if (dt == null) return "";
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 30) return "Ahora";
    if (diff.inMinutes < 60) return "${diff.inMinutes} min";
    if (diff.inHours < 24) return "${diff.inHours} h";
    return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
  }

  IconData _iconFor(NotificacionApi n) {
    final t = n.tipoNotificacion.toUpperCase();
    if (t.contains("INCIDENTE")) return Icons.warning_amber_rounded;
    if (t.contains("SOS")) return Icons.sos_rounded;
    if (t.contains("RUTA")) return Icons.alt_route_rounded;
    return Icons.notifications_rounded;
  }

  Color _colorFor(NotificacionApi n) {
    final t = n.tipoNotificacion.toUpperCase();
    if (t.contains("SOS")) return const Color(0xFFFF6B6B);
    if (t.contains("RUTA")) return const Color(0xFF5C9ECC);
    return const Color(0xFFFF5A5F);
  }
}
