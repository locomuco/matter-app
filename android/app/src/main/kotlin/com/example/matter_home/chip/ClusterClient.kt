package com.example.matter_home.chip

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.BasicInformation
import chip.devicecontroller.ClusterIDMapping.Descriptor
import chip.devicecontroller.ClusterIDMapping.LevelControl
import chip.devicecontroller.ClusterIDMapping.OnOff
import chip.devicecontroller.ClusterIDMapping.RelativeHumidityMeasurement
import chip.devicecontroller.ClusterIDMapping.Thermostat
import chip.devicecontroller.InvokeCallback
import chip.devicecontroller.ReportCallback
import chip.devicecontroller.ResubscriptionAttemptCallback
import chip.devicecontroller.SubscriptionEstablishedCallback
import chip.devicecontroller.WriteAttributesCallback
import chip.devicecontroller.model.AttributeWriteRequest
import chip.devicecontroller.model.ChipAttributePath
import chip.devicecontroller.model.ChipPathId
import chip.devicecontroller.model.InvokeElement
import chip.devicecontroller.model.NodeState
import matter.tlv.AnonymousTag
import matter.tlv.ContextSpecificTag
import matter.tlv.TlvReader
import matter.tlv.TlvWriter
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * High-level Matter cluster client.
 *
 * Uses the modern invoke / readPath / subscribeToPath API (same as CHIPTool's
 * OnOffClientFragment) rather than the older generated ChipClusters.*  classes.
 * All operations establish a CASE session via [ChipClient.getConnectedDevicePointer].
 */
object ClusterClient {

    private const val TAG         = "ClusterClient"
    private const val ENDPOINT_1  = 1   // standard on/off endpoint for lighting / plugs

    // ── On / Off ─────────────────────────────────────────────────────────────

    /** Sends an OnOff cluster On or Off command to [nodeId]. */
    suspend fun setOnOff(context: Context, nodeId: Long, on: Boolean, endpoint: Int = ENDPOINT_1) {
        val ptr = ChipClient.getConnectedDevicePointer(context, nodeId)
        val cmdId = if (on) OnOff.Command.On.id else OnOff.Command.Off.id
        val element = InvokeElement.newInstance(endpoint, OnOff.ID, cmdId, null, null)
        invoke(context, ptr, element)
        Log.d(TAG, "OnOff ${if (on) "On" else "Off"} → nodeId=$nodeId ep=$endpoint")
    }

    /**
     * Reads the OnOff attribute from [nodeId].
     * Returns `false` if the attribute cannot be read.
     */
    suspend fun readOnOff(
        context: Context,
        nodeId: Long,
        endpoint: Int = ENDPOINT_1,
    ): Boolean {
        val ptr  = ChipClient.getConnectedDevicePointer(context, nodeId)
        val path = ChipAttributePath.newInstance(endpoint, OnOff.ID, OnOff.Attribute.OnOff.id)
        return suspendCancellableCoroutine { cont ->
            ChipClient.getController().readPath(
                object : ReportCallback {
                    override fun onError(
                        attributePath: chip.devicecontroller.model.ChipAttributePath?,
                        eventPath: chip.devicecontroller.model.ChipEventPath?,
                        ex: Exception,
                    ) {
                        Log.e(TAG, "readOnOff error", ex)
                        cont.resumeWithException(ex)
                    }

                    override fun onReport(state: NodeState?) {
                        val tlv = state
                            ?.getEndpointState(endpoint)
                            ?.getClusterState(OnOff.ID)
                            ?.getAttributeState(OnOff.Attribute.OnOff.id)
                            ?.tlv
                        val value = tlv?.let { TlvReader(it).getBool(AnonymousTag) } ?: false
                        Log.d(TAG, "readOnOff → $value (nodeId=$nodeId)")
                        if (cont.isActive) cont.resume(value)
                    }
                },
                ptr,
                listOf(path),
                null,
                false,
                0,
            )
        }
    }

