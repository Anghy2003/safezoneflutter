import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/contacto_emergencia.dart';
import '../service/contacto_emergencia_service.dart';
import '../service/cloudinary_service.dart';

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _relationController = TextEditingController();

  File? _imageFile; // ✅ FOTO
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationController.dispose();
    super.dispose();
  }

  bool get isNightMode {
    final hour = DateTime.now().hour;
    return hour >= 19 || hour < 6;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final bool keyboardOpen = media.viewInsets.bottom > 0;

    final bool night = isNightMode;

    final Color bgColor =
        night ? const Color(0xFF05070A) : const Color(0xFFF3F4F6);
    final Color cardColor =
        night ? const Color(0xFF0B1016) : Colors.white;
    final Color primaryText =
        night ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
    final Color secondaryText =
        night ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final Color inputFill =
        night ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final Color inputBorder =
        night ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    final Color cardShadowColor =
        night ? Colors.black.withOpacity(0.7) : Colors.black.withOpacity(0.06);

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // 🔝 HEADER
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      color: primaryText,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Nuevo contacto",
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.contact_mail_outlined,
                    size: 22,
                    color: secondaryText,
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: keyboardOpen ? 20 : 0,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: size.height * 0.7),
                  child: Column(
                    mainAxisAlignment: keyboardOpen
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: [
                      if (!keyboardOpen) const SizedBox(height: 10),

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
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFF6B6B),
                                          Color(0xFFE53935),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFE53935)
                                              .withOpacity(0.45),
                                          blurRadius: 18,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 44,
                                      backgroundColor: Colors.white,
                                      backgroundImage: _imageFile != null
                                          ? FileImage(_imageFile!)
                                          : null,
                                      child: _imageFile == null
                                          ? const Icon(
                                              Icons.person_add_alt_1_rounded,
                                              size: 40,
                                              color: Color(0xFFE53935),
                                            )
                                          : null,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: -2,
                                    right: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFFE53935),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Agregar foto (opcional)",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 22),

                      // 🧊 CARD FORM
                      Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.fromLTRB(20, 20, 20, 18),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: cardShadowColor,
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

                              _buildField(
                                label: "Nombre *",
                                controller: _nameController,
                                hint: "Ej. Mamá, Papá, Policía",
                                icon: Icons.person_outline_rounded,
                                primaryText: primaryText,
                                inputFill: inputFill,
                                inputBorder: inputBorder,
                                validator: (v) =>
                                    v == null || v.trim().isEmpty
                                        ? "Ingresa el nombre"
                                        : null,
                              ),

                              const SizedBox(height: 14),

                              _buildField(
                                label: "Teléfono *",
                                controller: _phoneController,
                                hint: "+593 9XXXXXXXX",
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                primaryText: primaryText,
                                inputFill: inputFill,
                                inputBorder: inputBorder,
                                validator: (v) =>
                                    v == null || v.trim().isEmpty
                                        ? "Ingresa el teléfono"
                                        : null,
                              ),

                              const SizedBox(height: 14),

                              _buildField(
                                label: "Relación (opcional)",
                                controller: _relationController,
                                hint: "Familiar, Policía, Bomberos…",
                                icon: Icons.group_outlined,
                                primaryText: primaryText,
                                inputFill: inputFill,
                                inputBorder: inputBorder,
                              ),

                              const SizedBox(height: 22),

                              SizedBox(
                                width: double.infinity,
                                child: GestureDetector(
                                  onTap: _isSaving ? null : _handleSave,
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 120),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(24),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFF5A5A),
                                          Color(0xFFE53935),
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: _isSaving
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child:
                                                  CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text(
                                              "Guardar contacto",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
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

                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
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
        Text(label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: primaryText,
            )),
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
          ),
        ),
      ],
    );
  }

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
                if (img != null) {
                  setState(() => _imageFile = File(img.path));
                }
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
                if (img != null) {
                  setState(() => _imageFile = File(img.path));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? fotoUrl;

      if (_imageFile != null) {
        fotoUrl = await CloudinaryService.uploadImage(_imageFile!);
        if (fotoUrl == null) {
          throw Exception("No se pudo subir la foto");
        }
      }

      final contacto = await ContactoEmergenciaService.createContacto(
        nombre: _nameController.text.trim(),
        telefono: _phoneController.text.trim(),
        relacion: _relationController.text.trim().isEmpty
            ? null
            : _relationController.text.trim(),
        fotoUrl: fotoUrl,
      );

      if (!mounted) return;

      Navigator.pop<ContactoEmergencia>(context, contacto);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al guardar contacto: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
