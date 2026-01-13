import 'package:hive/hive.dart';
import '../models/contacto_emergencia.dart';

class EmergencyContactsCache {
  EmergencyContactsCache._();
  static final EmergencyContactsCache instance = EmergencyContactsCache._();

  static const String _boxName = "emergency_contacts_cache";

  // ✅ nuevo: contactos completos
  static const String _keyContacts = "contacts";

  // ✅ legacy: por si antes guardaste solo phones
  static const String _keyPhonesLegacy = "phones";

  static const int maxContacts = 5;

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;

    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    _ready = true;

    // ✅ migración simple: si hay phones legacy y no hay contacts, crea contacts básicos
    final existingContacts = _box.get(_keyContacts);
    final legacyPhones = _box.get(_keyPhonesLegacy);

    final hasContacts = existingContacts is List && existingContacts.isNotEmpty;
    final hasLegacyPhones = legacyPhones is List && legacyPhones.isNotEmpty;

    if (!hasContacts && hasLegacyPhones) {
      final phones = legacyPhones
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();

      final mapped = phones.take(maxContacts).map((p) {
        return {
          "id": null,
          "usuarioId": 0,
          "nombre": "Contacto (Offline)",
          "telefono": p,
          "relacion": null,
          "prioridad": 1,
          "activo": true,
          "fechaAgregadoMillis": DateTime.now().millisecondsSinceEpoch,
          "fotoUrl": null,
        };
      }).toList();

      await _box.put(_keyContacts, mapped);
    }
  }

  Box get _box => Hive.box(_boxName);

  // =========================
  // ✅ CONTACTOS COMPLETOS
  // =========================

  List<ContactoEmergencia> getContacts() {
    // ✅ defensa: si no han llamado init()
    if (!Hive.isBoxOpen(_boxName)) return <ContactoEmergencia>[];

    final v = _box.get(_keyContacts);
    if (v is! List) return <ContactoEmergencia>[];

    final out = <ContactoEmergencia>[];
    for (final item in v) {
      if (item is Map) {
        out.add(_mapToContact(Map<String, dynamic>.from(item)));
      }
    }

    // Orden DESC por fecha (robusto)
    out.sort((a, b) {
      final ams = _millisOf(_safeFecha(a));
      final bms = _millisOf(_safeFecha(b));
      return bms.compareTo(ams);
    });

    return out;
  }

  Future<void> saveContacts(List<ContactoEmergencia> contacts) async {
    await init();

    final cleaned = _dedupeAndLimit(contacts, maxContacts);
    final mapped = cleaned.map(_contactToMap).toList();

    await _box.put(_keyContacts, mapped);

    // opcional: mantener legacy phones actualizado
    await _box.put(
      _keyPhonesLegacy,
      cleaned.map((c) => c.telefono.trim()).where((p) => p.isNotEmpty).toList(),
    );
  }

  /// Upsert por teléfono (clave práctica).
  /// Retorna false si no se pudo insertar por límite (maxContacts) y era un nuevo.
  Future<bool> upsertContact(ContactoEmergencia c) async {
    await init();

    final phoneKey = c.telefono.trim();
    if (phoneKey.isEmpty) return false;

    final current = getContacts();
    final idx = current.indexWhere((e) => e.telefono.trim() == phoneKey);

    if (idx >= 0) {
      current[idx] = c;
      await saveContacts(current);
      return true;
    }

    if (current.length >= maxContacts) return false;

    await saveContacts([...current, c]);
    return true;
  }

  Future<void> removeByPhone(String phone) async {
    await init();

    final p = phone.trim();
    if (p.isEmpty) return;

    final current = getContacts();
    current.removeWhere((e) => e.telefono.trim() == p);
    await saveContacts(current);
  }

  Future<void> clear() async {
    await init();
    await _box.delete(_keyContacts);
    await _box.delete(_keyPhonesLegacy);
  }

  // =========================
  // ✅ PHONES (para SMS offline)
  // =========================

  List<String> getPhones() {
    if (!Hive.isBoxOpen(_boxName)) return <String>[];

    final contacts = getContacts();
    if (contacts.isNotEmpty) {
      return contacts
          .map((c) => c.telefono.trim())
          .where((p) => p.isNotEmpty)
          .toSet()
          .toList();
    }

    // fallback legacy
    final v = _box.get(_keyPhonesLegacy);
    if (v is List) {
      return v
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    }
    return <String>[];
  }

  // =========================
  // Helpers robustos
  // =========================

  dynamic _safeFecha(ContactoEmergencia c) {
    try {
      // ignore: invalid_use_of_protected_member
      return (c as dynamic).fechaAgregado;
    } catch (_) {
      return null;
    }
  }

  int _millisOf(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is DateTime) return v.millisecondsSinceEpoch;

    if (v is String) {
      final dt = DateTime.tryParse(v);
      if (dt != null) return dt.millisecondsSinceEpoch;
    }
    return 0;
  }

  DateTime _dateFromMillis(dynamic v) {
    final ms = _millisOf(v);
    if (ms <= 0) return DateTime.now();
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  List<ContactoEmergencia> _dedupeAndLimit(
    List<ContactoEmergencia> input,
    int limit,
  ) {
    // dedupe por teléfono
    final map = <String, ContactoEmergencia>{};

    for (final c in input) {
      final key = c.telefono.trim();
      if (key.isEmpty) continue;
      map[key] = c;
    }

    final list = map.values.toList();

    // Orden DESC por fecha (robusto)
    list.sort((a, b) {
      final ams = _millisOf(_safeFecha(a));
      final bms = _millisOf(_safeFecha(b));
      return bms.compareTo(ams);
    });

    return list.take(limit).toList();
  }

  Map<String, dynamic> _contactToMap(ContactoEmergencia c) {
    return {
      "id": c.id,
      "usuarioId": c.usuarioId,
      "nombre": c.nombre,
      "telefono": c.telefono,
      "relacion": c.relacion,
      "prioridad": c.prioridad,
      "activo": c.activo,
      "fechaAgregadoMillis": _millisOf(_safeFecha(c)),
      "fotoUrl": c.fotoUrl,
    };
  }

  ContactoEmergencia _mapToContact(Map<String, dynamic> m) {
    return ContactoEmergencia(
      id: m["id"] as int?,
      usuarioId: (m["usuarioId"] as int?) ?? 0,
      nombre: (m["nombre"] as String?) ?? "Contacto",
      telefono: (m["telefono"] as String?) ?? "",
      relacion: m["relacion"] as String?,
      prioridad: (m["prioridad"] as int?) ?? 1,
      activo: (m["activo"] as bool?) ?? true,
      fechaAgregado: _dateFromMillis(m["fechaAgregadoMillis"]),
      fotoUrl: m["fotoUrl"] as String?,
    );
  }
}
