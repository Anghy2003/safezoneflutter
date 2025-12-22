import 'package:flutter/material.dart';
import 'package:safezone_app/service/groq_service.dart';

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

  late GroqService _groqService;
  bool _isSending = false;

  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();

    _groqService = GroqService(
      apiKey: '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',
    );

    _messages.add(
      ChatMessage(
        text:
            "Hola, soy Isis Ayuda. Estoy aquí para acompañarte y apoyarte. Cuéntame, ¿qué está pasando?",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
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

    try {
      final aiResponse = await _groqService.getEmergencyAdvice(
        emergencyType: widget.emergencyType,
        userMessage: text,
      );

      setState(() {
        _messages.add(
          ChatMessage(
            text: aiResponse,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    } catch (_) {
      setState(() {
        _messages.add(
          ChatMessage(
            text:
                "Lo siento, hubo un problema al obtener la respuesta. Intenta nuevamente.",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    } finally {
      _isSending = false;
      _scrollToBottom();
      setState(() {});
    }
  }

  // ===================== UI ======================

  Widget _bubble(ChatMessage msg, bool night, Color card) {
    final isUser = msg.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [Color(0xFFFF5A5A), Color(0xFFE53935)],
                )
              : null,
          color: isUser
              ? null
              : (night ? const Color(0xFF111827) : card),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft:
                isUser ? const Radius.circular(18) : const Radius.circular(6),
            bottomRight:
                isUser ? const Radius.circular(6) : const Radius.circular(18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: isUser
                ? Colors.white
                : (night ? const Color(0xFFF9FAFB) : const Color(0xFF111827)),
            fontSize: 14,
            height: 1.3,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final bool night = hour >= 19 || hour < 6;

    final bg = night ? const Color(0xFF05070A) : const Color(0xFFF3F4F6);
    final card = night ? const Color(0xFF0B1016) : Colors.white;
    final text = night ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
    final sub = night ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new, color: text, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Isis Ayuda",
                        style: TextStyle(
                          color: text,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        "Te acompaño en: ${widget.emergencyType}",
                        style: TextStyle(color: sub, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // CHAT
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: night ? const Color(0xFF020617) : card,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) =>
                      _bubble(_messages[i], night, card),
                ),
              ),
            ),

            // INPUT
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Escribe tu mensaje…',
                        filled: true,
                        fillColor:
                            night ? const Color(0xFF111827) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isSending
                        ? const CircularProgressIndicator()
                        : const Icon(Icons.send, color: Color(0xFFE53935)),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
