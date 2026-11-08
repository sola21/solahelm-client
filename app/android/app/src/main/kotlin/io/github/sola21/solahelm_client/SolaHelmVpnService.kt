package io.github.sola21.solahelm_client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.IpPrefix
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import java.net.InetAddress

/**
 * Opens the TUN device for the Go core. The core gets the file descriptor and
 * reads/writes packets; Android owns addresses and routes. The app itself is
 * excluded from the VPN, so the core's own connections never loop back.
 */
class SolaHelmVpnService : VpnService() {

    companion object {
        const val ACTION_START = "io.github.sola21.solahelm.START"
        const val ACTION_STOP = "io.github.sola21.solahelm.STOP"
        const val ACTION_DISCONNECT = "io.github.sola21.solahelm.DISCONNECT"

        // Android needs a notification while a VPN runs in the background. The
        // user picks how visible it is: a normal one, or a folded one (no
        // status-bar icon, at the bottom of the shade). "vpn_quiet" can also be
        // switched off entirely in Android's settings.
        const val CHANNEL = "vpn"
        const val CHANNEL_QUIET = "vpn_quiet"
        private const val NOTIFICATION_ID = 1

        @Volatile
        var instance: SolaHelmVpnService? = null
            private set

        /** Called once the TUN is up (fd) or failed (error). */
        @Volatile
        var onStarted: ((Int?, String?) -> Unit)? = null

        // Must match engine.AndroidTunAddress / AndroidTunAddress6 in the Go core.
        private const val ADDRESS4 = "172.19.0.1"
        private const val ADDRESS6 = "fdfe:dcba:9876::1"
        private const val DNS4 = "172.19.0.2"

        fun ensureChannels(context: Context) {
            if (Build.VERSION.SDK_INT < 26) return
            val nm = context.getSystemService(NotificationManager::class.java) ?: return
            if (nm.getNotificationChannel(CHANNEL) == null) {
                nm.createNotificationChannel(
                    NotificationChannel(CHANNEL, context.getString(R.string.channel_vpn), NotificationManager.IMPORTANCE_LOW),
                )
            }
            if (nm.getNotificationChannel(CHANNEL_QUIET) == null) {
                nm.createNotificationChannel(
                    NotificationChannel(CHANNEL_QUIET, context.getString(R.string.channel_vpn_quiet), NotificationManager.IMPORTANCE_MIN)
                        .apply { setShowBadge(false) },
                )
            }
        }
    }

    private var tun: ParcelFileDescriptor? = null
    private var title = "SolaHelm"

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onDestroy() {
        closeTun()
        CoreNetwork.unwatch(this)
        instance = null
        CoreControl.changed(applicationContext, fromOutside = false)
        super.onDestroy()
    }

    override fun onRevoke() {
        // Another VPN took over, or the user turned us off in system settings.
        stopVpn()
        MainActivity.emit("vpnRevoked", null)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> stopVpn()
            ACTION_DISCONNECT -> CoreControl.stop(this)
            ACTION_START -> {
                title = intent.getStringExtra("title") ?: "SolaHelm"
                startForegroundCompat()
                val mtu = intent.getIntExtra("mtu", 1500)
                val excludeLan = intent.getBooleanExtra("excludeLan", true)
                val cb = onStarted
                onStarted = null
                try {
                    CoreNetwork.watch(this)
                    val fd = establish(mtu, excludeLan)
                    CoreControl.changed(applicationContext, fromOutside = false)
                    cb?.invoke(fd, null)
                } catch (e: Exception) {
                    stopVpn()
                    cb?.invoke(null, e.message ?: e.toString())
                }
            }
        }
        return START_NOT_STICKY
    }

    /** Takes the VPN down (the core closes the descriptor itself when it stops). */
    fun stopVpn() {
        closeTun()
        CoreNetwork.unwatch(this)
        stopForegroundCompat()
        stopSelf()
    }

    /** Re-posts the notification after the user changed how visible it should be. */
    fun refreshNotification() {
        startForegroundCompat()
    }

    private fun establish(mtu: Int, excludeLan: Boolean): Int {
        closeTun()
        val b = Builder()
            .setSession("SolaHelm")
            .setMtu(mtu)
            .addAddress(ADDRESS4, 30)
            .addAddress(ADDRESS6, 126)
            .addRoute("0.0.0.0", 0)
            .addRoute("::", 0)
            .addDnsServer(DNS4)
        try {
            b.addDisallowedApplication(packageName)
        } catch (_: Exception) {
        }
        if (excludeLan && Build.VERSION.SDK_INT >= 33) {
            for ((ip, bits) in listOf("10.0.0.0" to 8, "172.16.0.0" to 12, "192.168.0.0" to 16, "169.254.0.0" to 16)) {
                b.excludeRoute(IpPrefix(InetAddress.getByName(ip), bits))
            }
        }
        if (Build.VERSION.SDK_INT >= 29) b.setMetered(false)
        val pfd = b.establish() ?: throw IllegalStateException("VPN permission was not granted")
        tun = pfd
        // The core owns the descriptor from here on (it closes it on stop).
        return pfd.detachFd()
    }

    private fun closeTun() {
        try {
            tun?.close()
        } catch (_: Exception) {
        }
        tun = null
    }

    private fun startForegroundCompat() {
        ensureChannels(this)
        val visible = CoreControl.notificationVisible(this)
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE,
        )
        val disconnect = PendingIntent.getService(
            this, 1, Intent(this, SolaHelmVpnService::class.java).setAction(ACTION_DISCONNECT), PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(this, if (visible) CHANNEL else CHANNEL_QUIET)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this).setPriority(if (visible) Notification.PRIORITY_LOW else Notification.PRIORITY_MIN)
        }
        val n: Notification = builder
            .setSmallIcon(R.drawable.ic_chevrons)
            .setContentTitle(title)
            .setContentText(getString(R.string.vpn_connected))
            .setContentIntent(open)
            .addAction(Notification.Action.Builder(null, getString(R.string.action_disconnect), disconnect).build())
            .setOngoing(true)
            .setShowWhen(false)
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, n)
        }
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE) else @Suppress("DEPRECATION") stopForeground(true)
    }
}