    /**
     * Subscribes to the OnOff attribute, calling [onValue] whenever it changes.
     * The subscription lives until the [context] scope is cancelled.
     */
    fun subscribeOnOff(
        context: Context,
        nodeId: Long,
        endpoint: Int = ENDPOINT_1,
        minIntervalSec: Int = 1,
        maxIntervalSec: Int = 10,
        onValue: (Boolean) -> Unit,
        onError: (Exception) -> Unit,
    ) {
        val path = ChipAttributePath.newInstance(endpoint, OnOff.ID, OnOff.Attribute.OnOff.id)
        ChipClient.getController().also { ctrl ->
            ctrl.getConnectedDevicePointer(nodeId,
                object : chip.devicecontroller.GetConnectedDeviceCallbackJni.GetConnectedDeviceCallback {
                    override fun onDeviceConnected(ptr: Long) {
                        ctrl.subscribeToPath(
                            SubscriptionEstablishedCallback { id ->
                                Log.d(TAG, "OnOff subscription established subscriptionId=$id")
                            },
                            ResubscriptionAttemptCallback { cause, next ->
                                Log.d(TAG, "OnOff resubscription: cause=$cause nextMs=$next")
                            },
                            object : ReportCallback {
                                override fun onError(a: chip.devicecontroller.model.ChipAttributePath?, e: chip.devicecontroller.model.ChipEventPath?, ex: Exception) = onError(ex)
                                override fun onReport(state: NodeState?) {
                                    val tlv = state
                                        ?.getEndpointState(endpoint)
                                        ?.getClusterState(OnOff.ID)
                                        ?.getAttributeState(OnOff.Attribute.OnOff.id)?.tlv
                                    tlv?.let { onValue(TlvReader(it).getBool(AnonymousTag)) }
                                }
                            },
                            ptr,
                            listOf(path),
                            null,
                            minIntervalSec,
                            maxIntervalSec,
                            false,  // keepSubscriptions
                            false,  // isFabricFiltered
                            0,      // imTimeoutMs
                        )
                    }
                    override fun onConnectionFailure(nodeId: Long, error: Exception) = onError(error)
                })
        }
    }

    // ── Level Control ─────────────────────────────────────────────────────────

    /**
     * Sends a LevelControl MoveToLevel command.
     * [level] is 0–254 (Matter spec §3.10).
     */
    suspend fun moveToLevel(
        context: Context,
        nodeId: Long,
        level: Int,
        endpoint: Int = ENDPOINT_1,
    ) {
        val ptr = ChipClient.getConnectedDevicePointer(context, nodeId)
        val tlv = TlvWriter()
            .startStructure(AnonymousTag)
            .put(ContextSpecificTag(LevelControl.MoveToLevelCommandField.Level.id), level.toUInt())
            .put(ContextSpecificTag(LevelControl.MoveToLevelCommandField.TransitionTime.id), 0u)
            .put(ContextSpecificTag(LevelControl.MoveToLevelCommandField.OptionsMask.id), 0u)
            .put(ContextSpecificTag(LevelControl.MoveToLevelCommandField.OptionsOverride.id), 0u)
            .endStructure()
            .getEncoded()
        val element = InvokeElement.newInstance(
            endpoint, LevelControl.ID, LevelControl.Command.MoveToLevel.id, tlv, null,
        )
        invoke(context, ptr, element)
        Log.d(TAG, "MoveToLevel $level → nodeId=$nodeId ep=$endpoint")
    }

    // ── Generic invoke ────────────────────────────────────────────────────────

    private suspend fun invoke(context: Context, devicePointer: Long, element: InvokeElement) =
        suspendCancellableCoroutine<Unit> { cont ->
            ChipClient.getController().invoke(
                object : InvokeCallback {
                    override fun onError(ex: Exception?) {
                        Log.e(TAG, "invoke error", ex)
                        if (cont.isActive) cont.resumeWithException(
                            ex ?: Exception("invoke failed")
                        )
                    }
                    override fun onResponse(el: InvokeElement?, code: Long) {
                        Log.d(TAG, "invoke success code=$code")
                        if (cont.isActive) cont.resume(Unit)
                    }
                },
                devicePointer,
                element,
                0,
                0,
            )
        }

    // ── Descriptor cluster — device type list ─────────────────────────────────

