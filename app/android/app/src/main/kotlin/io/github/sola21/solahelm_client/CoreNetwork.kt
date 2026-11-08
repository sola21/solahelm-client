package io.github.sola21.solahelm_client

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.github.sola21.core.mobile.Mobile
import java.net.NetworkInterface

/**
 * Tells the Go core about the device's real (non-VPN) network: its DNS
 * servers (mihomo's "system" DNS, sing-box's "local" DNS) and its interface
 * (sing-box's default interface).
 *
 * The default-network callback can't be used for this: for the VPN owner it
 * reports the VPN itself once the tunnel is up. So, like sing-box's own app,
 * this follows the best network that has Internet access and isn't a VPN.
 */
object CoreNetwork {

    private var callback: ConnectivityManager.NetworkCallback? = null
    private var current: Network? = null

    /** One-shot update (core start): the active network, unless it's a VPN. */
    fun pushActive(context: Context) {
        val cm = context.getSystemService(ConnectivityManager::class.java) ?: return
        val net = cm.activeNetwork ?: return
        if (cm.getNetworkCapabilities(net)?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true) return
        push(cm.getLinkProperties(net))
    }

    fun watch(context: Context) {
        if (callback != null) return
        val cm = context.getSystemService(ConnectivityManager::class.java) ?: return
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
            .build()
        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                current = network
                push(cm.getLinkProperties(network))
            }

            override fun onLinkPropertiesChanged(network: Network, lp: LinkProperties) {
                if (network == current) push(lp)
            }

            override fun onLost(network: Network) {
                if (network == current) {
                    current = null
                    lost()
                }
            }
        }
        try {
            val handler = Handler(Looper.getMainLooper())
            if (Build.VERSION.SDK_INT >= 31) {
                cm.registerBestMatchingNetworkCallback(request, cb, handler)
            } else {
                cm.requestNetwork(request, cb, handler)
            }
            callback = cb
        } catch (_: Exception) {
        }
    }

    fun unwatch(context: Context) {
        val cb = callback ?: return
        callback = null
        current = null
        try {
            context.getSystemService(ConnectivityManager::class.java)?.unregisterNetworkCallback(cb)
        } catch (_: Exception) {
        }
    }

    private fun push(lp: LinkProperties?) {
        try {
            if (lp == null) return
            val dns = lp.dnsServers.mapNotNull { it.hostAddress?.substringBefore('%') }
            if (dns.isNotEmpty()) Mobile.setSystemDNS(dns.joinToString(","))
            val name = lp.interfaceName
            val index = try {
                if (name == null) -1 else NetworkInterface.getByName(name)?.index ?: -1
            } catch (_: Exception) {
                -1
            }
            Mobile.setDefaultNetwork(name ?: "", index)
        } catch (_: Throwable) {
        }
    }

    private fun lost() {
        try {
            Mobile.setDefaultNetwork("", -1)
        } catch (_: Throwable) {
        }
    }
}
