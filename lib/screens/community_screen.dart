import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

import '../routes/app_routes.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  // 0 = Comunidad, 1 = Cerca (vecinos)
  int _selectedTab = 0;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const String _baseUrl = "http://192.168.3.25:8080/api";
  static const String _wsUrl = "http://192.168.3.25:8080/ws";

  bool _isLoading = false;

  final List<Map<String, dynamic>> _communityMessages = [];
  final List<Map<String, dynamic>> _nearbyMessages = [];

  StompClient? stompClient;
  int? myUserId;
  int? comunidadId;

  String? myName;
  String? myPhotoUrl;

  bool _isDisposed = false;

  /// ✅ Para permitir "Mostrar" un contenido sensible localmente (solo en el cliente)
  final Set<dynamic> _unlockedSensitive = <dynamic>{}; // guarda message['id'] o fallback

  bool get isNightMode {
    final hour = DateTime.now().hour;
    return hour >= 19 || hour < 6;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleInitialArgsAndInit();
    });
  }

  Future<void> _handleInitialArgsAndInit() async {
    final route = ModalRoute.of(context);
    if (route != null) {
      final args = route.settings.arguments;
      if (args is Map) {
        final dynamic openTabArg = args['openTab'];
        if (openTabArg is int && (openTabArg == 0 || openTabArg == 1)) {
          if (mounted) setState(() => _selectedTab = openTabArg);
        }

        final dynamic comunidadIdArg = args['comunidadId'];
        if (comunidadIdArg != null) {
          final int? parsedId = int.tryParse(comunidadIdArg.toString().trim());
          if (parsedId != null) {
            comunidadId = parsedId;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt("comunidadId", parsedId);
          }
        }
      }
    }

    await _initUserDataAndConnect();
  }

  @override
  void dispose() {
    _isDisposed = true;
    try {
      stompClient?.deactivate();
    } catch (_) {}
    stompClient = null;

    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ===================== INIT: prefs + WS + historial =====================

  Future<void> _initUserDataAndConnect() async {
    final prefs = await SharedPreferences.getInstance();

    myUserId = prefs.getInt("userId");
    comunidadId ??= prefs.getInt("comunidadId") ?? prefs.getInt("communityId");

    myName = prefs.getString("userName");
    myPhotoUrl = prefs.getString("photoUrl");

    if (_isDisposed) return;

    _connectWebSocket();
    await _loadMessagesFromBackend();
  }

  void _connectWebSocket() {
    if (_isDisposed) return;

    stompClient = StompClient(
      config: StompConfig.SockJS(
        url: _wsUrl,
        onConnect: _onWSConnected,
        onWebSocketError: (error) => debugPrint("WS ERROR: $error"),
        onDisconnect: (frame) => debugPrint("WS DISCONNECTED"),
      ),
    );

    stompClient!.activate();
  }

  void _onWSConnected(StompFrame frame) {
    if (comunidadId == null || _isDisposed || !mounted) return;

    stompClient!.subscribe(
      destination: "/topic/comunidad-$comunidadId",
      callback: (frame) {
        if (_isDisposed || !mounted) return;
        if (frame.body != null) _processIncomingMessage(frame.body!, false);
      },
    );

    stompClient!.subscribe(
      destination: "/topic/vecinos-$comunidadId",
      callback: (frame) {
        if (_isDisposed || !mounted) return;
        if (frame.body != null) _processIncomingMessage(frame.body!, true);
      },
    );
  }

  // ===================== PARSE MENSAJE WS =====================

  void _processIncomingMessage(String body, bool isNearby) {
    if (_isDisposed || !mounted) return;

    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return;
    }
    if (decoded is! Map) return;

    final Map<String, dynamic> data = Map<String, dynamic>.from(decoded);

    final int? msgComunidadId = (data["comunidadId"] is num)
        ? (data["comunidadId"] as num).toInt()
        : int.tryParse((data["comunidadId"] ?? "").toString());

    if (comunidadId != null &&
        msgComunidadId != null &&
        msgComunidadId != comunidadId) {
      return;
    }

    final String canal = (data["canal"] ?? "").toString().toUpperCase();
    final bool msgIsNearby = canal == "VECINOS";

    // usuario plano
    final int? senderId = (data["usuarioId"] is num)
        ? (data["usuarioId"] as num).toInt()
        : int.tryParse((data["usuarioId"] ?? "").toString());

    final String senderName = (data["usuarioNombre"] ?? "Usuario").toString();
    String? avatarUrl = (data["usuarioFotoUrl"] ?? "").toString();
    if (avatarUrl.trim().isEmpty) avatarUrl = null;

    final bool isMe = myUserId != null && senderId != null && myUserId == senderId;
    if (isMe && (avatarUrl == null || avatarUrl.isEmpty)) avatarUrl = myPhotoUrl;

    final String text = (data["mensaje"] ?? "").toString();

    // adjuntos
    final String? imagenUrl = _nullIfBlank(data["imagenUrl"]);
    final String? videoUrl = _nullIfBlank(data["videoUrl"]);
    final String? audioUrl = _nullIfBlank(data["audioUrl"]);

    final bool hasText = text.trim().isNotEmpty;
    final bool hasAnyMedia = imagenUrl != null || videoUrl != null || audioUrl != null;
    if (!hasText && !hasAnyMedia) return;

    // hora
    String time = "";
    final fechaEnvio = data["fechaEnvio"];
    if (fechaEnvio != null) {
      try {
        final dt = DateTime.parse(fechaEnvio.toString());
        time =
            "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      } catch (_) {}
    }

    // ✅ sensible
    final bool contenidoSensible = (data["contenidoSensible"] == true);
    final String? sensibilidadMotivo = _nullIfBlank(data["sensibilidadMotivo"]);
    final double? sensibilidadScore = (data["sensibilidadScore"] is num)
        ? (data["sensibilidadScore"] as num).toDouble()
        : double.tryParse((data["sensibilidadScore"] ?? "").toString());

    final msg = {
      'sender': isMe ? 'Tú' : senderName,
      'message': text,
      'time': time,
      'isMe': isMe,
      'avatar': avatarUrl ?? '',
      'userId': senderId,

      // extras
      'imagenUrl': imagenUrl,
      'videoUrl': videoUrl,
      'audioUrl': audioUrl,
      'replyToId': data['replyToId'],
      'canal': canal,
      'tipo': (data['tipo'] ?? 'texto').toString(),
      'id': data['id'],

      // ✅ sensibles
      'contenidoSensible': contenidoSensible,
      'sensibilidadMotivo': sensibilidadMotivo,
      'sensibilidadScore': sensibilidadScore,
    };

    if (_isDisposed || !mounted) return;

    setState(() {
      if (msgIsNearby) {
        _nearbyMessages.add(msg);
      } else {
        _communityMessages.add(msg);
      }
    });

    _scrollToBottom();
  }

  // ===================== HISTORIAL (REST) =====================

  Future<void> _loadMessagesFromBackend() async {
    if (_isDisposed) return;
    if (comunidadId == null) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      final uriComunidad = Uri.parse("$_baseUrl/mensajes-comunidad/historial")
          .replace(queryParameters: {
        "comunidadId": comunidadId.toString(),
        "canal": "COMUNIDAD",
      });

      final uriVecinos = Uri.parse("$_baseUrl/mensajes-comunidad/historial")
          .replace(queryParameters: {
        "comunidadId": comunidadId.toString(),
        "canal": "VECINOS",
      });

      final resp1 = await http.get(uriComunidad);
      if (resp1.statusCode != 200) {
        throw Exception("Error ${resp1.statusCode}: ${resp1.body}");
      }

      final resp2 = await http.get(uriVecinos);
      if (resp2.statusCode != 200) {
        throw Exception("Error ${resp2.statusCode}: ${resp2.body}");
      }

      final dynamic list1 = jsonDecode(resp1.body);
      final dynamic list2 = jsonDecode(resp2.body);

      if (list1 is! List || list2 is! List) {
        throw Exception("Respuesta inesperada: se esperaba lista");
      }

      _communityMessages
        ..clear()
        ..addAll(list1.map(_mapDtoToBubble).whereType<Map<String, dynamic>>());

      _nearbyMessages
        ..clear()
        ..addAll(list2.map(_mapDtoToBubble).whereType<Map<String, dynamic>>());

      if (!_isDisposed && mounted) {
        setState(() {});
        _scrollToBottom();
      }
    } catch (e) {
      if (_isDisposed || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("No se pudieron cargar los mensajes: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (_isDisposed || !mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic>? _mapDtoToBubble(dynamic raw) {
    if (raw is! Map) return null;
    final data = Map<String, dynamic>.from(raw);

    final int? senderId = (data["usuarioId"] is num)
        ? (data["usuarioId"] as num).toInt()
        : int.tryParse((data["usuarioId"] ?? "").toString());

    final bool isMe = myUserId != null && senderId != null && myUserId == senderId;

    String? avatarUrl = (data["usuarioFotoUrl"] ?? "").toString();
    if (avatarUrl.trim().isEmpty) avatarUrl = null;
    if (isMe && (avatarUrl == null || avatarUrl.isEmpty)) avatarUrl = myPhotoUrl;

    final String text = (data["mensaje"] ?? "").toString();

    final String? imagenUrl = _nullIfBlank(data["imagenUrl"]);
    final String? videoUrl = _nullIfBlank(data["videoUrl"]);
    final String? audioUrl = _nullIfBlank(data["audioUrl"]);

    final bool hasText = text.trim().isNotEmpty;
    final bool hasAnyMedia = imagenUrl != null || videoUrl != null || audioUrl != null;
    if (!hasText && !hasAnyMedia) return null;

    String time = "";
    final fechaEnvio = data["fechaEnvio"];
    if (fechaEnvio != null) {
      try {
        final dt = DateTime.parse(fechaEnvio.toString());
        time =
            "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      } catch (_) {}
    }

    final bool contenidoSensible = (data["contenidoSensible"] == true);
    final String? sensibilidadMotivo = _nullIfBlank(data["sensibilidadMotivo"]);
    final double? sensibilidadScore = (data["sensibilidadScore"] is num)
        ? (data["sensibilidadScore"] as num).toDouble()
        : double.tryParse((data["sensibilidadScore"] ?? "").toString());

    return {
      'sender': isMe ? 'Tú' : (data["usuarioNombre"] ?? "Usuario").toString(),
      'message': text,
      'time': time,
      'isMe': isMe,
      'avatar': avatarUrl ?? '',
      'userId': senderId,

      // extras
      'imagenUrl': imagenUrl,
      'videoUrl': videoUrl,
      'audioUrl': audioUrl,
      'replyToId': data['replyToId'],
      'canal': (data['canal'] ?? '').toString(),
      'tipo': (data['tipo'] ?? 'texto').toString(),
      'id': data['id'],

      // ✅ sensibles
      'contenidoSensible': contenidoSensible,
      'sensibilidadMotivo': sensibilidadMotivo,
      'sensibilidadScore': sensibilidadScore,
    };
  }

  // ===================== UI =====================

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomPadding = media.padding.bottom;

    final bool night = isNightMode;

    final Color bgColor = night ? const Color(0xFF05070A) : const Color(0xFFF3F4F6);
    final Color cardColor = night ? const Color(0xFF0B1016) : Colors.white;
    final Color primaryText = night ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
    final Color secondaryText = night ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    const Color primaryGrad1 = Color(0xFFFF5A5A);
    const Color primaryGrad2 = Color(0xFFE53935);

    const Color bubbleMeStart = primaryGrad1;
    const Color bubbleMeEnd = primaryGrad2;

    final Color bubbleOthers = night ? const Color(0xFF111827) : Colors.white;
    final Color cardShadow = night ? Colors.black.withOpacity(0.7) : Colors.black.withOpacity(0.06);

    final List<Map<String, dynamic>> currentMessages =
        _selectedTab == 0 ? _communityMessages : _nearbyMessages;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: bgColor)),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          AppRoutes.navigateAndClearStack(context, AppRoutes.home);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.4)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedTab == 0 ? "Comunidad" : "Personas cercanas",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedTab == 0
                                  ? "Organiza alertas y apoyo con tus vecinos."
                                  : "Recibe avisos de emergencias cerca de ti.",
                              style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        backgroundImage: (myPhotoUrl != null && myPhotoUrl!.isNotEmpty)
                            ? NetworkImage(myPhotoUrl!)
                            : null,
                        child: (myPhotoUrl == null || myPhotoUrl!.isEmpty)
                            ? Text(
                                (myName != null && myName!.isNotEmpty) ? myName![0].toUpperCase() : 'T',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        _buildTabButton(label: "Comunidad", index: 0, isNightMode: night, activeGrad1: primaryGrad1, activeGrad2: primaryGrad2),
                        _buildTabButton(label: "Cerca", index: 1, isNightMode: night, activeGrad1: primaryGrad1, activeGrad2: primaryGrad2),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : RefreshIndicator(
                          color: primaryGrad2,
                          onRefresh: _loadMessagesFromBackend,
                          child: currentMessages.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: const [
                                    SizedBox(height: 80),
                                    Center(
                                      child: Text(
                                        "No hay mensajes aún.\nSé el primero en escribir.",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.white70, fontSize: 14),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  controller: _scrollController,
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                  itemCount: currentMessages.length,
                                  itemBuilder: (context, index) {
                                    return _buildMessageBubble(
                                      currentMessages[index],
                                      isNightMode: night,
                                      cardColor: cardColor,
                                      bubbleMeStart: bubbleMeStart,
                                      bubbleMeEnd: bubbleMeEnd,
                                      bubbleOthers: bubbleOthers,
                                      cardShadow: cardShadow,
                                    );
                                  },
                                ),
                        ),
                ),

                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 10,
                        bottom: 10 + bottomPadding,
                      ),
                      decoration: BoxDecoration(
                        color: night
                            ? const Color(0xFF020617).withOpacity(0.88)
                            : Colors.white.withOpacity(0.92),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, -3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: night ? const Color(0xFF020617) : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: TextField(
                                controller: _messageController,
                                style: TextStyle(color: primaryText, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: "Escribe un mensaje...",
                                  hintStyle: TextStyle(color: secondaryText, fontSize: 13),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _sendMessage,
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(colors: [primaryGrad1, primaryGrad2]),
                              ),
                              child: const Icon(Icons.send_rounded, color: Colors.white, size: 21),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required int index,
    required bool isNightMode,
    required Color activeGrad1,
    required Color activeGrad2,
  }) {
    final bool isActive = _selectedTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedTab != index) {
            setState(() => _selectedTab = index);
            _scrollToBottom();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isActive ? LinearGradient(colors: [activeGrad1, activeGrad2]) : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===================== BURBUJA CON FILTRO SENSIBLE =====================

  Widget _buildMessageBubble(
    Map<String, dynamic> message, {
    required bool isNightMode,
    required Color cardColor,
    required Color bubbleMeStart,
    required Color bubbleMeEnd,
    required Color bubbleOthers,
    required Color cardShadow,
  }) {
    final bool isMe = (message['isMe'] ?? false) == true;
    final String avatar = (message['avatar'] ?? '').toString();
    final String sender = (message['sender'] ?? '').toString();
    final String time = (message['time'] ?? '').toString();
    final String text = (message['message'] ?? '').toString();

    final String? imagenUrl = message['imagenUrl'] as String?;
    final String? videoUrl = message['videoUrl'] as String?;
    final String? audioUrl = message['audioUrl'] as String?;

    final bool contenidoSensible = message['contenidoSensible'] == true;
    final String? motivo = message['sensibilidadMotivo'] as String?;
    final double? score = message['sensibilidadScore'] as double?;
    final dynamic msgId = message['id'] ?? '${message['time']}-${message['userId']}-${message['tipo']}';

    final bool unlocked = _unlockedSensitive.contains(msgId);

    ImageProvider? avatarProvider;
    if (avatar.isNotEmpty) {
      avatarProvider = avatar.startsWith('http')
          ? NetworkImage(avatar)
          : AssetImage(avatar) as ImageProvider;
    }

    final Color timeColor = const Color(0xFF9CA3AF);

    Widget wrapSensitive({required Widget child}) {
      if (!contenidoSensible || unlocked) return child;

      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Opacity(opacity: 0.25, child: child),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.visibility_off, color: Colors.white, size: 18),
                    const SizedBox(height: 6),
                    const Text(
                      "Contenido sensible",
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    if ((motivo ?? '').isNotEmpty || score != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if ((motivo ?? '').isNotEmpty) 'Motivo: $motivo',
                          if (score != null) 'Score: ${score!.toStringAsFixed(2)}',
                        ].join(" • "),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 10.5),
                      ),
                    ],
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _unlockedSensitive.add(msgId);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.25)),
                        ),
                        child: const Text(
                          "Mostrar",
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: isNightMode ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB),
              backgroundImage: avatarProvider,
              child: avatarProvider == null
                  ? Text(
                      sender.isNotEmpty ? sender[0].toUpperCase() : "?",
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      sender,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isNightMode ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                      ),
                    ),
                  ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isMe ? LinearGradient(colors: [bubbleMeStart, bubbleMeEnd]) : null,
                    color: isMe ? null : bubbleOthers,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cardShadow,
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      if (imagenUrl != null) ...[
                        wrapSensitive(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(imagenUrl, width: 220, fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      if (videoUrl != null) ...[
                        wrapSensitive(
                          child: Container(
                            width: 220,
                            height: 140,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: Icon(Icons.play_circle_fill, color: Colors.white, size: 48),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      if (audioUrl != null) ...[
                        wrapSensitive(
                          child: Container(
                            width: 180,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.white.withOpacity(0.25) : Colors.black.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.audiotrack, color: isMe ? Colors.white : Colors.black87),
                                const SizedBox(width: 10),
                                Text(
                                  "Audio adjunto",
                                  style: TextStyle(fontSize: 12.5, color: isMe ? Colors.white : Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      if (text.isNotEmpty)
                        Text(
                          text,
                          style: TextStyle(
                            fontSize: 14,
                            color: isMe
                                ? Colors.white
                                : (isNightMode ? const Color(0xFFF9FAFB) : const Color(0xFF111827)),
                          ),
                        ),
                    ],
                  ),
                ),

                if (time.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                    child: Text(time, style: TextStyle(fontSize: 10, color: timeColor)),
                  ),
              ],
            ),
          ),

          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: isNightMode ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB),
              backgroundImage: avatarProvider,
            ),
          ],
        ],
      ),
    );
  }

  // ===================== ENVIAR MENSAJE (DTO nuevo + sensible) =====================

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || stompClient == null || comunidadId == null || myUserId == null || _isDisposed) {
      return;
    }

    final bool isNearbyTab = _selectedTab == 1;

    // ✅ Por ahora, texto NO sensible.
    // Cuando adjuntes foto/video/audio y pases el análisis (flutter),
    // setea estos valores antes de enviar:
    final bool contenidoSensible = false;
    final String? sensibilidadMotivo = null;
    final double? sensibilidadScore = null;

    final msg = {
      "usuarioId": myUserId,
      "comunidadId": comunidadId,
      "canal": isNearbyTab ? "VECINOS" : "COMUNIDAD",
      "tipo": "texto",
      "mensaje": text,
      "imagenUrl": null,
      "videoUrl": null,
      "audioUrl": null,
      "replyToId": null,

      // ✅ NUEVO: FILTRO SENSIBLE
      "contenidoSensible": contenidoSensible,
      "sensibilidadMotivo": sensibilidadMotivo,
      "sensibilidadScore": sensibilidadScore,
    };

    try {
      stompClient!.send(
        destination: isNearbyTab ? "/app/chat/vecinos" : "/app/chat/comunidad",
        body: jsonEncode(msg),
      );
    } catch (e) {
      if (!mounted || _isDisposed) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al enviar mensaje: $e"), backgroundColor: Colors.red),
      );
      return;
    }

    _messageController.clear();
    _scrollToBottom();
  }

  // ===================== HELPERS =====================

  String? _nullIfBlank(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  void _scrollToBottom() {
    if (_isDisposed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients || _isDisposed) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }
}