    /**
     * Reads the DeviceTypeList attribute (cluster 0x001D, attribute 0x0000) from
     * endpoint 0 (root) and returns all device-type IDs the device advertises.
     *
     * The TLV is a list of DeviceTypeStruct { deviceType: uint32, revision: uint16 }.
     * Returns an empty list on any error so callers can fall back to a default.
     */
    suspend fun readDeviceTypes(
        context: Context,
        nodeId: Long,
        endpoint: Int = 0,
    ): List<Int> {
        val ptr  = ChipClient.getConnectedDevicePointer(context, nodeId)
        val path = ChipAttributePath.newInstance(
            endpoint,
            Descriptor.ID,
            Descriptor.Attribute.DeviceTypeList.id,
        )
        return suspendCancellableCoroutine { cont ->
            ChipClient.getController().readPath(
                object : ReportCallback {
                    override fun onError(
                        attributePath: chip.devicecontroller.model.ChipAttributePath?,
                        eventPath: chip.devicecontroller.model.ChipEventPath?,
                        ex: Exception,
                    ) {
                        Log.e(TAG, "readDeviceTypes error", ex)
                        if (cont.isActive) cont.resume(emptyList())
                    }

                    override fun onReport(state: NodeState?) {
                        val tlv = state
                            ?.getEndpointState(endpoint)
                            ?.getClusterState(Descriptor.ID)
                            ?.getAttributeState(Descriptor.Attribute.DeviceTypeList.id)
                            ?.tlv

                        if (tlv == null) {
                            if (cont.isActive) cont.resume(emptyList())
                            return
                        }

                        val types = mutableListOf<Int>()
                        Log.d(TAG, "DeviceTypeList TLV bytes (${tlv.size}): " +
                            tlv.take(32).joinToString(" ") { "%02X".format(it) })
                        try {
                            val reader = TlvReader(tlv)
                            // Attribute value is encoded as TLV Array (0x16) with AnonymousTag
                            reader.enterArray(AnonymousTag)
                            while (!reader.isEndOfContainer()) {
                                reader.enterStructure(AnonymousTag)
                                // Field 0 = device_type (uint32), field 1 = revision
                                // Must use getULong — device type IDs are unsigned and getLong
                                // rejects UnsignedIntValue (e.g. 0x0301 = thermostat)
                                val typeId = reader.getULong(ContextSpecificTag(0)).toInt()
                                types.add(typeId)
                                // skip revision (field 1) and any extras
                                while (!reader.isEndOfContainer()) reader.skipElement()
                                reader.exitContainer()
                            }
                            reader.exitContainer()
                        } catch (e: Exception) {
                            Log.w(TAG, "DeviceTypeList TLV parse error: ${e.message}", e)
                        }

                        if (cont.isActive) cont.resume(types)
                    }
                },
                ptr,
                listOf(path),
                null,
                false,
                0,
            )
        }
    }

    // ── Basic Information cluster ─────────────────────────────────────────────

    /**
     * Reads SerialNumber (0x000E) and SoftwareVersionString (0x000A) from the
     * Basic Information cluster (0x0028) on endpoint 0 (root).
     * Returns a pair (serialNumber, softwareVersionString), both nullable.
     */
    suspend fun readBasicInfo(context: Context, nodeId: Long): Pair<String?, String?> {
        val ptr = ChipClient.getConnectedDevicePointer(context, nodeId)
        val paths = listOf(
            ChipAttributePath.newInstance(0, BasicInformation.ID, BasicInformation.Attribute.SerialNumber.id),
            ChipAttributePath.newInstance(0, BasicInformation.ID, BasicInformation.Attribute.SoftwareVersionString.id),
        )
        return suspendCancellableCoroutine { cont ->
            var lastState: NodeState? = null
            ChipClient.getController().readPath(
                object : ReportCallback {
                    override fun onError(a: chip.devicecontroller.model.ChipAttributePath?, e: chip.devicecontroller.model.ChipEventPath?, ex: Exception) {
                        Log.e(TAG, "readBasicInfo error", ex)
                        if (cont.isActive) cont.resume(Pair(null, null))
                    }
                    override fun onReport(state: NodeState?) { if (state != null) lastState = state }
                    override fun onDone() {
                        val cluster = lastState?.getEndpointState(0)?.getClusterState(BasicInformation.ID)
                        fun strAttr(id: Long) = cluster?.getAttributeState(id)
                            ?.getValue()?.let { it as? String }
                        val serial = strAttr(BasicInformation.Attribute.SerialNumber.id)
                        val swVer  = strAttr(BasicInformation.Attribute.SoftwareVersionString.id)
                        Log.d(TAG, "readBasicInfo serial=$serial swVer=$swVer")
                        if (cont.isActive) cont.resume(Pair(serial, swVer))
                    }
                },
                ptr, paths, null, false, 0,
            )
        }
    }

