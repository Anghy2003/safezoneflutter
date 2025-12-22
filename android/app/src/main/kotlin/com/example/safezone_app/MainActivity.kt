package com.example.safezone_app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    // MISMO canal que en Flutter y VolumeService
    private val CHANNEL = "safezone/background_sos"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVolumeService" -> {
                    startVolumeService()
                    result.success(null)
                }
                "stopVolumeService" -> {
                    stopVolumeService()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startVolumeService() {
        val intent = Intent(this, VolumeService::class.java)

        // ✅ Ya NO usamos startForegroundService
        startService(intent)
    }

    private fun stopVolumeService() {
        val intent = Intent(this, VolumeService::class.java)
        stopService(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Aquí luego puedes leer extras como "open_sos" si quieres
    }
}
