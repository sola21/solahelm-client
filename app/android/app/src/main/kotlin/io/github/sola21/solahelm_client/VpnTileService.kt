package io.github.sola21.solahelm_client

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Intent
import android.graphics.drawable.Icon
import android.net.VpnService
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.widget.Toast

/** Quick-settings tile: turns the VPN on (repeating the app's last start) and off. */
class VpnTileService : TileService() {

    companion object {
        /** The tile while the shade shows it; it must be redrawn directly then. */
        @Volatile
        var visible: VpnTileService? = null
            private set
    }

    override fun onStartListening() {
        super.onStartListening()
        visible = this
        render()
    }

    override fun onStopListening() {
        if (visible === this) visible = null
        super.onStopListening()
    }

    override fun onClick() {
        super.onClick()
        if (CoreControl.busy) return
        if (CoreControl.isOn()) {
            CoreControl.stop(this)
            render()
            return
        }
        if (VpnService.prepare(this) != null) {
            openApp() // the VPN permission can only be granted from an activity
            return
        }
        CoreControl.startLast(this) { error ->
            render()
            when (error) {
                null -> {}
                CoreControl.NO_LAST_START -> {
                    Toast.makeText(applicationContext, R.string.tile_first_connect, Toast.LENGTH_LONG).show()
                    openApp()
                }
                else -> Toast.makeText(applicationContext, getString(R.string.tile_error, error), Toast.LENGTH_LONG).show()
            }
        }
        render()
    }

    fun render() {
        val tile = qsTile ?: return
        val on = CoreControl.isOn()
        tile.icon = Icon.createWithResource(this, R.drawable.ic_chevrons)
        tile.label = getString(R.string.tile_label)
        tile.state = when {
            CoreControl.busy -> Tile.STATE_UNAVAILABLE
            on -> Tile.STATE_ACTIVE
            else -> Tile.STATE_INACTIVE
        }
        if (Build.VERSION.SDK_INT >= 29) {
            tile.subtitle = getString(
                when {
                    CoreControl.busy -> R.string.tile_connecting
                    on -> R.string.tile_on
                    else -> R.string.tile_off
                },
            )
        }
        tile.updateTile()
    }

    @SuppressLint("StartActivityAndCollapseDeprecated")
    private fun openApp() {
        val intent = Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= 34) {
            startActivityAndCollapse(PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE))
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