    // ── Thermostat cluster ────────────────────────────────────────────────────

    /**
     * Reads LocalTemperature, OccupiedHeatingSetpoint, OccupiedCoolingSetpoint,
     * SystemMode and ControlSequenceOfOperation from the Thermostat cluster.
     * All temperatures are in centidegrees (0.01 °C units); divide by 100 for °C.
     * Returns a map with nullable Int values for each key.
     */
    suspend fun readThermostat(
        context: Context,
        nodeId: Long,
        endpoint: Int = ENDPOINT_1,
    ): Map<String, Int?> {
        val ptr = ChipClient.getConnectedDevicePointer(context, nodeId)
        val paths = listOf(
            ChipAttributePath.newInstance(endpoint, Thermostat.ID, Thermostat.Attribute.LocalTemperature.id),
            ChipAttributePath.newInstance(endpoint, Thermostat.ID, Thermostat.Attribute.OccupiedHeatingSetpoint.id),
            ChipAttributePath.newInstance(endpoint, Thermostat.ID, Thermostat.Attribute.OccupiedCoolingSetpoint.id),
            ChipAttributePath.newInstance(endpoint, Thermostat.ID, Thermostat.Attribute.SystemMode.id),
            ChipAttributePath.newInstance(endpoint, Thermostat.ID, Thermostat.Attribute.ControlSequenceOfOperation.id),
        )
        return suspendCancellableCoroutine { cont ->
            var lastState: NodeState? = null
            ChipClient.getController().readPath(
                object : ReportCallback {
                    override fun onError(
                        a: chip.devicecontroller.model.ChipAttributePath?,
                        e: chip.devicecontroller.model.ChipEventPath?,
                        ex: Exception,
                    ) {
                        Log.e(TAG, "readThermostat error", ex)
                        if (cont.isActive) cont.resume(emptyMap())
                    }
                    override fun onReport(state: NodeState?) {
                        if (state != null) lastState = state
                    }
                    override fun onDone() {
                        val cluster = lastState
                            ?.getEndpointState(endpoint)
                            ?.getClusterState(Thermostat.ID)
                        // Returns Int? — maps 0x8000 (Matter nullable int16 null sentinel) to null
                        fun attr(id: Long): Int? {
                            val v = cluster?.getAttributeState(id)?.getValue()
                                ?.let { (it as? Number)?.toInt() }
                                ?: return null
                            // LocalTemperature null sentinel per Matter spec §4.3.9.3
                            if (v == 0x8000) return null
                            return v
                        }
                        val result = mapOf(
                            "localTemp"       to attr(Thermostat.Attribute.LocalTemperature.id),
                            "heatingSetpoint" to attr(Thermostat.Attribute.OccupiedHeatingSetpoint.id),
                            "coolingSetpoint" to attr(Thermostat.Attribute.OccupiedCoolingSetpoint.id),
                            "systemMode"      to attr(Thermostat.Attribute.SystemMode.id),
                            "controlSequence" to attr(Thermostat.Attribute.ControlSequenceOfOperation.id),
                        )
                        Log.d(TAG, "readThermostat → $result")
                        if (cont.isActive) cont.resume(result)
                    }
                },
                ptr, paths, null, false, 0,
            )
        }
    }

