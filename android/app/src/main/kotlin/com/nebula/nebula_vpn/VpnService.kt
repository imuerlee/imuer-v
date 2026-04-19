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
        
        // 日志辅助函数
        fun logD(msg: String) { Log.d(TAG, "[D] $msg") }
        fun logI(msg: String) { Log.i(TAG, "[I] $msg") }
        fun logW(msg: String) { Log.w(TAG, "[W] $msg") }
        fun logE(msg: String) { Log.e(TAG, "[E] $msg") }
        fun logE(msg: String, e: Exception) { Log.e(TAG, "[E] $msg", e) }
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
        logI("========== onCreate START ==========")
        super.onCreate()
        instance = this
        logI("onCreate: instance set")
        createNotificationChannel()
        logI("onCreate: notification channel created")
        logI("========== onCreate END ==========")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        logI("========== onStartCommand START ==========")
        logI("onStartCommand: action=${intent?.action}")
        
        when (intent?.action) {
            ACTION_CONNECT -> {
                logI("onStartCommand: ACTION_CONNECT")
                val config = intent?.getSerializableExtra("config") as? Map<String, Any>
                logI("onStartCommand: config class=${config?.javaClass?.name}, size=${config?.size}")
                connect(config)
            }
            ACTION_DISCONNECT -> {
                logI("onStartCommand: ACTION_DISCONNECT")
                disconnect()
            }
            else -> {
                logW("onStartCommand: unknown action: ${intent?.action}")
            }
        }
        
        logI("========== onStartCommand END ==========")
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        logI("onBind: intent=$intent")
        logI("onBind: returning null")
        return null
    }

    override fun onDestroy() {
        logI("========== onDestroy START ==========")
        try {
            logI("onDestroy: setting instance to null")
            instance = null
            logI("onDestroy: calling disconnect()")
            disconnect()
            logI("onDestroy: calling serviceScope.cancel()")
            serviceScope.cancel()
            logI("onDestroy: completed")
        } catch (e: Exception) {
            logE("onDestroy: EXCEPTION: ${e.message}", e)
        }
        super.onDestroy()
        logI("========== onDestroy END ==========")
    }

    private fun createNotificationChannel() {
        logI("========== createNotificationChannel START ==========")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            logI("createNotificationChannel: SDK >= O, creating notification channel")
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "NebulaVPN",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "VPN connection status"
                logI("createNotificationChannel: channel created with id=$NOTIFICATION_CHANNEL_ID")
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            logI("createNotificationChannel: got NotificationManager")
            notificationManager.createNotificationChannel(channel)
            logI("createNotificationChannel: channel created successfully")
        } else {
            logI("createNotificationChannel: SDK < O, no need to create channel")
        }
        logI("========== createNotificationChannel END ==========")
    }

    private fun createNotification(title: String, text: String): Notification {
        logI("========== createNotification START ==========")
        logI("createNotification: title='$title', text='$text'")
        
        logI("createNotification: creating PendingIntent")
        val pendingIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        logI("createNotification: PendingIntent created")
        
        logI("createNotification: building notification")
        val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
        
        logI("createNotification: notification built successfully")
        logI("========== createNotification END ==========")
        return notification
    }
    
    private fun startForegroundWithNotification(title: String, text: String) {
        logI("========== startForegroundWithNotification START ==========")
        logI("startForegroundWithNotification: title='$title', text='$text'")
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            logI("startForegroundWithNotification: SDK >= Q, using FOREGROUND_SERVICE_TYPE_DATA_SYNC")
            logI("startForegroundWithNotification: calling startForeground($NOTIFICATION_ID, notification, FOREGROUND_SERVICE_TYPE_DATA_SYNC)")
            startForeground(NOTIFICATION_ID, createNotification(title, text), ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            logI("startForegroundWithNotification: SDK < Q, using regular startForeground")
            logI("startForegroundWithNotification: calling startForeground($NOTIFICATION_ID, notification)")
            startForeground(NOTIFICATION_ID, createNotification(title, text))
        }
        
        logI("========== startForegroundWithNotification END ==========")
    }
    
    private fun updateNotification(title: String, text: String) {
        logI("========== updateNotification START ==========")
        logI("updateNotification: title='$title', text='$text'")
        
        val notification = createNotification(title, text)
        val notificationManager = getSystemService(NotificationManager::class.java)
        logI("updateNotification: calling notificationManager.notify($NOTIFICATION_ID, notification)")
        notificationManager.notify(NOTIFICATION_ID, notification)
        
        logI("========== updateNotification END ==========")
    }

    private fun connect(config: Map<String, Any>?) {
        logI("========== connect START ==========")
        logI("connect: config=$config")
        logI("connect: config size=${config?.size ?: 0}")
        
        // 打印所有配置参数
        config?.forEach { (key, value) ->
            logI("connect:   config[$key] = $value (${value::class.java.simpleName})")
        }
        
        serviceScope.launch {
            try {
                logI("connect: launch started")
                
                // 步骤1: 启动前台通知
                logI("connect: ===== STEP 1: startForegroundWithNotification =====")
                startForegroundWithNotification("Nebula VPN", "Connecting...")
                logI("connect: foreground notification started")
                
                // 更新状态
                logI("connect: setting state to CONNECTING")
                _connectionState.value = ConnectionState.CONNECTING
                sendStateChange()
                logI("connect: state change sent")
                
                // 保存配置
                serverConfig = config
                logI("connect: serverConfig saved")
                
                // 步骤2: 检查 v2ray-core
                logI("connect: ===== STEP 2: checkV2RayCore =====")
                val v2rayReady = checkV2RayCore()
                logI("connect: checkV2RayCore returned: $v2rayReady")
                
                if (!v2rayReady) {
                    logE("connect: checkV2RayCore FAILED")
                    updateNotification("Nebula VPN", "Failed to prepare v2ray-core")
                    throw IllegalStateException("Failed to prepare v2ray-core")
                }
                logI("connect: v2ray-core is ready")
                
                // 步骤3: 生成配置文件
                logI("connect: ===== STEP 3: generateConfig =====")
                val configPath = generateConfig(config)
                logI("connect: generateConfig returned: $configPath")
                
                // 步骤4: 建立 VPN 连接
                logI("connect: ===== STEP 4: establish VPN =====")
                logI("connect: creating VpnService.Builder")
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
                
                logI("connect: adding disallowed application: $packageName")
                builder.addDisallowedApplication(packageName)
                
                logI("connect: calling builder.establish()")
                vpnFileDescriptor = builder.establish()
                logI("connect: establish returned: $vpnFileDescriptor")
                
                if (vpnFileDescriptor == null) {
                    logE("connect: builder.establish() returned NULL!")
                    throw IllegalStateException("Failed to establish VPN connection")
                }
                logI("connect: VPN connection established successfully")
                
                // 设置系统代理
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    logI("connect: SDK >= Q, calling setUnderlyingNetworks(null)")
                    setUnderlyingNetworks(null)
                }
                
                // 步骤5: 启动 v2ray-core
                logI("connect: ===== STEP 5: startV2Ray =====")
                updateNotification("Nebula VPN", "Starting v2ray-core...")
                startV2Ray(configPath)
                logI("connect: v2ray started")
                
                // 步骤6: 测试连接
                logI("connect: ===== STEP 6: testConnection =====")
                updateNotification("Nebula VPN", "Testing connection...")
                logI("connect: waiting 2 seconds...")
                delay(2000)
                
                val connectionOk = testConnection()
                logI("connect: testConnection returned: $connectionOk")
                
                if (!connectionOk) {
                    logE("connect: connection test FAILED!")
                    updateNotification("Nebula VPN", "Connection test failed")
                    throw IllegalStateException("Connection test failed")
                }
                logI("connect: connection test PASSED")
                
                // 步骤7: 连接成功
                logI("connect: ===== STEP 7: connected =====")
                updateNotification("Nebula VPN", "VPN connected")
                
                _connectionState.value = ConnectionState.CONNECTED
                sendStateChange()
                logI("connect: state changed to CONNECTED")
                
                // 启动统计收集
                logI("connect: starting collectStats coroutine")
                collectStats()
                
                logI("========== connect SUCCESS ==========")
                
            } catch (e: Exception) {
                logE("connect: EXCEPTION: ${e.message}", e)
                logE("connect: stacktrace:")
                e.stackTrace.forEach { logE("connect:   at $it") }
                
                _connectionState.value = ConnectionState.ERROR
                sendStateChange()
                logI("connect: state changed to ERROR")
                
                logI("connect: calling disconnect()")
                disconnect()
                
                logI("========== connect FAILED ==========")
            }
        }
        
        logI("========== connect END ==========")
    }

    fun disconnect() {
        logI("========== disconnect START ==========")
        logI("disconnect: current state: ${_connectionState.value}")
        
        serviceScope.launch {
            try {
                logI("disconnect: launch started")
                
                logI("disconnect: setting state to DISCONNECTING")
                _connectionState.value = ConnectionState.DISCONNECTING
                sendStateChange()
                logI("disconnect: state change sent")
                
                // 停止 v2ray-core
                logI("disconnect: calling stopV2Ray()")
                stopV2Ray()
                logI("disconnect: v2ray stopped")
                
                // 关闭 VPN 连接
                logI("disconnect: vpnFileDescriptor=$vpnFileDescriptor")
                vpnFileDescriptor?.close()
                vpnFileDescriptor = null
                logI("disconnect: vpnFileDescriptor closed and set to null")
                
                // 停止前台服务
                logI("disconnect: stopping foreground service")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    logI("disconnect: SDK >= N, using stopForeground(STOP_FOREGROUND_REMOVE)")
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    logI("disconnect: SDK < N, using deprecated stopForeground(true)")
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
                logI("disconnect: foreground service stopped")
                
                // 重置统计
                logI("disconnect: resetting statistics")
                uploadSpeed = 0
                downloadSpeed = 0
                totalUpload = 0
                totalDownload = 0
                logI("disconnect: statistics reset")
                
                _connectionState.value = ConnectionState.DISCONNECTED
                sendStateChange()
                logI("disconnect: state changed to DISCONNECTED")
                
                logI("========== disconnect SUCCESS ==========")
                
            } catch (e: Exception) {
                logE("disconnect: EXCEPTION: ${e.message}", e)
                logI("========== disconnect FAILED ==========")
            }
        }
        
        logI("========== disconnect END ==========")
    }

    private suspend fun checkV2RayCore(): Boolean {
        logI("========== checkV2RayCore START ==========")
        
        val v2rayPath = getV2RayPath()
        val file = File(v2rayPath)
        
        logI("checkV2RayCore: v2rayPath=$v2rayPath")
        logI("checkV2RayCore: file.exists()=${file.exists()}")
        
        if (file.exists()) {
            logI("checkV2RayCore: v2ray-core already exists, returning true")
            logI("========== checkV2RayCore END (true) ==========")
            return true
        }
        
        logI("checkV2RayCore: v2ray-core not found, trying to copy from assets")
        logI("========== checkV2RayCore END (calling copyFromAssets) ==========")
        return copyFromAssets()
    }

    private suspend fun copyFromAssets(): Boolean {
        logI("========== copyFromAssets START ==========")
        
        return withContext(Dispatchers.IO) {
            try {
                logI("copyFromAssets: starting")
                val assetManager = assets
                val destDir = filesDir
                val v2rayFile = File(destDir, "v2ray")
                
                logI("copyFromAssets: assetManager=$assetManager")
                logI("copyFromAssets: destDir=$destDir")
                logI("copyFromAssets: v2rayFile=${v2rayFile.absolutePath}")
                
                // 复制 v2ray 主程序
                logI("copyFromAssets: ===== copying v2ray main binary =====")
                try {
                    logI("copyFromAssets: opening assets/v2ray/v2ray")
                    assetManager.open("v2ray/v2ray").use { input ->
                        logI("copyFromAssets: input stream opened")
                        v2rayFile.outputStream().use { output ->
                            logI("copyFromAssets: output stream opened, copying...")
                            input.copyTo(output)
                            logI("copyFromAssets: copy completed")
                        }
                    }
                    logI("copyFromAssets: v2ray binary copied successfully")
                } catch (e: Exception) {
                    logE("copyFromAssets: FAILED to copy v2ray: ${e.message}", e)
                    logI("========== copyFromAssets END (false) ==========")
                    return@withContext false
                }
                
                // 复制 geoip.dat
                logI("copyFromAssets: ===== copying geoip.dat =====")
                try {
                    val geoipFile = File(destDir, "geoip.dat")
                    logI("copyFromAssets: geoipFile=${geoipFile.absolutePath}")
                    assetManager.open("v2ray/geoip.dat").use { input ->
                        geoipFile.outputStream().use { output ->
                            input.copyTo(output)
                        }
                    }
                    logI("copyFromAssets: geoip.dat copied successfully")
                } catch (e: Exception) {
                    logW("copyFromAssets: geoip.dat not found or failed to copy: ${e.message}")
                }
                
                // 复制 geosite.dat
                logI("copyFromAssets: ===== copying geosite.dat =====")
                try {
                    val geositeFile = File(destDir, "geosite.dat")
                    logI("copyFromAssets: geositeFile=${geositeFile.absolutePath}")
                    assetManager.open("v2ray/geosite.dat").use { input ->
                        geositeFile.outputStream().use { output ->
                            input.copyTo(output)
                        }
                    }
                    logI("copyFromAssets: geosite.dat copied successfully")
                } catch (e: Exception) {
                    logW("copyFromAssets: geosite.dat not found or failed to copy: ${e.message}")
                }
                
                logI("copyFromAssets: setting executable permission")
                v2rayFile.setExecutable(true, false)
                
                // 验证复制结果
                logI("copyFromAssets: verifying copy")
                val exists = v2rayFile.exists()
                val canExecute = v2rayFile.canExecute()
                logI("copyFromAssets: exists=$exists, canExecute=$canExecute")
                
                logI("========== copyFromAssets END (true) ==========")
                return@withContext true
            } catch (e: Exception) {
                logE("copyFromAssets: EXCEPTION: ${e.message}", e)
                logI("========== copyFromAssets END (false) ==========")
                return@withContext false
            }
        }
    }

    private suspend fun downloadV2RayCore(): Boolean {
        logI("========== downloadV2RayCore START ==========")
        
        return withContext(Dispatchers.IO) {
            try {
                logI("downloadV2RayCore: starting download")
                
                // 选择合适的 Android 版本
                val arch = System.getProperty("os.arch") ?: "arm64-v8a"
                val url = when {
                    arch.contains("arm64") || arch.contains("aarch64") -> {
                        logI("downloadV2RayCore: detected arm64 architecture")
                        "https://github.com/v2fly/v2ray-core/releases/download/v5.22.0/v2ray-android-arm64-v8a.zip"
                    }
                    arch.contains("arm") -> {
                        logI("downloadV2RayCore: detected arm architecture")
                        "https://github.com/v2fly/v2ray-core/releases/download/v5.22.0/v2ray-android-armeabi-v7a.zip"
                    }
                    arch.contains("86") -> {
                        logI("downloadV2RayCore: detected x86 architecture")
                        "https://github.com/v2fly/v2ray-core/releases/download/v5.22.0/v2ray-android-386.zip"
                    }
                    else -> {
                        logW("downloadV2RayCore: unknown architecture, defaulting to arm64-v8a")
                        "https://github.com/v2fly/v2ray-core/releases/download/v5.22.0/v2ray-android-arm64-v8a.zip"
                    }
                }
                
                logI("downloadV2RayCore: URL=$url")
                
                val destDir = filesDir
                val zipFile = File(cacheDir, "v2ray.zip")
                val v2rayFile = File(destDir, "v2ray")
                
                logI("downloadV2RayCore: destDir=$destDir")
                logI("downloadV2RayCore: zipFile=${zipFile.absolutePath}")
                logI("downloadV2RayCore: v2rayFile=${v2rayFile.absolutePath}")
                
                // 使用 HttpURLConnection 下载
                logI("downloadV2RayCore: opening connection")
                val conn = java.net.URL(url).openConnection() as java.net.HttpURLConnection
                conn.connectTimeout = 60000
                conn.readTimeout = 60000
                conn.requestMethod = "GET"
                logI("downloadV2RayCore: connection opened, responseCode=${conn.responseCode}")
                
                val fileLength = conn.contentLength
                logI("downloadV2RayCore: fileLength=$fileLength")
                
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
                                logD("downloadV2RayCore: progress=$progress%")
                            }
                        }
                    }
                }
                conn.disconnect()
                
                logI("downloadV2RayCore: download completed, total=$total bytes")
                
                // 解压 zip 文件
                logI("downloadV2RayCore: extracting zip")
                java.util.zip.ZipFile(zipFile).use { zip ->
                    logI("downloadV2RayCore: zip entries=${zip.size()}")
                    val entry = zip.getEntry("v2ray")
                    logI("downloadV2RayCore: v2ray entry=$entry")
                    
                    if (entry != null) {
                        zip.getInputStream(entry).use { input ->
                            v2rayFile.outputStream().use { output ->
                                input.copyTo(output)
                            }
                        }
                        logI("downloadV2RayCore: v2ray extracted")
                    } else {
                        logW("downloadV2RayCore: v2ray entry not found in zip")
                    }
                }
                
                // 删除 zip 文件
                logI("downloadV2RayCore: deleting zip file")
                zipFile.delete()
                
                // 设置可执行权限
                logI("downloadV2RayCore: setting executable permission")
                v2rayFile.setExecutable(true)
                
                logI("========== downloadV2RayCore END (true) ==========")
                return@withContext true
                
            } catch (e: Exception) {
                logE("downloadV2RayCore: EXCEPTION: ${e.message}", e)
                logI("========== downloadV2RayCore END (false) ==========")
                return@withContext false
            }
        }
    }

    private fun generateConfig(config: Map<String, Any>?): String {
        logI("========== generateConfig START ==========")
        logI("generateConfig: input config=$config")
        
        // 解析配置参数
        val protocol = (config?.get("protocol") as? String) ?: "vmess"
        val address = (config?.get("address") as? String) ?: ""
        val port = (config?.get("port") as? Int) ?: 443
        val uuid = (config?.get("uuid") as? String) ?: ""
        val security = (config?.get("security") as? String) ?: "auto"
        val network = (config?.get("network") as? String) ?: "tcp"
        
        logI("generateConfig: parsed parameters:")
        logI("generateConfig:   protocol=$protocol")
        logI("generateConfig:   address=$address")
        logI("generateConfig:   port=$port")
        logI("generateConfig:   uuid=$uuid")
        logI("generateConfig:   security=$security")
        logI("generateConfig:   network=$network")
        
        val useTls = port == 443
        val streamSecurity = if (useTls) "tls" else "none"
        
        logI("generateConfig: derived values:")
        logI("generateConfig:   useTls=$useTls")
        logI("generateConfig:   streamSecurity=$streamSecurity")
        logI("generateConfig:   PROXY_PORT=$PROXY_PORT")
        
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
            append("\"protocol\":\"$protocol\",")
            append("\"settings\":{")
            append("\"vnext\":[{")
            append("\"address\":\"$address\",")
            append("\"port\":$port,")
            append("\"users\":[{\"id\":\"$uuid\",\"security\":\"$security\"}]")
            append("}]},")
            append("\"streamSettings\":{")
            append("\"network\":\"$network\",")
            append("\"security\":\"$streamSecurity\"")
            append("},")
            append("\"tag\":\"proxy\"")
            append("}")
            append("]")
            append("}")
        }
        
        logI("generateConfig: JSON length=${configJson.length}")
        logD("generateConfig: JSON=$configJson")
        
        val configFile = File(filesDir, "config.json")
        logI("generateConfig: configFile=${configFile.absolutePath}")
        
        logI("generateConfig: writing JSON to file")
        configFile.writeText(configJson)
        logI("generateConfig: file write completed")
        
        // 验证文件写入
        val exists = configFile.exists()
        val length = configFile.length()
        logI("generateConfig: verification: exists=$exists, length=$length")
        
        logI("========== generateConfig END ==========")
        return configFile.absolutePath
    }

    private fun getV2RayPath(): String {
        val path = File(filesDir, "v2ray").absolutePath
        logI("getV2RayPath: returning $path")
        return path
    }

    private fun startV2Ray(configPath: String) {
        logI("========== startV2Ray START ==========")
        logI("startV2Ray: configPath=$configPath")
        
        val v2rayPath = getV2RayPath()
        logI("startV2Ray: v2rayPath=$v2rayPath")
        
        val v2rayFile = File(v2rayPath)
        logI("startV2Ray: v2rayFile.exists()=${v2rayFile.exists()}")
        logI("startV2Ray: v2rayFile.canExecute()=${v2rayFile.canExecute()}")
        
        val command = arrayOf(
            v2rayPath,
            "-config=$configPath"
        )
        
        logI("startV2Ray: command=${command.joinToString(" ")}")
        
        try {
            val processBuilder = ProcessBuilder(*command)
            processBuilder.redirectErrorStream(true)
            logI("startV2Ray: ProcessBuilder created")
            
            logI("startV2Ray: calling processBuilder.start()")
            v2rayProcess = processBuilder.start()
            logI("startV2Ray: process started")
            
            // 读取 v2ray 输出
            logI("startV2Ray: starting output reader thread")
            v2rayProcess?.inputStream?.bufferedReader()?.forEachLine { line ->
                logD("v2ray: $line")
            }
            logI("startV2Ray: output reader finished")
            
        } catch (e: Exception) {
            logE("startV2Ray: EXCEPTION: ${e.message}", e)
        }
        
        logI("========== startV2Ray END ==========")
    }

    private fun stopV2Ray() {
        logI("========== stopV2Ray START ==========")
        logI("stopV2Ray: v2rayProcess=$v2rayProcess")
        
        try {
            v2rayProcess?.let { process ->
                logI("stopV2Ray: calling process.destroy()")
                process.destroy()
                logI("stopV2Ray: process.destroy() called")
                
                logI("stopV2Ray: waiting for process to exit")
                val exitCode = process.waitFor()
                logI("stopV2Ray: process exited with code=$exitCode")
            } ?: run {
                logI("stopV2Ray: v2rayProcess is null, nothing to stop")
            }
        } catch (e: Exception) {
            logE("stopV2Ray: EXCEPTION: ${e.message}", e)
        }
        
        v2rayProcess = null
        logI("stopV2Ray: v2rayProcess set to null")
        
        logI("========== stopV2Ray END ==========")
    }

    private suspend fun testConnection(): Boolean {
        logI("========== testConnection START ==========")
        
        return withContext(Dispatchers.IO) {
            try {
                logI("testConnection: creating socket")
                val socket = java.net.Socket()
                logI("testConnection: socket created")
                
                logI("testConnection: connecting to 8.8.8.8:53 with timeout 5000ms")
                socket.connect(InetSocketAddress("8.8.8.8", 53), 5000)
                logI("testConnection: connected successfully")
                
                logI("testConnection: closing socket")
                socket.close()
                logI("testConnection: socket closed")
                
                logI("========== testConnection END (true) ==========")
                return@withContext true
                
            } catch (e: Exception) {
                logE("testConnection: EXCEPTION: ${e.message}", e)
                logI("========== testConnection END (false) ==========")
                return@withContext false
            }
        }
    }

    private suspend fun collectStats() {
        logI("========== collectStats START ==========")
        logI("collectStats: starting in while loop")
        
        // TrafficStats 返回的是累计值，需要记录初始值
        logI("collectStats: getting initial traffic stats")
        val initialRx = android.net.TrafficStats.getUidRxBytes(applicationInfo.uid)
        val initialTx = android.net.TrafficStats.getUidTxBytes(applicationInfo.uid)
        var lastRx = initialRx
        var lastTx = initialTx
        
        logI("collectStats: initialRx=$initialRx, initialTx=$initialTx")
        
        // 会话累计流量
        var sessionRx: Long = 0
        var sessionTx: Long = 0
        
        var loopCount = 0
        while (_connectionState.value == ConnectionState.CONNECTED) {
            loopCount++
            logD("collectStats: loop #$loopCount")
            
            try {
                // 获取当前累计流量
                val currentRx = android.net.TrafficStats.getUidRxBytes(applicationInfo.uid)
                val currentTx = android.net.TrafficStats.getUidTxBytes(applicationInfo.uid)
                
                logD("collectStats: currentRx=$currentRx, currentTx=$currentTx")
                
                // 计算本次间隔的流量
                val deltaRx = currentRx - lastRx
                val deltaTx = currentTx - lastTx
                
                logD("collectStats: deltaRx=$deltaRx, deltaTx=$deltaTx")
                
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
                
                logD("collectStats: sessionRx=$sessionRx, sessionTx=$sessionTx")
                logD("collectStats: uploadSpeed=$uploadSpeed, downloadSpeed=$downloadSpeed")
                logD("collectStats: totalUpload=$totalUpload, totalDownload=$totalDownload")
                
                // 发送统计更新
                logD("collectStats: sending stats update")
                sendStatsUpdate()
                
                delay(1000)
                
            } catch (e: Exception) {
                logE("collectStats: loop #$loopCount EXCEPTION: ${e.message}", e)
                delay(1000)
            }
        }
        
        logI("collectStats: loop ended, loopCount=$loopCount")
        logI("collectStats: final state: ${_connectionState.value}")
        logI("========== collectStats END ==========")
    }

    private val _statsFlow = MutableStateFlow(mapOf<String, Long>(
        "uploadSpeed" to 0,
        "downloadSpeed" to 0,
        "totalUpload" to 0,
        "totalDownload" to 0
    ))
    val statsFlow: StateFlow<Map<String, Long>> = _statsFlow.asStateFlow()

    private fun sendStatsUpdate() {
        logD("========== sendStatsUpdate START ==========")
        logD("sendStatsUpdate: uploadSpeed=$uploadSpeed")
        logD("sendStatsUpdate: downloadSpeed=$downloadSpeed")
        logD("sendStatsUpdate: totalUpload=$totalUpload")
        logD("sendStatsUpdate: totalDownload=$totalDownload")
        
        _statsFlow.value = mapOf(
            "uploadSpeed" to uploadSpeed,
            "downloadSpeed" to downloadSpeed,
            "totalUpload" to totalUpload,
            "totalDownload" to totalDownload
        )
        
        // 发送广播
        logD("sendStatsUpdate: creating broadcast intent")
        val intent = Intent(ACTION_STATS_UPDATE).apply {
            putExtra(EXTRA_UPLOAD_SPEED, uploadSpeed)
            putExtra(EXTRA_DOWNLOAD_SPEED, downloadSpeed)
            putExtra(EXTRA_TOTAL_UPLOAD, totalUpload)
            putExtra(EXTRA_TOTAL_DOWNLOAD, totalDownload)
            putExtra(EXTRA_CONNECTION_STATE, _connectionState.value.name)
        }
        logD("sendStatsUpdate: calling sendBroadcast()")
        sendBroadcast(intent)
        logD("sendStatsUpdate: broadcast sent")
        
        // 直接调用回调发送到 Flutter
        logD("sendStatsUpdate: invoking onStatsUpdate callback")
        onStatsUpdate?.invoke(mapOf(
            "uploadSpeed" to uploadSpeed,
            "downloadSpeed" to downloadSpeed,
            "totalUpload" to totalUpload,
            "totalDownload" to totalDownload
        ))
        logD("sendStatsUpdate: callback invoked")
        
        logD("========== sendStatsUpdate END ==========")
    }

    private fun sendStateChange() {
        logD("========== sendStateChange START ==========")
        
        val state = _connectionState.value.name
        logD("sendStateChange: state=$state")
        
        val intent = Intent(ACTION_STATE_CHANGE).apply {
            putExtra(EXTRA_CONNECTION_STATE, state)
        }
        logD("sendStateChange: calling sendBroadcast()")
        sendBroadcast(intent)
        logD("sendStateChange: broadcast sent")
        
        logD("sendStateChange: invoking onStateChange callback with state=$state")
        onStateChange?.invoke(state)
        logD("sendStateChange: callback invoked")
        
        logD("========== sendStateChange END ==========")
    }

    // 供 MainActivity 调用的获取统计方法
    fun getStats(): Map<String, Long> {
        logD("getStats: returning current stats")
        logD("getStats: uploadSpeed=$uploadSpeed")
        logD("getStats: downloadSpeed=$downloadSpeed")
        logD("getStats: totalUpload=$totalUpload")
        logD("getStats: totalDownload=$totalDownload")
        
        return mapOf(
            "uploadSpeed" to uploadSpeed,
            "downloadSpeed" to downloadSpeed,
            "totalUpload" to totalUpload,
            "totalDownload" to totalDownload
        )
    }
}
