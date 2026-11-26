package com.medisathi.bd.osudsheba

import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Medicine alarms over the lock screen.
//
// Android decides whether this activity may appear over the lock screen when the alarm starts
// it, from the activity's CURRENT "show when locked" state (the manifest value, or the last
// one set in code, which Android keeps even after the app process is killed). Turning it on
// only once the alarm has arrived is too late: the alarm was hidden and appeared after unlock.
//
// So the activity is always ready for an alarm while it is NOT on screen, and never shows
// over the lock screen otherwise:
//  - in use (not an alarm): "show when locked" off, so a locked phone never reveals it;
//  - left with the phone unlocked (Home, another app): turned on; something else is on top;
//  - screen turned off with the app open: the app steps behind the home screen (its place is
//    kept), then turned on; on wake the lock screen shows over Home, not over the app;
//  - an alarm arrives: shown over the lock screen; when the alarm closes on a locked phone,
//    the app steps back again.
class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.medisathi.bd.osudsheba/alarm"
    private var methodChannel: MethodChannel? = null

    /** A dose alarm (or a reminder tapped) opened the app and is still on screen. */
    private var alarmShowing = false

    /** An alarm that arrived before Flutter was listening; Flutter collects it at start. */
    private var pendingAlarmPayload: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        alarmShowing = isAlarm(intent)
        if (alarmShowing) setLockScreenFlags(true)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    // The alarm screen closed.
                    "clearLockScreen" -> {
                        alarmShowing = false
                        if (isLocked()) stepBehindLockScreen() else setLockScreenFlags(false)
                        result.success(null)
                    }
                    // An alarm that arrived while Flutter was still starting (null if none).
                    "takePendingAlarm" -> {
                        result.success(pendingAlarmPayload)
                        pendingAlarmPayload = null
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

    // The alarm (or a reminder tap) while the activity exists: pass its payload to Flutter so
    // the alarm screen opens for that dose. Also kept, in case Flutter is not listening yet
    // (the app process was restarted for this alarm): Flutter then takes it when it starts.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (isAlarm(intent)) {
            alarmShowing = true
            setLockScreenFlags(true)
        }

        val payload = intent.getStringExtra("payload")
            ?: intent.getStringExtra("notification_payload")
            ?: intent.dataString

        if (payload != null && payload.isNotEmpty()) {
            if (isAlarm(intent)) pendingAlarmPayload = payload
            methodChannel?.invokeMethod("onAlarmReceived", payload, object : MethodChannel.Result {
                // Flutter received it: no need to keep it (or it would reopen on next start).
                override fun success(result: Any?) {
                    if (pendingAlarmPayload == payload) pendingAlarmPayload = null
                }
                override fun error(code: String, message: String?, details: Any?) {}
                override fun notImplemented() {}
            })
        }
    }

    override fun onResume() {
        super.onResume()
        // In use, not as an alarm: never shown over the lock screen.
        if (!alarmShowing) setLockScreenFlags(false)
    }

    override fun onStop() {
        super.onStop()
        if (isFinishing || alarmShowing) return
        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (power.isInteractive && !isLocked()) {
            // Left normally: something else is on top, so this exposes nothing.
            setLockScreenFlags(true)
        } else {
            // Screen turned off with the app open.
            stepBehindLockScreen()
        }
    }

    /** Moves the app behind the home screen (its screens are kept) and readies it for alarms. */
    private fun stepBehindLockScreen() {
        moveTaskToBack(true)
        setLockScreenFlags(true)
    }

    private fun isLocked(): Boolean =
        (getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager).isKeyguardLocked

    /** flutter_local_notifications opens the app with this action for alarms and reminder taps. */
    private fun isAlarm(intent: Intent?) = intent?.action == "SELECT_NOTIFICATION"

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
