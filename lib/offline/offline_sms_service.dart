// lib/offline/offline_sms_service.dart
import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:another_telephony/telephony.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

enum SmsPrecheckFail {
  notAndroid,
  noPhones,
  permissionDenied,
  notCapable,
}

enum SmsAttemptOutcome {
  sentConfirmed,
  sentAssumed,
  failedByStatus,
  failedByException,
  skippedInvalid,
  fallbackOpened, // ✅ abrió app SMS como alternativa
}

class SmsAttempt {
  final String input;
  final List<String> tried;
  final SmsAttemptOutcome outcome;
  final String? detail;

  const SmsAttempt({
    required this.input,
    required this.tried,
    required this.outcome,
    this.detail,
  });
}

class SmsBulkResult {
  final bool anyOk;
  final SmsPrecheckFail? precheckFail;
  final bool? permissionGranted;
  final bool? smsCapable;
  final List<SmsAttempt> attempts;

  const SmsBulkResult({
    required this.anyOk,
    required this.precheckFail,
    required this.permissionGranted,
    required this.smsCapable,
    required this.attempts,
  });

  String uiMessage() {
    if (precheckFail != null) {
      switch (precheckFail!) {
        case SmsPrecheckFail.notAndroid:
          return "Envío directo de SMS solo funciona en Android.";
        case SmsPrecheckFail.noPhones:
          return "No hay números válidos para enviar SMS.";
        case SmsPrecheckFail.permissionDenied:
          return "Permiso SMS denegado. Actívalo en Ajustes > Apps > SafeZone > Permisos.";
        case SmsPrecheckFail.notCapable:
          return "Este dispositivo no permite enviar SMS (sin SIM / sin servicio / no SMS-capable).";
      }
    }

    final fallback = attempts.where((a) => a.outcome == SmsAttemptOutcome.fallbackOpened).toList();
    if (fallback.isNotEmpty) {
      return "Tu Android bloqueó el envío directo. Se abrió la app de SMS con el mensaje listo.";
    }

    final failedByException = attempts.where((a) => a.outcome == SmsAttemptOutcome.failedByException).toList();
    if (failedByException.isNotEmpty) {
      final d = failedByException.first.detail ?? "Excepción desconocida";
      return "Fallo enviando SMS: $d";
    }

    final failedByStatus = attempts.where((a) => a.outcome == SmsAttemptOutcome.failedByStatus).toList();
    if (failedByStatus.isNotEmpty) {
      final d = failedByStatus.first.detail ?? "Estado de envío fallido";
      return "Operador/OEM rechazó el envío: $d";
    }

    final invalids = attempts.where((a) => a.outcome == SmsAttemptOutcome.skippedInvalid).length;
    if (invalids == attempts.length && attempts.isNotEmpty) {
      return "Todos los números son inválidos o incompletos.";
    }

    return anyOk ? "SMS enviado (o intentado) correctamente." : "No se pudo enviar el SMS.";
  }

  String debugSummary() {
    final b = StringBuffer();
    b.writeln("anyOk=$anyOk precheckFail=$precheckFail permissionGranted=$permissionGranted smsCapable=$smsCapable");
    for (final a in attempts) {
      b.writeln("- input=${a.input} tried=${a.tried} outcome=${a.outcome} detail=${a.detail}");
    }
    return b.toString();
  }
}

class OfflineSmsService {
  OfflineSmsService();

  final Telephony _telephony = Telephony.instance;

  Future<bool> sendSmsToMany({
    required List<String> phones,
    required String message,
  }) async {
    final r = await sendSmsToManyDetailed(phones: phones, message: message);
    return r.anyOk;
  }

