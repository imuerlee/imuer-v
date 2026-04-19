package com.nebula.nebula_vpn

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.net.ProxyInfo
import android.net.VpnService as AndroidVpnService
import android.os.Build
import android.os.IBinder
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.io.File
import java.net.InetSocketAddress

class VpnService : AndroidVpnService() {
    companion object {
        const val TAG = "NebulaVpnService"
        const val NOTIFICATION_CHANNEL_ID = "nebula_vpn_channel"
        const val NOTIFICATION_ID = 1
        const val ACTION_CONNECT = "com.nebula.nebula_vpn.CONNECT"
        const val ACTION_DISCONNECT = "com.nebula.nebula_vpn.DISCONNECT"
        const val ACTION_STATS_UPDATE = "com.nebula.nebula_vpn.STATS_UPDATE"
        const val ACTION_STATE_CHANGE = "com.nebula.nebula_vpn.STATE_CHANGE"
        const val EXTRA_UPLOAD_SPEED = "uploadSpeed"
        const val EXTRA_DOWNLOAD_SPEED = "downloadSpeed"
        const val EXTRA_TOTAL_UPLOAD = "totalUpload"
        const val EXTRA_TOTAL_DOWNLOAD = "totalDownload"
        const val EXTRA_CONNECTION_STATE = "connectionState"
        const val VPN_ADDRESS = "10.0.0.2"
        const val VPN_ADDRESS_V6 = "fd00::2"
        const val DNS_SERVER = "8.8.8.8"
        const val DNS_SERVER_V6 = "2001:4860:4860::8888"
        const val PROXY_PORT = 10808

        @Volatile
        private var instance: VpnService? = null

        fun getInstance(): VpnService? = instance
        
        // 用于直接发送事件到 Flutter 的回调
        var onStatsUpdate: ((Map<String, Any>) -> Unit)? = null
        var onStateChange: ((String) -> Unit)? = null
    }
    
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    // 状态
    private val _connectionState = MutableStateFlow(ConnectionState.DISCONNECTED)
    val connectionState: StateFlow<ConnectionState> = _connectionState.asStateFlow()
    
    // 流量统计
    private var uploadSpeed: Long = 0
    private var downloadSpeed: Long = 0
    private var totalUpload: Long = 0
    private var totalDownload: Long = 0
    
    // 文件描述符和进程
    private var vpnFileDescriptor: ParcelFileDescriptor? = null
    private var v2rayProcess: Process? = null
    
    // V2Ray 配置
    private var serverConfig: Map<String, Any>? = null

    enum class ConnectionState {
        DISCONNECTED,
        CONNECTING,
        CONNECTED,
        DISCONNECTING,
        ERROR
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "VpnService.onStartCommand: action=${intent?.action}")
        when (intent?.action) {
            ACTION_CONNECT -> {
                val config = intent.getSerializableExtra("config") as? Map<String, Any>
                Log.i(TAG, "VpnService.onStartCommand: CONNECT, config=$config")
                connect(config)
            }
            ACTION_DISCONNECT -> {
                Log.i(TAG, "VpnService.onStartCommand: DISCONNECT")
                disconnect()
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        disconnect()
        serviceScope.cancel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "NebulaVPN",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "VPN connection status"
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(title: String, text: String): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
    
    private fun startForegroundWithNotification(title: String, text: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, createNotification(title, text), ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, createNotification(title, text))
        }
    }
    