    /**
     * Writes [centidegrees] (int16, 0.01 °C units) to OccupiedHeatingSetpoint.
     * E.g. pass 2100 to set 21.00 °C.
     */
    suspend fun writeHeatingSetpoint(
        context: Context,
        nodeId: Long,
        centidegrees: Int,
        endpoint: Int = ENDPOINT_1,
    ) {
        val ptr = ChipClient.getConnectedDevicePointer(context, nodeId)
        // OccupiedHeatingSetpoint is int16 — encode as signed short TLV
        val tlv = TlvWriter().put(AnonymousTag, centidegrees.toShort()).getEncoded()
        val req = AttributeWriteRequest.newInstance(
            endpoint,
            Thermostat.ID,
            Thermostat.Attribute.OccupiedHeatingSetpoint.id,
            tlv,
        )
        suspendCancellableCoroutine<Unit> { cont ->
            ChipClient.getController().write(
                object : WriteAttributesCallback {
                    override fun onError(path: chip.devicecontroller.model.ChipAttributePath?, ex: Exception) {
                        Log.e(TAG, "writeHeatingSetpoint error", ex)
                        if (cont.isActive) cont.resumeWithException(ex)
                    }
                    override fun onResponse(path: chip.devicecontroller.model.ChipAttributePath?, status: chip.devicecontroller.model.Status?) {
                        Log.d(TAG, "writeHeatingSetpoint response status=$status")
                    }
                    override fun onDone() {
                        if (cont.isActive) cont.resume(Unit)
                    }
                },
                ptr,
                listOf(req),
                0,
                0,
            )
        }
        Log.d(TAG, "writeHeatingSetpoint ${centidegrees / 100.0}°C → nodeId=$nodeId ep=$endpoint")
    }

    /**
     * Writes [mode] (uint8 enum) to SystemMode attribute (0x001C).
     * 0=Off 1=Auto 3=Cool 4=Heat 5=EmergencyHeat 7=FanOnly
     */
    suspend fun writeSystemMode(
        context: Context,
        nodeId: Long,
        mode: Int,
        endpoint: Int = ENDPOINT_1,
    ) {
        val ptr = ChipClient.getConnectedDevicePointer(context, nodeId)
        // SystemMode is enum8 (uint8) — use putUnsigned so it encodes as unsigned
        val tlv = TlvWriter().putUnsigned(AnonymousTag, mode).getEncoded()
        val req = AttributeWriteRequest.newInstance(
            endpoint,
            Thermostat.ID,
            Thermostat.Attribute.SystemMode.id,
            tlv,
        )
        suspendCancellableCoroutine<Unit> { cont ->
            ChipClient.getController().write(
                object : WriteAttributesCallback {
                    override fun onError(path: chip.devicecontroller.model.ChipAttributePath?, ex: Exception) {
                        Log.e(TAG, "writeSystemMode error", ex)
                        if (cont.isActive) cont.resumeWithException(ex)
                    }
                    override fun onResponse(path: chip.devicecontroller.model.ChipAttributePath?, status: chip.devicecontroller.model.Status?) {
                        Log.d(TAG, "writeSystemMode response status=$status")
                    }
                    override fun onDone() {
                        if (cont.isActive) cont.resume(Unit)
                    }
                },
                ptr, listOf(req), 0, 0,
            )
        }
        Log.d(TAG, "writeSystemMode mode=$mode → nodeId=$nodeId ep=$endpoint")
    }

    // ── Relative Humidity Measurement cluster ─────────────────────────────────

    /**
     * Reads MeasuredValue (0x0000) from the Relative Humidity Measurement
     * cluster (0x0405) on [endpoint].
     *
     * The value is in units of 0.01 % RH (e.g. 5723 = 57.23 %).
     * Returns null when the attribute is not present or reports the null
     * sentinel (0xFFFF per Matter spec §2.6.5).
     */
    suspend fun readHumidity(
        context: Context,
        nodeId: Long,
        endpoint: Int = ENDPOINT_1,
    ): Int? {
        val ptr  = ChipClient.getConnectedDevicePointer(context, nodeId)
        val path = ChipAttributePath.newInstance(
            endpoint,
            RelativeHumidityMeasurement.ID,
            RelativeHumidityMeasurement.Attribute.MeasuredValue.id,
        )
        return suspendCancellableCoroutine { cont ->
            ChipClient.getController().readPath(
                object : ReportCallback {
                    override fun onError(
                        attributePath: chip.devicecontroller.model.ChipAttributePath?,
                        eventPath: chip.devicecontroller.model.ChipEventPath?,
                        ex: Exception,
                    ) {
                        Log.w(TAG, "readHumidity not available: ${ex.message}")
                        if (cont.isActive) cont.resume(null)
                    }

                    override fun onReport(state: NodeState?) {
                        val raw = state
                            ?.getEndpointState(endpoint)
                            ?.getClusterState(RelativeHumidityMeasurement.ID)
                            ?.getAttributeState(RelativeHumidityMeasurement.Attribute.MeasuredValue.id)
                            ?.getValue()
                            ?.let { (it as? Number)?.toInt() }
                        // 0xFFFF is the Matter null sentinel for this attribute
                        val value = if (raw == null || raw == 0xFFFF) null else raw
                        Log.d(TAG, "readHumidity → ${value?.let { "${it / 100.0}%" } ?: "null"}")
                        if (cont.isActive) cont.resume(value)
                    }
                },
                ptr,
                listOf(path),
                null,
                false,
                0,
            )
        }
    }

