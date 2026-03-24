package chip.devicecontroller.model

import chip.ChipSdkStubException

class Status private constructor() {
    companion object {
        @JvmStatic fun newInstance(status: Int): Status = throw ChipSdkStubException()
    }
}

class AttributeWriteRequest private constructor() {
    fun getTlvByteArray(): ByteArray = throw ChipSdkStubException()
    companion object {
        @JvmStatic fun newInstance(
            endpointId: Int, clusterId: Long, attributeId: Long, tlv: ByteArray,
        ): AttributeWriteRequest = throw ChipSdkStubException()
    }
}

class ChipPathId private constructor() {
    fun getId(): Long = throw ChipSdkStubException()
    companion object {
        @JvmStatic fun forId(id: Long): ChipPathId = throw ChipSdkStubException()
        @JvmStatic fun forWildcard(): ChipPathId = throw ChipSdkStubException()
    }
}

class ChipAttributePath private constructor() {
    companion object {
        @JvmStatic fun newInstance(
            endpointId: Int,
            clusterId: Long,
            attributeId: Long,
        ): ChipAttributePath = throw ChipSdkStubException()

        @JvmStatic fun newInstance(
            endpointId: ChipPathId,
            clusterId: ChipPathId,
            attributeId: ChipPathId,
        ): ChipAttributePath = throw ChipSdkStubException()
    }
}

class ChipEventPath private constructor() {
    companion object {
        @JvmStatic fun newInstance(
            endpointId: Int,
            clusterId: Long,
            eventId: Long,
        ): ChipEventPath = throw ChipSdkStubException()
    }
}

class InvokeElement private constructor() {
    companion object {
        @JvmStatic fun newInstance(
            endpointId: Int,
            clusterId: Long,
            commandId: Long,
            tlv: ByteArray?,
            json: String?,
        ): InvokeElement = throw ChipSdkStubException()
    }
}

class NodeState {
    fun getEndpointState(endpointId: Int): EndpointState? = throw ChipSdkStubException()
    fun getEndpointStates(): Map<Int, EndpointState> = throw ChipSdkStubException()
}

class EndpointState {
    fun getClusterState(clusterId: Long): ClusterState? = throw ChipSdkStubException()
    fun getClusterStates(): Map<Long, ClusterState> = throw ChipSdkStubException()
}

class ClusterState {
    fun getAttributeState(attributeId: Long): AttributeState? = throw ChipSdkStubException()
    fun getAttributeStates(): Map<Long, AttributeState> = throw ChipSdkStubException()
}

class AttributeState {
    val tlv: ByteArray? get() = throw ChipSdkStubException()
    fun getValue(): Any? = throw ChipSdkStubException()
    fun getJson(): org.json.JSONObject? = throw ChipSdkStubException()
}
