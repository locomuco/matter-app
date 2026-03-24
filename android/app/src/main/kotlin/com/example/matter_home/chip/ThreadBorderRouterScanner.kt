package com.example.matter_home.chip

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.util.Log
import kotlinx.coroutines.delay
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.atomic.AtomicBoolean

object ThreadBorderRouterScanner {

    private const val TAG          = "ThreadBRScanner"
    private const val SERVICE_TYPE = "_meshcop._udp"
    private const val SCAN_MS      = 6_000L

    data class BorderRouterInfo(
        val serviceName: String,
        val networkName: String,
        val extPanId:    String,
        val vendorName:  String,
        val modelName:   String,
        val host:        String,
        val port:        Int,
        val txt:         Map<String, String> = emptyMap(),
    )

    suspend fun scan(context: Context): List<BorderRouterInfo> {
        val nsd    = context.getSystemService(Context.NSD_SERVICE) as NsdManager
        val wifi   = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val lock   = wifi.createMulticastLock("thread_scan").also { it.acquire() }

        val found         = ConcurrentHashMap<String, BorderRouterInfo>()
        val queue         = LinkedBlockingQueue<NsdServiceInfo>()
        val resolveActive = AtomicBoolean(false)

        fun ByteArray.hex() = joinToString("") { "%02x".format(it) }
        fun ByteArray.str() = try { toString(Charsets.UTF_8) } catch (_: Exception) { hex() }
        fun ByteArray.isPrintable() = all { it in 0x20..0x7E }

        fun resolveNext() {
            val svc = queue.poll() ?: run { resolveActive.set(false); return }
            nsd.resolveService(svc, object : NsdManager.ResolveListener {
                override fun onResolveFailed(s: NsdServiceInfo?, err: Int) {
                    Log.w(TAG, "Resolve failed err=$err for ${s?.serviceName}")
                    resolveNext()
                }
                override fun onServiceResolved(info: NsdServiceInfo) {
                    val a    = info.attributes
                    val nn   = a["nn"]?.str()?.ifEmpty { info.serviceName } ?: info.serviceName
                    val xp   = a["xp"]?.hex() ?: ""
                    val vn   = a["vn"]?.str() ?: ""
                    val mn   = a["mn"]?.str() ?: ""
                    val host = info.host?.hostAddress ?: ""

                    // Collect all TXT record fields, decoding printable ones as
                    // UTF-8 and binary ones as hex.
                    val txt  = a.entries.associate { (k, v) ->
                        k to (if (v.isPrintable()) v.str() else v.hex())
                    }

                    Log.d(TAG, "✓ Resolved: nn=$nn xp=$xp host=$host port=${info.port} vn=$vn mn=$mn")
                    found[info.serviceName] = BorderRouterInfo(
                        serviceName = info.serviceName,
                        networkName = nn,
                        extPanId    = xp,
                        vendorName  = vn,
                        modelName   = mn,
                        host        = host,
                        port        = info.port,
                        txt         = txt,
                    )
                    resolveNext()
                }
            })
        }

        val listener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(t: String)             { Log.d(TAG, "started $t") }
            override fun onDiscoveryStopped(t: String)             { Log.d(TAG, "stopped $t") }
            override fun onStartDiscoveryFailed(t: String, e: Int) { Log.w(TAG, "start failed e=$e") }
            override fun onStopDiscoveryFailed(t: String, e: Int)  { Log.w(TAG, "stop failed e=$e") }
            override fun onServiceLost(s: NsdServiceInfo)          { Log.d(TAG, "lost ${s.serviceName}") }
            override fun onServiceFound(s: NsdServiceInfo) {
                Log.d(TAG, "found ${s.serviceName}")
                queue.put(s)
                if (resolveActive.compareAndSet(false, true)) resolveNext()
            }
        }

        nsd.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, listener)
        delay(SCAN_MS)
        try { nsd.stopServiceDiscovery(listener) } catch (e: Exception) {
            Log.w(TAG, "stopDiscovery: ${e.message}")
        }
        lock.release()

        Log.i(TAG, "Scan complete – ${found.size} border router(s)")
        return found.values.sortedBy { it.networkName }
    }
}