    private fun updateNotification(title: String, text: String) {
        val notification = createNotification(title, text)
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun connect(config: Map<String, Any>?) {
        Log.i(TAG, "VpnService.connect: starting")
        serviceScope.launch {
            try {
                // 立即启动前台通知，显示"连接中"
                Log.i(TAG, "VpnService.connect: starting foreground notification")
                startForegroundWithNotification("Nebula VPN", "Connecting...")
                
                _connectionState.value = ConnectionState.CONNECTING
                sendStateChange()
                
                serverConfig = config
                
                // 检查并下载 v2ray-core
                Log.i(TAG, "VpnService.connect: checking v2ray-core")
                if (!checkV2RayCore()) {
                    updateNotification("Nebula VPN", "Failed to download v2ray-core")
                    throw IllegalStateException("Failed to prepare v2ray-core")
                }
                Log.i(TAG, "VpnService.connect: v2ray-core ready")
                
                // 生成配置文件
                Log.i(TAG, "VpnService.connect: generating config")
                val configPath = generateConfig(config)
                Log.i(TAG, "VpnService.connect: configPath = $configPath")
                
                // 准备 VpnService.Builder
                Log.i(TAG, "VpnService.connect: establishing VPN")
                val builder = Builder()
                    .addAddress(VPN_ADDRESS, 24)
                    .addAddress(VPN_ADDRESS_V6, 64)
                    .addDnsServer(DNS_SERVER)
                    .addDnsServer(DNS_SERVER_V6)
                    .addRoute("0.0.0.0", 0)
                    .addRoute("::", 0)
                    .setSession("NebulaVPN")
                    .setBlocking(true)
                    .setMtu(1500)
                
                // 添加允许的应用（可选）
                // builder.addAllowedApplication("com.android.browser")
                
                // 添加绕过应用
                builder.addDisallowedApplication(packageName)
                
                // 建立 VPN 连接
                Log.i(TAG, "VpnService.connect: calling builder.establish()")
                vpnFileDescriptor = builder.establish()
                Log.i(TAG, "VpnService.connect: vpnFileDescriptor = $vpnFileDescriptor")
                    ?: throw IllegalStateException("Failed to establish VPN connection")
                
                // 设置系统代理
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    setUnderlyingNetworks(null)
                }
                
                // 更新通知
                updateNotification("Nebula VPN", "Starting v2ray-core...")
                
                // 启动 v2ray-core
                startV2Ray(configPath)
                
                // 等待连接建立
                updateNotification("Nebula VPN", "Testing connection...")
                delay(2000)
                
                // 测试连接
                if (!testConnection()) {
                    updateNotification("Nebula VPN", "Connection test failed")
                    throw IllegalStateException("Connection test failed")
                }
                
                // 连接成功，更新通知
                updateNotification("Nebula VPN", "VPN connected")
                
                _connectionState.value = ConnectionState.CONNECTED
                sendStateChange()
                
                // 启动统计收集
                collectStats()
                
                Log.i(TAG, "VPN connected successfully")
                
            } catch (e: Exception) {
                Log.e(TAG, "Connection failed: ${e.message}", e)
                Log.e(TAG, "Connection failed: stacktrace = ${e.stackTrace}")
                _connectionState.value = ConnectionState.ERROR
                sendStateChange()
                disconnect()
            }
        }
    }

    fun disconnect() {
        serviceScope.launch {
            try {
                _connectionState.value = ConnectionState.DISCONNECTING
                sendStateChange()
                
                // 停止 v2ray-core
                stopV2Ray()
                
                // 关闭 VPN 连接
                vpnFileDescriptor?.close()
                vpnFileDescriptor = null
                
                // 停止前台服务
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
                
                // 重置统计
                uploadSpeed = 0
                downloadSpeed = 0
                totalUpload = 0
                totalDownload = 0
                
                _connectionState.value = ConnectionState.DISCONNECTED
                sendStateChange()
                
                Log.i(TAG, "VPN disconnected")
                
            } catch (e: Exception) {
                Log.e(TAG, "Disconnect failed: ${e.message}")
            }
        }
    }

    private suspend fun checkV2RayCore(): Boolean {
        val v2rayPath = getV2RayPath()
        val file = File(v2rayPath)
        
        if (file.exists()) {
            Log.i(TAG, "v2ray-core already exists")
            return true
        }
        
        // 下载 v2ray-core
        Log.i(TAG, "Downloading v2ray-core...")
        return downloadV2RayCore()
    }

    private suspend fun downloadV2RayCore(): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                // 选择合适的 Android 版本
                val arch = System.getProperty("os.arch") ?: "arm64-v8a"
                val url = when {
                    arch.contains("arm64") || arch.contains("aarch64") -> 
                        "https://github.com/v2fly/v2ray-core/releases/download/v5.22.0/v2ray-android-arm64-v8a.zip"
                    arch.contains("arm") -> 
                        "https://github.com/v2fly/v2ray-core/releases/download/v5.22.0/v2ray-android-armeabi-v7a.zip"
                    arch.contains("86") -> 
                        "https://github.com/v2fly/v2ray-core/releases/download/v5.22.0/v2ray-android-386.zip"
                    else -> 
                        "https://github.com/v2fly/v2ray-core/releases/download/v5.22.0/v2ray-android-arm64-v8a.zip"
                }
                
