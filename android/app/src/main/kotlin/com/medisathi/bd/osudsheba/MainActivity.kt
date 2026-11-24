package com.medisathi.bd.osudsheba

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Medicine alarms. With "Full-screen alarm" chosen in Reminder settings, Android opens this
// activity from the alarm (full-screen intent). Only then may it show over the lock screen and
// wake the screen; the alarm screen turns that off again when it closes ("clearLockScreen"),
// so medicine data is otherwise only visible after the phone is unlocked.
class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.medisathi.bd.osudsheba/alarm"
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showOverLockScreenIfAlarm(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "clearLockScreen" -> {
                        setLockScreenFlags(false)
                        result.success(null)
                    }
                    // Android 14+: has the user allowed full-screen alarms for this app?
                    "canUseFullScreen" -> {
                        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        result.success(
                            Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE || nm.canUseFullScreenIntent()
                        )
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    // Tapping a reminder (or the alarm opening) while the app is running: pass its payload
    // to Flutter so the alarm screen opens for that dose.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        showOverLockScreenIfAlarm(intent)

        val payload = intent.getStringExtra("payload")
            ?: intent.getStringExtra("notification_payload")
            ?: intent.dataString

        if (payload != null && payload.isNotEmpty()) {
            methodChannel?.invokeMethod("onAlarmReceived", payload)
        }
    }

    /** flutter_local_notifications opens the app with this action for alarms and taps. */
    private fun showOverLockScreenIfAlarm(intent: Intent?) {
        if (intent?.action == "SELECT_NOTIFICATION") setLockScreenFlags(true)
    }

    private fun setLockScreenFlags(on: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(on)
            setTurnScreenOn(on)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (on) window.addFlags(flags) else window.clearFlags(flags)
        }
    }
}
