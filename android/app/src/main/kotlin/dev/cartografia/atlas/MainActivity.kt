package dev.cartografia.atlas

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity(), EventChannel.StreamHandler {
    private var receiver: BroadcastReceiver? = null
    private var callback: ConnectivityManager.NetworkCallback? = null
    private var channel: EventChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.cartografia.atlas/network")
        channel?.setStreamHandler(this)
    }

    @Suppress("DEPRECATION")
    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        onCancel(null)
        val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        var previous: Boolean? = null
        fun report() {
            val online = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                manager.getNetworkCapabilities(manager.activeNetwork)
                    ?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true
            } else {
                manager.activeNetworkInfo?.isConnected == true
            }
            if (previous != online) events.success(online)
            previous = online
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val observer = object : ConnectivityManager.NetworkCallback() {
                private fun refresh() = runOnUiThread { if (callback === this) report() }
                override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) = refresh()
                override fun onLost(network: Network) = refresh()
            }
            callback = observer
            manager.registerDefaultNetworkCallback(observer)
            report()
            return
        }
        val listener = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) = report()
        }
        registerReceiver(listener, IntentFilter(ConnectivityManager.CONNECTIVITY_ACTION))
        receiver = listener
    }

    override fun onCancel(arguments: Any?) {
        callback?.let { (getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager).unregisterNetworkCallback(it) }
        callback = null
        receiver?.let { unregisterReceiver(it) }
        receiver = null
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        onCancel(null)
        channel?.setStreamHandler(null)
        channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
