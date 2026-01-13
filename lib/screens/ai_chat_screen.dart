import 'dart:async';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../service/groq_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class AiChatScreen extends StatefulWidget {
  final String emergencyType;

  const AiChatScreen({
    super.key,
    required this.emergencyType,
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final SafeZoneAiApi _aiApi;
  bool _isSending = false;

  final List<ChatMessage> _messages = [];

  bool get isNightMode => Theme.of(context).brightness == Brightness.dark;

  // Temas sugeridos
  late final List<String> _quickTopics = [
    "Me siento en peligro, ¿qué hago?",
    "Estoy viendo algo sospechoso",
    "Necesito ayuda para reportar un incidente",
  ];

  @override
  void initState() {
    super.initState();
    _aiApi = SafeZoneAiApi();

    _messages.add(
      ChatMessage(
        text:
            "Hola, soy Isis Ayuda. Estoy aquí para acompañarte y apoyarte. Cuéntame, ¿qué está pasando?",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// History para backend:
  /// [{role:"user", content:"..."}, {role:"assistant", content:"..."}]
  List<Map<String, String>> _buildHistory({int maxTurns = 12}) {
    final tail = _messages.length <= maxTurns
        ? _messages
        : _messages.sublist(_messages.length - maxTurns);

    return tail
        .map((m) => {
              "role": m.isUser ? "user" : "assistant",
              "content": m.text,
            })
        .toList(growable: false);
  }

  Future<bool> _hasInternet() async {
    final conn = await Connectivity().checkConnectivity();
    return conn != ConnectivityResult.none;
  }

  String _offlineFallbackMessage() {
    return "Ahora mismo no tengo conexión para usar el chat con IA.\n\n"
        "Si estás en una situación de riesgo, usa el botón de Reporte o tus contactos de emergencia.";
  }

  String _serverFallbackMessage() {
    return "Estoy teniendo problemas para conectarme al servidor en este momento.\n\n"
        "Intenta nuevamente en unos minutos. Si es una emergencia, usa el botón de Reporte o tus contactos de emergencia.";
  }

  Future<void> _sendMessage({String? forcedText}) async {
    final text = (forcedText ?? _controller.text).trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _controller.clear();
      _isSending = true;
    });

    _scrollToBottom();

    // =========================
    // 1) OFFLINE: respuesta inmediata “pro”
    // =========================
    final online = await _hasInternet();
    if (!online) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: _offlineFallbackMessage(),
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isSending = false;
      });
      _scrollToBottom();
      return;
    }

    // =========================
    // 2) ONLINE: intenta backend con timeout
    // =========================
    try {
      final history = _buildHistory();

      final aiResponse = await _aiApi
          .chatIsis(
            emergencyType: widget.emergencyType,
            userMessage: text,
            history: history,
          )
          .timeout(const Duration(seconds: 18));

      setState(() {
        _messages.add(
          ChatMessage(
            text: aiResponse,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    } on TimeoutException {
      setState(() {
        _messages.add(
          ChatMessage(
            text: _serverFallbackMessage(),
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    } catch (_) {
      // Aquí cae: 500, 503, problemas de red intermitente, etc.
      setState(() {
        _messages.add(
          ChatMessage(
            text: _serverFallbackMessage(),
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    } finally {
      _isSending = false;
      _scrollToBottom();
      if (mounted) setState(() {});
    }
  }

  // ===================== UI HELPERS =====================

  Color _bg() => isNightMode ? const Color(0xFF0B0F17) : const Color(0xFFF5F7FA);
  Color _card() => isNightMode ? const Color(0xFF0F172A) : Colors.white;
  Color _ink() => isNightMode ? const Color(0xFFE5E7EB) : const Color(0xFF111827);
  Color _muted() => isNightMode ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
  Color _stroke() => isNightMode ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);

  Widget _pill({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _card(),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _stroke()),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isNightMode ? 0.25 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _topicButton(String text) {
    return InkWell(
      onTap: () => _sendMessage(forcedText: text),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isNightMode ? Colors.white.withOpacity(0.04) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _stroke()),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: _ink(),
                  fontSize: 13.5,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.chevron_right_rounded, color: _muted(), size: 22),
          ],
        ),
      ),
    );
  }

  Widget _messageBubble(ChatMessage msg) {
    final isUser = msg.isUser;

    final bubbleColor = isUser
        ? (isNightMode ? Colors.white.withOpacity(0.06) : const Color(0xFFF3F4F6))
        : _card();

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: EdgeInsets.fromLTRB(
          isUser ? 70 : 14,
          8,
          isUser ? 14 : 70,
          8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _stroke()),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isNightMode ? 0.20 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: _ink(),
            fontSize: 14,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _headerIntro() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: _ink(), size: 18),
            ),
            Expanded(
              child: Center(
                child: Text(
                  "Isis Chat",
                  style: TextStyle(
                    color: _ink(),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 12),
        Image.asset(
          "assets/images/safezone_bot.gif",
          width: 92,
          height: 92,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 8),
        Text(
          "Hola, mi nombre es Isis",
          style: TextStyle(
            color: _ink(),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Text(
            "Estoy aquí para ayudarte. ¿Cómo puedo asistirte hoy?",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted(),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _pill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Selecciona un tema que quieras preguntar",
                  style: TextStyle(
                    color: _ink(),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Puedes elegir un tema de las opciones o escribir un mensaje directamente.",
                  style: TextStyle(
                    color: _muted(),
                    fontSize: 12.3,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isNightMode ? Colors.white.withOpacity(0.04) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _stroke()),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.local_police_outlined, size: 16, color: _muted()),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Emergencia: ${widget.emergencyType}",
                          style: TextStyle(
                            color: _muted(),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              _topicButton(_quickTopics[0]),
              const SizedBox(height: 10),
              _topicButton(_quickTopics[1]),
              const SizedBox(height: 10),
              _topicButton(_quickTopics[2]),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _inputBar() {
    final Color panel = isNightMode
        ? const Color(0xFF0F172A).withOpacity(0.92)
        : Colors.white.withOpacity(0.96);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          decoration: BoxDecoration(
            color: panel,
            border: Border(top: BorderSide(color: _stroke())),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isNightMode ? 0.25 : 0.08),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: TextStyle(color: _ink()),
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: "Escribe un mensaje…",
                    hintStyle: TextStyle(color: _muted(), fontSize: 13),
                    filled: true,
                    fillColor: isNightMode
                        ? Colors.white.withOpacity(0.05)
                        : const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: _isSending ? null : () => _sendMessage(),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF5A5A), Color(0xFFE53935)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isNightMode ? 0.30 : 0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _isSending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: _messages.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) return _headerIntro();
                  final msg = _messages[index - 1];
                  return _messageBubble(msg);
                },
              ),
            ),
            _inputBar(),
          ],
        ),
      ),
    );
  }
}
