import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';

import '../models/contacto_emergencia.dart';
import '../routes/app_routes.dart';
import '../service/contacto_emergencia_service.dart';
import 'add_contact_screen.dart';
import '../widgets/safezone_nav_bar.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  int _currentIndex = 1;
  final TextEditingController _searchController = TextEditingController();

  List<ContactoEmergencia> _contacts = [];
  bool _isLoading = false;
  String? _errorMessage;

  // 🔊 Voz
  late stt.SpeechToText _speech;
  bool _speechAvailable = false;
  bool _isListening = false;

  bool get isNightMode {
    final hour = DateTime.now().hour;
    return hour >= 19 || hour < 6;
  }

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _speech = stt.SpeechToText();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: (s) {
        debugPrint("speech status: $s");
        if (s == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (e) => debugPrint("speech error: $e"),
    );

    if (!mounted) return;
    setState(() => _speechAvailable = available);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _speech.stop();
    super.dispose();
  }

  List<ContactoEmergencia> get _filteredContacts {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _contacts;

    return _contacts.where((c) {
      final nombre = c.nombre.toLowerCase();
      final telefono = c.telefono.toLowerCase();
      final relacion = (c.relacion ?? '').toLowerCase();
      return nombre.contains(query) ||
          telefono.contains(query) ||
          relacion.contains(query);
    }).toList();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await ContactoEmergenciaService.getContactosUsuarioActual();
      if (!mounted) return;
      setState(() {
        _contacts = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomPadding = media.padding.bottom;

    final bool night = isNightMode;

    final Color bgColor =
        night ? const Color(0xFF05070A) : const Color(0xFFF3F4F6);
    final Color cardColor = night ? const Color(0xFF0B1016) : Colors.white;
    final Color primaryText =
        night ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
    final Color secondaryText =
        night ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final Color searchFill = night ? const Color(0xFF111827) : Colors.white;
    final Color searchBorder =
        night ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // 🔝 HEADER
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => AppRoutes.goBack(context),
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          size: 20,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(width: 4),
                      CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            const Color(0xFFFF6B6B).withOpacity(0.2),
                        child: const Icon(
                          Icons.group,
                          color: Color(0xFFE53935),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Contactos",
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _addContact,
                        child: const Text(
                          "+ Add contact",
                          style: TextStyle(
                            color: Color(0xFFE53935),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 🔍 BUSCADOR + MIC
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: searchFill,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: searchBorder),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Icon(Icons.search, color: secondaryText, size: 20),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            style: TextStyle(color: primaryText, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: "search",
                              hintStyle: TextStyle(
                                color: secondaryText,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _toggleVoiceSearch,
                          icon: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            size: 20,
                            color: _isListening
                                ? const Color(0xFFE53935)
                                : secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 📋 LISTA / ESTADOS
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildContactsContent(
                      cardColor,
                      primaryText,
                      secondaryText,
                      night,
                    ),
                  ),
                ),

                SizedBox(height: 90 + bottomPadding),
              ],
            ),
          ),

          // 🔻 NAV
          SafeZoneNavBar(
            currentIndex: _currentIndex,
            isNightMode: night,
            bottomPadding: bottomPadding,
            onTap: _onNavTap,
          ),
        ],
      ),
    );
  }

  Widget _buildContactsContent(
    Color cardColor,
    Color primaryText,
    Color secondaryText,
    bool night,
  ) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          'Error: $_errorMessage',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Colors.redAccent),
        ),
      );
    }

    final list = _filteredContacts;

    if (list.isEmpty) {
      return Center(
        child: Text(
          "No hay contactos.\nPulsa “+ Add contact” para agregar uno.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: secondaryText),
        ),
      );
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        return _buildContactItem(
          list[index],
          cardColor,
          primaryText,
          secondaryText,
          night,
        );
      },
    );
  }

  Widget _buildContactItem(
    ContactoEmergencia contact,
    Color cardColor,
    Color primaryText,
    Color secondaryText,
    bool night,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(night ? 0.18 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: _contactAvatar(contact),
        title: Text(
          contact.nombre,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: primaryText,
          ),
        ),
        subtitle: Text(
          contact.telefono,
          style: TextStyle(
            color: secondaryText,
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.grey.shade400,
          size: 22,
        ),
        onTap: () => _openContactDetail(contact, night),
      ),
    );
  }

  Widget _contactAvatar(ContactoEmergencia c) {
    final url = (c.fotoUrl ?? '').trim();

    if (url.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: const Color(0xFFFF6B6B).withOpacity(0.15),
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
      );
    }

    return CircleAvatar(
      radius: 22,
      backgroundColor: const Color(0xFFFF6B6B).withOpacity(0.15),
      child: Text(
        c.nombre.isNotEmpty ? c.nombre[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Color(0xFFE53935),
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;

    setState(() => _currentIndex = index);

    switch (index) {
      case 0:
        AppRoutes.navigateAndReplace(context, AppRoutes.home);
        break;
      case 1:
        break;
      case 2:
        AppRoutes.navigateAndReplace(context, AppRoutes.explore);
        break;
      case 3:
        AppRoutes.navigateAndReplace(context, AppRoutes.community);
        break;
    }
  }

  Future<void> _addContact() async {
    final contacto = await Navigator.push<ContactoEmergencia?>(
      context,
      MaterialPageRoute(builder: (context) => const AddContactScreen()),
    );

    if (contacto != null) {
      setState(() => _contacts.add(contacto));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contacto guardado correctamente')),
      );
    }
  }

  void _openContactDetail(ContactoEmergencia contact, bool night) {
    final Color dialogBg =
        night ? const Color(0xFF0B1016) : Colors.white.withOpacity(0.98);
    final Color primary =
        night ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
    final Color secondary =
        night ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.86,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: dialogBg,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.30),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: night
                      ? const Color(0xFF1F2937)
                      : const Color(0xFFF0F0F0),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar grande
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFE53935)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE53935).withOpacity(0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: night
                          ? const Color(0xFF111827)
                          : const Color(0xFFF9FAFB),
                      backgroundImage: (contact.fotoUrl != null &&
                              contact.fotoUrl!.trim().isNotEmpty)
                          ? NetworkImage(contact.fotoUrl!.trim())
                          : null,
                      child: (contact.fotoUrl == null ||
                              contact.fotoUrl!.trim().isEmpty)
                          ? Text(
                              contact.nombre.isNotEmpty
                                  ? contact.nombre[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Color(0xFFE53935),
                                fontWeight: FontWeight.bold,
                                fontSize: 26,
                              ),
                            )
                          : null,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    contact.nombre,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: primary,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    contact.telefono,
                    style: TextStyle(
                      fontSize: 14,
                      color: secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  if (contact.relacion != null &&
                      contact.relacion!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      "Relación: ${contact.relacion}",
                      style: TextStyle(
                        fontSize: 13,
                        color: secondary,
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Chips opcionales (si existen en tu modelo)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _pill(
                        icon: Icons.verified_user_outlined,
                        label: (contact.activo ?? true) ? "Activo" : "Inactivo",
                        night: night,
                      ),
                      if (contact.prioridad != null)
                        _pill(
                          icon: Icons.low_priority_rounded,
                          label: "Prioridad ${contact.prioridad}",
                          night: night,
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Acciones
                  Row(
                    children: [
                      Expanded(
                        child: _actionButton(
                          label: "Llamar",
                          icon: Icons.call_rounded,
                          onTap: () => _callPhone(contact.telefono),
                          night: night,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _actionButton(
                          label: "WhatsApp",
                          icon: Icons.chat_rounded,
                          onTap: () => _openWhatsApp(contact.telefono),
                          night: night,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Cerrar",
                        style: TextStyle(
                          color: night
                              ? const Color(0xFFFF6B6B)
                              : const Color(0xFFE53935),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required bool night,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: night ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: night ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFE53935)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: night ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool night,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF5A5A), Color(0xFFE53935)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE53935).withOpacity(0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _callPhone(String phone) async {
    final cleaned = phone.replaceAll(' ', '').replaceAll('-', '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    // WhatsApp usa E164 sin símbolos, típicamente: 5939XXXXXXXX
    final cleaned = phone
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .replaceAll('+', '');

    final uri = Uri.parse("https://wa.me/$cleaned");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // 🔊 VOZ
  void _toggleVoiceSearch() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Búsqueda por voz no disponible en este dispositivo.'),
        ),
      );
      return;
    }

    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    if (mounted) setState(() => _isListening = true);

    await _speech.listen(
      localeId: 'es_EC',
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _searchController.text = result.recognizedWords;
          _searchController.selection = TextSelection.fromPosition(
            TextPosition(offset: _searchController.text.length),
          );
        });
      },
    );
  }
}