  Future<SmsBulkResult> sendSmsToManyDetailed({
    required List<String> phones,
    required String message,
  }) async {
    if (!Platform.isAndroid) {
      dev.log("OfflineSmsService: notAndroid");
      return const SmsBulkResult(
        anyOk: false,
        precheckFail: SmsPrecheckFail.notAndroid,
        permissionGranted: null,
        smsCapable: null,
        attempts: [],
      );
    }

    final cleaned = phones
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    if (cleaned.isEmpty) {
      dev.log("OfflineSmsService: noPhones");
      return const SmsBulkResult(
        anyOk: false,
        precheckFail: SmsPrecheckFail.noPhones,
        permissionGranted: null,
        smsCapable: null,
        attempts: [],
      );
    }

    // ✅ Permisos runtime
    bool? granted;
    try {
      // algunos OEM fallan con requestSmsPermissions solo, por eso usamos phone+sms
      granted = await _telephony.requestPhoneAndSmsPermissions;
    } catch (e) {
      dev.log("OfflineSmsService: requestPhoneAndSmsPermissions exception => $e");
      granted = false;
    }

    dev.log("OfflineSmsService: permissions => $granted");

    if (granted != true) {
      return SmsBulkResult(
        anyOk: false,
        precheckFail: SmsPrecheckFail.permissionDenied,
        permissionGranted: granted,
        smsCapable: null,
        attempts: const [],
      );
    }

    // ✅ Capacidad real
    bool canSend = false;
    try {
      canSend = (await _telephony.isSmsCapable) ?? false;
    } catch (e) {
      dev.log("OfflineSmsService: isSmsCapable exception => $e");
      canSend = false;
    }
    dev.log("OfflineSmsService: isSmsCapable => $canSend");

    if (!canSend) {
      return SmsBulkResult(
        anyOk: false,
        precheckFail: SmsPrecheckFail.notCapable,
        permissionGranted: granted,
        smsCapable: canSend,
        attempts: const [],
      );
    }

    final attempts = <SmsAttempt>[];
    bool anyOk = false;

    for (final raw in cleaned) {
      final variants = normalizarE164EcuadorVariantes(raw);

      if (variants.isEmpty) {
        attempts.add(SmsAttempt(
          input: raw,
          tried: const [],
          outcome: SmsAttemptOutcome.skippedInvalid,
          detail: "Número inválido / incompleto",
        ));
        continue;
      }

      bool sentThis = false;

      // Intentar envío directo por cada variante
      for (final to in variants) {
        final r = await _sendOneAttemptRobust(to: to, message: message);

        attempts.add(SmsAttempt(
          input: raw,
          tried: [to],
          outcome: r.$1,
          detail: r.$2,
        ));

        if (r.$1 == SmsAttemptOutcome.sentConfirmed ||
            r.$1 == SmsAttemptOutcome.sentAssumed) {
          anyOk = true;
          sentThis = true;
          break;
        }

        // ✅ Caso clave: SmsManager null -> fallback
        final detail = (r.$2 ?? "").toLowerCase();
        if (detail.contains("smsmanager") || detail.contains("failed_to_fetch_sms")) {
          final okFallback = await _openSmsAppFallback(
            phones: variants,
            message: message,
          );
          if (okFallback) {
            attempts.add(SmsAttempt(
              input: raw,
              tried: variants,
              outcome: SmsAttemptOutcome.fallbackOpened,
              detail: "Android bloqueó SMS directo: se abrió app SMS",
            ));
            anyOk = true; // consideramos “resuelto” porque el usuario puede enviar
            sentThis = true;
            break;
          }
        }
      }

      if (sentThis) {
        await Future.delayed(const Duration(milliseconds: 250));
      }
    }

    final result = SmsBulkResult(
      anyOk: anyOk,
      precheckFail: null,
      permissionGranted: granted,
      smsCapable: canSend,
      attempts: attempts,
    );

    dev.log("OfflineSmsService RESULT:\n${result.debugSummary()}");
    return result;
  }

