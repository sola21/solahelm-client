package io.github.sola21.solahelm_client

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.service.quicksettings.TileService
import io.github.sola21.core.mobile.Mobile
import io.github.sola21.core.mobile.Protector
import org.json.JSONObject
import java.io.File

/**
 * Starts and stops the Go core and the VPN from native code. The app's UI
 * drives it through MainActivity's channel; the quick-settings tile and the
 * notification's "Disconnect" use it without the UI, repeating the last start
 * the app made (the core keeps it, see mobile.StartLast).
 */
object CoreControl {

    private val main = Handler(Looper.getMainLooper())
    private const val PREFS = "solahelm"
    private const val KEY_NOTIFY = "notificationVisible"

    @Volatile
    var busy = false
        private set

    /** Where the app keeps the core's files; the same path the Dart side uses. */
    private fun defaultWorkDir(context: Context) = File(context.filesDir, "solahelm-client/core").path

    /** Runs the control service (once per process) and returns {addr, secret, versions}. */
    @Synchronized
    fun ensureCore(context: Context, workDir: String? = null): Map<String, String> {
        val app = context.applicationContext
        val dir = workDir ?: defaultWorkDir(app)
        File(dir).mkdirs()
        val addr = Mobile.start(dir, object : Protector {
            // The app is excluded from its own VPN, so this is a safety net only.
            override fun protect(fd: Int): Boolean = SolaHelmVpnService.instance?.protect(fd) ?: true
        })
        CoreNetwork.pushActive(app)
        Mobile.setOwnerFinder(ConnectionOwners(app))
        return mapOf("addr" to addr, "secret" to Mobile.secret(), "versions" to Mobile.versions())
    }

    fun isOn(): Boolean = SolaHelmVpnService.instance != null || Mobile.running()

    /** Opens the TUN through the VPN service; [done] gets the descriptor or an error (main thread). */
    fun openTun(context: Context, mtu: Int, excludeLan: Boolean, title: String, done: (Int?, String?) -> Unit) {
        SolaHelmVpnService.onStarted = { fd, error -> main.post { done(fd, error) } }
        val intent = Intent(context, SolaHelmVpnService::class.java)
            .setAction(SolaHelmVpnService.ACTION_START)
            .putExtra("mtu", mtu)
            .putExtra("excludeLan", excludeLan)
            .putExtra("title", title)
        try {
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
        } catch (e: Exception) {
            SolaHelmVpnService.onStarted = null
            main.post { done(null, e.message ?: e.toString()) }
        }
    }

    fun closeTun() {
        SolaHelmVpnService.instance?.stopVpn()
    }

    /**
     * Starts what the app last started (tile). [done] gets null on success,
     * [NO_LAST_START] when the app never connected, or an error message.
     */
    fun startLast(context: Context, done: (String?) -> Unit) {
        val app = context.applicationContext
        if (busy) return
        busy = true
        changed(app, fromOutside = false)
        val finish = { error: String? ->
            main.post {
                busy = false
                changed(app, fromOutside = true)
                done(error)
            }
        }
        Thread {
            try {
                ensureCore(app)
                val info = Mobile.lastStart()
                if (info.isEmpty()) {
                    finish(NO_LAST_START)
                    return@Thread
                }
                val j = JSONObject(info)
                if (j.optString("mode") == "tun") {
                    val mtu = j.optInt("mtu").takeIf { it > 0 } ?: 1500
                    main.post {
                        openTun(app, mtu, true, "SolaHelm") { fd, error ->
                            if (fd == null) {
                                finish(error ?: "VPN")
                                return@openTun
                            }
                            Thread {
                                try {
                                    Mobile.startLast(fd)
                                    finish(null)
                                } catch (e: Exception) {
                                    main.post { closeTun() }
                                    finish(e.message ?: e.toString())
                                }
                            }.start()
                        }
                    }
                } else {
                    Mobile.startLast(0)
                    finish(null)
                }
            } catch (e: Exception) {
                finish(e.message ?: e.toString())
            }
        }.start()
    }

    /** Stops the core and the VPN (tile, notification). */
    fun stop(context: Context) {
        val app = context.applicationContext
        if (busy) return
        busy = true
        changed(app, fromOutside = false)
        Thread {
            try {
                Mobile.stopCore()
            } catch (_: Exception) {
            }
            main.post {
                closeTun()
                busy = false
                changed(app, fromOutside = true)
            }
        }.start()
    }

    /**
     * Something changed the connection: refresh the tile, and when it wasn't
     * the app's own UI, tell the UI so it shows the right state.
     */
    fun changed(context: Context, fromOutside: Boolean) {
        main.post { VpnTileService.visible?.render() }
        try {
            TileService.requestListeningState(context, ComponentName(context, VpnTileService::class.java))
        } catch (_: Exception) {
        }
        if (fromOutside) MainActivity.emit("coreChanged", null)
    }

    // ---- the "VPN is running" notification ----

    fun notificationVisible(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_NOTIFY, true)

    fun setNotificationVisible(context: Context, visible: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_NOTIFY, visible).apply()
        SolaHelmVpnService.instance?.refreshNotification()
    }

    const val NO_LAST_START = "no-last-start"
}
