import 'dart:async';
import 'package:flutter/material.dart';

import '../service/notificaciones_service.dart';
import '../service/notificacion_read_store.dart';
import '../screens/notifications_screen.dart';

class NotificationBellButton extends StatefulWidget {
  final bool night;
  final int? comunidadId;

  const NotificationBellButton({
    super.key,
    required this.night,
    required this.comunidadId,
  });

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  final _service = NotificacionesService();
  final _store = NotificacionReadStore();

  int _unread = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refreshUnread();
    _timer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _refreshUnread(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshUnread() async {
    final cid = widget.comunidadId;
    if (cid == null) {
      if (!mounted) return;
      setState(() => _unread = 0);
      return;
    }

    try {
      final notis = await _service.listarPorComunidad(comunidadId: cid);
      final read = await _store.getReadIds();
      final unread = notis.where((n) => !read.contains(n.id)).length;

      if (!mounted) return;
      setState(() => _unread = unread);
    } catch (_) {
      // Silencioso para no molestar UI
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtleText = widget.night ? Colors.white70 : Colors.grey.shade700;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () async {
            final cid = widget.comunidadId;
            if (cid == null) return;

            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NotificationsScreen(comunidadId: cid),
              ),
            );

            await _refreshUnread();
          },
          icon: Icon(
            Icons.notifications_outlined,
            size: 20,
            color: subtleText,
          ),
        ),
        if (_unread > 0)
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5A5F),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: widget.night ? const Color(0xFF181A24) : Colors.white,
                  width: 2,
                ),
              ),
              child: Text(
                _unread > 99 ? "99+" : _unread.toString(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
