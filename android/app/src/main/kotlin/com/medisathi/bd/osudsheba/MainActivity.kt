package com.medisathi.bd.osudsheba

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Reminders arrive as high-priority alarm notifications. The app no longer shows itself over
// the lock screen or wakes the screen (no full-screen intent, Play policy), so medicine data is
// only visible after the phone is unlocked.
class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.medisathi.bd.osudsheba/alarm"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
    }

    // Tapping a reminder while the app is open: pass its payload to Flutter so the
    // alarm screen opens for that dose.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val payload = intent.getStringExtra("payload")
            ?: intent.getStringExtra("notification_payload")
            ?: intent.dataString

        if (payload != null && payload.isNotEmpty()) {
            methodChannel?.invokeMethod("onAlarmReceived", payload)
        }
    }
}
