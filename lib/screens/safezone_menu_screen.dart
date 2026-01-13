// lib/screens/safezone_menu_screen.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../routes/app_routes.dart';
import '../service/auth_service.dart';
import '../widgets/safezone_nav_bar.dart';

class SafeZoneMenuScreen extends StatefulWidget {
  /// Opcionales: si vienen por arguments o constructor, se usan para pintar rápido.
  final String? photoUrl;
  final String? displayName;

  const SafeZoneMenuScreen({
    super.key,
    this.photoUrl,
    this.displayName, required bool night,
  });

  @override
  State<SafeZoneMenuScreen> createState() => _SafeZoneMenuScreenState();
}

class _SafeZoneMenuScreenState extends State<SafeZoneMenuScreen> {
  bool _loading = true;

  bool _isSuperAdmin = false;
  bool _isCommunityAdmin = false;

  String? _name;
  String? _photoUrl;
  String? _email;

  String? _userRole;
  String? _communityRole;

  List<Map<String, dynamic>> _communities = [];

  // ---------- Theme (dinámico por Theme.of(context)) ----------
  bool get _night => Theme.of(context).brightness == Brightness.dark;

  Color get _bg => _night ? const Color(0xFF0B1016) : const Color(0xFFF5F6F8);
  Color get _card => _night ? const Color(0xFF0F172A) : Colors.white;
  Color get _text => _night ? Colors.white : const Color(0xFF111827);
  Color get _muted => _night ? Colors.white70 : const Color(0xFF6B7280);
  Color get _border => _night ? Colors.white12 : Colors.black12;

  static const Color _accent = Color(0xFFFF5A5F);
  static const Color _danger = Color(0xFFE53935);