    // ── Wildcard cluster/attribute read (for Cluster Inspector) ──────────────

    /**
     * Reads ALL attributes from ALL clusters on ALL endpoints using a wildcard
     * path. Returns a JSON string shaped as:
     *   [ { "endpoint": 0,
     *       "clusterId": 40,
     *       "attributes": [ { "id": 1, "value": "tado GmbH" }, … ] }, … ]
     *
     * onReport may be called multiple times with partial data; onDone signals
     * the complete interaction so we resume there.
     */
    suspend fun readAllClusters(context: Context, nodeId: Long): String {
        val ptr  = ChipClient.getConnectedDevicePointer(context, nodeId)
        val path = ChipAttributePath.newInstance(
            ChipPathId.forWildcard(),
            ChipPathId.forWildcard(),
            ChipPathId.forWildcard(),
        )
        return suspendCancellableCoroutine { cont ->
            var accumulated: NodeState? = null
            ChipClient.getController().readPath(
                object : ReportCallback {
                    override fun onError(
                        a: chip.devicecontroller.model.ChipAttributePath?,
                        e: chip.devicecontroller.model.ChipEventPath?,
                        ex: Exception,
                    ) {
                        Log.e(TAG, "readAllClusters error", ex)
                        if (cont.isActive) cont.resume("[]")
                    }

                    override fun onReport(state: NodeState?) {
                        if (state != null) accumulated = state
                    }

                    override fun onDone() {
                        val json = buildClustersJson(accumulated)
                        if (cont.isActive) cont.resume(json)
                    }
                },
                ptr,
                listOf(path),
                null,
                false,
                0,
            )
        }
    }

    private fun buildClustersJson(state: NodeState?): String {
        if (state == null) return "[]"
        val sb = StringBuilder("[")
        var firstCluster = true
        try {
            state.getEndpointStates().forEach { (epId, epState) ->
                epState.getClusterStates().forEach { (clusterId, clusterState) ->
                    if (!firstCluster) sb.append(",")
                    firstCluster = false
                    sb.append("{\"endpoint\":$epId,\"clusterId\":$clusterId,\"attributes\":[")
                    var firstAttr = true
                    clusterState.getAttributeStates().forEach { (attrId, attrState) ->
                        if (!firstAttr) sb.append(",")
                        firstAttr = false
                        val raw = try {
                            val v = attrState.getValue()
                            when (v) {
                                null       -> "null"
                                is Boolean -> v.toString()
                                is Number  -> v.toString()
                                else       -> "\"${jsonEscape(v.toString())}\""
                            }
                        } catch (_: Exception) { "\"?\"" }
                        sb.append("{\"id\":$attrId,\"value\":$raw}")
                    }
                    sb.append("]}")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "buildClustersJson error", e)
        }
        sb.append("]")
        return sb.toString()
    }

    /** Properly escapes a string for embedding in a JSON double-quoted value. */
    private fun jsonEscape(s: String): String = buildString(s.length + 8) {
        for (c in s) {
            when (c) {
                '\\'     -> append("\\\\")
                '"'      -> append("\\\"")
                '\n'     -> append("\\n")
                '\r'     -> append("\\r")
                '\t'     -> append("\\t")
                '\b'     -> append("\\b")
                '\u000C' -> append("\\f")
                else     -> if (c.code < 0x20) append("\\u%04x".format(c.code)) else append(c)
            }
        }
    }
}