                Log.i(TAG, "Downloading from: $url")
                
                val destDir = filesDir
                val zipFile = File(cacheDir, "v2ray.zip")
                val v2rayFile = File(destDir, "v2ray")
                
                // 使用 HttpURLConnection 下载
                val conn = java.net.URL(url).openConnection() as java.net.HttpURLConnection
                conn.connectTimeout = 60000
                conn.readTimeout = 60000
                conn.requestMethod = "GET"
                
                val fileLength = conn.contentLength
                val data = ByteArray(4096)
                var total: Long = 0
                var count: Int
                
                conn.inputStream.use { input ->
                    zipFile.outputStream().use { output ->
                        while (true) {
                            count = input.read(data)
                            if (count < 0) break
                            output.write(data, 0, count)
                            total += count.toLong()
                            
                            // 更新下载进度
                            if (fileLength > 0) {
                                val progress = (total * 100 / fileLength).toInt()
                                Log.d(TAG, "Download progress: $progress%")
                            }
                        }
                    }
                }
                conn.disconnect()
                
                Log.i(TAG, "Download completed, extracting...")
                
                // 解压 zip 文件
                java.util.zip.ZipFile(zipFile).use { zip ->
                    val entry = zip.getEntry("v2ray")
                    if (entry != null) {
                        zip.getInputStream(entry).use { input ->
                            v2rayFile.outputStream().use { output ->
                                input.copyTo(output)
                            }
                        }
                    }
                }
                
                // 删除 zip 文件
                zipFile.delete()
                
                // 设置可执行权限
                v2rayFile.setExecutable(true)
                