  @override
  void initState() {
    super.initState();

    // ✅ pinta rápido con lo que vino por constructor
    final argName = (widget.displayName ?? '').trim();
    final argPhoto = (widget.photoUrl ?? '').trim();

    _name = argName.isNotEmpty ? argName : null;
    _photoUrl = argPhoto.isNotEmpty ? argPhoto : null;

    // ✅ y además intenta leer por arguments (por si el builder no pasó constructor)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readRouteArguments();
    });

    _loadSessionData();
  }

  void _readRouteArguments() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final dn = (args["displayName"] ?? '').toString().trim();
      final pu = (args["photoUrl"] ?? '').toString().trim();

      if (!mounted) return;
      setState(() {
        if ((_name ?? '').trim().isEmpty && dn.isNotEmpty) _name = dn;
        if ((_photoUrl ?? '').trim().isEmpty && pu.isNotEmpty) _photoUrl = pu;
      });
    }
  }

  Future<void> _loadSessionData() async {
    // ✅ 1) Pintar rápido con cache (sin esperar red)
    final prefs = await SharedPreferences.getInstance();

    final cachedName = (prefs.getString('displayName') ?? '').trim();
    final cachedPhoto = (prefs.getString('photoUrl') ?? '').trim();
    final cachedEmail = (prefs.getString('email') ?? '').trim();

    if (!mounted) return;
    setState(() {
      _name = (_name?.trim().isNotEmpty == true)
          ? _name
          : (cachedName.isNotEmpty ? cachedName : null);

      _photoUrl = (_photoUrl?.trim().isNotEmpty == true)
          ? _photoUrl
          : (cachedPhoto.isNotEmpty ? cachedPhoto : null);

      _email = cachedEmail.isNotEmpty ? cachedEmail : null;

      _loading = false; // ✅ ya mostramos UI
    });

    // ✅ 2) Rehidrata sesión y flags (local)
    try {
      await AuthService.restoreSession();
    } catch (_) {}

    final email = ((await AuthService.getCurrentUserEmail()) ?? '').trim();
    final userRole = ((await AuthService.getCurrentUserRole()) ?? '').trim();
    final communityRole =
        ((await AuthService.getCurrentCommunityRole()) ?? '').trim();

    final isSuperAdmin = await AuthService.isSuperAdminAsync();
    final isCommunityAdmin = await AuthService.isCommunityAdminAsync();

    final communities = await _loadCommunitiesFallback(prefs);

    if (!mounted) return;
    setState(() {
      if (email.isNotEmpty) _email = email;
      _userRole = userRole.isNotEmpty ? userRole : _userRole;
      _communityRole = communityRole.isNotEmpty ? communityRole : _communityRole;
      _isSuperAdmin = isSuperAdmin;
      _isCommunityAdmin = isCommunityAdmin;
      _communities = communities;
    });
  }

  Future<List<Map<String, dynamic>>> _loadCommunitiesFallback(
    SharedPreferences prefs,
  ) async {
    // compat: communityId / comunidadId
    final id = prefs.getInt("communityId") ?? prefs.getInt("comunidadId");
    final name = (prefs.getString("comunidadNombre") ?? '').trim();
    final photo = (prefs.getString("comunidadFotoUrl") ?? '').trim();

    if (id == null && name.isEmpty) return [];

    final isAdminComunidad = prefs.getBool("isAdminComunidad") ?? false;

    return [
      {
        "id": id ?? 0,
        "name": name.isNotEmpty ? name : "Mi comunidad",
        "photoUrl": photo.isNotEmpty ? photo : null,
        "role": isAdminComunidad ? "ADMIN" : "USER",
      }
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          SafeArea(
            child: CustomScrollView(
              slivers: [
                _topBar(context),
                SliverToBoxAdapter(child: const SizedBox(height: 10)),
                SliverToBoxAdapter(child: _profileCard(context)),
                SliverToBoxAdapter(child: const SizedBox(height: 12)),

                SliverToBoxAdapter(child: _sectionTitle("Tus accesos directos")),
                SliverToBoxAdapter(child: _communitiesStrip(context)),
                SliverToBoxAdapter(child: const SizedBox(height: 10)),

                SliverToBoxAdapter(child: _quickGrid(context)),
                SliverToBoxAdapter(child: const SizedBox(height: 12)),

                if (_isSuperAdmin) ...[
                  SliverToBoxAdapter(
                      child: _sectionTitle("Administrador global")),
                  SliverToBoxAdapter(child: _adminGlobalBlock(context)),
                  SliverToBoxAdapter(child: const SizedBox(height: 12)),
                ],
                if (_isCommunityAdmin) ...[
                  SliverToBoxAdapter(
                    child: _sectionTitle("Administrador de comunidad"),
                  ),
                  SliverToBoxAdapter(child: _adminCommunityBlock(context)),
                  SliverToBoxAdapter(child: const SizedBox(height: 12)),
                ],

                SliverToBoxAdapter(child: _sectionTitle("Cuenta")),
                SliverToBoxAdapter(child: _accountBlock(context)),

                // ✅ espacio para que el contenido no quede detrás del NavBar
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),

          // ✅ NAVBAR OVERLAY (como Home)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeZoneNavBar(
              currentIndex: 3,
              isNightMode: _night,
              photoUrl: _photoUrl,
              onTap: (i) {
                switch (i) {
                  case 0:
                    AppRoutes.navigateAndReplace(context, AppRoutes.home);
                    break;
                  case 1:
                    AppRoutes.navigateAndReplace(context, AppRoutes.explore);
                    break;
                  case 2:
                    AppRoutes.navigateAndReplace(context, AppRoutes.community);
                    break;
                  case 3:
                    break;
                }
              },
            ),
          ),

          // ✅ Loading ligero (NO tapa la pantalla completa)
          if (_loading)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: IgnorePointer(
                ignoring: true,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(_night ? 0.35 : 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Cargando menú…",
                          style: TextStyle(
                            color: _text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------- Top Bar ----------------
  SliverAppBar _topBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: _bg,
      foregroundColor: _text,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: _circleIconButton(
          icon: Icons.close_rounded,
          onTap: () => AppRoutes.navigateAndReplace(context, AppRoutes.home),
        ),
      ),
      title: Text(
        "Menú",
        style: TextStyle(
          color: _text,
          fontWeight: FontWeight.w900,
          fontSize: 28,
        ),
      ),
      actions: [
        _circleIconButton(
          icon: Icons.settings_outlined,
          onTap: () => _go(context, AppRoutes.profile),
        ),
        const SizedBox(width: 8),
        _circleIconButton(
          icon: Icons.search,
          onTap: () => _openMenuSearch(context),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _circleIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Material(
        color: _card,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: _text),
          ),
        ),
      ),
    );
  }

  // ---------------- Search (simple y funcional) ----------------
  Future<void> _openMenuSearch(BuildContext context) async {
    final items = <_MenuSearchItem>[
      _MenuSearchItem(
        title: "Perfil",
        subtitle: "Editar tu cuenta",
        icon: Icons.person_outline,
        keywords: const ["perfil", "cuenta", "usuario", "editar"],
        onSelected: () => _go(context, AppRoutes.profile),
      ),
      _MenuSearchItem(
        title: "Contactos",
        subtitle: "Tus contactos de emergencia",
        icon: Icons.contacts_outlined,
        keywords: const ["contactos", "emergencia", "telefono"],
        onSelected: () => _go(context, AppRoutes.contacts),
      ),
      _MenuSearchItem(
        title: "Notificaciones",
        subtitle: "Alertas de tu comunidad",
        icon: Icons.notifications_none_rounded,
        keywords: const ["notificaciones", "alertas", "avisos", "incidentes"],
        onSelected: () => _goToNotifications(context),
      ),
      _MenuSearchItem(
        title: "Mis comunidades",
        subtitle: "Ver todas tus comunidades",
        icon: Icons.groups_rounded,
        keywords: const ["mis comunidades", "comunidades", "grupo", "unirme"],
        onSelected: () => _go(context, AppRoutes.myCommunities),
      ),
    ];

    final result = await showSearch<_MenuSearchResult?>(
      context: context,
      delegate: _MenuSearchDelegate(items: items, night: _night),
    );

    if (!mounted) return;
    if (result != null) result.onSelected();
  }

  // ---------------- Notificaciones (REAL) ----------------
  Future<void> _goToNotifications(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    final comunidadId =
        prefs.getInt("comunidadId") ?? prefs.getInt("communityId") ?? 0;

    if (comunidadId <= 0) {
      _snack(context, "Primero selecciona una comunidad para ver notificaciones.");
      _go(context, AppRoutes.communityPicker);
      return;
    }

    _go(
      context,
      AppRoutes.notifications,
      arguments: {"comunidadId": comunidadId},
    );
  }

  // ---------------- Profile Card ----------------
  Widget _profileCard(BuildContext context) {
    final name =
        (_name?.trim().isNotEmpty == true) ? _name!.trim() : "Mi cuenta";

    final roleLabel = _isSuperAdmin
        ? "Admin global"
        : _isCommunityAdmin
            ? "Admin de comunidad"
            : "Usuario";

    final subtitle =
        (_email != null && _email!.isNotEmpty) ? _email! : roleLabel;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_night ? 0.35 : 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _profileAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _text,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      if ((_userRole?.isNotEmpty == true) ||
                          (_communityRole?.isNotEmpty == true)) ...[
                        const SizedBox(height: 3),
                        Text(
                          _debugRoleLine(roleLabel),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _muted.withOpacity(0.85),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: _night
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.05),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _go(context, AppRoutes.profile),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(Icons.chevron_right_rounded, color: _muted),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileAvatar() {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _accent, width: 2),
        color: Colors.white,
      ),
      child: ClipOval(
        child: (_photoUrl != null && _photoUrl!.trim().isNotEmpty)
            ? Image.network(
                _photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.person, color: _accent),
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2));
                },
              )
            : const Icon(Icons.person, color: _accent),
      ),
    );
  }

  // ---------------- Communities ----------------
  Widget _communitiesStrip(BuildContext context) {
    if (_communities.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.groups_rounded, color: _muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Aún no tienes comunidades vinculadas.",
                  style: TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _go(context, AppRoutes.communityPicker),
                child: const Text("Unirme"),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 92,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
        scrollDirection: Axis.horizontal,
        itemCount: _communities.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = _communities[i];

          final int id = (c["id"] is num) ? (c["id"] as num).toInt() : 0;
          final String name = (c["name"] ?? "Comunidad").toString();
          final String? photo = (c["photoUrl"] as String?);
          final String role = (c["role"] ?? "").toString().toUpperCase().trim();

          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _enterCommunity(
              context,
              comunidadId: id,
              comunidadNombre: name,
              comunidadFotoUrl: photo,
              role: role,
            ),
            child: Container(
              width: 190,
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _communityAvatar(photoUrl: photo),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _text,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          role.isEmpty ? "Entrar" : role,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _muted,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: _muted),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _enterCommunity(
    BuildContext context, {
    required int comunidadId,
    required String comunidadNombre,
    String? comunidadFotoUrl,
    required String role,
  }) async {
    if (comunidadId <= 0) {
      _snack(context, "No se pudo seleccionar la comunidad (id inválido).");
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt("comunidadId", comunidadId);
    await prefs.setString("comunidadNombre", comunidadNombre);

    if ((comunidadFotoUrl ?? "").trim().isNotEmpty) {
      await prefs.setString("comunidadFotoUrl", comunidadFotoUrl!.trim());
    } else {
      await prefs.remove("comunidadFotoUrl");
    }

    final isAdminComunidad = role == "ADMIN" || role == "ADMIN_COMUNIDAD";
    await prefs.setBool("isAdminComunidad", isAdminComunidad);

    // compat con tu app
    await prefs.setInt("communityId", comunidadId);
    await prefs.setString("communityRole", isAdminComunidad ? "ADMIN" : "USER");

    await AuthService.restoreSession();
    if (!mounted) return;

    AppRoutes.navigateAndReplace(
      context,
      AppRoutes.community,
      arguments: {"comunidadId": comunidadId, "openTab": 0},
    );
  }

  Widget _communityAvatar({String? photoUrl}) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        color: _night
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.04),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: (photoUrl != null && photoUrl.trim().isNotEmpty)
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.groups_rounded, color: _muted),
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2));
                },
              )
            : Icon(Icons.groups_rounded, color: _muted),
      ),
    );
  }

  // ---------------- Quick Grid (CORREGIDO) ----------------
  Widget _quickGrid(BuildContext context) {
    final items = <_QuickItem>[
      _QuickItem(
        icon: Icons.person_outline,
        label: "Perfil",
        onTap: () => _go(context, AppRoutes.profile),
      ),
      _QuickItem(
        icon: Icons.contacts_outlined,
        label: "Contactos",
        onTap: () => _go(context, AppRoutes.contacts),
      ),
      _QuickItem(
        icon: Icons.notifications_none_rounded,
        label: "Notificaciones",
        onTap: () => _goToNotifications(context),
      ),
      // ✅ CAMBIO: Consejos -> Mis comunidades
      _QuickItem(
        icon: Icons.groups_rounded,
        label: "Mis comunidades",
        onTap: () => _go(context, AppRoutes.myCommunities),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        itemCount: items.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.6,
        ),
        itemBuilder: (_, i) => _quickTile(items[i]),
      ),
    );
  }

  Widget _quickTile(_QuickItem it) {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: it.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(it.icon, color: _accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  it.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- Admin blocks ----------------
  Widget _adminGlobalBlock(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: _longTile(
        icon: Icons.dashboard_outlined,
        title: "Dashboard",
        subtitle: "Resumen general",
        onTap: () => _go(context, AppRoutes.admin),
      ),
    );
  }

  Widget _adminCommunityBlock(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: _longTile(
        icon: Icons.how_to_reg_outlined,
        title: "Solicitudes",
        subtitle: "Aprobar / Rechazar ingresos",
        onTap: () => _go(context, AppRoutes.communityAdminRequests),
      ),
    );
  }

  // ---------------- Account ----------------
  Widget _accountBlock(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: _longTile(
        icon: Icons.logout_rounded,
        title: "Cerrar sesión",
        subtitle: "Salir de SafeZone",
        danger: true,
        onTap: () async {
          await AuthService.logout();
          if (!context.mounted) return;
          AppRoutes.navigateAndClearStack(context, AppRoutes.login);
        },
      ),
    );
  }

  // ---------------- Long Tile ----------------
  Widget _longTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final c = danger ? _danger : _accent;

    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: c.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: c),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: danger ? _danger : _text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: _muted),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- Helpers ----------------
  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Text(
        t,
        style: TextStyle(
          color: _muted,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  String _debugRoleLine(String roleLabel) {
    final ur = (_userRole ?? '').trim();
    final cr = (_communityRole ?? '').trim();
    if (ur.isEmpty && cr.isEmpty) return roleLabel;
    if (ur.isNotEmpty && cr.isNotEmpty) {
      return "$roleLabel • userRole=$ur • communityRole=$cr";
    }
    if (ur.isNotEmpty) return "$roleLabel • userRole=$ur";
    return "$roleLabel • communityRole=$cr";
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _go(BuildContext context, String route, {Object? arguments}) {
    AppRoutes.navigateTo(context, route, arguments: arguments);
  }
}

class _QuickItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  _QuickItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

// =============================
// Search Delegate (simple)
// =============================
class _MenuSearchItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> keywords;
  final VoidCallback onSelected;

  _MenuSearchItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.keywords,
    required this.onSelected,
  });
}

