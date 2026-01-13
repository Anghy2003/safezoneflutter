import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ Picker nativo
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';

import '../models/contacto_emergencia.dart';
import '../service/contacto_emergencia_service.dart';
import '../service/cloudinary_service.dart';

// ✅ cache Hive (contactos completos)
import '../offline/emergency_contacts_cache.dart';

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  static const int _maxEmergencyContacts = 5;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _relationController = TextEditingController();

  final FlutterNativeContactPicker _contactPicker = FlutterNativeContactPicker();

  File? _imageFile;
  bool _isSaving = false;

  final _cache = EmergencyContactsCache.instance;
  bool _cacheReady = false;

  bool get isNightMode => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _initCache();
  }

  Future<void> _initCache() async {
    await _cache.init();
    if (!mounted) return;
    setState(() => _cacheReady = true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationController.dispose();
    super.dispose();
  }

  Future<int?> _getUserIdFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt("userId");
  }

  // =========================
  // Helpers: teléfono
  // =========================

  String _normalizePhone(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return "";

    // conserva + si existe al inicio
    final hasPlus = raw.startsWith("+");
    final digits = raw.replaceAll(RegExp(r"[^\d]"), "");
    if (digits.isEmpty) return "";
    return hasPlus ? "+$digits" : digits;
  }

  bool _phoneExistsInCache(String phoneNormalized) {
    final list = _cache.getContacts();
    return list.any((c) => _normalizePhone(c.telefono) == phoneNormalized);
  }

  int _cachedCount() => _cache.getContacts().length;

  // =========================
  // UI
  // =========================

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bool keyboardOpen = media.viewInsets.bottom > 0;

    final bool night = isNightMode;

    final Color bgColor = night ? const Color(0xFF05070A) : const Color(0xFFF3F4F6);
    final Color cardColor = night ? const Color(0xFF0B1016) : Colors.white;
    final Color primaryText = night ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
    final Color secondaryText = night ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final Color inputFill = night ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final Color inputBorder = night ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    final Color cardShadow = night ? Colors.black.withOpacity(0.7) : Colors.black.withOpacity(0.06);

    final count = _cacheReady ? _cachedCount() : 0;
    final left = (_maxEmergencyContacts - count);

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // ================= HEADER =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_ios_new, color: primaryText, size: 20),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Nuevo contacto",
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),

                  // ✅ Botón Importar (manteniendo estética)
                  GestureDetector(
                    onTap: (_isSaving || !_cacheReady) ? null : _importFromContacts,
                    child: Opacity(
                      opacity: (_isSaving || !_cacheReady) ? 0.6 : 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: inputBorder),
                          color: cardColor,
                          boxShadow: [
                            BoxShadow(
                              color: cardShadow,
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.person_search, size: 18, color: secondaryText),
                            const SizedBox(width: 8),
                            Text(
                              "Importar",
                              style: TextStyle(
                                color: primaryText,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
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

            // ================= BODY =================
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: keyboardOpen ? 20 : 0,
                ),
                child: Column(
                  mainAxisAlignment: keyboardOpen ? MainAxisAlignment.start : MainAxisAlignment.center,
                  children: [
                    if (!keyboardOpen)
                      GestureDetector(
                        onTap: _pickImage,
                        child: Column(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [Color(0xFFFF6B6B), Color(0xFFE53935)],
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 44,
                                    backgroundColor: Colors.white,
                                    backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                                    child: _imageFile == null
                                        ? const Icon(Icons.person_add_alt_1_rounded,
                                            size: 40, color: Color(0xFFE53935))
                                        : null,
                                  ),
                                ),
                                Positioned(
                                  bottom: -2,
                                  right: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFFE53935),
                                    ),
                                    child: const Icon(Icons.camera_alt_rounded,
                                        color: Colors.white, size: 16),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Agregar foto (opcional)",
                              style: TextStyle(fontSize: 13, color: secondaryText),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 22),

                    // ================= CARD =================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: cardShadow,
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Datos del contacto",
                              style: TextStyle(
                                color: primaryText,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),

                            _field(
                              label: "Nombre *",
                              controller: _nameController,
                              hint: "Ej. Mamá, Policía",
                              icon: Icons.person_outline,
                              primaryText: primaryText,
                              inputFill: inputFill,
                              inputBorder: inputBorder,
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? "Ingresa el nombre" : null,
                            ),

                            const SizedBox(height: 14),

                            _field(
                              label: "Teléfono *",
                              controller: _phoneController,
                              hint: "+593 9XXXXXXXX",
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              primaryText: primaryText,
                              inputFill: inputFill,
                              inputBorder: inputBorder,
                              validator: (v) {
                                final p = _normalizePhone(v ?? "");
                                if (p.isEmpty) return "Ingresa el teléfono";
                                return null;
                              },
                            ),

                            const SizedBox(height: 14),

                            _field(
                              label: "Relación (opcional)",
                              controller: _relationController,
                              hint: "Familiar, Bomberos…",
                              icon: Icons.group_outlined,
                              primaryText: primaryText,
                              inputFill: inputFill,
                              inputBorder: inputBorder,
                            ),

                            const SizedBox(height: 10),

                            // ✅ indicador máximo 5
                            Text(
                              !_cacheReady
                                  ? "Cargando cache…"
                                  : (left <= 0
                                      ? "Límite alcanzado: ya tienes $_maxEmergencyContacts contactos de emergencia."
                                      : "Puedes agregar $left contacto(s) más (máximo $_maxEmergencyContacts)."),
                              style: TextStyle(fontSize: 12.5, color: secondaryText),
                            ),

                            const SizedBox(height: 18),

                            GestureDetector(
                              onTap: _isSaving ? null : _handleSave,
                              child: Opacity(
                                opacity: _isSaving ? 0.8 : 1,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: const BoxDecoration(
                                    borderRadius: BorderRadius.all(Radius.circular(24)),
                                    gradient: LinearGradient(
                                      colors: [Color(0xFFFF5A5A), Color(0xFFE53935)],
                                    ),
                                  ),
                                  child: Center(
                                    child: _isSaving
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                                color: Colors.white, strokeWidth: 2),
                                          )
                                        : const Text(
                                            "Guardar contacto",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color primaryText,
    required Color inputFill,
    required Color inputBorder,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(color: primaryText),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: inputFill,
            prefixIcon: Icon(icon, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE53935)),
            ),
          ),
        ),
      ],
    );
  }

  // =========================
  // Foto
  // =========================

  Future<void> _pickImage() async {
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Galería"),
              onTap: () async {
                Navigator.pop(context);
                final img = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 75,
                );
                if (img != null && mounted) setState(() => _imageFile = File(img.path));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text("Cámara"),
              onTap: () async {
                Navigator.pop(context);
                final img = await picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 75,
                );
                if (img != null && mounted) setState(() => _imageFile = File(img.path));
              },
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // Importar contacto del sistema
  // =========================

  Future<void> _importFromContacts() async {
    try {
      await _cache.init();

      final count = _cachedCount();
      if (count >= _maxEmergencyContacts) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Ya tienes $_maxEmergencyContacts contactos de emergencia. Elimina uno para agregar otro.",
            ),
          ),
        );
        return;
      }

      final contact = await _contactPicker.selectPhoneNumber();
      if (contact == null) return;

      final fullName = (contact.fullName ?? "").trim();
      final phoneRaw = (contact.selectedPhoneNumber ?? "").trim();
      final phone = _normalizePhone(phoneRaw);

      if (phone.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Este contacto no tiene número válido.")),
        );
        return;
      }

      if (_phoneExistsInCache(phone)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ese número ya está en tus contactos de emergencia.")),
        );
        return;
      }

      if (fullName.isNotEmpty) _nameController.text = fullName;
      _phoneController.text = phone;

      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No se pudo importar el contacto: $e")),
      );
    }
  }

  // =========================
  // Guardar (OFFLINE/ONLINE)
  // =========================

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final nombre = _nameController.text.trim();
    final telefono = _normalizePhone(_phoneController.text);
    final relacion = _relationController.text.trim().isEmpty ? null : _relationController.text.trim();

    try {
      await _cache.init();

      // ✅ duplicado (por teléfono)
      if (_phoneExistsInCache(telefono)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ese número ya está registrado en tus contactos.")),
        );
        return;
      }

      final usuarioId = await _getUserIdFromPrefs();
      if (usuarioId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se encontró userId. Inicia sesión otra vez.")),
        );
        return;
      }

      final conn = await Connectivity().checkConnectivity();

      // =========================
      // OFFLINE
      // =========================
      if (conn == ConnectivityResult.none) {
        final local = ContactoEmergencia(
          id: null,
          usuarioId: usuarioId,
          nombre: nombre,
          telefono: telefono,
          relacion: relacion,
          prioridad: 1,
          activo: true,
          fechaAgregado: DateTime.now(),
          fotoUrl: null,
        );

        final ok = await _cache.upsertContact(local);
        if (!ok) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Límite alcanzado: máximo $_maxEmergencyContacts contactos.")),
          );
          return;
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sin internet: guardado localmente.")),
        );

        Navigator.pop<ContactoEmergencia>(context, local);
        return;
      }

      // =========================
      // ONLINE
      // =========================
      String? fotoUrl;
      if (_imageFile != null) {
        try {
          fotoUrl = await CloudinaryService.uploadImage(_imageFile!);
        } catch (_) {
          // si falla la foto, igual seguimos con el guardado
          fotoUrl = null;
        }
      }

      final contacto = await ContactoEmergenciaService.createContacto(
        nombre: nombre,
        telefono: telefono,
        relacion: relacion,
        fotoUrl: fotoUrl,
      );

      final ok = await _cache.upsertContact(contacto);
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Límite alcanzado: máximo $_maxEmergencyContacts contactos.")),
        );
        return;
      }

      if (!mounted) return;
      Navigator.pop<ContactoEmergencia>(context, contacto);
    } catch (e) {
      // ✅ fallback: si falla backend, lo dejamos en cache como local
      try {
        final usuarioId = await _getUserIdFromPrefs() ?? 0;

        final local = ContactoEmergencia(
          id: null,
          usuarioId: usuarioId,
          nombre: nombre,
          telefono: telefono,
          relacion: relacion,
          prioridad: 1,
          activo: true,
          fechaAgregado: DateTime.now(),
          fotoUrl: null,
        );

        final ok = await _cache.upsertContact(local);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Límite alcanzado: máximo $_maxEmergencyContacts contactos.")),
          );
          return;
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No se pudo guardar en servidor. Quedó guardado localmente: $e")),
        );
        Navigator.pop<ContactoEmergencia>(context, local);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al guardar: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