                Log.i(TAG, "v2ray-core installed successfully")
                true
                
            } catch (e: Exception) {
                Log.e(TAG, "Download failed: ${e.message}")
                false
            }
        }
    }

    private fun generateConfig(config: Map<String, Any>?): String {
        val configJson = buildString {
            append("{")
            append("\"log\":{\"loglevel\":\"warning\"},")
            append("\"inbounds\":[{")
            append("\"port\":$PROXY_PORT,")
            append("\"protocol\":\"http\",")
            append("\"settings\":{},")
            append("\"sniffing\":{\"enabled\":true,\"destOverride\":[\"http\",\"tls\"]}")
            append("}],")
            append("\"outbounds\":[{")
            
            val protocol = (config?.get("protocol") as? String) ?: "vmess"
            append("\"protocol\":\"$protocol\",")
            append("\"settings\":{")
            append("\"vnext\":[{")
            
            val address = (config?.get("address") as? String) ?: ""
            val port = (config?.get("port") as? Int) ?: 443
            val uuid = (config?.get("uuid") as? String) ?: ""
            val security = (config?.get("security") as? String) ?: "auto"
            
            append("\"address\":\"$address\",")
            append("\"port\":$port,")
            append("\"users\":[{\"id\":\"$uuid\",\"security\":\"$security\"}]")
            append("}]},")
            
            val network = (config?.get("network") as? String) ?: "tcp"
            val useTls = port == 443
            append("\"streamSettings\":{")
            append("\"network\":\"$network\",")
            append("\"security\":\"${if (useTls) "tls" else "none"}\"")
            append("},")
            append("\"tag\":\"proxy\"")
            append("}")
            append("]")
            append("}")
        }
        
        val configFile = File(filesDir, "config.json")
        configFile.writeText(configJson)
        
        return configFile.absolutePath
    }

    private fun getV2RayPath(): String {
        return File(filesDir, "v2ray").absolutePath
    }

    private fun startV2Ray(configPath: String) {
        val v2rayPath = getV2RayPath()
        
        val command = arrayOf(
            v2rayPath,
            "-config=$configPath"
        )
        
        val processBuilder = ProcessBuilder(*command)
        processBuilder.redirectErrorStream(true)
        
        v2rayProcess = processBuilder.start()
        
        // 读取日志
        v2rayProcess?.inputStream?.bufferedReader()?.forEachLine { line ->
            Log.d(TAG, "v2ray: $line")
        }
    }

    private fun stopV2Ray() {
        v2rayProcess?.destroy()
        v2rayProcess = null
    }

    private suspend fun testConnection(): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val socket = java.net.Socket()
                socket.connect(InetSocketAddress("8.8.8.8", 53), 5000)
                socket.close()
                true
            } catch (e: Exception) {
                Log.e(TAG, "Connection test failed: ${e.message}")
                false
            }
        }
    }

    private suspend fun collectStats() {
        // TrafficStats 返回的是累计值，需要记录初始值
        val initialRx = android.net.TrafficStats.getUidRxBytes(applicationInfo.uid)
        val initialTx = android.net.TrafficStats.getUidTxBytes(applicationInfo.uid)
        var lastRx = initialRx
        var lastTx = initialTx
        
        // 会话累计流量
        var sessionRx: Long = 0
        var sessionTx: Long = 0
        
        while (_connectionState.value == ConnectionState.CONNECTED) {
            try {
                // 获取当前累计流量
                val currentRx = android.net.TrafficStats.getUidRxBytes(applicationInfo.uid)
                val currentTx = android.net.TrafficStats.getUidTxBytes(applicationInfo.uid)
                
                // 计算本次间隔的流量
                val deltaRx = currentRx - lastRx
                val deltaTx = currentTx - lastTx
                
                // 更新上次值
                lastRx = currentRx
                lastTx = currentTx
                
                // 累加会话总流量
                sessionRx += deltaRx
                sessionTx += deltaTx
                
                // 计算速度 (字节/秒)
                uploadSpeed = deltaTx
                downloadSpeed = deltaRx
                
                // 更新总流量
                totalUpload = sessionTx
                totalDownload = sessionRx
                
                // 发送统计更新
                sendStatsUpdate()
                
                delay(1000)
                
            } catch (e: Exception) {
                Log.e(TAG, "Stats collection failed: ${e.message}")
                delay(1000)
            }
        }
    }

    private val _statsFlow = MutableStateFlow(mapOf<String, Long>(
        "uploadSpeed" to 0,
        "downloadSpeed" to 0,
        "totalUpload" to 0,
        "totalDownload" to 0
    ))
    val statsFlow: StateFlow<Map<String, Long>> = _statsFlow.asStateFlow()

    private fun sendStatsUpdate() {
        _statsFlow.value = mapOf(
            "uploadSpeed" to uploadSpeed,
            "downloadSpeed" to downloadSpeed,
            "totalUpload" to totalUpload,
            "totalDownload" to totalDownload
        )
        
        // 发送广播以便 MainActivity 可以接收
        val intent = Intent(ACTION_STATS_UPDATE).apply {
            putExtra(EXTRA_UPLOAD_SPEED, uploadSpeed)
            putExtra(EXTRA_DOWNLOAD_SPEED, downloadSpeed)
            putExtra(EXTRA_TOTAL_UPLOAD, totalUpload)
            putExtra(EXTRA_TOTAL_DOWNLOAD, totalDownload)
            putExtra(EXTRA_CONNECTION_STATE, _connectionState.value.name)
        }
        sendBroadcast(intent)
        
        // 直接调用回调发送到 Flutter
        onStatsUpdate?.invoke(mapOf(
            "uploadSpeed" to uploadSpeed,
            "downloadSpeed" to downloadSpeed,
            "totalUpload" to totalUpload,
            "totalDownload" to totalDownload
        ))
    }

    private fun sendStateChange() {
        val state = _connectionState.value.name
        val intent = Intent(ACTION_STATE_CHANGE).apply {
            putExtra(EXTRA_CONNECTION_STATE, state)
        }
        sendBroadcast(intent)
        
        // 直接调用回调发送到 Flutter
        onStateChange?.invoke(state)
    }

    // 供 MainActivity 调用的获取统计方法
    fun getStats(): Map<String, Long> {
        return mapOf(
            "uploadSpeed" to uploadSpeed,
            "downloadSpeed" to downloadSpeed,
            "totalUpload" to totalUpload,
            "totalDownload" to totalDownload
        )
    }
}
