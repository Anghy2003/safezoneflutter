// lib/screens/contacts_screen.dart
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';

import '../models/contacto_emergencia.dart';
import '../offline/emergency_contacts_cache.dart';
import '../routes/app_routes.dart';
import '../service/auth_service.dart';
import '../service/contacto_emergencia_service.dart';
import 'add_contact_screen.dart';
import '../widgets/safezone_nav_bar.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  // ✅ 4 items: Home, Explorar, Comunidades, Menú
  int _currentIndex = 0;

  final TextEditingController _searchController = TextEditingController();

  List<ContactoEmergencia> _contacts = [];
  bool _isLoading = false;
  String? _errorMessage;

  // 🔊 Voz
  late final stt.SpeechToText _speech;
  bool _speechAvailable = false;
  bool _isListening = false;

  // ✅ Header cache (para navbar + menu)
  String? _headerPhotoUrl;
  String? _headerDisplayName;

  // ✅ Cache Hive para offline (SMS + fallback UI)
  final EmergencyContactsCache _contactsCache = EmergencyContactsCache.instance;

  bool get isNightMode => Theme.of(context).brightness == Brightness.dark;

  bool get _voiceSupported {
    // speech_to_text solo tiene sentido en mobile; evita crashes en desktop/web
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();

    // ⚠️ IMPORTANTE: blindar todo lo que corre al iniciar
    _safeInit();
  }

  Future<void> _safeInit() async {
    // No uses setState si el widget ya no está montado
    try {
      await _loadHeaderFromPrefs();

      // Voz (no debe tumbar la pantalla si falla)
      await _initSpeechSafe();

      // Boot (sesión + cache + carga contactos)
      await _bootSafe();
    } catch (e) {
      // Si algo raro pasa igual no cerramos la app
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = "Error al iniciar: $e";
      });
    }
  }

  Future<void> _bootSafe() async {
    try {
      // ✅ Asegura sesión rehidratada ANTES de consumir servicios
      await AuthService.ensureRestored();

      // ✅ Si no hay sesión, no intentes cargar contactos
      final userId = await AuthService.getCurrentUserId();
      if (userId == null || userId <= 0) {
        if (!mounted) return;
        AppRoutes.navigateAndClearStack(context, AppRoutes.login);
        return;
      }

      // ✅ Init cache y luego carga (online o fallback offline)
      try {
        await _contactsCache.init();
      } catch (_) {}

      await _loadContacts();
    } catch (e) {
      // No cierres la app si falla sesión/cache
      if (!mounted) return;

      final cached = _safeReadCachedContacts();
      if (cached.isNotEmpty) {
        setState(() {
          _contacts = cached;
          _isLoading = false;
          _errorMessage = null;
        });
        _snack("Fallo inicial. Mostrando contactos offline.");
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = "Error en boot: $e";
        });
      }
    }
  }

  Future<void> _loadHeaderFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final photo = (prefs.getString('photoUrl') ?? '').trim();
      final name = (prefs.getString('displayName') ?? '').trim();

      if (!mounted) return;
      setState(() {
        _headerPhotoUrl = photo.isNotEmpty ? photo : null;
        _headerDisplayName = name.isNotEmpty ? name : null;
      });
    } catch (_) {}
  }

  Future<void> _initSpeechSafe() async {
    if (!_voiceSupported) {
      if (!mounted) return;
      setState(() {
        _speechAvailable = false;
        _isListening = false;
      });
      return;
    }

    try {
      final available = await _speech.initialize(
        onStatus: (s) {
          // según plataforma, puede llegar "done", "notListening", etc.
          if (!mounted) return;
          if (s == 'notListening' || s == 'done') {
            setState(() => _isListening = false);
          }
        },
        onError: (err) {
          if (!mounted) return;
          setState(() => _isListening = false);
        },
      );

      if (!mounted) return;
      setState(() => _speechAvailable = available);
    } catch (_) {
      // Si speech_to_text revienta, no tumbamos la app
      if (!mounted) return;
      setState(() {
        _speechAvailable = false;
        _isListening = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    try {
      _speech.stop();
    } catch (_) {}
    super.dispose();
  }

  List<ContactoEmergencia> get _filteredContacts {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _contacts;

    return _contacts.where((c) {
      return c.nombre.toLowerCase().contains(query) ||
          c.telefono.toLowerCase().contains(query) ||
          (c.relacion ?? '').toLowerCase().contains(query);
    }).toList();
  }

  // ✅ Internet real (mejor que solo Connectivity)
  Future<bool> _hasInternetNow() async {
    try {
      final r = await Connectivity().checkConnectivity();
      if (r == ConnectivityResult.none) return false;

      final res = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 3));

      return res.isNotEmpty && res.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ✅ Carga Online; si falla => fallback a Hive
  Future<void> _loadContacts() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ✅ si no hay internet real, saltamos directo a cache
      final hasInternet = await _hasInternetNow();
      if (!hasInternet) {
        final cached = _safeReadCachedContacts();
        if (!mounted) return;

        setState(() {
          _contacts = cached;
          _isLoading = false;
          _errorMessage = null;
        });

        if (cached.isNotEmpty) {
          _snack("Sin internet: mostrando contactos guardados (offline).");
        } else {
          _snack("Sin internet y sin contactos guardados aún.");
        }
        return;
      }

      // ✅ Online: esta llamada debe incluir X-User-Id desde el SERVICE corregido
      final list = await ContactoEmergenciaService.getMisContactosActivos();

      // ✅ Guardar en cache para SOS offline
      try {
        await _contactsCache.saveContacts(list);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _contacts = list;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      // ✅ Fallback a cache si falla por red/timeout/500, etc.
      final cached = _safeReadCachedContacts();

      if (!mounted) return;

      if (cached.isNotEmpty) {
        setState(() {
          _contacts = cached;
          _isLoading = false;
          _errorMessage = null;
        });
        _snack("No se pudo cargar del servidor. Mostrando cache offline.");
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  List<ContactoEmergencia> _safeReadCachedContacts() {
    try {
      return _contactsCache.getContacts();
    } catch (_) {
      return <ContactoEmergencia>[];
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final night = isNightMode;

    final bgColor = night ? const Color(0xFF05070A) : const Color(0xFFF3F4F6);
    final cardColor = night ? const Color(0xFF0B1016) : Colors.white;
    final primaryText =
        night ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
    final secondaryText =
        night ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final searchFill = night ? const Color(0xFF111827) : Colors.white;
    final searchBorder =
        night ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(primaryText),
                _buildSearchBar(
                  primaryText,
                  secondaryText,
                  searchFill,
                  searchBorder,
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 90),
              ],
            ),
          ),
          SafeZoneNavBar(
            currentIndex: _currentIndex,
            isNightMode: night,
            photoUrl: _headerPhotoUrl,
            onTap: _onNavTap,
            bottomExtra: 0,
          ),
        ],
      ),
    );
  }

  // ========================= UI =========================

  Widget _buildHeader(Color primaryText) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () =>
                AppRoutes.navigateAndReplace(context, AppRoutes.home),
            icon: Icon(Icons.arrow_back_ios_new, size: 20, color: primaryText),
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
              "+ Agregar",
              style: TextStyle(
                color: Color(0xFFE53935),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(
    Color primaryText,
    Color secondaryText,
    Color fill,
    Color border,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(Icons.search, color: secondaryText),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: primaryText),
                decoration: InputDecoration(
                  hintText: "Buscar",
                  hintStyle: TextStyle(color: secondaryText),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
            IconButton(
              onPressed: _toggleVoiceSearch,
              icon: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: _isListening ? const Color(0xFFE53935) : secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsContent(
    Color cardColor,
    Color primaryText,
    Color secondaryText,
    bool night,
  ) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_errorMessage != null) {
      return Center(
        child: Text(
          "Error: $_errorMessage",
          style: const TextStyle(color: Colors.redAccent),
          textAlign: TextAlign.center,
        ),
      );
    }

    final list = _filteredContacts;

    if (list.isEmpty) {
      return Center(
        child: Text(
          "No hay contactos.\nPulsa “+ Agregar” para crear uno.",
          textAlign: TextAlign.center,
          style: TextStyle(color: secondaryText),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadContacts,
      child: ListView.builder(
        itemCount: list.length,
        itemBuilder: (_, i) => _buildContactItem(
          list[i],
          cardColor,
          primaryText,
          secondaryText,
          night,
        ),
      ),
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
            color: Colors.black.withOpacity(night ? 0.18 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: _contactAvatar(contact),
        title: Text(contact.nombre, style: TextStyle(color: primaryText)),
        subtitle: Text(contact.telefono, style: TextStyle(color: secondaryText)),
        trailing: Icon(Icons.chevron_right, color: secondaryText),
        onTap: () => _openContactDetail(contact, night),
      ),
    );
  }

  Widget _contactAvatar(ContactoEmergencia c) {
    final url = (c.fotoUrl ?? '').trim();
    if (url.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      backgroundColor: const Color(0xFFFF6B6B).withOpacity(0.15),
      child: Text(
        c.nombre.isNotEmpty ? c.nombre[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Color(0xFFE53935),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ========================= NAV BAR =========================
  void _onNavTap(int index) {
    if (index == 3) {
      AppRoutes.navigateTo(
        context,
        AppRoutes.menu,
        arguments: {
          "photoUrl": _headerPhotoUrl,
          "displayName": _headerDisplayName ?? "Mi cuenta",
        },
      );
      return;
    }

    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);

    switch (index) {
      case 0:
        AppRoutes.navigateAndReplace(context, AppRoutes.home);
        break;
      case 1:
        AppRoutes.navigateAndReplace(context, AppRoutes.explore);
        break;
      case 2:
        AppRoutes.navigateAndReplace(context, AppRoutes.community);
        break;
    }
  }

  // ========================= ACCIONES =========================

  Future<void> _addContact() async {
    final contacto = await Navigator.push<ContactoEmergencia?>(
      context,
      MaterialPageRoute(builder: (_) => const AddContactScreen()),
    );

    if (contacto != null) {
      await _loadContacts(); // ✅ esto también cachea
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Contacto guardado correctamente")),
      );
    }
  }

  void _toggleVoiceSearch() async {
    if (!_voiceSupported) {
      _snack("Búsqueda por voz no disponible en este dispositivo.");
      return;
    }
    if (!_speechAvailable) {
      _snack("Voz no disponible. Revisa permisos de micrófono.");
      return;
    }

    try {
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
          setState(() => _searchController.text = result.recognizedWords);
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isListening = false);
      _snack("No se pudo iniciar la búsqueda por voz.");
    }
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    final uri = Uri.parse("https://wa.me/$cleaned");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ========================= DETALLE (MODAL) =========================
  void _openContactDetail(ContactoEmergencia contact, bool night) {
    final cardColor = night ? const Color(0xFF0B1016) : Colors.white;
    final primaryText =
        night ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
    final secondaryText =
        night ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final border = night ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(night ? 0.35 : 0.15),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 14,
                  bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: secondaryText.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _detailAvatar(contact, night),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contact.nombre.isNotEmpty
                                    ? contact.nombre
                                    : "Sin nombre",
                                style: TextStyle(
                                  color: primaryText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                contact.telefono,
                                style: TextStyle(
                                  color: secondaryText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if ((contact.relacion ?? '').trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE53935)
                                          .withOpacity(night ? 0.20 : 0.10),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      contact.relacion!.trim(),
                                      style: const TextStyle(
                                        color: Color(0xFFE53935),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close_rounded, color: secondaryText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "Cerrar",
                          style: TextStyle(
                            color: secondaryText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailAvatar(ContactoEmergencia c, bool night) {
    final url = (c.fotoUrl ?? '').trim();
    final hasPhoto = url.isNotEmpty;

    if (hasPhoto) {
      return CircleAvatar(
        radius: 28,
        backgroundColor: Colors.transparent,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
      );
    }

    return CircleAvatar(
      radius: 28,
      backgroundColor: const Color(0xFFFF6B6B).withOpacity(night ? 0.18 : 0.12),
      child: Text(
        c.nombre.isNotEmpty ? c.nombre[0].toUpperCase() : "?",
        style: const TextStyle(
          color: Color(0xFFE53935),
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool night,
  }) {
    final bg = night ? const Color(0xFF111827) : const Color(0xFFF3F4F6);
    final border = night ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    final text = night ? const Color(0xFFF9FAFB) : const Color(0xFF111827);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: const Color(0xFFE53935)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
