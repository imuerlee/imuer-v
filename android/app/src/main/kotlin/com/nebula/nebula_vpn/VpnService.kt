package com.nebula.nebula_vpn

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import com.nebula.nebula_vpn.MainActivity
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import java.nio.ByteBuffer
import kotlin.concurrent.thread

class VpnService : VpnService() {
    
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
        const val PROXY_HOST = "127.0.0.1"
        const val PROXY_PORT = 10808
        
        private var instance: com.nebula.nebula_vpn.VpnService? = null
        
        fun logI(msg: String) { Log.i(TAG, "[I] $msg") }
        fun logE(msg: String) { Log.e(TAG, "[E] $msg") }
        fun logE(msg: String, e: Exception) { Log.e(TAG, "[E] $msg", e) }
        fun logD(msg: String) { Log.d(TAG, "[D] $msg") }
        
        @Volatile
        private var isRunning = false
        
        fun getInstance(): com.nebula.nebula_vpn.VpnService? = instance
        fun isRunning(): Boolean = isRunning
        
        // Callbacks for MainActivity
        var onStatsUpdate: ((Map<String, Long>) -> Unit)? = null
        var onStateChange: ((String) -> Unit)? = null
    }
    
    enum class ConnectionState {
        DISCONNECTED,
        CONNECTING,
        CONNECTED,
        DISCONNECTING,
        ERROR
    }
    
    private var vpnInterface: ParcelFileDescriptor? = null
    private var forwarderThread: Thread? = null
    private var statsThread: Thread? = null
    private var v2rayProcess: Process? = null
    
    private var uploadSpeed: Long = 0
    private var downloadSpeed: Long = 0
    private var totalUpload: Long = 0
    private var totalDownload: Long = 0
    private var lastUpload: Long = 0
    private var lastDownload: Long = 0
    
    private val _connectionState = ConnectionState.DISCONNECTED
    val connectionState: ConnectionState get() = _connectionState
    
    fun getStats(): Map<String, Long> = mapOf(
        "uploadSpeed" to uploadSpeed,
        "downloadSpeed" to downloadSpeed,
        "totalUpload" to totalUpload,
        "totalDownload" to totalDownload
    )
    
    private var serverConfig: Map<String, Any>? = null
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        logI("VpnService onCreate")
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        logI("onStartCommand: action=${intent?.action}")
        
        when (intent?.action) {
            ACTION_CONNECT -> {
                @Suppress("UNCHECKED_CAST")
                val config = intent.getSerializableExtra("config") as? Map<String, Any>
                logI("onStartCommand: CONNECT with config=$config")
                serverConfig = config
                startForeground(NOTIFICATION_ID, createNotification("Nebula VPN", "Connecting..."))
                startVpn(config)
            }
            ACTION_DISCONNECT -> {
                logI("onStartCommand: DISCONNECT")
                stopVpn()
            }
        }
        
        return START_STICKY
    }
    
    override fun onDestroy() {
        logI("VpnService onDestroy")
        stopVpn()
        instance = null
        super.onDestroy()
    }
    
    override fun onBind(intent: Intent?): android.os.IBinder? {
        return null
    }
    
    private fun startVpn(config: Map<String, Any>?) {
        logI("========== startVpn START ==========")
        
        if (isRunning) {
            logI("startVpn: already running")
            return
        }
        
        isRunning = true
        
        thread {
            try {
                // Step 1: Copy v2ray binary
                logI("startVpn: Step 1 - Copying v2ray binary")
                copyV2RayBinary()
                
                // Step 2: Generate v2ray config
                logI("startVpn: Step 2 - Generating v2ray config")
                val configPath = generateV2RayConfig(config)
                
                // Step 3: Start v2ray
                logI("startVpn: Step 3 - Starting v2ray")
                startV2Ray(configPath)
                
                // Step 4: Create VPN interface
                logI("startVpn: Step 4 - Creating VPN interface")
                createVpnInterface()
                
                // Step 5: Start traffic forwarding
                logI("startVpn: Step 5 - Starting traffic forwarder")
                startTrafficForwarder()
                
                // Step 6: Start stats
                logI("startVpn: Step 6 - Starting stats")
                startStatsCollection()
                
                logI("startVpn: VPN started successfully!")
                updateNotification("Nebula VPN", "Connected")
                
            } catch (e: Exception) {
                logE("startVpn: Exception: ${e.message}", e)
                isRunning = false
                updateNotification("Nebula VPN", "Error: ${e.message}")
                stopSelf()
            }
        }
        
        logI("========== startVpn END ==========")
    }
    
    private fun copyV2RayBinary() {
        logI("copyV2RayBinary: Checking v2ray binary")
        
        val v2rayFile = File(filesDir, "v2ray")
        
        if (v2rayFile.exists() && v2rayFile.canExecute()) {
            logI("copyV2RayBinary: v2ray already exists")
            return
        }
        
        logI("copyV2RayBinary: Copying v2ray from assets")
        
        try {
            assets.open("v2ray/v2ray").use { input ->
                FileOutputStream(v2rayFile).use { output ->
                    input.copyTo(output)
                }
            }
            v2rayFile.setExecutable(true)
            logI("copyV2RayBinary: v2ray copied successfully")
        } catch (e: Exception) {
            logE("copyV2RayBinary: Failed to copy v2ray: ${e.message}", e)
            throw e
        }
    }
    
    private fun generateV2RayConfig(config: Map<String, Any>?): String {
        logI("generateV2RayConfig: Generating v2ray configuration")
        
        val protocol = (config?.get("protocol") as? String) ?: "vmess"
        val address = (config?.get("address") as? String) ?: ""
        val port = (config?.get("port") as? Int) ?: 443
        val uuid = (config?.get("uuid") as? String) ?: ""
        val security = (config?.get("security") as? String) ?: "auto"
        val network = (config?.get("network") as? String) ?: "tcp"
        
        logI("generateV2RayConfig: protocol=$protocol, address=$address, port=$port")
        logI("generateV2RayConfig: uuid=$uuid, security=$security, network=$network")
        
        val useTls = port == 443
        val streamSecurity = if (useTls) "tls" else "none"
        
        val configJson = """
        {
            "log": {
                "loglevel": "warning"
            },
            "dns": {
                "servers": ["8.8.8.8", "1.1.1.1"]
            },
            "inbounds": [{
                "tag": "socks-in",
                "port": $PROXY_PORT,
                "protocol": "socks",
                "settings": {
                    "auth": "noauth",
                    "udp": true,
                    "ip": "127.0.0.1"
                }
            }],
            "outbounds": [{
                "protocol": "$protocol",
                "settings": {
                    "vnext": [{
                        "address": "$address",
                        "port": $port,
                        "users": [{"id": "$uuid", "security": "$security"}]
                    }]
                },
                "streamSettings": {
                    "network": "$network",
                    "security": "$streamSecurity"
                },
                "tag": "proxy"
            }, {
                "protocol": "freedom",
                "tag": "direct"
            }],
            "routing": {
                "domainStrategy": "IPIfNonMatch",
                "rules": [{
                    "type": "field",
                    "ip": ["geoip:private"],
                    "outboundTag": "direct"
                }]
            }
        }
        """.trimIndent()
        
        val configFile = File(filesDir, "config.json")
        configFile.writeText(configJson)
        
        logI("generateV2RayConfig: Config written to ${configFile.absolutePath}")
        
        return configFile.absolutePath
    }
    
    private fun startV2Ray(configPath: String) {
        logI("startV2Ray: Starting v2ray")
        
        val v2rayPath = File(filesDir, "v2ray").absolutePath
        val v2rayFile = File(v2rayPath)
        
        if (!v2rayFile.exists()) {
            throw Exception("v2ray binary not found at $v2rayPath")
        }
        
        val command = arrayOf(v2rayPath, "-config=$configPath")
        logI("startV2Ray: command=${command.joinToString(" ")}")
        
        val processBuilder = ProcessBuilder(*command)
        processBuilder.redirectErrorStream(true)
        processBuilder.directory(filesDir)
        
        v2rayProcess = processBuilder.start()
        logI("startV2Ray: v2ray process started")
        
        // Read output in background
        thread {
            try {
                v2rayProcess?.inputStream?.bufferedReader()?.forEachLine { line ->
                    Log.d(TAG, "v2ray: $line")
                }
            } catch (e: Exception) {
                Log.e(TAG, "v2ray output reader exception: ${e.message}")
            }
        }
        
        // Wait for v2ray to start
        Thread.sleep(2000)
        
        if (v2rayProcess?.isAlive != true) {
            val exitCode = v2rayProcess?.exitValue() ?: -1
            logE("startV2Ray: v2ray failed to start, exit code: $exitCode")
            throw Exception("v2ray failed to start, exit code: $exitCode")
        }
        
        logI("startV2Ray: v2ray is running")
    }
    
    private fun createVpnInterface() {
        logI("createVpnInterface: Creating VPN interface")
        
        val builder = Builder()
            .addAddress(VPN_ADDRESS, 24)
            .addAddress(VPN_ADDRESS_V6, 64)
            .addDnsServer(DNS_SERVER)
            .addRoute("0.0.0.0", 0)
            .addRoute("::", 0)
            .setSession("NebulaVPN")
            .setBlocking(true)
            .setMtu(1500)
        
        builder.addDisallowedApplication(packageName)
        
        vpnInterface = builder.establish()
        
        if (vpnInterface == null) {
            throw Exception("Failed to establish VPN interface")
        }
        
        logI("createVpnInterface: VPN interface created successfully")
    }
    
    private fun startTrafficForwarder() {
        logI("startTrafficForwarder: Starting TUN-to-SOCKS forwarder")
        
        val vpnFd = vpnInterface ?: throw Exception("VPN interface not created")
        
        forwarderThread = thread {
            try {
                val inputStream = FileInputStream(vpnFd.fileDescriptor)
                val outputStream = FileOutputStream(vpnFd.fileDescriptor)
                val buffer = ByteBuffer.allocate(32767)
                
                logI("startTrafficForwarder: Forwarder loop started")
                
                while (isRunning) {
                    try {
                        buffer.clear()
                        val length = inputStream.read(buffer.array())
                        
                        if (length > 0) {
                            totalUpload += length
                            
                            // Parse IP header
                            val version = (buffer.array()[0].toInt() shr 4) and 0xF
                            
                            if (version == 4) {
                                // IPv4
                                val destIp = extractIpv4Dest(buffer.array())
                                val destPort = extractTcpPort(buffer.array(), length)
                                val protocol = buffer.array()[9].toInt() and 0xFF
                                
                                logD("startTrafficForwarder: IPv4 packet, proto=$protocol, dest=$destIp:$destPort, len=$length")
                                
                                if (protocol == 6) { // TCP
                                    forwardTcpPacket(buffer.array(), length, outputStream)
                                }
                            } else if (version == 6) {
                                // IPv6
                                val destIp = extractIpv6Dest(buffer.array())
                                val destPort = extractTcpPort(buffer.array(), length)
                                logD("startTrafficForwarder: IPv6 packet, dest=$destIp:$destPort, len=$length")
                            }
                        }
                    } catch (e: Exception) {
                        if (isRunning) {
                            logE("startTrafficForwarder: Exception: ${e.message}", e)
                        }
                    }
                }
                
                logI("startTrafficForwarder: Forwarder loop ended")
                
            } catch (e: Exception) {
                logE("startTrafficForwarder: Exception: ${e.message}", e)
            }
        }
    }
    
    private fun extractIpv4Dest(packet: ByteArray): String {
        if (packet.size < 20) return "0.0.0.0"
        return "${packet[16].toInt() and 0xFF}.${packet[17].toInt() and 0xFF}.${packet[18].toInt() and 0xFF}.${packet[19].toInt() and 0xFF}"
    }
    
    private fun extractIpv6Dest(packet: ByteArray): String {
        if (packet.size < 40) return "::"
        val sb = StringBuilder()
        for (i in 24..39 step 2) {
            if (sb.isNotEmpty()) sb.append(":")
            sb.append(String.format("%x", ((packet[i].toInt() and 0xFF) shl 8) or (packet[i+1].toInt() and 0xFF)))
        }
        return sb.toString()
    }
    
    private fun extractTcpPort(packet: ByteArray, length: Int): Int {
        if (length < 24) return 0
        return ((packet[22].toInt() and 0xFF) shl 8) or (packet[23].toInt() and 0xFF)
    }
    
    private fun forwardTcpPacket(packet: ByteArray, length: Int, tunOutput: FileOutputStream) {
        var socket: Socket? = null
        try {
            val destIp = extractIpv4Dest(packet)
            val destPort = extractTcpPort(packet, length)
            
            // Connect to v2ray SOCKS proxy
            socket = Socket()
            socket.connect(InetSocketAddress(PROXY_HOST, PROXY_PORT), 5000)
            socket.soTimeout = 10000
            
            val socksOut = socket.getOutputStream()
            val socksIn = socket.getInputStream()
            
            // Build SOCKS5 CONNECT request
            val ipParts = destIp.split(".").map { it.toInt().toByte() }
            val portBytes = byteArrayOf(
                (destPort shr 8).toByte(),
                (destPort and 0xFF).toByte()
            )
            
            // SOCKS5 CONNECT: VER(1) + CMD(1) + RSV(1) + ATYP(1) + DST.ADDR + DST.PORT
            val connectRequest = byteArrayOf(
                0x05,  // SOCKS version
                0x01,  // CMD: CONNECT
                0x00,  // RSV
                0x01   // ATYP: IPv4
            ) + ipParts.toByteArray() + portBytes
            
            socksOut.write(connectRequest)
            socksOut.flush()
            
            // Read SOCKS response
            val response = ByteArray(10)
            val respLen = socksIn.read(response)
            
            if (respLen < 2 || response[1].toInt() != 0x00) {
                logE("forwardTcpPacket: SOCKS CONNECT failed, response=${response.contentToString()}")
                return
            }
            
            // Extract TCP header length to find data payload
            val ihl = (packet[0].toInt() and 0x0F) * 4
            val tcpDataLen = length - ihl
            
            if (tcpDataLen > 0) {
                // Send data after TCP header
                socksOut.write(packet, ihl, tcpDataLen)
                socksOut.flush()
            }
            
            // Read response from SOCKS proxy
            val responseBuffer = ByteBuffer.allocate(65535)
            val responseLength = socksIn.read(responseBuffer.array())
            
            if (responseLength > 0) {
                totalDownload += responseLength
                
                // Build response packet (simplified - just copy data back)
                // In a real implementation, we would rebuild the IP/TCP headers
                responseBuffer.limit(responseLength)
            }
            
        } catch (e: Exception) {
            logE("forwardTcpPacket: Exception: ${e.message}", e)
        } finally {
            try {
                socket?.close()
            } catch (e: Exception) {}
        }
    }
    
    private fun startStatsCollection() {
        statsThread = thread {
            while (isRunning) {
                try {
                    Thread.sleep(1000)
                    logD("stats: totalUp=$totalUpload, totalDown=$totalDownload")
                } catch (e: Exception) {
                    if (isRunning) {
                        logE("stats: Exception: ${e.message}", e)
                    }
                }
            }
        }
    }
    
    private fun stopVpn() {
        logI("========== stopVpn START ==========")
        
        isRunning = false
        
        try {
            forwarderThread?.interrupt()
            statsThread?.interrupt()
            v2rayProcess?.destroy()
            vpnInterface?.close()
        } catch (e: Exception) {
            logE("stopVpn: Exception: ${e.message}", e)
        }
        
        totalUpload = 0
        totalDownload = 0
        
        updateNotification("Nebula VPN", "Disconnected")
        
        logI("========== stopVpn END ==========")
        
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }
    
    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            "Nebula VPN",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "VPN connection status"
        }
        
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(channel)
    }
    
    private fun createNotification(title: String, content: String): android.app.Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
    
    private fun updateNotification(title: String, content: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, createNotification(title, content))
    }
}
