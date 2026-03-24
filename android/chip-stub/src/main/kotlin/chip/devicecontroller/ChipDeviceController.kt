package chip.devicecontroller

import chip.ChipSdkStubException
import chip.devicecontroller.model.AttributeWriteRequest
import chip.devicecontroller.model.ChipAttributePath
import chip.devicecontroller.model.ChipEventPath
import chip.devicecontroller.model.InvokeElement

/** Stub for chip.devicecontroller.ChipDeviceController */
class ChipDeviceController(params: ControllerParams) {

    companion object {
        @JvmStatic fun loadJni(): Unit = throw ChipSdkStubException()
    }

    interface CompletionListener {
        fun onConnectDeviceComplete()
        fun onStatusUpdate(status: Int)
        fun onPairingComplete(code: Long)
        fun onPairingDeleted(code: Long)
        fun onCommissioningComplete(nodeId: Long, errorCode: Long)
        fun onReadCommissioningInfo(
            vendorId: Int, productId: Int,
            wifiEndpointId: Int, threadEndpointId: Int,
        )
        fun onCommissioningStatusUpdate(nodeId: Long, stage: String, errorCode: Long)
        fun onCommissioningStageStart(nodeId: Long, stage: String)
        fun onNotifyChipConnectionClosed()
        fun onCloseBleComplete()
        fun onError(error: Throwable?)
        fun onOpCSRGenerationComplete(csr: ByteArray)
        fun onICDRegistrationInfoRequired()
        fun onICDRegistrationComplete(errorCode: Long, icdDeviceInfo: ICDDeviceInfo)
    }

    val compressedFabricId: Long get() = throw ChipSdkStubException()

    fun setCompletionListener(l: CompletionListener?): Unit = throw ChipSdkStubException()

    fun setDeviceAttestationDelegate(
        failureSafeTimeoutSecs: Int,
        delegate: DeviceAttestationDelegate,
    ): Unit = throw ChipSdkStubException()

    fun continueCommissioning(
        devicePtr: Long,
        ignoreAttestationFailure: Boolean,
    ): Unit = throw ChipSdkStubException()

    fun pairDeviceThroughBLE(
        gatt: android.bluetooth.BluetoothGatt?,
        connId: Int,
        nodeId: Long,
        setupPinCode: Long,
        params: CommissionParameters,
    ): Unit = throw ChipSdkStubException()

    fun pairDeviceWithAddress(
        nodeId: Long,
        address: String,
        port: Int,
        discriminator: Int,
        setupPinCode: Long,
        params: CommissionParameters,
    ): Unit = throw ChipSdkStubException()

    fun getConnectedDevicePointer(
        nodeId: Long,
        callback: GetConnectedDeviceCallbackJni.GetConnectedDeviceCallback,
    ): Unit = throw ChipSdkStubException()

    fun invoke(
        callback: InvokeCallback,
        devicePointer: Long,
        invokeElement: InvokeElement,
        timedRequestTimeoutMs: Int,
        imTimeoutMs: Int,
    ): Unit = throw ChipSdkStubException()

    fun readPath(
        callback: ReportCallback,
        devicePointer: Long,
        attributePaths: List<ChipAttributePath>?,
        eventPaths: List<ChipEventPath>?,
        isFabricFiltered: Boolean,
        imTimeoutMs: Int,
    ): Unit = throw ChipSdkStubException()

    fun write(
        callback: WriteAttributesCallback,
        devicePointer: Long,
        attributeList: List<AttributeWriteRequest>,
        timedRequestTimeoutMs: Int,
        imTimeoutMs: Int,
    ): Unit = throw ChipSdkStubException()

    fun subscribeToPath(
        subscriptionEstablishedCallback: SubscriptionEstablishedCallback,
        resubscriptionAttemptCallback: ResubscriptionAttemptCallback,
        reportCallback: ReportCallback,
        devicePointer: Long,
        attributePaths: List<ChipAttributePath>?,
        eventPaths: List<ChipEventPath>?,
        minInterval: Int,
        maxInterval: Int,
        keepSubscriptions: Boolean,
        autoResubscribe: Boolean,
        imTimeoutMs: Int,
    ): Unit = throw ChipSdkStubException()

    fun unpairDevice(nodeId: Long): Unit = throw ChipSdkStubException()

    fun close(): Unit = throw ChipSdkStubException()
}