class _MenuSearchResult {
  final VoidCallback onSelected;
  _MenuSearchResult(this.onSelected);
}

class _MenuSearchDelegate extends SearchDelegate<_MenuSearchResult?> {
  final List<_MenuSearchItem> items;
  final bool night;

  _MenuSearchDelegate({required this.items, required this.night});

  Color get _bg => night ? const Color(0xFF0B1016) : const Color(0xFFF5F6F8);
  Color get _card => night ? const Color(0xFF0F172A) : Colors.white;
  Color get _text => night ? Colors.white : const Color(0xFF111827);
  Color get _muted => night ? Colors.white70 : const Color(0xFF6B7280);
  Color get _border => night ? Colors.white12 : Colors.black12;

  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      scaffoldBackgroundColor: _bg,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: _bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: _text),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        hintStyle: TextStyle(color: _muted),
        border: InputBorder.none,
      ),
      textTheme: base.textTheme.copyWith(
        titleLarge: TextStyle(color: _text, fontWeight: FontWeight.w900),
      ),
    );
  }

  @override
  String get searchFieldLabel => "Buscar en el menú";

  @override
  TextStyle get searchFieldStyle =>
      TextStyle(color: _text, fontWeight: FontWeight.w800);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.trim().isNotEmpty)
        IconButton(
          onPressed: () => query = '',
          icon: Icon(Icons.close_rounded, color: _text),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: Icon(Icons.arrow_back_ios_new_rounded, color: _text, size: 18),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _resultsList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _resultsList(context);

  Widget _resultsList(BuildContext context) {
    final q = query.trim().toLowerCase();

    final filtered = q.isEmpty
        ? items
        : items.where((it) {
            final hay = it.title.toLowerCase().contains(q) ||
                it.subtitle.toLowerCase().contains(q) ||
                it.keywords.any((k) => k.toLowerCase().contains(q));
            return hay;
          }).toList();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final it = filtered[i];
        return Material(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => close(context, _MenuSearchResult(it.onSelected)),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5A5F).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(it.icon, color: const Color(0xFFFF5A5F)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          it.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _text,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          it.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _muted,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: _muted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