  Future<(SmsAttemptOutcome, String?)> _sendOneAttemptRobust({
    required String to,
    required String message,
  }) async {
    final completer = Completer<(SmsAttemptOutcome, String?)>();

    final watchdog = Timer(const Duration(seconds: 2), () {
      if (!completer.isCompleted) {
        // OEMs que no reportan statusListener
        completer.complete((SmsAttemptOutcome.sentAssumed, "Sin callback de estado (OEM/operador)"));
      }
    });

    try {
      dev.log("OfflineSmsService: sendSms to=$to multipart=${_shouldMultipart(message)}");

      await _telephony.sendSms(
        to: to,
        message: message,
        isMultipart: _shouldMultipart(message),
        statusListener: (status) {
          final s = _statusName(status);
          dev.log("OfflineSmsService: status($to) => $s");
          if (completer.isCompleted) return;

          if (s == 'SENT') {
            completer.complete((SmsAttemptOutcome.sentConfirmed, "SENT"));
            return;
          }
          if (s == 'FAILED' || s == 'FAILURE' || s == 'ERROR' || s == 'UNDELIVERABLE') {
            completer.complete((SmsAttemptOutcome.failedByStatus, s));
            return;
          }
        },
      );
    } on PlatformException catch (e) {
      // ✅ aquí cae tu error "Error getting SmsManager"
      final msg = "${e.code}: ${e.message}";
      dev.log("OfflineSmsService: PlatformException => $msg");
      if (!completer.isCompleted) {
        completer.complete((SmsAttemptOutcome.failedByException, msg));
      }
    } catch (e) {
      dev.log("OfflineSmsService: exception => $e");
      if (!completer.isCompleted) {
        completer.complete((SmsAttemptOutcome.failedByException, e.toString()));
      }
    }

    final out = await completer.future;
    watchdog.cancel();
    return out;
  }

  bool _shouldMultipart(String message) {
    final hasUnicode = message.runes.any((c) => c > 127);
    final limit = hasUnicode ? 70 : 160;
    return message.length > limit;
  }

  String _statusName(dynamic status) {
    try {
      final String? n = (status as dynamic).name as String?;
      if (n != null && n.isNotEmpty) return n.toUpperCase();
    } catch (_) {}
    final s = status.toString();
    final last = s.contains('.') ? s.split('.').last : s;
    return last.toUpperCase();
  }

  // ✅ Fallback: abre app SMS con el mensaje listo (no depende de SmsManager del plugin)
  Future<bool> _openSmsAppFallback({
    required List<String> phones,
    required String message,
  }) async {
    try {
      final recipients = phones
          .map((p) => p.replaceAll(RegExp(r'[^\d\+]'), ''))
          .where((p) => p.isNotEmpty)
          .toSet()
          .toList();

      if (recipients.isEmpty) return false;

      // Android acepta separados por ';'
      final to = recipients.join(';');
      final uri = Uri.parse('sms:$to?body=${Uri.encodeComponent(message)}');

      final ok = await canLaunchUrl(uri);
      if (!ok) return false;

      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      dev.log("OfflineSmsService: fallback launch error => $e");
      return false;
    }
  }

  List<String> normalizarE164EcuadorVariantes(String input) {
    final v = normalizarE164Ecuador(input);
    if (v == null) return const [];
    if (v.startsWith('+')) return [v, v.substring(1)];
    return [v];
  }

  String? normalizarE164Ecuador(String input) {
    var p = input.trim();
    if (p.isEmpty) return null;

    p = p.replaceAll(RegExp(r'[^\d\+]'), '');

    if (p.startsWith('+593')) return p;
    if (p.startsWith('593')) return '+$p';

    if (RegExp(r'^09\d{8}$').hasMatch(p)) return '+593${p.substring(1)}';
    if (RegExp(r'^9\d{8}$').hasMatch(p)) return '+593$p';

    if (RegExp(r'^0[2-7]\d{7}$').hasMatch(p)) return '+593${p.substring(1)}';

    if (RegExp(r'^\+?\d+$').hasMatch(p)) return p;

    return null;
  }
}
