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
        
        // 日志辅助函数
        fun logD(msg: String) { Log.d(TAG, "[D] $msg") }
        fun logI(msg: String) { Log.i(TAG, "[I] $msg") }
        fun logW(msg: String) { Log.w(TAG, "[W] $msg") }
        fun logE(msg: String) { Log.e(TAG, "[E] $msg") }
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
    
    // 等待 VPN 权限的 config
    private var pendingConfig: Map<String, Any>? = null
    
    // 广播接收器
    private val statsReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            logI("========== statsReceiver.onReceive START ==========")
            logI("statsReceiver: context=$context")
            logI("statsReceiver: intent=$intent")
            logI("statsReceiver: action=${intent?.action}")
            
            try {
                when (intent?.action) {
                    VpnService.ACTION_STATS_UPDATE -> {
                        logI("statsReceiver: ACTION_STATS_UPDATE received")
                        val uploadSpeed = intent.getLongExtra(VpnService.EXTRA_UPLOAD_SPEED, 0)
                        val downloadSpeed = intent.getLongExtra(VpnService.EXTRA_DOWNLOAD_SPEED, 0)
                        val totalUpload = intent.getLongExtra(VpnService.EXTRA_TOTAL_UPLOAD, 0)
                        val totalDownload = intent.getLongExtra(VpnService.EXTRA_TOTAL_DOWNLOAD, 0)
                        
                        logI("statsReceiver: uploadSpeed=$uploadSpeed")
                        logI("statsReceiver: downloadSpeed=$downloadSpeed")
                        logI("statsReceiver: totalUpload=$totalUpload")
                        logI("statsReceiver: totalDownload=$totalDownload")
                        
                        cachedStats = mapOf(
                            "uploadSpeed" to uploadSpeed,
                            "downloadSpeed" to downloadSpeed,
                            "totalUpload" to totalUpload,
                            "totalDownload" to totalDownload
                        )
                        
                        logI("statsReceiver: cachedStats updated")
                    }
                    VpnService.ACTION_STATE_CHANGE -> {
                        val state = intent.getStringExtra(VpnService.EXTRA_CONNECTION_STATE)
                        logI("statsReceiver: ACTION_STATE_CHANGE received, state=$state")
                    }
                    else -> {
                        logW("statsReceiver: unknown action: ${intent?.action}")
                    }
                }
            } catch (e: Exception) {
                logE("statsReceiver: EXCEPTION: ${e.message}", e)
            }
            
            logI("========== statsReceiver.onReceive END ==========")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        logI("========== MainActivity.onCreate START ==========")
        logI("MainActivity.onCreate: savedInstanceState=$savedInstanceState")
        
        super.onCreate(savedInstanceState)
        
        logI("MainActivity.onCreate: calling setupPlatformChannels()")
        setupPlatformChannels()
        logI("MainActivity.onCreate: setupPlatformChannels() completed")
        
        logI("MainActivity.onCreate: calling bindToVpnService()")
        bindToVpnService()
        logI("MainActivity.onCreate: bindToVpnService() completed")
        
        logI("MainActivity.onCreate: calling registerBroadcastReceiver()")
        registerBroadcastReceiver()
        logI("MainActivity.onCreate: registerBroadcastReceiver() completed")
        
        logI("========== MainActivity.onCreate END ==========")
    }
    
    private fun registerBroadcastReceiver() {
        logI("========== registerBroadcastReceiver START ==========")
        
        val filter = IntentFilter().apply {
            addAction(VpnService.ACTION_STATS_UPDATE)
            addAction(VpnService.ACTION_STATE_CHANGE)
            logI("registerBroadcastReceiver: filter added ACTIONS")
        }
        
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            logI("registerBroadcastReceiver: SDK >= TIRAMISU, using RECEIVER_NOT_EXPORTED")
            registerReceiver(statsReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            logI("registerBroadcastReceiver: SDK < TIRAMISU, using regular registerReceiver")
            registerReceiver(statsReceiver, filter)
        }
        
        logI("========== registerBroadcastReceiver END ==========")
    }
    
    private fun unregisterBroadcastReceiver() {
        logI("========== unregisterBroadcastReceiver START ==========")
        try {
            unregisterReceiver(statsReceiver)
            logI("unregisterBroadcastReceiver: receiver unregistered successfully")
        } catch (e: Exception) {
            logW("unregisterBroadcastReceiver: receiver not registered: ${e.message}")
        }
        logI("========== unregisterBroadcastReceiver END ==========")
    }

    private fun bindToVpnService() {
        logI("========== bindToVpnService START ==========")
        
        // 使用 VpnService 单例获取实例
        vpnService = VpnService.getInstance()
        serviceBound = vpnService != null
        
        logI("bindToVpnService: vpnService=$vpnService")
        logI("bindToVpnService: serviceBound=$serviceBound")
        
        logI("========== bindToVpnService END ==========")
    }

    private fun setupPlatformChannels() {
        logI("========== setupPlatformChannels START ==========")
        
        logI("setupPlatformChannels: setting method channel handler")
        methodChannel.setMethodCallHandler { call, result ->
            logI("========== methodChannel.call START ==========")
            logI("methodChannel.call: method=${call.method}")
            logI("methodChannel.call: arguments=${call.arguments}")
            
            try {
                when (call.method) {
                    "connect" -> {
                        logI("methodChannel.call: handling 'connect'")
                        handleConnect(call, result)
                    }
                    "disconnect" -> {
                        logI("methodChannel.call: handling 'disconnect'")
                        handleDisconnect(result)
                    }
                    "getStatus" -> {
                        logI("methodChannel.call: handling 'getStatus'")
                        handleGetStatus(result)
                    }
                    else -> {
                        logW("methodChannel.call: method not implemented: ${call.method}")
                        result.notImplemented()
                    }
                }
            } catch (e: Exception) {
                logE("methodChannel.call: EXCEPTION: ${e.message}", e)
                result.error("EXCEPTION", e.message, null)
            }
            
            logI("========== methodChannel.call END ==========")
        }
        logI("setupPlatformChannels: method channel handler set")
        
        logI("setupPlatformChannels: setting event channel stream handler")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventSink?) {
                logI("========== EventChannel.onListen START ==========")
                logI("EventChannel.onListen: arguments=$arguments")
                logI("EventChannel.onListen: events=$events")
                
                eventSink = events
                logI("EventChannel.onListen: eventSink set")
                
                // 设置 VpnService 的回调以直接接收统计更新
                logI("EventChannel.onListen: setting VpnService callbacks")
                VpnService.onStatsUpdate = { stats ->
                    logD("EventChannel.onListen: onStatsUpdate called with stats=$stats")
                    runOnUiThread {
                        logD("EventChannel.onListen: sending stats event to flutter")
                        eventSink?.success(mapOf("type" to "stats") + stats)
                        logD("EventChannel.onListen: stats event sent")
                    }
                }
                VpnService.onStateChange = { state ->
                    logD("EventChannel.onListen: onStateChange called with state=$state")
                    runOnUiThread {
                        logD("EventChannel.onListen: sending state event to flutter")
                        eventSink?.success(mapOf("type" to state.lowercase(), "message" to "State changed"))
                        logD("EventChannel.onListen: state event sent")
                    }
                }
                logI("EventChannel.onListen: callbacks set")
                
                logI("EventChannel.onListen: calling startStatsPolling()")
                startStatsPolling()
                logI("EventChannel.onListen: startStatsPolling() completed")
                
                logI("========== EventChannel.onListen END ==========")
            }

            override fun onCancel(arguments: Any?) {
                logI("========== EventChannel.onCancel START ==========")
                logI("EventChannel.onCancel: arguments=$arguments")
                
                eventSink = null
                logI("EventChannel.onCancel: eventSink set to null")
                
                VpnService.onStatsUpdate = null
                VpnService.onStateChange = null
                logI("EventChannel.onCancel: VpnService callbacks cleared")
                
                logI("EventChannel.onCancel: calling stopStatsPolling()")
                stopStatsPolling()
                logI("EventChannel.onCancel: stopStatsPolling() completed")
                
                logI("========== EventChannel.onCancel END ==========")
            }
        })
        logI("setupPlatformChannels: event channel stream handler set")
        
        logI("========== setupPlatformChannels END ==========")
    }

    private fun startStatsPolling() {
        logI("========== startStatsPolling START ==========")
        
        statsRunnable = object : Runnable {
            private var count = 0
            
            override fun run() {
                count++
                logD("startStatsPolling: run #$count")
                
                // 每次轮询时刷新 VpnService 引用
                if (vpnService == null) {
                    logD("startStatsPolling: vpnService is null, refreshing from getInstance()")
                    vpnService = VpnService.getInstance()
                    logD("startStatsPolling: vpnService refreshed: $vpnService")
                }
                
                vpnService?.let { service ->
                    logD("startStatsPolling: getting stats from service")
                    val stats = service.getStats()
                    val state = service.connectionState.value
                    
                    logD("startStatsPolling: stats=$stats")
                    logD("startStatsPolling: state=$state")
                    
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
                            logD("startStatsPolling: state=CONNECTED, sending connected event")
                            sendEvent("connected", mapOf(
                                "message" to "VPN connected",
                                "uploadSpeed" to stats["uploadSpeed"]!!,
                                "downloadSpeed" to stats["downloadSpeed"]!!,
                                "totalUpload" to stats["totalUpload"]!!,
                                "totalDownload" to stats["totalDownload"]!!
                            ))
                        }
                        VpnService.ConnectionState.CONNECTING -> {
                            logD("startStatsPolling: state=CONNECTING, sending connecting event")
                            sendEvent("connecting", mapOf("message" to "Connecting..."))
                        }
                        VpnService.ConnectionState.DISCONNECTING -> {
                            logD("startStatsPolling: state=DISCONNECTING, sending disconnecting event")
                            sendEvent("disconnecting", mapOf("message" to "Disconnecting..."))
                        }
                        VpnService.ConnectionState.DISCONNECTED -> {
                            logD("startStatsPolling: state=DISCONNECTED, sending disconnected event")
                            sendEvent("disconnected", mapOf("message" to "VPN disconnected"))
                        }
                        VpnService.ConnectionState.ERROR -> {
                            logD("startStatsPolling: state=ERROR, sending error event")
                            sendEvent("error", mapOf("message" to "VPN connection error"))
                        }
                        else -> {
                            logW("startStatsPolling: unknown state: $state")
                        }
                    }
                } ?: run {
                    logD("startStatsPolling: vpnService is still null, skipping")
                }
                
                logD("startStatsPolling: scheduling next poll in 1000ms")
                handler.postDelayed(this, 1000)
            }
        }
        
        logI("startStatsPolling: statsRunnable created, starting first poll")
        handler.post(statsRunnable!!)
        
        logI("========== startStatsPolling END ==========")
    }

    private fun stopStatsPolling() {
        logI("========== stopStatsPolling START ==========")
        
        statsRunnable?.let { runnable ->
            logI("stopStatsPolling: removing callbacks for statsRunnable")
            handler.removeCallbacks(runnable)
            statsRunnable = null
            logI("stopStatsPolling: statsRunnable cleared")
        } ?: run {
            logI("stopStatsPolling: statsRunnable is null, nothing to stop")
        }
        
        logI("========== stopStatsPolling END ==========")
    }

    private fun handleConnect(call: MethodCall, result: MethodChannel.Result) {
        logI("========== handleConnect START ==========")
        logI("handleConnect: call=$call")
        logI("handleConnect: call.method=${call.method}")
        logI("handleConnect: call.arguments=${call.arguments}")
        
        try {
            val config = call.argument<Map<String, Any>>("config")
            logI("handleConnect: config=$config")
            logI("handleConnect: config size=${config?.size ?: 0}")
            
            // 打印所有配置参数
            config?.forEach { (key, value) ->
                logI("handleConnect:   config[$key] = $value (${value::class.java.simpleName})")
            }
            
            if (config == null) {
                logE("handleConnect: config is null, returning error")
                result.error("INVALID_CONFIG", "Configuration is required", null)
                return
            }

            logI("handleConnect: checking VPN permission")
            val vpnIntent = android.net.VpnService.prepare(this)
            logI("handleConnect: vpnIntent=$vpnIntent")
            
            if (vpnIntent != null) {
                logI("handleConnect: VPN permission required, saving config to pendingConfig")
                // 需要权限，保存 config 等授权完成后启动
                pendingConfig = config
                logI("handleConnect: pendingConfig=$pendingConfig")
                logI("handleConnect: calling startActivityForResult()")
                startActivityForResult(vpnIntent, VPN_PERMISSION_REQUEST_CODE)
                logI("handleConnect: returning success (will connect after permission)")
                result.success(true)
                return
            }

            // 直接启动 VPN 服务
            logI("handleConnect: VPN permission already granted, starting service directly")
            startVpnService(config)
            logI("handleConnect: VPN connect initiated")
            result.success(true)
            
        } catch (e: Exception) {
            logE("handleConnect: EXCEPTION: ${e.message}", e)
            result.error("EXCEPTION", e.message, null)
        }
        
        logI("========== handleConnect END ==========")
    }
    
    private fun startVpnService(config: Map<String, Any>) {
        logI("========== startVpnService START ==========")
        logI("startVpnService: config=$config")
        
        try {
            logI("startVpnService: creating intent")
            val intent = Intent(this, VpnService::class.java).apply {
                action = VpnService.ACTION_CONNECT
                putExtra("config", HashMap<String, Any>(config))
            }
            logI("startVpnService: intent created")
            logI("startVpnService: intent.action=${intent.action}")
            logI("startVpnService: intent extras=${intent.extras}")
            
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                logI("startVpnService: SDK >= O, using startForegroundService()")
                startForegroundService(intent)
                logI("startVpnService: startForegroundService() called")
            } else {
                logI("startVpnService: SDK < O, using startService()")
                startService(intent)
                logI("startVpnService: startService() called")
            }
            
            logI("startVpnService: service started successfully")
            
        } catch (e: Exception) {
            logE("startVpnService: EXCEPTION: ${e.message}", e)
        }
        
        logI("========== startVpnService END ==========")
    }

    private fun handleDisconnect(result: MethodChannel.Result) {
        logI("========== handleDisconnect START ==========")
        
        try {
            logI("handleDisconnect: creating intent")
            val intent = Intent(this, VpnService::class.java).apply {
                action = VpnService.ACTION_DISCONNECT
            }
            logI("handleDisconnect: intent.action=${intent.action}")
            
            logI("handleDisconnect: calling startService()")
            startService(intent)
            logI("handleDisconnect: service started")
            
            logI("handleDisconnect: returning success")
            result.success(true)
            
        } catch (e: Exception) {
            logE("handleDisconnect: EXCEPTION: ${e.message}", e)
            result.error("EXCEPTION", e.message, null)
        }
        
        logI("========== handleDisconnect END ==========")
    }

    private fun handleGetStatus(result: MethodChannel.Result) {
        logI("========== handleGetStatus START ==========")
        
        try {
            // 刷新 VpnService 引用
            if (vpnService == null) {
                logI("handleGetStatus: refreshing vpnService from getInstance()")
                vpnService = VpnService.getInstance()
            }
            
            // 返回缓存的统计数据和连接状态
            val isConnected = vpnService?.connectionState?.value == VpnService.ConnectionState.CONNECTED
            val isRunning = vpnService?.connectionState?.value == VpnService.ConnectionState.CONNECTED ||
                           vpnService?.connectionState?.value == VpnService.ConnectionState.CONNECTING
            
            val status = mapOf(
                "connected" to isConnected,
                "running" to isRunning,
                "uploadSpeed" to cachedStats["uploadSpeed"]!!,
                "downloadSpeed" to cachedStats["downloadSpeed"]!!,
                "totalUpload" to cachedStats["totalUpload"]!!,
                "totalDownload" to cachedStats["totalDownload"]!!
            )
            
            logI("handleGetStatus: isConnected=$isConnected")
            logI("handleGetStatus: isRunning=$isRunning")
            logI("handleGetStatus: cachedStats=$cachedStats")
            logI("handleGetStatus: returning status=$status")
            
            result.success(status)
            
        } catch (e: Exception) {
            logE("handleGetStatus: EXCEPTION: ${e.message}", e)
            result.error("EXCEPTION", e.message, null)
        }
        
        logI("========== handleGetStatus END ==========")
    }

    private fun sendEvent(type: String, data: Map<String, Any>) {
        logD("========== sendEvent START ==========")
        logD("sendEvent: type=$type")
        logD("sendEvent: data=$data")
        
        runOnUiThread {
            try {
                logD("sendEvent: sending to eventSink")
                eventSink?.success(mapOf("type" to type) + data)
                logD("sendEvent: sent successfully")
            } catch (e: Exception) {
                logE("sendEvent: EXCEPTION: ${e.message}", e)
            }
        }
        
        logD("========== sendEvent END ==========")
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        logI("========== MainActivity.onActivityResult START ==========")
        logI("MainActivity.onActivityResult: requestCode=$requestCode")
        logI("MainActivity.onActivityResult: resultCode=$resultCode")
        logI("MainActivity.onActivityResult: data=$data")
        
        super.onActivityResult(requestCode, resultCode, data)
        
        try {
            if (requestCode == VPN_PERMISSION_REQUEST_CODE) {
                logI("MainActivity.onActivityResult: VPN permission request")
                
                if (resultCode == RESULT_OK) {
                    logI("MainActivity.onActivityResult: RESULT_OK - permission granted")
                    
                    pendingConfig?.let { config ->
                        logI("MainActivity.onActivityResult: starting VPN with pending config")
                        logI("MainActivity.onActivityResult: pendingConfig=$config")
                        startVpnService(config)
                        pendingConfig = null
                        logI("MainActivity.onActivityResult: pendingConfig cleared")
                    } ?: run {
                        logW("MainActivity.onActivityResult: pendingConfig is null!")
                    }
                } else {
                    logE("MainActivity.onActivityResult: permission denied, resultCode=$resultCode")
                    pendingConfig = null
                    logI("MainActivity.onActivityResult: pendingConfig cleared")
                    sendEvent("error", mapOf("message" to "VPN permission denied"))
                    logI("MainActivity.onActivityResult: error event sent")
                }
            } else {
                logW("MainActivity.onActivityResult: unknown requestCode=$requestCode")
            }
        } catch (e: Exception) {
            logE("MainActivity.onActivityResult: EXCEPTION: ${e.message}", e)
        }
        
        logI("========== MainActivity.onActivityResult END ==========")
    }

    override fun onDestroy() {
        logI("========== MainActivity.onDestroy START ==========")
        
        try {
            logI("MainActivity.onDestroy: calling unregisterBroadcastReceiver()")
            unregisterBroadcastReceiver()
            logI("MainActivity.onDestroy: unregisterBroadcastReceiver() completed")
            
            logI("MainActivity.onDestroy: calling serviceScope.cancel()")
            serviceScope.cancel()
            logI("MainActivity.onDestroy: serviceScope cancelled")
            
            logI("MainActivity.onDestroy: calling stopStatsPolling()")
            stopStatsPolling()
            logI("MainActivity.onDestroy: stopStatsPolling() completed")
            
        } catch (e: Exception) {
            logE("MainActivity.onDestroy: EXCEPTION: ${e.message}", e)
        }
        
        super.onDestroy()
        logI("========== MainActivity.onDestroy END ==========")
    }
}
