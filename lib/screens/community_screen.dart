// lib/screens/community_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../routes/app_routes.dart';
import '../service/chat_service.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _selectedTab = 0; // 0 Comunidad, 1 Cerca

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final ChatService _chat = ChatService();

  bool _isLoading = false;
  bool _isDisposed = false;

  // ===== OFFLINE/ONLINE =====
  bool _isOnline = true; // ✅ ahora significa "Internet real", no solo Wi-Fi
  bool _bannerShownOnce = false;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  // ===== Data =====
  final List<Map<String, dynamic>> _communityMessages = []; // NEWEST -> OLDEST
  final List<Map<String, dynamic>> _nearbyMessages = []; // NEWEST -> OLDEST

  // Paginación (una por tab)
  static const int _pageSize = 30;

  bool _fetchingMoreCommunity = false;
  bool _fetchingMoreNearby = false;

  bool _hasMoreCommunity = true;
  bool _hasMoreNearby = true;

  dynamic _cursorOldestCommunity; // id o timestamp del más antiguo cargado
  dynamic _cursorOldestNearby;

  // Nuevos mensajes mientras estás scrolleando arriba
  int _pendingNewCommunity = 0;
  int _pendingNewNearby = 0;

  int? myUserId;
  int? comunidadId;

  String? myName;
  String? myPhotoUrl;

  final Set<dynamic> _unlockedSensitive = <dynamic>{};

  bool get isNightMode => Theme.of(context).brightness == Brightness.dark;

  // ===================== INTERNET REAL CHECK =====================
  // Connectivity != Internet. Esto valida DNS real.
  Future<bool> _hasRealInternet() async {
    try {
      final result = await InternetAddress.lookup('one.one.one.one')
          .timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ===================== CONNECTIVITY HELPERS =====================

  bool _isOnlineFromResults(List<ConnectivityResult> results) {
    // "tiene red" si existe cualquier medio distinto de none
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<void> _checkOnlineNow() async {
    try {
      final results = await Connectivity().checkConnectivity(); // ✅ List<ConnectivityResult>
      final hasNetwork = _isOnlineFromResults(results);
      final online = hasNetwork ? await _hasRealInternet() : false;

      if (!mounted || _isDisposed) return;
      setState(() => _isOnline = online);

      if (!online) {
        await _loadCachedBothTabs();
      }
    } catch (_) {
      if (!mounted || _isDisposed) return;
      setState(() => _isOnline = false);
      await _loadCachedBothTabs();
    }
  }

  void _startConnectivityListener() {
    _connSub?.cancel();
    _connSub = Connectivity().onConnectivityChanged.listen((results) async {
      if (!mounted || _isDisposed) return;

      final hasNetwork = _isOnlineFromResults(results);
      final online = hasNetwork ? await _hasRealInternet() : false;

      if (!mounted || _isDisposed) return;
      if (online == _isOnline) return;

      setState(() => _isOnline = online);

      if (!online) {
        // offline: cargar cache y avisar
        await _loadCachedBothTabs();
        if (!_bannerShownOnce && mounted) {
          _bannerShownOnce = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Sin internet. Mostrando mensajes guardados.")),
          );
        }
      } else {
        // online: reconectar + refrescar
        _connectIfReady();
        await _loadLatestBothTabs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Internet restaurado. Sincronizando chat...")),
          );
        }
      }
    });
  }

  bool _looksLikeNoInternetError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('timed out') ||
        msg.contains('clientexception') ||
        msg.contains('no address associated with hostname') ||
        msg.contains('errno = 7');
  }

  Future<void> _forceOfflineFallback({bool showSnack = true}) async {
    if (!mounted || _isDisposed) return;
    setState(() => _isOnline = false);
    await _loadCachedBothTabs();

    if (showSnack && !_bannerShownOnce && mounted) {
      _bannerShownOnce = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sin internet. Mostrando mensajes guardados.")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleInitialArgsAndInit());
    _scrollController.addListener(_onScroll);

    _startConnectivityListener();
    _checkOnlineNow();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _scrollController.removeListener(_onScroll);
    _connSub?.cancel();
    _chat.disconnect();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ===================== INIT =====================

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

    await _initUserAndMaybeConnect();
  }

  Future<void> _initUserAndMaybeConnect() async {
    final prefs = await SharedPreferences.getInstance();

    myUserId = prefs.getInt("userId");
    comunidadId ??= prefs.getInt("comunidadId") ?? prefs.getInt("communityId");

    myName = prefs.getString("userName");
    myPhotoUrl = prefs.getString("photoUrl");

    if (_isDisposed || !mounted) return;

    if (myUserId == null || comunidadId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No se encontró userId/comunidadId en sesión."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _chat.onCommunityMessage = (msg) {
      if (_isDisposed || !mounted) return;
      _onIncomingMessage(isCommunity: true, msg: msg);
      _cacheAppend(isCommunity: true, msg: msg);
    };

    _chat.onNearbyMessage = (msg) {
      if (_isDisposed || !mounted) return;
      _onIncomingMessage(isCommunity: false, msg: msg);
      _cacheAppend(isCommunity: false, msg: msg);
    };

    _chat.onWsError = (err) async {
      if (_isDisposed || !mounted) return;

      // Si no hay internet real, no molestamos con errores WS
      if (!_isOnline) return;

      // Si el WS cae por red, pasamos a offline
      final looksOffline = err.toString().toLowerCase().contains('socket') ||
          err.toString().toLowerCase().contains('failed host lookup');
      if (looksOffline) {
        await _forceOfflineFallback(showSnack: true);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("WS error: $err"), backgroundColor: Colors.red),
      );
    };

    if (_isOnline) {
      _connectIfReady();
      await _loadLatestBothTabs();
    } else {
      await _loadCachedBothTabs();
    }
  }

  void _connectIfReady() {
    if (_isDisposed) return;
    if (!_isOnline) return;
    if (myUserId == null || comunidadId == null) return;
    if (_chat.isConnected) return;

    _chat.connect(
      comunidadId: comunidadId!,
      myUserId: myUserId!,
      myPhotoUrl: myPhotoUrl,
    );
  }

  void _onIncomingMessage({required bool isCommunity, required Map<String, dynamic> msg}) {
    final list = isCommunity ? _communityMessages : _nearbyMessages;

    final newId = msg['id'];
    if (newId != null && list.any((m) => m['id'] == newId)) return;

    setState(() {
      list.insert(0, msg); // NEWEST primero
    });

    if (_isNearLatest()) {
      _scrollToLatest();
    } else {
      setState(() {
        if (isCommunity) {
          _pendingNewCommunity++;
        } else {
          _pendingNewNearby++;
        }
      });
    }
  }

  // ===================== CACHE =====================

  String _cacheKey({required int comunidadId, required String canal}) => "chat_cache_${comunidadId}_$canal";

  Future<void> _cacheSave({
    required bool isCommunity,
    required List<Map<String, dynamic>> itemsNewestFirst,
  }) async {
    if (comunidadId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final canal = isCommunity ? "COMUNIDAD" : "VECINOS";

    final sliced = itemsNewestFirst.take(60).toList();
    await prefs.setString(_cacheKey(comunidadId: comunidadId!, canal: canal), jsonEncode(sliced));
  }

  Future<void> _cacheAppend({required bool isCommunity, required Map<String, dynamic> msg}) async {
    if (comunidadId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final canal = isCommunity ? "COMUNIDAD" : "VECINOS";

    final key = _cacheKey(comunidadId: comunidadId!, canal: canal);
    final raw = prefs.getString(key);

    List<Map<String, dynamic>> list = [];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } catch (_) {}
    }

    final id = msg['id'];
    if (id != null && list.any((m) => m['id'] == id)) return;

    list.insert(0, msg);
    if (list.length > 60) list = list.take(60).toList();

    await prefs.setString(key, jsonEncode(list));
  }

  Future<void> _loadCachedBothTabs() async {
    if (_isDisposed || !mounted) return;
    if (comunidadId == null) return;

    final prefs = await SharedPreferences.getInstance();

    List<Map<String, dynamic>> read(String canal) {
      final raw = prefs.getString(_cacheKey(comunidadId: comunidadId!, canal: canal));
      if (raw == null || raw.trim().isEmpty) return [];
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } catch (_) {}
      return [];
    }

    final cachedCommunity = read("COMUNIDAD");
    final cachedNearby = read("VECINOS");

    setState(() {
      _communityMessages
        ..clear()
        ..addAll(cachedCommunity);
      _nearbyMessages
        ..clear()
        ..addAll(cachedNearby);

      _pendingNewCommunity = 0;
      _pendingNewNearby = 0;

      // offline: no paginar
      _hasMoreCommunity = false;
      _hasMoreNearby = false;
    });

    _scrollToLatest(jump: true);
  }

  // ===================== PAGINACIÓN =====================

  Future<void> _loadLatestBothTabs() async {
    if (_isDisposed || !mounted) return;

    // ✅ Revalidar Internet real antes de pedir historial
    if (_isOnline) {
      final ok = await _hasRealInternet();
      if (!ok) {
        await _forceOfflineFallback(showSnack: true);
        return;
      }
    } else {
      await _loadCachedBothTabs();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final latestCommunity = await _loadLatest(canal: "COMUNIDAD");
      final latestNearby = await _loadLatest(canal: "VECINOS");

      if (_isDisposed || !mounted) return;

      setState(() {
        _communityMessages
          ..clear()
          ..addAll(latestCommunity.itemsNewestFirst);
        _nearbyMessages
          ..clear()
          ..addAll(latestNearby.itemsNewestFirst);

        _hasMoreCommunity = latestCommunity.hasMore;
        _hasMoreNearby = latestNearby.hasMore;

        _cursorOldestCommunity = latestCommunity.cursorOldest;
        _cursorOldestNearby = latestNearby.cursorOldest;

        _pendingNewCommunity = 0;
        _pendingNewNearby = 0;
      });

      await _cacheSave(isCommunity: true, itemsNewestFirst: _communityMessages);
      await _cacheSave(isCommunity: false, itemsNewestFirst: _nearbyMessages);

      _scrollToLatest(jump: true);
    } catch (e) {
      if (_isDisposed || !mounted) return;

      // ✅ Si es "no internet/DNS" -> OFFLINE sin error rojo
      if (_looksLikeNoInternetError(e)) {
        await _forceOfflineFallback(showSnack: true);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No se pudieron cargar los mensajes: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (_isDisposed || !mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _onScroll() {
    if (_isDisposed) return;
    if (!_scrollController.hasClients) return;
    if (!_isOnline) return; // offline: no paginar

    final pos = _scrollController.position;
    final bool isNearOldest = pos.pixels >= (pos.maxScrollExtent - 220);
    if (!isNearOldest) return;

    if (_selectedTab == 0) {
      if (_fetchingMoreCommunity || !_hasMoreCommunity) return;
      _loadOlder(canal: "COMUNIDAD");
    } else {
      if (_fetchingMoreNearby || !_hasMoreNearby) return;
      _loadOlder(canal: "VECINOS");
    }
  }

  Future<void> _loadOlder({required String canal}) async {
    if (_isDisposed) return;
    if (!_isOnline) return;

    // ✅ revalidar internet real
    final ok = await _hasRealInternet();
    if (!ok) {
      await _forceOfflineFallback(showSnack: true);
      return;
    }

    final bool isCommunity = canal == "COMUNIDAD";
    if (isCommunity) {
      _fetchingMoreCommunity = true;
    } else {
      _fetchingMoreNearby = true;
    }

    double oldMax = 0;
    double oldPixels = 0;
    if (_scrollController.hasClients) {
      oldMax = _scrollController.position.maxScrollExtent;
      oldPixels = _scrollController.position.pixels;
    }

    try {
      final cursor = isCommunity ? _cursorOldestCommunity : _cursorOldestNearby;

      final page = await _loadOlderPage(
        canal: canal,
        cursorOldest: cursor,
      );

      if (_isDisposed || !mounted) return;

      if (page.itemsNewestFirst.isEmpty) {
        setState(() {
          if (isCommunity) _hasMoreCommunity = false;
          if (!isCommunity) _hasMoreNearby = false;
        });
        return;
      }

      setState(() {
        final list = isCommunity ? _communityMessages : _nearbyMessages;
        list.addAll(page.itemsNewestFirst);

        if (isCommunity) {
          _cursorOldestCommunity = page.cursorOldest;
          _hasMoreCommunity = page.hasMore;
        } else {
          _cursorOldestNearby = page.cursorOldest;
          _hasMoreNearby = page.hasMore;
        }
      });

      await _cacheSave(isCommunity: isCommunity, itemsNewestFirst: isCommunity ? _communityMessages : _nearbyMessages);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final newMax = _scrollController.position.maxScrollExtent;
        final delta = newMax - oldMax;
        if (delta > 0) {
          _scrollController.jumpTo(oldPixels + delta);
        }
      });
    } catch (e) {
      if (_looksLikeNoInternetError(e)) {
        await _forceOfflineFallback(showSnack: true);
      }
      // si no, silencioso (tu decisión)
    } finally {
      if (isCommunity) {
        _fetchingMoreCommunity = false;
      } else {
        _fetchingMoreNearby = false;
      }
    }
  }

  // ===================== BACKEND ADAPTER =====================

  Future<_ChatPage> _loadLatest({required String canal}) async {
    final list = await _chat.loadHistorial(
      comunidadId: comunidadId!,
      canal: canal,
      myUserId: myUserId,
      myPhotoUrl: myPhotoUrl,
    );

    final normalized = _normalizeNewestFirst(list);
    final items = normalized.length > _pageSize ? normalized.take(_pageSize).toList() : normalized;

    final cursorOldest = items.isEmpty ? null : _cursorFromMessage(items.last);
    final hasMore = normalized.length > items.length;

    return _ChatPage(itemsNewestFirst: items, cursorOldest: cursorOldest, hasMore: hasMore);
  }

  Future<_ChatPage> _loadOlderPage({required String canal, required dynamic cursorOldest}) async {
    final list = await _chat.loadHistorial(
      comunidadId: comunidadId!,
      canal: canal,
      myUserId: myUserId,
      myPhotoUrl: myPhotoUrl,
    );

    final normalized = _normalizeNewestFirst(list);

    final older = normalized.where((m) {
      if (cursorOldest == null) return false;
      final c = _cursorFromMessage(m);
      if (c == null) return false;

      final ci = _tryInt(c);
      final oi = _tryInt(cursorOldest);
      if (ci != null && oi != null) return ci < oi;

      return c.toString().compareTo(cursorOldest.toString()) < 0;
    }).toList();

    final pageItems = older.take(_pageSize).toList();
    final newCursorOldest = pageItems.isEmpty ? cursorOldest : _cursorFromMessage(pageItems.last);

    return _ChatPage(itemsNewestFirst: pageItems, cursorOldest: newCursorOldest, hasMore: older.length > pageItems.length);
  }

  List<Map<String, dynamic>> _normalizeNewestFirst(List<Map<String, dynamic>> list) {
    final copy = List<Map<String, dynamic>>.from(list);

    int? keyInt(Map<String, dynamic> m) {
      final v = m['id'] ?? m['createdAtMillis'] ?? m['createdAt'] ?? m['time'];
      return _tryInt(v);
    }

    final hasAny = copy.any((m) => keyInt(m) != null);
    if (hasAny) {
      copy.sort((a, b) {
        final ai = keyInt(a) ?? -1;
        final bi = keyInt(b) ?? -1;
        return bi.compareTo(ai);
      });
      return copy;
    }
    return copy;
  }

  dynamic _cursorFromMessage(Map<String, dynamic> m) {
    return m['id'] ?? m['createdAtMillis'] ?? m['createdAt'] ?? m['time'];
  }

  int? _tryInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  bool _isNearLatest() {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.pixels <= 120; // reverse:true => latest = 0
  }

  void _scrollToLatest({bool jump = false}) {
    if (_isDisposed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients || _isDisposed) return;
      if (jump) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });
  }

  void _clearPending() {
    setState(() {
      if (_selectedTab == 0) {
        _pendingNewCommunity = 0;
      } else {
        _pendingNewNearby = 0;
      }
    });
  }

  // ===================== UI =====================

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomPadding = media.padding.bottom;

    final bool night = isNightMode;

    final Color bgColor = night ? const Color(0xFF05070A) : const Color(0xFFF3F4F6);
    final Color surface = night ? const Color(0xFF0B1016) : Colors.white;
    final Color surface2 = night ? const Color(0xFF111827) : const Color(0xFFF9FAFB);

    final Color primaryText = night ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
    final Color secondaryText = night ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    final Color borderColor = night ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);
    final Color cardShadow = night ? Colors.black.withOpacity(0.65) : Colors.black.withOpacity(0.06);

    const Color primaryGrad1 = Color(0xFFFF5A5A);
    const Color primaryGrad2 = Color(0xFFE53935);

    const Color bubbleMeStart = primaryGrad1;
    const Color bubbleMeEnd = primaryGrad2;

    final Color bubbleOthers = surface;

    final List<Map<String, dynamic>> currentMessages = _selectedTab == 0 ? _communityMessages : _nearbyMessages;

    final pendingNew = _selectedTab == 0 ? _pendingNewCommunity : _pendingNewNearby;

    final bool hasMore = _selectedTab == 0 ? _hasMoreCommunity : _hasMoreNearby;
    final bool fetchingMore = _selectedTab == 0 ? _fetchingMoreCommunity : _fetchingMoreNearby;

    final Color headerBg = night ? const Color(0xFF060A10) : Colors.white;
    final Color headerTitleColor = night ? Colors.white : const Color(0xFF111827);
    final Color headerSubtitleColor = night ? Colors.white70 : const Color(0xFF6B7280);

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

                // ✅ OFFLINE BANNER
                if (!_isOnline)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB91C1C).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFB91C1C).withOpacity(0.35)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.wifi_off_rounded, color: Color(0xFFB91C1C)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Sin internet • Mostrando mensajes guardados",
                              style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFB91C1C)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ===== HEADER =====
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: headerBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderColor),
                      boxShadow: [BoxShadow(color: cardShadow, blurRadius: 14, offset: const Offset(0, 6))],
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => AppRoutes.navigateAndClearStack(context, AppRoutes.home),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: night ? Colors.white.withOpacity(0.10) : const Color(0xFFF3F4F6),
                              shape: BoxShape.circle,
                              border: Border.all(color: borderColor),
                            ),
                            child: Icon(Icons.arrow_back_ios_new, size: 18, color: night ? Colors.white : const Color(0xFF111827)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedTab == 0 ? "Comunidad" : "Personas cercanas",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: headerTitleColor),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selectedTab == 0 ? "Organiza alertas y apoyo con tus vecinos." : "Recibe avisos de emergencias cerca de ti.",
                                style: TextStyle(fontSize: 11.5, color: headerSubtitleColor),
                              ),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: night ? Colors.white.withOpacity(0.18) : const Color(0xFFE5E7EB),
                          // ✅ no intentes NetworkImage si estás offline real
                          backgroundImage: (_isOnline && myPhotoUrl != null && myPhotoUrl!.isNotEmpty) ? NetworkImage(myPhotoUrl!) : null,
                          child: (myPhotoUrl == null || myPhotoUrl!.isEmpty || !_isOnline)
                              ? Text(
                                  (myName != null && myName!.isNotEmpty) ? myName![0].toUpperCase() : 'T',
                                  style: TextStyle(color: night ? Colors.white : const Color(0xFF111827), fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ===== TABS =====
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: night ? Colors.white.withOpacity(0.08) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                      boxShadow: [BoxShadow(color: cardShadow, blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        _buildTabButton(
                          label: "Comunidad",
                          index: 0,
                          isNightMode: night,
                          activeGrad1: primaryGrad1,
                          activeGrad2: primaryGrad2,
                          inactiveText: night ? Colors.white70 : const Color(0xFF111827),
                        ),
                        _buildTabButton(
                          label: "Cerca",
                          index: 1,
                          isNightMode: night,
                          activeGrad1: primaryGrad1,
                          activeGrad2: primaryGrad2,
                          inactiveText: night ? Colors.white70 : const Color(0xFF111827),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                if (pendingNew > 0 && !_isNearLatest())
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: GestureDetector(
                      onTap: () {
                        _clearPending();
                        _scrollToLatest();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(colors: [primaryGrad1, primaryGrad2]),
                          boxShadow: [BoxShadow(color: primaryGrad2.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text("$pendingNew mensaje(s) nuevo(s)", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  ),

                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator(color: night ? Colors.white : primaryGrad2))
                      : RefreshIndicator(
                          color: primaryGrad2,
                          onRefresh: _loadLatestBothTabs,
                          child: currentMessages.isEmpty
                              ? ListView(
                                  reverse: true,
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    const SizedBox(height: 80),
                                    Center(
                                      child: Text(
                                        _isOnline ? "No hay mensajes aún.\nSé el primero en escribir." : "Sin internet.\nNo hay mensajes guardados para mostrar.",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: secondaryText, fontSize: 14),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  controller: _scrollController,
                                  reverse: true,
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  itemCount: currentMessages.length + ((hasMore || fetchingMore) ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    if ((hasMore || fetchingMore) && index == currentMessages.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6, bottom: 16),
                                        child: Center(
                                          child: fetchingMore
                                              ? CircularProgressIndicator(color: night ? Colors.white : primaryGrad2)
                                              : Text("Desliza para cargar más...", style: TextStyle(color: secondaryText, fontSize: 12)),
                                        ),
                                      );
                                    }

                                    final msg = currentMessages[index];
                                    return _buildMessageBubble(
                                      msg,
                                      isNightMode: night,
                                      surface: surface,
                                      surface2: surface2,
                                      primaryText: primaryText,
                                      secondaryText: secondaryText,
                                      bubbleMeStart: bubbleMeStart,
                                      bubbleMeEnd: bubbleMeEnd,
                                      bubbleOthers: bubbleOthers,
                                      cardShadow: cardShadow,
                                      borderColor: borderColor,
                                    );
                                  },
                                ),
                        ),
                ),

                // ===== INPUT (bloqueado si offline) =====
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: EdgeInsets.only(left: 14, right: 14, top: 10, bottom: 10 + bottomPadding),
                      decoration: BoxDecoration(
                        color: night ? const Color(0xFF020617).withOpacity(0.88) : Colors.white,
                        border: Border(top: BorderSide(color: borderColor)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(night ? 0.18 : 0.08), blurRadius: 12, offset: const Offset(0, -3))],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: night ? const Color(0xFF0B1220) : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: borderColor),
                              ),
                              child: TextField(
                                controller: _messageController,
                                enabled: _isOnline,
                                style: TextStyle(color: primaryText, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: _isOnline ? "Escribe un mensaje..." : "Sin internet (no puedes enviar)",
                                  hintStyle: TextStyle(color: secondaryText, fontSize: 13),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _isOnline
                                ? _sendMessage
                                : () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Sin internet. No se puede enviar mensajes.")),
                                    );
                                  },
                            child: Opacity(
                              opacity: _isOnline ? 1.0 : 0.45,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(colors: [primaryGrad1, primaryGrad2]),
                                ),
                                child: const Icon(Icons.send_rounded, color: Colors.white, size: 21),
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
    required Color inactiveText,
  }) {
    final bool isActive = _selectedTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedTab != index) {
            setState(() => _selectedTab = index);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isActive ? LinearGradient(colors: [activeGrad1, activeGrad2]) : null,
            color: isActive ? null : Colors.transparent,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isActive ? Colors.white : inactiveText),
            ),
          ),
        ),
      ),
    );
  }

  // ===================== BURBUJA =====================

  String? _asStringOrNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  double? _asDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> message, {
    required bool isNightMode,
    required Color surface,
    required Color surface2,
    required Color primaryText,
    required Color secondaryText,
    required Color bubbleMeStart,
    required Color bubbleMeEnd,
    required Color bubbleOthers,
    required Color cardShadow,
    required Color borderColor,
  }) {
    final bool isMe = (message['isMe'] ?? false) == true;

    final String sender = (message['sender'] ?? '').toString();
    final String time = (message['time'] ?? '').toString();
    final String text = (message['message'] ?? '').toString();

    final String? imagenUrl = _asStringOrNull(message['imagenUrl']);
    final String? videoUrl = _asStringOrNull(message['videoUrl']);
    final String? audioUrl = _asStringOrNull(message['audioUrl']);

    final bool contenidoSensible = message['contenidoSensible'] == true;
    final String? motivo = _asStringOrNull(message['sensibilidadMotivo']);
    final double? score = _asDoubleOrNull(message['sensibilidadScore']);

    final dynamic msgId = message['id'] ?? '${message['time']}-${message['userId']}-${message['tipo']}';
    final bool unlocked = _unlockedSensitive.contains(msgId);

    final String avatarOthers = (message['avatar'] ?? '').toString();

    ImageProvider? avatarProviderOthers;
    if (avatarOthers.isNotEmpty) {
      // Si estás offline, no fuerces NetworkImage; igual cae al errorBuilder del widget
      if (_isOnline && avatarOthers.startsWith('http')) {
        avatarProviderOthers = NetworkImage(avatarOthers);
      } else if (!avatarOthers.startsWith('http')) {
        avatarProviderOthers = AssetImage(avatarOthers);
      }
    }

    ImageProvider? avatarProviderMe;
    if (_isOnline && (myPhotoUrl ?? '').isNotEmpty) {
      avatarProviderMe = NetworkImage(myPhotoUrl!);
    }

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
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
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
                      onTap: () => setState(() => _unlockedSensitive.add(msgId)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.25)),
                        ),
                        child: const Text(
                          "Mostrar",
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
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

    final bool othersIsWhite = !isMe && bubbleOthers == Colors.white;
    final BoxBorder? othersBorder = othersIsWhite ? Border.all(color: borderColor) : null;

    final Color nameColor = isNightMode ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
    final Color timeColor = secondaryText;

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
              backgroundImage: avatarProviderOthers,
              child: avatarProviderOthers == null
                  ? Text(
                      sender.isNotEmpty ? sender[0].toUpperCase() : "?",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isNightMode ? Colors.white : const Color(0xFF111827)),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && sender.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(sender, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: nameColor)),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isMe ? LinearGradient(colors: [bubbleMeStart, bubbleMeEnd]) : null,
                    color: isMe ? null : bubbleOthers,
                    border: othersBorder,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 6),
                      bottomRight: Radius.circular(isMe ? 6 : 18),
                    ),
                    boxShadow: [BoxShadow(color: cardShadow, blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      if (imagenUrl != null && imagenUrl.isNotEmpty) ...[
                        wrapSensitive(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              imagenUrl,
                              width: 240,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 240,
                                height: 140,
                                decoration: BoxDecoration(
                                  color: surface2,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Center(child: Icon(Icons.broken_image, color: secondaryText)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (videoUrl != null && videoUrl.isNotEmpty) ...[
                        wrapSensitive(
                          child: Container(
                            width: 240,
                            height: 140,
                            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(14)),
                            child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 48)),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (audioUrl != null && audioUrl.isNotEmpty) ...[
                        wrapSensitive(
                          child: Container(
                            width: 190,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.white.withOpacity(0.25) : (isNightMode ? Colors.white.withOpacity(0.08) : const Color(0xFFF3F4F6)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.audiotrack, color: isMe ? Colors.white : primaryText),
                                const SizedBox(width: 10),
                                Text(
                                  "Audio adjunto",
                                  style: TextStyle(fontSize: 12.5, color: isMe ? Colors.white : primaryText, fontWeight: FontWeight.w600),
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
                          style: TextStyle(fontSize: 14, height: 1.25, color: isMe ? Colors.white : primaryText, fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                ),
                if (time.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 6, right: 6),
                    child: Text(time, style: TextStyle(fontSize: 10.5, color: timeColor, fontWeight: FontWeight.w500)),
                  ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: isNightMode ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB),
              backgroundImage: avatarProviderMe,
              child: avatarProviderMe == null
                  ? Text(
                      (myName != null && myName!.isNotEmpty) ? myName![0].toUpperCase() : "T",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isNightMode ? Colors.white : const Color(0xFF111827)),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  // ===================== ENVIAR (OFFLINE BLOQUEADO) =====================

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || _isDisposed) return;
    if (myUserId == null || comunidadId == null) return;

    // ✅ revalidar internet real antes de enviar
    if (_isOnline) {
      final ok = await _hasRealInternet();
      if (!ok) {
        await _forceOfflineFallback(showSnack: true);
        return;
      }
    }

    if (!_isOnline) {
      if (!mounted || _isDisposed) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sin internet. No se puede enviar mensajes.")),
      );
      return;
    }

    if (!_chat.isConnected) {
      _connectIfReady();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Reconectando al chat... intenta otra vez.")),
        );
      }
      return;
    }

    final bool vecinos = _selectedTab == 1;

    try {
      _chat.sendTextMessage(
        myUserId: myUserId!,
        comunidadId: comunidadId!,
        vecinos: vecinos,
        text: text,
      );

      _messageController.clear();
      if (_isNearLatest()) _scrollToLatest();
    } catch (e) {
      if (!mounted || _isDisposed) return;

      // si cayó por red, pasamos a offline
      if (_looksLikeNoInternetError(e)) {
        await _forceOfflineFallback(showSnack: true);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al enviar mensaje: $e"), backgroundColor: Colors.red),
      );
    }
  }
}

class _ChatPage {
  final List<Map<String, dynamic>> itemsNewestFirst;
  final dynamic cursorOldest;
  final bool hasMore;

  _ChatPage({
    required this.itemsNewestFirst,
    required this.cursorOldest,
    required this.hasMore,
  });
}
