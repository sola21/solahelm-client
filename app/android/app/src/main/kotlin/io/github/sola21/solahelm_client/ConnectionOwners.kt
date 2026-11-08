package io.github.sola21.solahelm_client

import android.content.Context
import android.net.ConnectivityManager
import android.os.Build
import io.github.sola21.core.mobile.OwnerFinder
import java.net.InetAddress
import java.net.InetSocketAddress

/**
 * Which app a TUN connection belongs to, for the connections list. Only the
 * active VPN app may ask (Android 10+). Answers "uid<TAB>pkg1,pkg2" or "".
 */
class ConnectionOwners(private val context: Context) : OwnerFinder {

    override fun findOwner(proto: Int, srcIP: String, srcPort: Int, dstIP: String, dstPort: Int): String {
        if (Build.VERSION.SDK_INT < 29) return ""
        return try {
            val cm = context.getSystemService(ConnectivityManager::class.java) ?: return ""
            val uid = cm.getConnectionOwnerUid(
                proto,
                InetSocketAddress(InetAddress.getByName(srcIP), srcPort),
                InetSocketAddress(InetAddress.getByName(dstIP), dstPort),
            )
            if (uid < 0) return ""
            val packages = context.packageManager.getPackagesForUid(uid)?.joinToString(",").orEmpty()
            "$uid\t$packages"
        } catch (_: Exception) {
            ""
        }
    }
}
