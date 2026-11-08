package io.github.sola21.solahelm_client

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * "solahelm/android" channel:
 *  coreStart(workDir) -> {addr, secret}  runs the Go control daemon in this process
 *  vpnStart({mtu, excludeLan, title}) -> fd  asks for the VPN permission if needed, opens the TUN
 *  vpnStop()
 *  setNotificationVisible({visible}), openNotificationSettings()
 * and events back to Dart: vpnRevoked, coreChanged (the tile or the
 * notification turned the VPN on or off).
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "solahelm/android"
        private const val REQ_VPN = 1001
        private const val REQ_NOTIFY = 1002
        private var channel: MethodChannel? = null
        private val main = Handler(Looper.getMainLooper())

        fun emit(method: String, args: Any?) {
            main.post { channel?.invokeMethod(method, args) }
        }
    }

    private var pendingVpn: MethodChannel.Result? = null
    private var pendingArgs: Map<*, *>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "coreStart" -> {
                    try {
                        result.success(CoreControl.ensureCore(this, call.argument<String>("workDir")))
                    } catch (e: Exception) {
                        result.error("core", e.message, null)
                    }
                }
                "vpnStart" -> {
                    if (pendingVpn != null) {
                        result.error("busy", "VPN start already in progress", null)
                        return@setMethodCallHandler
                    }
                    pendingVpn = result
                    pendingArgs = call.arguments as? Map<*, *>
                    askNotificationPermission()
                    val prepare = VpnService.prepare(this)
                    if (prepare != null) {
                        @Suppress("DEPRECATION")
                        startActivityForResult(prepare, REQ_VPN)
                    } else {
                        startVpnService()
                    }
                }
                "vpnStop" -> {
                    CoreControl.closeTun()
                    result.success(null)
                }
                "vpnRunning" -> result.success(SolaHelmVpnService.instance != null)
                "setNotificationVisible" -> {
                    CoreControl.setNotificationVisible(this, call.argument<Boolean>("visible") ?: true)
                    result.success(null)
                }
                "openNotificationSettings" -> {
                    openNotificationSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun askNotificationPermission() {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ_NOTIFY)
        }
    }

    /** Android's page for the folded notification, where it can be switched off entirely. */
    private fun openNotificationSettings() {
        SolaHelmVpnService.ensureChannels(this)
        val intent = if (Build.VERSION.SDK_INT >= 26) {
            Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                .putExtra(Settings.EXTRA_CHANNEL_ID, SolaHelmVpnService.CHANNEL_QUIET)
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).setData(android.net.Uri.fromParts("package", packageName, null))
        }
        try {
            startActivity(intent)
        } catch (_: Exception) {
        }
    }

    private fun startVpnService() {
        val result = pendingVpn ?: return
        val args = pendingArgs
        pendingVpn = null
        pendingArgs = null
        CoreControl.openTun(
            this,
            (args?.get("mtu") as? Int) ?: 1500,
            (args?.get("excludeLan") as? Boolean) ?: true,
            (args?.get("title") as? String) ?: "SolaHelm",
        ) { fd, error ->
            if (fd != null) result.success(fd) else result.error("vpn", error, null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_VPN) return
        if (resultCode == RESULT_OK) {
            startVpnService()
        } else {
            pendingVpn?.error("vpn-denied", "VPN permission was not granted", null)
            pendingVpn = null
            pendingArgs = null
        }
    }
}
