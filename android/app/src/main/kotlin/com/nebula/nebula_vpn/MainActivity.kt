package com.nebula.nebula_vpn

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel.EventSink
import kotlinx.coroutines.*

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "NebulaVPN"
        private const val METHOD_CHANNEL = "nebula_vpn/method"
        private const val EVENT_CHANNEL = "nebula_vpn/events"
        private const val VPN_PERMISSION_REQUEST_CODE = 1001
    }

    private val methodChannel get() = MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, METHOD_CHANNEL)
    private val eventChannel get() = EventChannel(flutterEngine!!.dartExecutor.binaryMessenger, EVENT_CHANNEL)
    
    private var eventSink: EventSink? = null
    private val serviceScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private val handler = Handler(Looper.getMainLooper())
    
    // 定期发送统计更新
    private var statsRunnable: Runnable? = null
    
    // 缓存最新的统计数据，用于 handleGetStatus
    private var cachedStats = mapOf<String, Long>(
        "uploadSpeed" to 0L,
        "downloadSpeed" to 0L,
        "totalUpload" to 0L,
        "totalDownload" to 0L
    )
    
    // 绑定到 VpnService
    private var vpnService: VpnService? = null
    private var serviceBound = false
    
    // 广播接收器
    private val statsReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                VpnService.ACTION_STATS_UPDATE -> {
                    cachedStats = mapOf(
                        "uploadSpeed" to intent.getLongExtra(VpnService.EXTRA_UPLOAD_SPEED, 0),
                        "downloadSpeed" to intent.getLongExtra(VpnService.EXTRA_DOWNLOAD_SPEED, 0),
                        "totalUpload" to intent.getLongExtra(VpnService.EXTRA_TOTAL_UPLOAD, 0),
                        "totalDownload" to intent.getLongExtra(VpnService.EXTRA_TOTAL_DOWNLOAD, 0)
                    )
                }
                VpnService.ACTION_STATE_CHANGE -> {
                    val state = intent.getStringExtra(VpnService.EXTRA_CONNECTION_STATE)
                    Log.d(TAG, "State changed to: $state")
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setupPlatformChannels()
        bindToVpnService()
        registerBroadcastReceiver()
    }
    
    private fun registerBroadcastReceiver() {
        val filter = IntentFilter().apply {
            addAction(VpnService.ACTION_STATS_UPDATE)
            addAction(VpnService.ACTION_STATE_CHANGE)
        }
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(statsReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(statsReceiver, filter)
        }
    }
    
    private fun unregisterBroadcastReceiver() {
        try {
            unregisterReceiver(statsReceiver)
        } catch (e: Exception) {
            Log.w(TAG, "Receiver not registered: ${e.message}")
        }
    }

    private fun bindToVpnService() {
        // 使用 VpnService 单例获取实例
        vpnService = VpnService.getInstance()
        serviceBound = vpnService != null
        Log.i(TAG, "VpnService bound: $serviceBound")
    }

    private fun setupPlatformChannels() {
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "connect" -> handleConnect(call, result)
                "disconnect" -> handleDisconnect(result)
                "getStatus" -> handleGetStatus(result)
                else -> result.notImplemented()
            }
        }

        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventSink?) {
                eventSink = events
                
                // 设置 VpnService 的回调以直接接收统计更新
                VpnService.onStatsUpdate = { stats ->
                    runOnUiThread {
                        eventSink?.success(mapOf("type" to "stats") + stats)
                    }
                }
                VpnService.onStateChange = { state ->
                    runOnUiThread {
                        eventSink?.success(mapOf("type" to state.lowercase(), "message" to "State changed"))
                    }
                }
                
                startStatsPolling()
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                VpnService.onStatsUpdate = null
                VpnService.onStateChange = null
                stopStatsPolling()
            }
        })
    }

    private fun startStatsPolling() {
        statsRunnable = object : Runnable {
            override fun run() {
                // 每次轮询时刷新 VpnService 引用
                if (vpnService == null) {
                    vpnService = VpnService.getInstance()
                }
                
                vpnService?.let { service ->
                    val stats = service.getStats()
                    val state = service.connectionState.value
                    
                    // 缓存统计数据
                    cachedStats = mapOf(
                        "uploadSpeed" to stats["uploadSpeed"]!!,
                        "downloadSpeed" to stats["downloadSpeed"]!!,
                        "totalUpload" to stats["totalUpload"]!!,
                        "totalDownload" to stats["totalDownload"]!!
                    )
                    
                    // 根据状态发送初始连接事件（后续状态变化由回调处理）
                    when (state) {
                        VpnService.ConnectionState.CONNECTED -> {
                            sendEvent("connected", mapOf(
                                "message" to "VPN connected",
                                "uploadSpeed" to stats["uploadSpeed"]!!,
                                "downloadSpeed" to stats["downloadSpeed"]!!,
                                "totalUpload" to stats["totalUpload"]!!,
                                "totalDownload" to stats["totalDownload"]!!
                            ))
                        }
                        VpnService.ConnectionState.CONNECTING -> {
                            sendEvent("connecting", mapOf("message" to "Connecting..."))
                        }
                        VpnService.ConnectionState.DISCONNECTING -> {
                            sendEvent("disconnecting", mapOf("message" to "Disconnecting..."))
                        }
                        VpnService.ConnectionState.DISCONNECTED -> {
                            sendEvent("disconnected", mapOf("message" to "VPN disconnected"))
                        }
                        VpnService.ConnectionState.ERROR -> {
                            sendEvent("error", mapOf("message" to "VPN connection error"))
                        }
                    }
                }
                
                handler.postDelayed(this, 1000)
            }
        }
        handler.post(statsRunnable!!)
    }

    private fun stopStatsPolling() {
        statsRunnable?.let { handler.removeCallbacks(it) }
        statsRunnable = null
    }

    private fun handleConnect(call: MethodCall, result: MethodChannel.Result) {
        val config = call.argument<Map<String, Any>>("config")
        if (config == null) {
            result.error("INVALID_CONFIG", "Configuration is required", null)
            return
        }

        val vpnIntent = android.net.VpnService.prepare(this)
        if (vpnIntent != null) {
            startActivityForResult(vpnIntent, VPN_PERMISSION_REQUEST_CODE)
            result.success(true)
            return
        }

        val intent = Intent(this, VpnService::class.java).apply {
            action = VpnService.ACTION_CONNECT
            putExtra("config", HashMap<String, Any>(config))
        }
        
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }

        Log.i(TAG, "VPN connect initiated")
        result.success(true)
    }

    private fun handleDisconnect(result: MethodChannel.Result) {
        val intent = Intent(this, VpnService::class.java).apply {
            action = VpnService.ACTION_DISCONNECT
        }
        startService(intent)

        Log.i(TAG, "VPN disconnect initiated")
        result.success(true)
    }

    private fun handleGetStatus(result: MethodChannel.Result) {
        // 返回缓存的统计数据和连接状态
        val isConnected = vpnService?.connectionState?.value == VpnService.ConnectionState.CONNECTED
        val status = mapOf(
            "connected" to isConnected,
            "uploadSpeed" to cachedStats["uploadSpeed"]!!,
            "downloadSpeed" to cachedStats["downloadSpeed"]!!,
            "totalUpload" to cachedStats["totalUpload"]!!,
            "totalDownload" to cachedStats["totalDownload"]!!
        )
        
        result.success(status)
    }

    private fun sendEvent(type: String, data: Map<String, Any>) {
        runOnUiThread {
            eventSink?.success(mapOf("type" to type) + data)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == VPN_PERMISSION_REQUEST_CODE) {
            if (resultCode == RESULT_OK) {
                Log.i(TAG, "VPN permission granted")
            } else {
                Log.e(TAG, "VPN permission denied")
                sendEvent("error", mapOf("message" to "VPN permission denied"))
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterBroadcastReceiver()
        serviceScope.cancel()
        stopStatsPolling()
    }
}
