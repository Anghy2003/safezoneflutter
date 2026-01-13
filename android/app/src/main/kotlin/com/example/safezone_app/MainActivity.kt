package com.example.safezone_app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val EXTRA_OPEN_QUICK_SOS = "openQuickSos"
    }

    private val CHANNEL = "safezone/background_sos"
    private var channel: MethodChannel? = null

    // ✅ Si el intent llega antes de que el channel exista, lo guardamos aquí
    private var pendingOpenQuickSos: Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingOpenQuickSos = intent?.getBooleanExtra(EXTRA_OPEN_QUICK_SOS, false) ?: false
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        // ✅ Ahora sí: el channel existe, entonces disparamos si estaba pendiente
        maybeOpenQuickSos()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingOpenQuickSos = intent.getBooleanExtra(EXTRA_OPEN_QUICK_SOS, false)

        // ✅ Si ya está listo el channel, abre el modal
        maybeOpenQuickSos()
    }

    private fun maybeOpenQuickSos() {
        if (!pendingOpenQuickSos) return
        pendingOpenQuickSos = false

        // Limpia el extra para no repetir en futuros resumes
        intent?.removeExtra(EXTRA_OPEN_QUICK_SOS)

        channel?.invokeMethod("openQuickSos", null)
    }
}
