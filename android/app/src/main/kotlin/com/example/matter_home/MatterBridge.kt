package com.example.matter_home

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.example.matter_home.chip.ChipClient
import com.example.matter_home.chip.ClusterClient
import com.example.matter_home.chip.MatterCommissioner
import com.example.matter_home.chip.SetupPayloadHelper
import com.example.matter_home.chip.AndroidThreadCredentialReader
import com.example.matter_home.chip.ThreadBorderRouterScanner
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class MatterBridge(private val context: Context) {

    companion object {
        private const val TAG = "MatterBridge"
    }

    private val main  = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // ── EventChannel sink (set by MainActivity) ───────────────────────────────
    @Volatile private var eventSink: EventChannel.EventSink? = null

    fun setEventSink(sink: EventChannel.EventSink?) { eventSink = sink }

    fun emitEvent(msg: String) {
        main.post { eventSink?.success(msg) }
    }

    // ── Guard: require real CHIP SDK ──────────────────────────────────────────
    private fun requireChip(result: MethodChannel.Result, block: suspend () -> Unit) {
        if (!ChipClient.isAvailable) {
            result.error(
                "CHIP_SDK_UNAVAILABLE",
                "The CHIP SDK is not loaded. Place CHIPController.aar in android/app/libs/ and rebuild.",
                null,
            )
            return
        }
        scope.launch {
            try { block() } catch (e: Exception) {
                Log.e(TAG, "CHIP call failed", e)
                main.post { result.error("CHIP_ERROR", e.message, null) }
            }
        }
    }

    // ── ping ──────────────────────────────────────────────────────────────────

    fun ping(result: MethodChannel.Result) = result.success(true)

    // ── Commission via BLE ────────────────────────────────────────────────────

    fun commissionDevice(
        payload: String,
        wifiSsid: String?,
        wifiPassword: String?,
        threadDatasetHex: String?,
        nodeId: Long,
        result: MethodChannel.Result,
    ) = requireChip(result) {
        val parsed = SetupPayloadHelper.parse(payload)
        val threadDataset = threadDatasetHex
            ?.filter { it.isLetterOrDigit() }
            ?.chunked(2)
            ?.map { it.toInt(16).toByte() }
            ?.toByteArray()
        val commissionedNodeId = MatterCommissioner.commission(
            context          = context,
            payload          = parsed,
            wifiSsid         = wifiSsid,
            wifiPassword     = wifiPassword,
            threadDatasetTlv = threadDataset,
            nodeId           = nodeId,
            onEvent          = { msg -> Log.i(TAG, msg); emitEvent(msg) },
        )
        val deviceTypeId = readPrimaryDeviceType(commissionedNodeId)
        main.post {
            result.success(mapOf("nodeId" to commissionedNodeId.toInt(), "deviceTypeId" to deviceTypeId))
        }
    }

    // ── Commission via IP ─────────────────────────────────────────────────────

    fun commissionViaIp(
        ipAddress: String,
        port: Int,
        discriminator: Int,
        setupPinCode: Long,
        nodeId: Long,
        result: MethodChannel.Result,
    ) = requireChip(result) {
        val commissionedNodeId = MatterCommissioner.commissionViaIp(
            context       = context,
            ipAddress     = ipAddress,
            port          = port,
            discriminator = discriminator,
            setupPinCode  = setupPinCode,
            nodeId        = nodeId,
            onEvent       = { msg -> Log.i(TAG, msg); emitEvent(msg) },
        )
        val deviceTypeId = readPrimaryDeviceType(commissionedNodeId)
        main.post {
            result.success(mapOf("nodeId" to commissionedNodeId.toInt(), "deviceTypeId" to deviceTypeId))
        }
    }

    // ── On/Off ────────────────────────────────────────────────────────────────

    fun toggleDevice(nodeId: Long, on: Boolean, result: MethodChannel.Result) =
        requireChip(result) {
            ClusterClient.setOnOff(context, nodeId, on)
            main.post { result.success(true) }
        }

    // ── Level control ─────────────────────────────────────────────────────────

    fun setLevel(nodeId: Long, level: Int, result: MethodChannel.Result) =
        requireChip(result) {
            ClusterClient.moveToLevel(context, nodeId, level)
            main.post { result.success(true) }
        }

    // ── Read device state ─────────────────────────────────────────────────────

    fun readDeviceState(nodeId: Long, result: MethodChannel.Result) =
        requireChip(result) {
            try {
                val on = ClusterClient.readOnOff(context, nodeId)
                main.post {
                    result.success(mapOf("isOnline" to true, "isOn" to on, "brightness" to 254))
                }
            } catch (e: Exception) {
                Log.w(TAG, "readDeviceState offline? nodeId=$nodeId: ${e.message}")
                main.post { result.success(mapOf("isOnline" to false)) }
            }
        }

    // ── Multi-admin / share ───────────────────────────────────────────────────

    fun openCommissioningWindow(nodeId: Long, result: MethodChannel.Result) =
        requireChip(result) {
            // TODO: AdministratorCommissioning cluster openCommissioningWindow
            main.post { result.success(true) }
        }

    // ── Remove ───────────────────────────────────────────────────────────────

    fun removeDevice(nodeId: Long, result: MethodChannel.Result) =
        requireChip(result) {
            ChipClient.getController().unpairDevice(nodeId)
            main.post { result.success(true) }
        }

    // ── Thread credential store ───────────────────────────────────────────────

    // NOTE: requestPreferredCredentials is called directly from MainActivity
    //       (needs Activity reference for startIntentSenderForResult).

    // ── Thread Border Router discovery ───────────────────────────────────────

    fun discoverThreadNetworks(result: MethodChannel.Result) {
        scope.launch {
            try {
                val routers = ThreadBorderRouterScanner.scan(context)
                val sb = StringBuilder("[")
                routers.forEachIndexed { i, r ->
                    if (i > 0) sb.append(",")
                    sb.append("{")
                    sb.append("\"serviceName\":${jsonStr(r.serviceName)},")
                    sb.append("\"networkName\":${jsonStr(r.networkName)},")
                    sb.append("\"extPanId\":${jsonStr(r.extPanId)},")
                    sb.append("\"vendorName\":${jsonStr(r.vendorName)},")
                    sb.append("\"modelName\":${jsonStr(r.modelName)},")
                    sb.append("\"host\":${jsonStr(r.host)},")
                    sb.append("\"port\":${r.port},")
                    // txt: inline JSON object
                    sb.append("\"txt\":{")
                    r.txt.entries.forEachIndexed { j, (k, v) ->
                        if (j > 0) sb.append(",")
                        sb.append("${jsonStr(k)}:${jsonStr(v)}")
                    }
                    sb.append("}}")
                }
                sb.append("]")
                main.post { result.success(sb.toString()) }
            } catch (e: Exception) {
                Log.e(TAG, "discoverThreadNetworks error", e)
                main.post { result.error("THREAD_SCAN_ERROR", e.message, null) }
            }
        }
    }

    private fun jsonStr(s: String) = "\"${s.replace("\\","\\\\").replace("\"","\\\"")}\""

    // ── Parse setup payload (for UI pre-fill) ────────────────────────────────

    fun parsePayload(payload: String, result: MethodChannel.Result) {
        if (!ChipClient.isAvailable) {
            result.error("CHIP_SDK_UNAVAILABLE", "CHIP SDK not loaded", null)
            return
        }
        try {
            val parsed = SetupPayloadHelper.parse(payload)
            val caps = parsed.discoveryCapabilities.map { it.name }
            result.success(mapOf(
                "vendorId"             to parsed.vendorId,
                "productId"            to parsed.productId,
                "discriminator"        to parsed.discriminator,
                "hasShortDiscriminator" to parsed.hasShortDiscriminator,
                "discoveryCapabilities" to caps,   // e.g. ["BLE"], ["ON_NETWORK"], ["BLE","ON_NETWORK"]
            ))
        } catch (e: Exception) {
            result.error("PARSE_ERROR", e.message, null)
        }
    }

    fun getFabricId(result: MethodChannel.Result) {
        if (!ChipClient.isAvailable) { result.success("N/A"); return }
        val id = ChipClient.fabricId
        result.success("0x${id.toULong().toString(16).padStart(16,'0').uppercase()}")
    }

    fun readBasicInfo(nodeId: Long, result: MethodChannel.Result) =
        requireChip(result) {
            val (serial, swVer) = ClusterClient.readBasicInfo(context, nodeId)
            main.post {
                result.success(mapOf(
                    "serialNumber"    to (serial  ?: ""),
                    "softwareVersion" to (swVer   ?: ""),
                ))
            }
        }

    // ── Thermostat ────────────────────────────────────────────────────────────

    fun readThermostat(nodeId: Long, result: MethodChannel.Result) =
        requireChip(result) {
            val data = ClusterClient.readThermostat(context, nodeId)
            // MethodChannel can't carry Map<String,Int?> with null values reliably;
            // send as individual keys, using sentinel -32768 for "null / not present".
            main.post {
                result.success(mapOf(
                    "localTemp"       to (data["localTemp"]       ?: Int.MIN_VALUE),
                    "heatingSetpoint" to (data["heatingSetpoint"] ?: Int.MIN_VALUE),
                    "coolingSetpoint" to (data["coolingSetpoint"] ?: Int.MIN_VALUE),
                    "systemMode"      to (data["systemMode"]      ?: -1),
                    "controlSequence" to (data["controlSequence"] ?: -1),
                ))
            }
        }

    fun writeHeatingSetpoint(nodeId: Long, centidegrees: Int, result: MethodChannel.Result) =
        requireChip(result) {
            ClusterClient.writeHeatingSetpoint(context, nodeId, centidegrees)
            main.post { result.success(true) }
        }

    fun writeSystemMode(nodeId: Long, mode: Int, result: MethodChannel.Result) =
        requireChip(result) {
            ClusterClient.writeSystemMode(context, nodeId, mode)
            main.post { result.success(true) }
        }

    // ── Cluster Inspector — wildcard read ────────────────────────────────────

    fun readClusters(nodeId: Long, result: MethodChannel.Result) =
        requireChip(result) {
            val json = ClusterClient.readAllClusters(context, nodeId)
            main.post { result.success(json) }
        }

    // ── Read device type from Descriptor cluster ───────────────────────────────

    fun readDeviceType(nodeId: Long, result: MethodChannel.Result) =
        requireChip(result) {
            val typeId = readPrimaryDeviceType(nodeId)
            main.post { result.success(typeId) }
        }

    /**
     * Reads the primary application device-type from the Descriptor cluster.
     *
     * Strategy per Matter spec:
     *  - Endpoint 0  = Root Node (infrastructure types: 0x0011, 0x0016, …)
     *  - Endpoint 1  = Primary application endpoint (thermostat, light, …)
     *
     * We try endpoint 1 first; if it yields nothing useful we fall back to
     * endpoint 0 while skipping known infrastructure types.
     */
    private val infraTypes = setOf(0x000E, 0x000F, 0x0011, 0x0016)

    private suspend fun readPrimaryDeviceType(nodeId: Long): Int {
        // Try endpoint 1 first (primary application endpoint for most devices)
        for (ep in listOf(1, 0)) {
            try {
                val types = ClusterClient.readDeviceTypes(context, nodeId, ep)
                Log.d(TAG, "Descriptor ep=$ep types=${types.map { "0x%04X".format(it) }}")
                val appType = types.firstOrNull { it !in infraTypes }
                if (appType != null) {
                    Log.i(TAG, "Primary device type 0x%04X from ep=$ep".format(appType))
                    return appType
                }
            } catch (e: Exception) {
                Log.w(TAG, "readDeviceTypes ep=$ep failed: ${e.message}")
            }
        }
        Log.w(TAG, "No application device type found, defaulting to OnOff Light")
        return 0x0100
    }
}
