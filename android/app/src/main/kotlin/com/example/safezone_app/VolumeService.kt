package com.example.safezone_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.database.ContentObserver
import android.media.AudioManager
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs

class VolumeService : Service() {

    private val CHANNEL_ID = "safezone_sos_channel"
    private val METHOD_CHANNEL = "safezone/background_sos"

    private var flutterEngine: FlutterEngine? = null
    private var methodChannel: MethodChannel? = null

    private var lastVolume = -1
    private var pressCount = 0

    override fun onCreate() {
        super.onCreate()
        Log.d("VolumeService", "✅ Servicio creado")

        createNotificationChannel()
        initFlutterEngine()
        startListeningVolume()

        Log.d("VolumeService", "🚀 Servicio escuchando botón de volumen")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        flutterEngine?.destroy()
        Log.d("VolumeService", "🛑 Servicio destruido")
    }

    private fun initFlutterEngine() {
        flutterEngine = FlutterEngine(this).apply {
            dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )
        }

        methodChannel = MethodChannel(
            flutterEngine!!.dartExecutor.binaryMessenger,
            METHOD_CHANNEL
        )

        Log.d("VolumeService", "📡 Canal conectado con Flutter (MethodChannel: $METHOD_CHANNEL)")
    }

    private fun startListeningVolume() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        lastVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)

        contentResolver.registerContentObserver(
            Settings.System.CONTENT_URI,
            true,
            object : ContentObserver(Handler(Looper.getMainLooper())) {
                override fun onChange(selfChange: Boolean) {
                    super.onChange(selfChange)
                    val current = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)

                    if (current != lastVolume) {
                        val diff = abs(current - lastVolume)

                        Log.d(
                            "VolumeService",
                            "📢 Cambio de volumen detectado ($lastVolume → $current), pasos=$diff"
                        )

                        repeat(diff) { step ->
                            Log.d("VolumeService", "   ↪️ Paso ${step + 1} de $diff")
                            onVolumeStep()
                        }

                        lastVolume = current
                    }
                }
            }
        )

        Log.d("VolumeService", "👀 Observando cambios de volumen del sistema")
    }

    private fun onVolumeStep() {
        pressCount++
        Log.d("VolumeService", "👉 Pulsación de volumen detectada: #$pressCount")

        if (pressCount >= 3) {
            Log.d("VolumeService", "🚨 *** SOS ACTIVADO POR BOTÓN FÍSICO ***")

            vibrarSOS()
            showSosNotification()
            triggerSOSFromNative()

            pressCount = 0
        }
    }

    private fun triggerSOSFromNative() {
        Log.d("VolumeService", "📩 Enviando evento 'onHardwareSOS' a Flutter...")
        methodChannel?.invokeMethod("onHardwareSOS", null)
    }

    // 📳 Vibración cuando se active el SOS
    private fun vibrarSOS() {
        try {
            val vibratorManager =
                getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? android.os.VibratorManager
            val vibrator =
                vibratorManager?.defaultVibrator ?: getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator

            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                vibrator.vibrate(
                    android.os.VibrationEffect.createOneShot(
                        600,
                        android.os.VibrationEffect.DEFAULT_AMPLITUDE
                    )
                )
            } else {
                vibrator.vibrate(600)
            }

            Log.d("VolumeService", "📳 Vibración SOS ejecutada")

        } catch (e: Exception) {
            Log.e("VolumeService", "❌ Error al vibrar: $e")
        }
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "SafeZone SOS",
            NotificationManager.IMPORTANCE_LOW
        )
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(channel)
    }

    private fun showSosNotification() {
        Log.d("VolumeService", "🧨 Mostrando notificación de SOS")

        val sosIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("open_sos", true)
        }

        val sosPendingIntent = PendingIntent.getActivity(
            this, 99, sosIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("🚨 SOS enviado")
            .setContentText("Se detectó un botón de emergencia físico.")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setAutoCancel(true)
            .setContentIntent(sosPendingIntent)
            .build()

        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(99, notification)
    }
}
